import SwiftUI

struct AppTheme {
	static func accent(for colorScheme: ColorScheme) -> Color {
		colorScheme == .dark ? Color(hex: "#607CAC") : Color(hex: "#5C9BD1")
	}

	static func feedBackgroundGradient(for colorScheme: ColorScheme)
		-> LinearGradient
	{
		LinearGradient(
			colors: colorScheme == .dark
				? [Color(hex: "#111821"), Color(hex: "#1A2431"), Color(hex: "#0E151D")]
				: [
					Color(hex: "#DCEBFA"), Color(hex: "#F7FAFF"), Color(hex: "#EAF2FB"),
				],
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

	static func cardSurfaceBackground(for colorScheme: ColorScheme) -> Color {
		pageBackground(for: colorScheme).opacity(0.7)
	}

	static func cardSurfaceBorder(for colorScheme: ColorScheme) -> Color {
		cardBackground(for: colorScheme)
	}

	static func cardSurfaceShadow(for colorScheme: ColorScheme) -> Color {
		Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
	}

	static func cardSurfaceShadowRadius(for colorScheme: ColorScheme) -> CGFloat {
		colorScheme == .dark ? 10 : 14
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
			.background(
				AppTheme.feedBackgroundGradient(for: colorScheme).ignoresSafeArea()
			)
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
							Color.blue.opacity(colorScheme == .dark ? 0.04 : 0.08),
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
	func body(content: Content) -> some View {
		content
			.foregroundStyle(Color.white)
			.blendMode(.difference)
			.opacity(0.9)
			.shadow(
				color: Color.black.opacity(0.08),
				radius: 1.2,
				x: 0,
				y: 1
			)
	}
}

private struct FeedChromeSecondaryModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.foregroundStyle(Color.white)
			.blendMode(.difference)
			.opacity(0.68)
			.shadow(
				color: Color.black.opacity(0.06),
				radius: 1,
				x: 0,
				y: 1
			)
	}
}

private struct GlassCardModifier: ViewModifier {
	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

		content
			.glassEffect(.regular, in: shape)
			.contentShape(shape)
	}
}

private struct FeedGlassCapsuleModifier: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	let isSelected: Bool

	func body(content: Content) -> some View {
		content
			.background(glassBackground)
			.overlay {
				if isSelected {
					Capsule()
						.fill(
							LinearGradient(
								colors: [
									Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
									Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12),
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
				}
			}
			.overlay {
				if isSelected {
					Capsule()
						.strokeBorder(
							Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
							lineWidth: 0.8
						)
				}
			}
	}

	private var glassBackground: some View {
		let shape = Capsule(style: .continuous)

		return ZStack {
			Color.clear
				.background(.ultraThinMaterial, in: shape)

			shape
				.fill(
					LinearGradient(
						colors: [
							Color.white.opacity(colorScheme == .dark ? 0.04 : 0.05),
							Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06),
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)

			shape
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22),
							Color.white.opacity(0.04),
							.clear,
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
			color: .black.opacity(colorScheme == .dark ? 0.14 : 0.05),
			radius: 8,
			x: 0,
			y: 4
		)
	}
}

private struct FeedGlassCircleModifier: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	let isSelected: Bool
	let size: CGFloat
	let font: Font

	func body(content: Content) -> some View {
		content
			.font(font)
			.frame(width: size, height: size)
			.glassEffect(glass, in: Circle())
			.contentShape(Circle())
			.shadow(
				color: .black.opacity(colorScheme == .dark ? 0.16 : 0.06),
				radius: 8,
				x: 0,
				y: 4
			)
	}

	private var glass: Glass {
		if isSelected {
			return .regular
				.tint(
					AppTheme.accent(for: colorScheme).opacity(
						colorScheme == .dark ? 0.32 : 0.28
					)
				)
				.interactive()
		}

		return .clear.interactive()
	}
}

private struct DismissGlassCircleModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.system(size: 18, weight: .semibold))
			.frame(width: 40, height: 40)
			.glassEffect(.clear.interactive(), in: Circle())
			.contentShape(Circle())
	}
}

private struct FeedGlassPillModifier: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		content
			.glassEffect(
				.clear,
				in: RoundedRectangle(cornerRadius: 27, style: .continuous)
			)
			.contentShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
			.shadow(
				color: .black.opacity(colorScheme == .dark ? 0.14 : 0.05),
				radius: 8,
				x: 0,
				y: 4
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

	func appGlassCard() -> some View {
		modifier(GlassCardModifier())
	}

	func appTextLinkStyle() -> some View {
		font(.subheadline.weight(.semibold))
			.foregroundStyle(Color.accentColor)
	}

	func appFeedGlassCircle(
		isSelected: Bool = false,
		size: CGFloat = 48,
		font: Font = .system(size: 18, weight: .semibold)
	) -> some View {
		modifier(
			FeedGlassCircleModifier(isSelected: isSelected, size: size, font: font)
		)
	}

	func appDismissGlassCircle() -> some View {
		modifier(DismissGlassCircleModifier())
	}

	func appFeedGlassPill() -> some View {
		modifier(FeedGlassPillModifier())
	}

	func appFeedGlassCapsule(isSelected: Bool = false) -> some View {
		modifier(FeedGlassCapsuleModifier(isSelected: isSelected))
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

struct AppPrimaryCapsuleButtonStyle: PrimitiveButtonStyle {
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.colorScheme) private var colorScheme

	let isLoading: Bool

	init(isLoading: Bool = false) {
		self.isLoading = isLoading
	}

	func makeBody(configuration: Configuration) -> some View {
		let accent = AppTheme.accent(for: colorScheme)
		let glassStyle: GlassButtonStyle =
			isEnabled
			? .glass(.regular.tint(accent))
			: .glass

		Button {
			guard !isLoading else { return }
			configuration.trigger()
		} label: {
			ZStack {
				configuration.label
					.font(.footnote.weight(.semibold))
					.padding(.horizontal, 4)
					.padding(.vertical, 2)
					.foregroundStyle(
						isEnabled ? Color.white : Color(uiColor: .systemGray4)
					)
					.opacity(isLoading ? 0 : 1)

				if isLoading {
					ProgressView()
						.controlSize(.small)
				}
			}
		}
		.controlSize(.regular)
		.buttonStyle(glassStyle)
	}
}

extension PrimitiveButtonStyle where Self == AppPrimaryCapsuleButtonStyle {
	static var appPrimaryCapsule: AppPrimaryCapsuleButtonStyle { .init() }
	static func appPrimaryCapsule(isLoading: Bool) -> AppPrimaryCapsuleButtonStyle
	{
		.init(isLoading: isLoading)
	}
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
