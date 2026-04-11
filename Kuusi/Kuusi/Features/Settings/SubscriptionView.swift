import SwiftUI

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

    let currentPlan: AppPlan
    let usageRatio: Double
    let usageText: String
    let renewalText: String?
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onManage: () -> Void

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var cardBorder: Color { AppTheme.cardBorder(for: colorScheme) }
    private var planCardWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 240 : 200
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            storageCard
            subscriptionCard
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
                        .font(.body.weight(.semibold))
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

                if currentPlan == .free {
                    HStack(spacing: 6) {
                        Text("Need more storage?")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Upgrade to premium.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .padding(14)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                        Button(action: onPurchase) {
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
                            footerText: renewalText,
                            footerActionTitle: subscriptionStore.willAutoRenew ? "Cancel subscription" : "Continue subscription",
                            isSelected: true,
                            action: onManage
                        )
                    }
                }
            }

            if currentPlan == .free {
                HStack(spacing: 6) {
                    Text("Already got premium?")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Restore purchases.", action: onRestore)
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
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
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(cardBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}
