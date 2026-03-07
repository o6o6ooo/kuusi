import FirebaseAuth
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var name = ""
    @State private var icon = "🌸"
    @State private var message: String?
    @State private var isError = false
    @State private var hasLoaded = false

    private let userService = UserService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                    TextField("Emoji icon", text: $icon)
                        .textInputAutocapitalization(.never)
                }

                Section("Security") {
                    Toggle(appState.biometricDisplayName, isOn: Binding(
                        get: { appState.biometricsEnabled },
                        set: { appState.setBiometricsEnabled($0) }
                    ))
                }

                Section {
                    Button("Save profile") {
                        Task {
                            await saveProfile()
                        }
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task {
                            await appState.signOut()
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(isError ? .red : .green)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                if !hasLoaded {
                    await loadProfile()
                    hasLoaded = true
                }
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
            try await userService.updateProfile(uid: uid, name: cleanName, icon: cleanIcon.isEmpty ? "🙂" : cleanIcon)
            message = "Profile saved."
            isError = false
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }
}
