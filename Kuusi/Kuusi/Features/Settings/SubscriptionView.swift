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
    private var currentPlan: AppPlan { displaySnapshot.isPremiumActive ? .premium : .free }
    private var effectiveQuotaMB: Double { currentPlan.quotaMB }
    private var premiumRenewalText: String? {
        guard let renewalDate = displaySnapshot.renewalDate else { return nil }
        let label = displaySnapshot.willAutoRenew ? "Renews on" : "Expires on"
        return "\(label) \(formatDate(renewalDate))"
    }
    private var usageRatio: Double {
        guard effectiveQuotaMB > 0 else { return 0 }
        return min(max(usageMB / effectiveQuotaMB, 0), 1)
    }
    private var usageText: String {
        "\(formatStorage(usageMB))/\(formatStorage(effectiveQuotaMB))"
    }
    private var isStorageLimitReached: Bool {
        PlanAccessPolicy.isStorageLimitReached(
            usageMB: usageMB,
            isPremiumActive: displaySnapshot.isPremiumActive
        )
    }
    private var storageBarHeight: CGFloat { 10 }
    private var planCardWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 220 : 200
    }
    private var planCardHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 220 : 200
    }
    @State private var billingMessage: AppMessage?
    @State private var clearBillingMessageTask: Task<Void, Never>?
    @State private var displaySnapshot = SubscriptionStore.makeEntitlementSnapshot(
        premiumActive: false,
        renewalDate: nil,
        autoRenew: false
    )
    @State private var pendingManageSubscriptionSnapshot: SubscriptionStore.EntitlementSnapshot?
    @State private var pendingManageSubscriptionClearTask: Task<Void, Never>?

    private var isSubscriptionUpdatePending: Bool {
        pendingManageSubscriptionSnapshot != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            storageCard
            subscriptionCard
        }
        .overlay(alignment: .topLeading) {
            Group {
                Text("ui-screen-subscription")
                    .accessibilityIdentifier("ui-screen-subscription")
                Text(displaySnapshot.isPremiumActive ? "ui-subscription-premium" : "ui-subscription-free")
                    .accessibilityIdentifier(displaySnapshot.isPremiumActive ? "ui-subscription-premium" : "ui-subscription-free")
            }
            .font(.caption2)
            .foregroundStyle(.clear)
            .frame(width: 0, height: 0)
            .clipped()
            .allowsHitTesting(false)
        }
        .onAppear {
            syncDisplaySnapshotFromStore()
        }
        .onChange(of: subscriptionStore.entitlementSnapshot) { _, newValue in
            displaySnapshot = newValue
            handlePotentialSubscriptionStatusChange(with: newValue)
        }
        .onChange(of: billingMessage) { _, newValue in
            scheduleBillingMessageAutoClear(for: newValue)
        }
        .onDisappear {
            clearBillingMessageTask?.cancel()
            clearBillingMessageTask = nil
            pendingManageSubscriptionClearTask?.cancel()
            pendingManageSubscriptionClearTask = nil
            pendingManageSubscriptionSnapshot = nil
        }
        .appToastMessage(billingMessage) {
            billingMessage = nil
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your storage")
                .font(.title3.weight(.bold))

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
                        .frame(height: storageBarHeight)
                    if barWidth > 0 {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(barWidth, storageBarHeight), height: storageBarHeight)
                    }
                }
            }
            .frame(height: storageBarHeight)

            if isStorageLimitReached {
                Text("You've reached your storage limit.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscription")
                .font(.title3.weight(.bold))

            Text("Upgrade to premium, cancel anytime.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if isSubscriptionUpdatePending {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating subscription...")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

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
                        .accessibilityIdentifier("subscription-premium-card-button")
                    } else {
                        planCard(
                            title: AppPlan.premium.title,
                            features: AppPlan.premium.featureLines,
                            footerText: premiumRenewalText,
                            footerActionTitle: displaySnapshot.willAutoRenew ? "Cancel subscription" : "Continue subscription",
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
                        .accessibilityIdentifier("subscription-restore-purchases-button")
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
        let initialSnapshot = displaySnapshot
        pendingManageSubscriptionSnapshot = initialSnapshot
        schedulePendingManageSubscriptionClear()

        do {
            try await subscriptionStore.openManageSubscriptions()
            syncDisplaySnapshotFromStore()
        } catch let error as SubscriptionStoreError {
            clearPendingManageSubscriptionTracking()
            billingMessage = AppMessage(error.appMessageID ?? .failedToOpenManageSubscriptions, .error)
        } catch {
            clearPendingManageSubscriptionTracking()
            billingMessage = AppMessage(.failedToOpenManageSubscriptions, .error)
        }
    }

    private func formatStorage(_ mb: Double) -> String {
        if mb >= 1024 {
            let gb = mb / 1024
            return String(format: "%.2fGB", gb)
        }

        return String(format: "%.2fMB", mb)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    @MainActor
    private func presentSubscriptionStatusChange(
        from previousSnapshot: SubscriptionStore.EntitlementSnapshot,
        currentSnapshot: SubscriptionStore.EntitlementSnapshot
    ) -> Bool {
        guard previousSnapshot.willAutoRenew != currentSnapshot.willAutoRenew else {
            return false
        }

        clearPendingManageSubscriptionTracking()
        billingMessage = AppMessage(currentSnapshot.willAutoRenew ? .subscriptionResumed : .subscriptionCancelled, .success)
        return true
    }

    @MainActor
    private func syncDisplaySnapshotFromStore() {
        displaySnapshot = subscriptionStore.entitlementSnapshot
    }

    @MainActor
    private func handlePotentialSubscriptionStatusChange(with currentSnapshot: SubscriptionStore.EntitlementSnapshot) {
        guard let previousSnapshot = pendingManageSubscriptionSnapshot else { return }
        _ = presentSubscriptionStatusChange(from: previousSnapshot, currentSnapshot: currentSnapshot)
    }

    @MainActor
    private func clearPendingManageSubscriptionTracking() {
        pendingManageSubscriptionClearTask?.cancel()
        pendingManageSubscriptionClearTask = nil
        pendingManageSubscriptionSnapshot = nil
    }

    private func schedulePendingManageSubscriptionClear() {
        pendingManageSubscriptionClearTask?.cancel()
        pendingManageSubscriptionClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if Task.isCancelled { return }
            pendingManageSubscriptionSnapshot = nil
            pendingManageSubscriptionClearTask = nil
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

            VStack(alignment: .leading, spacing: 6) {
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
        }
        .padding(18)
        .frame(width: planCardWidth, alignment: .topLeading)
        .frame(height: planCardHeight, alignment: .topLeading)
        .appCardSurface(cornerRadius: 24, shadowRadius: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}
