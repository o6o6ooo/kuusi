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
    let billingMessage: InlineMessage?
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .regular))
                        .opacity(currentPlan == .free ? 1 : 0)
                        .frame(width: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free")
                            .font(.body.weight(.semibold))

                        Text(AppPlan.free.featureLines.map { "•  \($0)" }.joined(separator: "\n"))
                            .font(.callout.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .leading)

            if currentPlan == .free {
                Button(action: onPurchase) {
                    premiumSubscriptionCardContent
                }
                .buttonStyle(SubscriptionCardButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                premiumSubscriptionCardContent
            }

            if let billingMessage {
                InlineMessageView(message: billingMessage)
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

    private var premiumSubscriptionCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .regular))
                    .opacity(currentPlan == .premium ? 1 : 0)
                    .frame(width: 84)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Premium")
                        .font(.body.weight(.semibold))

                    if let premiumPriceLabel = subscriptionStore.premiumPriceLabel ?? AppPlan.premium.priceLabel {
                        Text(premiumPriceLabel)
                            .font(.callout.weight(.medium))
                    }

                    Text(AppPlan.premium.featureLines.map { "•  \($0)" }.joined(separator: "\n"))
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)

                    if let renewalText, currentPlan == .premium {
                        Text(renewalText)
                            .font(.callout.weight(.medium))
                    }

                    if currentPlan == .premium {
                        Button(subscriptionStore.willAutoRenew ? "Cancel subscription" : "Continue subscription", action: onManage)
                            .buttonStyle(.plain)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
