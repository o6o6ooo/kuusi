import SwiftUI

struct BackgroundColorPickerSheet: View {
	@Environment(\.dismiss) private var dismiss

	let selectedColour: String
	let onSelect: (String) -> Void

	private let avatarColours = [
		"#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#A4D1D7",
		"#CFE4F5", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E",
		"#4F89B7", "#2F5972", "#5DA6A7", "#027145", "#5B7F95",
	]

	var body: some View {
		NavigationStack {
			VStack(spacing: 24) {
				Text("profile.background_picker.title")
					.font(.title3.weight(.bold))
					.frame(maxWidth: .infinity, alignment: .leading)

				LazyVGrid(
					columns: Array(
						repeating: GridItem(.flexible(minimum: 56, maximum: 72)),
						count: 5
					),
					spacing: 16
				) {
					ForEach(avatarColours, id: \.self) { colour in
						Button {
							onSelect(colour)
							dismiss()
						} label: {
							Color.clear
								.glassEffect(.regular.tint(Color(hex: colour)), in: Circle())
								.frame(width: 58, height: 58)
								.contentShape(Circle())
								.overlay {
									if selectedColour == colour {
										Circle()
											.strokeBorder(Color.white.opacity(0.92), lineWidth: 2)
											.padding(3)

										Image(systemName: "checkmark")
											.font(.system(size: 16, weight: .bold))
											.foregroundStyle(Color.white)
											.shadow(
												color: .black.opacity(0.24),
												radius: 4,
												x: 0,
												y: 2
											)
									}
								}
								.shadow(
									color: .black.opacity(selectedColour == colour ? 0.12 : 0.05),
									radius: 6,
									x: 0,
									y: 2
								)
						}
						.buttonStyle(.plain)
					}
				}

				Spacer()
			}
			.padding(20)
			.appOverlayTheme()
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("common.close") {
						dismiss()
					}
				}
			}
		}
	}
}
