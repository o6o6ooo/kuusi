import SwiftUI

struct AppTheme {
    static func accent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#607CAC") : Color(hex: "#5C9BD1")
    }

    static func feedBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "#111821"), Color(hex: "#1A2431"), Color(hex: "#0E151D")]
                : [Color(hex: "#DCEBFA"), Color(hex: "#F7FAFF"), Color(hex: "#EAF2FB")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#1E2633") : Color(hex: "#FFFFFF")
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#2A3140") : Color(hex: "#F5F5F5")
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "#DCE2EA") : Color(hex: "#2A3140")
    }

    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    static let errorText = Color(hex: "#CE0000")
}

private struct ScreenThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let background = AppTheme.pageBackground(for: colorScheme)
        let text = AppTheme.primaryText(for: colorScheme)

        content
            .foregroundStyle(text)
            .background(background.ignoresSafeArea())
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct FeedBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.feedBackgroundGradient(for: colorScheme).ignoresSafeArea())
    }
}

private struct OverlayBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    AppTheme.feedBackgroundGradient(for: colorScheme)

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(colorScheme == .dark ? 0.58 : 0.72)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.26),
                            Color.clear,
                            Color.blue.opacity(colorScheme == .dark ? 0.04 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            )
    }
}

private struct OverlayThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let text = AppTheme.primaryText(for: colorScheme)

        content
            .foregroundStyle(text)
            .appOverlayBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct FeedChromePrimaryModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.regularMaterial)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.1),
                radius: 1.5,
                x: 0,
                y: 1
            )
    }
}

private struct FeedChromeSecondaryModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.thinMaterial)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.08),
                radius: 1,
                x: 0,
                y: 1
            )
    }
}

extension View {
    func screenTheme() -> some View {
        modifier(ScreenThemeModifier())
    }

    func appFeedBackground() -> some View {
        modifier(FeedBackgroundModifier())
    }

    func appOverlayBackground() -> some View {
        modifier(OverlayBackgroundModifier())
    }

    func appOverlayTheme() -> some View {
        modifier(OverlayThemeModifier())
    }

    func appFeedChromePrimaryStyle() -> some View {
        modifier(FeedChromePrimaryModifier())
    }

    func appFeedChromeSecondaryStyle() -> some View {
        modifier(FeedChromeSecondaryModifier())
    }

    func appTextLinkStyle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }

    func appErrorTextLinkStyle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.errorText)
    }

    func appSecondaryTextLinkStyle() -> some View {
        font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

struct AppPrimaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.accent(for: colorScheme).opacity(isEnabled ? 1 : 0.55), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AppPrimaryCapsuleButtonStyle {
    static var appPrimaryCapsule: AppPrimaryCapsuleButtonStyle { .init() }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
