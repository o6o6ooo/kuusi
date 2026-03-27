import Combine
import FirebaseAuth
import Foundation

@MainActor
final class SettingsProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var icon = "🌸"
    @Published var bgColour = "#A5C3DE"
    @Published var usageMB: Double = 0
    @Published var message: String?
    @Published var isError = false
    @Published var isEditingName = false

    private let userService = UserService()
    private var clearMessageTask: Task<Void, Never>?

    deinit {
        clearMessageTask?.cancel()
    }

    func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            guard let user = try await userService.fetchUser(uid: uid) else { return }
            name = user.name
            icon = user.icon
            bgColour = user.bgColour
            usageMB = user.usageMB
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    func saveProfile() async {
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
            scheduleMessageAutoClear(for: message)
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    func scheduleMessageAutoClear(for value: String?) {
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
