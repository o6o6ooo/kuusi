import SwiftUI

struct FeedTopChromeView: View {
    @Environment(\.colorScheme) private var colorScheme

    let groupName: String
    let subtitle: String
    let hasGroups: Bool
    let profileIcon: String
    let profileBackgroundColour: String
    let isFavouritesFilterEnabled: Bool
    let topInset: CGFloat
    let onUpload: () -> Void
    let onToggleFavourites: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(groupName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(chromePrimaryColor)
                    .shadow(color: chromeShadowColor, radius: 10, x: 0, y: 4)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(chromeSecondaryColor)
                    .shadow(color: chromeShadowColor.opacity(0.85), radius: 8, x: 0, y: 3)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if hasGroups {
                    roundChromeButton(
                        systemName: "plus",
                        isSelected: false,
                        foregroundColor: chromePrimaryColor,
                        accessibilityIdentifier: "feed-upload-button",
                        action: onUpload
                    )

                    roundChromeButton(
                        systemName: isFavouritesFilterEnabled ? "heart.fill" : "heart",
                        isSelected: isFavouritesFilterEnabled,
                        foregroundColor: chromePrimaryColor,
                        selectedForegroundColor: Color.accentColor,
                        accessibilityIdentifier: "feed-favourites-filter-button",
                        action: onToggleFavourites
                    )
                }

                Button(action: onOpenSettings) {
                    avatarBadge
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed-settings-button")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, max(0, topInset - 60))
    }

    private func roundChromeButton(
        systemName: String,
        isSelected: Bool,
        foregroundColor: Color,
        selectedForegroundColor: Color? = nil,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? (selectedForegroundColor ?? Color.clear) : Color.clear)
                .overlay {
                    if isSelected, let selectedForegroundColor {
                        Image(systemName: systemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selectedForegroundColor)
                    } else {
                        Image(systemName: systemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(foregroundColor)
                    }
                }
                .shadow(color: chromeShadowColor.opacity(0.9), radius: 8, x: 0, y: 3)
                .frame(width: 48, height: 48)
                .background(glassCircleBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(Color(hex: profileBackgroundColour))

            Text(profileIcon)
                .font(.system(size: 26))
        }
        .frame(width: 48, height: 48)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 18, x: 0, y: 8)
    }

    private func glassCircleBackground(isSelected: Bool) -> some View {
        let shape = Circle()

        return ZStack {
            Color.clear
                .background(.ultraThinMaterial, in: shape)

            shape
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.12),
                                Color.black.opacity(colorScheme == .dark ? 0.12 : 0.08)
                            ]
                            : [
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.05),
                                Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.26),
                            Color.white.opacity(0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )

            shape
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.1),
                    lineWidth: 0.6
                )
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private var chromePrimaryColor: Color {
        Color.white.opacity(0.94)
    }

    private var chromeSecondaryColor: Color {
        Color.white.opacity(0.72)
    }

    private var chromeShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.22)
    }
}
