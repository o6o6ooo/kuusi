import FirebaseAuth
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""
    @State private var icon = "🌸"
    @State private var bgColour = "#A5C3DE"
    @State private var message: String?
    @State private var isError = false
    @State private var hasLoaded = false
    @State private var isEmojiPickerPresented = false
    @State private var isQRCodeOverlayPresented = false
    @State private var clearMessageTask: Task<Void, Never>?

    private let userService = UserService()
    private let avatarColours = [
        "#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#B7D7C9",
        "#F1C994", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E"
    ]
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var errorText: Color { AppTheme.errorText }
    private var cardBorder: Color { AppTheme.cardBorder(for: colorScheme) }
    private var qrPayload: String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return "kuusi://user/\(uid)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 20) {
                            Button {
                                isEmojiPickerPresented = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: bgColour))
                                        .frame(width: 100, height: 100)
                                    Text(icon.isEmpty ? "🌸" : icon)
                                        .font(.system(size: 50))
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Name", text: $name)
                                    .textFieldStyle(.plain)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(primaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: 300)
                                    .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.92))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Spacer(minLength: 0)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 28, maximum: 50)), count: 5), spacing: 12) {
                            ForEach(avatarColours, id: \.self) { colour in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        bgColour = colour
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colour))
                                        .frame(width: 50, height: 50)
                                        .scaleEffect(bgColour == colour ? 1.07 : 1.0)
                                        .overlay {
                                            if bgColour == colour {
                                                Circle()
                                                    .stroke(.black.opacity(0.16), lineWidth: 1.5)
                                            }
                                        }
                                        .shadow(color: .black.opacity(bgColour == colour ? 0.15 : 0.06), radius: bgColour == colour ? 7 : 3, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 8) {
                            Spacer()
                            if let message, !isError {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                isQRCodeOverlayPresented = true
                            } label: {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(qrPayload == nil)
                            Button {
                                Task {
                                    await saveProfile()
                                }
                            } label: {
                                Image(systemName: "checkmark.icloud.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(cardBorder, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(appState.biometricDisplayName, isOn: Binding(
                            get: { appState.biometricsEnabled },
                            set: { appState.setBiometricsEnabled($0) }
                        ))
                        .font(.body.weight(.medium))
                        .foregroundStyle(primaryText)

                        Button {
                            Task {
                                await appState.signOut()
                            }
                        } label: {
                            Text("Sign out")
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    if let message, isError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(errorText)
                    }
                }
                .padding(16)
                .foregroundStyle(primaryText)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .screenTheme()
            .task {
                if !hasLoaded {
                    await loadProfile()
                    hasLoaded = true
                }
            }
            .sheet(isPresented: $isEmojiPickerPresented) {
                EmojiPickerSheet(selectedEmoji: $icon)
            }
            .sheet(isPresented: $isQRCodeOverlayPresented) {
                if let qrPayload {
                    MyQRCodeOverlayView(payload: qrPayload)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: message) { _, newValue in
                scheduleMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearMessageTask?.cancel()
                clearMessageTask = nil
            }
        }
    }

    @MainActor
    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if let user = try await userService.fetchUser(uid: uid) {
                name = user.name
                icon = user.icon
                bgColour = user.bgColour
            }
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    @MainActor
    private func saveProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            message = "Name cannot be empty."
            isError = true
            return
        }

        do {
            try await userService.updateProfile(
                uid: uid,
                name: cleanName,
                icon: cleanIcon.isEmpty ? "🌸" : cleanIcon,
                bgColour: bgColour
            )
            message = "Profile updated"
            isError = false
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    private func scheduleMessageAutoClear(for value: String?) {
        clearMessageTask?.cancel()
        guard value != nil, !isError else { return }

        let currentValue = value
        clearMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, message == currentValue, !isError {
                message = nil
            }
        }
    }
}

private struct MyQRCodeOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Your QR code")
                    .font(.headline.weight(.semibold))

                if let image = makeQRCodeImage(from: payload) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(18)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Text("Failed to generate QR code")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.errorText)
                }

                ShareLink(item: payload) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .screenTheme()
        }
    }

    private func makeQRCodeImage(from string: String) -> UIImage? {
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String

    private let emojis = [
        "☺️","😉","🥰","🥳","😎","🥺","😳","🫠","😲","🤑",
        "🐶","🐱","🐼","🐻‍❄️","🐰","🐨","🐸","🦁","🐷","🐻",
        "🦄","🦋","🦆","🐊","🐏","🐖","🦓","🦢","🐇","🦔",
        "🐈‍⬛","🐄","🌲","🎄","🎍","🌷","🌹","🥀","🌸","🪷",
        "💐","💭","🌝","🌜","🌚","🌞","🌍","🪐","☔️","⛄️",
        "🌦️","🌧️","❄️","🌨️","☁️","⭐️",
        "🍎","🍐","🍋","🍇","🍒","🍓","🍍","🍉","🥝","🥑",
        "🍅","🍆","🥒","🫛","🥦","🌽","🫜","🥕","🫒","🥫",
        "🍳","🥓","🥖","🧈","🥞","🍕","🌭","🥟","🍣","🍤",
        "🍙","🍥","🍡","🎂","🧁","🍩","🫖","🧃","🍺","🥄",
        "🎱","⛳️","🥌","⛷️","🛹","🎣","⚽️","🎾","🎧","🥁",
        "🎺","🎯","🎳","🎮","🚦","🗿","⛱️","🗼","⛩️","🗻",
        "✈️","🛩️","🚁","🚢","🚘","🚖","🛞","🏠","🏡",
				"💻","⌨️","📱","⌚️","⏰","💸","⚙️","🪏","🔨","🧻",
				"🪣","🧺","🪥","🪑","🚪","🎈","📫","📚","🗑️","👀",
        "🧣","🩴","⛑️","❤️","💛","💚","🩵","💙","🤍",
        "🩷","💞","💤","🌀","❔","🎶"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 36, maximum: 52)), count: 8), spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedEmoji == emoji ? Color.blue.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose Icon")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
