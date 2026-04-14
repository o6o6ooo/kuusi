import SwiftUI

private extension SubscriptionStoreError {
    var appMessageID: AppMessage.ID? {
        switch self {
        case .productUnavailable:
            return .subscriptionUnavailable
        case .purchasePending:
            return .purchasePendingApproval
        case .purchaseCancelled:
            return nil
        case .purchaseUnverified:
            return .purchaseCouldNotBeVerified
        case .manageSubscriptionsUnavailable:
            return .failedToOpenManageSubscriptions
        case .unknown:
            return .purchaseFailed
        }
    }
}

private struct SubscriptionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.97 : 1)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) private var colorScheme

    let usageMB: Double

    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var currentPlan: AppPlan { subscriptionStore.isPremiumActive ? .premium : .free }
    private var effectiveQuotaMB: Double { currentPlan.quotaMB }
    private var premiumRenewalText: String? {
        guard let renewalDate = subscriptionStore.renewalDate else { return nil }
        let label = subscriptionStore.willAutoRenew ? "Renews on" : "Expires on"
        return "\(label) \(formatDate(renewalDate))"
    }
    private var usageRatio: Double {
        guard effectiveQuotaMB > 0 else { return 0 }
        return min(max(usageMB / effectiveQuotaMB, 0), 1)
    }
    private var usageText: String {
        "\(formatStorage(usageMB))/\(formatStorage(effectiveQuotaMB))"
    }
    private var planCardWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 240 : 200
    }
    @State private var billingMessage: AppMessage?
    @State private var clearBillingMessageTask: Task<Void, Never>?
    @State private var subscriptionRefreshTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            storageCard
            subscriptionCard
        }
        .onChange(of: billingMessage) { _, newValue in
            scheduleBillingMessageAutoClear(for: newValue)
        }
        .onDisappear {
            clearBillingMessageTask?.cancel()
            clearBillingMessageTask = nil
            subscriptionRefreshTask?.cancel()
            subscriptionRefreshTask = nil
        }
        .appToastMessage(billingMessage) {
            billingMessage = nil
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your storage")
                .font(.title3.weight(.bold))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(usageText)
                        .font(.caption.weight(.semibold))
                }

                GeometryReader { proxy in
                    let barWidth = max(0, proxy.size.width * usageRatio)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(fieldBackground)
                            .frame(height: 22)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: barWidth, height: 22)
                    }
                }
                .frame(height: 22)
            }
            .padding(14)
            .appCardSurface(cornerRadius: 16)
        }
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscription")
                .font(.title3.weight(.bold))

            Text("Upgrade to premium, cancel anytime.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    planCard(
                        title: AppPlan.free.title,
                        features: AppPlan.free.featureLines,
                        footerText: nil,
                        footerActionTitle: nil,
                        isSelected: currentPlan == .free,
                        action: nil
                    )

                    if currentPlan == .free {
                        Button {
                            Task {
                                await purchasePremium()
                            }
                        } label: {
                            planCard(
                                title: AppPlan.premium.title,
                                features: AppPlan.premium.featureLines,
                                footerText: subscriptionStore.premiumPriceLabel ?? AppPlan.premium.priceLabel,
                                footerActionTitle: nil,
                                isSelected: false,
                                action: nil
                            )
                        }
                        .buttonStyle(SubscriptionCardButtonStyle())
                    } else {
                        planCard(
                            title: AppPlan.premium.title,
                            features: AppPlan.premium.featureLines,
                            footerText: premiumRenewalText,
                            footerActionTitle: subscriptionStore.willAutoRenew ? "Cancel subscription" : "Continue subscription",
                            isSelected: true,
                            action: {
                                Task {
                                    await openManageSubscriptions()
                                }
                            }
                        )
                    }
                }
            }

            if currentPlan == .free {
                HStack(spacing: 6) {
                    Text("Already got premium?")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Restore purchases.") {
                        Task {
                            await restorePurchases()
                        }
                    }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func scheduleBillingMessageAutoClear(for value: AppMessage?) {
        clearBillingMessageTask?.cancel()
        clearBillingMessageTask = AppMessageAutoClear.schedule(
            for: value,
            currentMessage: { billingMessage },
            clear: { billingMessage = nil }
        )
    }

    @MainActor
    private func purchasePremium() async {
        do {
            try await subscriptionStore.purchasePremium()
            billingMessage = AppMessage(.premiumUnlocked, .success)
        } catch let error as SubscriptionStoreError {
            guard let messageID = error.appMessageID else {
                return
            }
            billingMessage = AppMessage(messageID, .error)
        } catch {
            billingMessage = AppMessage(.purchaseFailed, .error)
        }
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await subscriptionStore.restorePurchases()
            billingMessage = currentPlan == .premium ? AppMessage(.purchasesRestored, .success) : AppMessage(.noActivePurchasesFound, .success)
        } catch {
            billingMessage = AppMessage(.failedToRestorePurchases, .error)
        }
    }

    @MainActor
    private func openManageSubscriptions() async {
        do {
            try await subscriptionStore.openManageSubscriptions()
            scheduleSubscriptionRefresh()
        } catch let error as SubscriptionStoreError {
            billingMessage = AppMessage(error.appMessageID ?? .failedToOpenManageSubscriptions, .error)
        } catch {
            billingMessage = AppMessage(.failedToOpenManageSubscriptions, .error)
        }
    }

    private func formatStorage(_ mb: Double) -> String {
        if mb >= 1024 {
            let gb = mb / 1024
            if abs(gb.rounded() - gb) < 0.01 {
                return "\(Int(gb.rounded()))GB"
            }
            return String(format: "%.1fGB", gb)
        }

        if mb.rounded() >= mb - 0.01 {
            return "\(Int(mb.rounded()))MB"
        }
        return String(format: "%.0fMB", mb)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func scheduleSubscriptionRefresh() {
        subscriptionRefreshTask?.cancel()
        subscriptionRefreshTask = Task { @MainActor in
            for delay in [300_000_000, 1_000_000_000, 2_500_000_000] {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                if Task.isCancelled { return }
                await subscriptionStore.prepare()
            }
        }
    }

    private func planCard(
        title: String,
        features: [String],
        footerText: String?,
        footerActionTitle: String?,
        isSelected: Bool,
        action: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.bold))

                Spacer(minLength: 12)

                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .medium))
                    .opacity(isSelected ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    Text("•  \(feature)")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if let footerText {
                Text(footerText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(footerActionTitle == nil ? .primary : .secondary)
            }

            if let footerActionTitle, let action {
                Button(footerActionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(18)
        .frame(width: planCardWidth, alignment: .topLeading)
        .frame(minHeight: 160, alignment: .topLeading)
        .appCardSurface(cornerRadius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}
