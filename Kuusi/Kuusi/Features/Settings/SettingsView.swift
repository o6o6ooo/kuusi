import FirebaseAuth
import SwiftUI
import Foundation

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
    @State private var clearMessageTask: Task<Void, Never>?
    @State private var usageMB: Double = 0
    @State private var quotaMB: Double = 5120

    private let userService = UserService()
    private let avatarColours = [
        "#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#B7D7C9",
        "#F1C994", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E"
    ]
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var errorText: Color { AppTheme.errorText }
    private var cardBorder: Color { AppTheme.cardBorder(for: colorScheme) }
    private var usageRatio: Double {
        guard quotaMB > 0 else { return 0 }
        return min(max(usageMB / quotaMB, 0), 1)
    }
    private var usageText: String {
        "\(formatStorage(usageMB))/\(formatStorage(quotaMB))"
    }
    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your storage")
                .font(.headline.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(usageText)
                        .font(.headline.weight(.semibold))
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

                HStack(spacing: 6) {
                    Text("Need more storage?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Upgrade to premium.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
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

                        storageCard

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
                usageMB = user.usageMB
                quotaMB = user.quotaMB
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

    private func formatStorage(_ mb: Double) -> String {
        if mb >= 1024 {
            let gb = mb / 1024
            if abs(gb.rounded() - gb) < 0.01 {
                return "\(Int(gb.rounded()))GB"
            }
            return String(format: "%.1fGB", gb)
        }

        if mb.rounded() >= mb - 0.01 {
            return "\(Int(mb.rounded()))MB"
        }
        return String(format: "%.0fMB", mb)
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
