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
                    .font(.largeTitle.weight(.bold))
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
                .foregroundStyle(isSelected ? (selectedForegroundColor ?? Color.clear) : Color.clear)
                .overlay {
                    if isSelected, let selectedForegroundColor {
                        Image(systemName: systemName)
                            .foregroundStyle(selectedForegroundColor)
                    } else {
                        Image(systemName: systemName)
                            .foregroundStyle(foregroundColor)
                    }
                }
                .appFeedGlassCircle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(Color(hex: profileBackgroundColour))

            Circle()
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22), lineWidth: 0.8)

            Text(profileIcon)
                .font(.system(size: 26))
        }
        .frame(width: 48, height: 48)
        .shadow(color: chromeShadowColor.opacity(0.55), radius: 8, x: 0, y: 4)
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
