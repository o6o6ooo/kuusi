import SwiftUI

struct AppTheme {
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

extension View {
    func screenTheme() -> some View {
        modifier(ScreenThemeModifier())
    }

    func appTextLinkStyle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }

    func appSecondaryTextLinkStyle() -> some View {
        font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

struct AppPrimaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(isEnabled ? 1 : 0.55), in: Capsule())
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
