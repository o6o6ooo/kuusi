import Combine
import FirebaseAuth
import Foundation

@MainActor
final class SettingsProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var icon = "🌸"
    @Published var bgColour = "#A5C3DE"
    @Published var usageMB: Double = 0
    @Published var inlineMessage: InlineMessage?
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
            setInlineMessage(.error(error.localizedDescription))
        }
    }

    func saveProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            setInlineMessage(.error("Name cannot be empty."))
            return
        }

        do {
            try await userService.updateProfile(
                uid: uid,
                name: cleanName,
                icon: cleanIcon.isEmpty ? "🌸" : cleanIcon,
                bgColour: bgColour
            )
            setInlineMessage(.success("Profile updated"))
        } catch {
            setInlineMessage(.error(error.localizedDescription))
        }
    }

    private func setInlineMessage(_ message: InlineMessage) {
        inlineMessage = message
        clearMessageTask?.cancel()
        clearMessageTask = InlineMessageAutoClear.schedule(
            for: message,
            currentMessage: { [weak self] in
                self?.inlineMessage
            },
            clear: { [weak self] in
                self?.inlineMessage = nil
            }
        )
    }

    func clearInlineMessage() {
        clearMessageTask?.cancel()
        clearMessageTask = nil
        inlineMessage = nil
    }
}
