import FirebaseAuth
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var name = ""
    @State private var icon = "🌸"
    @State private var bgColour = "#A5C3DE"
    @State private var message: String?
    @State private var isError = false
    @State private var hasLoaded = false
    @State private var isEmojiPickerPresented = false

    private let userService = UserService()
    private let avatarColours = [
        "#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#B7D7C9",
        "#F1C994", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 8) {
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
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: 300)
                                        .background(Color.white.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                Spacer(minLength: 0)
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 28, maximum: 50)), count: 5), spacing: 12) {
                                ForEach(avatarColours, id: \.self) { colour in
                                    Button {
                                        bgColour = colour
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: colour))
                                            .frame(width: 50, height: 50)
                                            .overlay {
                                                if bgColour == colour {
                                                    Circle()
                                                        .stroke(.black.opacity(0.4), lineWidth: 2)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                        Button("Save") {
                            Task {
                                await saveProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(appState.biometricDisplayName, isOn: Binding(
                            get: { appState.biometricsEnabled },
                            set: { appState.setBiometricsEnabled($0) }
                        ))
                        .font(.body.weight(.medium))

                        Button("Sign out", role: .destructive) {
                            Task {
                                await appState.signOut()
                            }
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(isError ? .red : .green)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if !hasLoaded {
                    await loadProfile()
                    hasLoaded = true
                }
            }
            .sheet(isPresented: $isEmojiPickerPresented) {
                EmojiPickerSheet(selectedEmoji: $icon)
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
            message = "Profile saved."
            isError = false
        } catch {
            message = error.localizedDescription
            isError = true
        }
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

private extension Color {
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
