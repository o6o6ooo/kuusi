import Combine
import FirebaseAuth
import Foundation
import UIKit

protocol SettingsProfileUserServicing {
    func fetchUser(uid: String) async throws -> AppUser?
    func updateProfile(uid: String, name: String, icon: String, bgColour: String) async throws
}

protocol SettingsProfileGoogleAccountServicing {
    func currentLinkedAccount(for user: User?) -> GoogleLinkedAccount
    func connectCurrentUser(presentingViewController: UIViewController) async throws -> GoogleLinkedAccount
    func disconnectCurrentUser() async throws
}

extension UserService: SettingsProfileUserServicing {}
extension GoogleAccountService: SettingsProfileGoogleAccountServicing {}

@MainActor
final class SettingsProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var icon = "🌸"
    @Published var bgColour = "#A5C3DE"
    @Published var usageMB: Double = 0
    @Published var googleLinkedEmail = ""
    @Published var isGoogleLinked = false
    @Published var isGoogleAccountActionInFlight = false
    @Published var toastMessage: ToastMessage?

    private let userService: SettingsProfileUserServicing
    private let googleAccountService: SettingsProfileGoogleAccountServicing
    private let currentUserIDProvider: @MainActor () -> String?
    private let linkedAccountProvider: @MainActor () -> GoogleLinkedAccount
    private let topViewControllerProvider: @MainActor () -> UIViewController?
    private var clearMessageTask: Task<Void, Never>?

    init(
        userService: SettingsProfileUserServicing,
        googleAccountService: SettingsProfileGoogleAccountServicing,
        currentUserIDProvider: @escaping @MainActor () -> String?,
        linkedAccountProvider: @escaping @MainActor () -> GoogleLinkedAccount,
        topViewControllerProvider: @escaping @MainActor () -> UIViewController?
    ) {
        self.userService = userService
        self.googleAccountService = googleAccountService
        self.currentUserIDProvider = currentUserIDProvider
        self.linkedAccountProvider = linkedAccountProvider
        self.topViewControllerProvider = topViewControllerProvider
    }

    convenience init() {
        let userService = UserService()
        let googleAccountService = GoogleAccountService()
        self.init(
            userService: userService,
            googleAccountService: googleAccountService,
            currentUserIDProvider: { Auth.auth().currentUser?.uid },
            linkedAccountProvider: { googleAccountService.currentLinkedAccount(for: Auth.auth().currentUser) },
            topViewControllerProvider: { UIApplication.topViewController() }
        )
    }

    deinit {
        clearMessageTask?.cancel()
    }

    func loadProfile() async {
        refreshGoogleConnectionState()
        guard let uid = currentUserIDProvider() else { return }

        do {
            guard let user = try await userService.fetchUser(uid: uid) else { return }
            name = user.name
            icon = user.icon
            bgColour = user.bgColour
            usageMB = user.usageMB
        } catch {
            setToastMessage(.error(error.localizedDescription))
        }
    }

    func connectGoogleAccount() async {
        guard let presentingViewController = topViewControllerProvider() else {
            setToastMessage(.error("Could not open Google Sign-In."))
            return
        }

        isGoogleAccountActionInFlight = true
        defer { isGoogleAccountActionInFlight = false }

        do {
            let linkedAccount = try await googleAccountService.connectCurrentUser(
                presentingViewController: presentingViewController
            )
            googleLinkedEmail = linkedAccount.email
            isGoogleLinked = linkedAccount.isLinked
            setToastMessage(.success("Google account connected"))
        } catch {
            setToastMessage(.error(error.localizedDescription))
        }
    }

    func disconnectGoogleAccount() async {
        isGoogleAccountActionInFlight = true
        defer { isGoogleAccountActionInFlight = false }

        do {
            try await googleAccountService.disconnectCurrentUser()
            googleLinkedEmail = ""
            isGoogleLinked = false
            setToastMessage(.success("Google account disconnected"))
        } catch {
            setToastMessage(.error(error.localizedDescription))
        }
    }

    func saveProfile() async {
        await saveProfile(name: name, icon: icon, bgColour: bgColour)
    }

    func saveProfile(name: String, icon: String, bgColour: String) async {
        guard let uid = currentUserIDProvider() else { return }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            setToastMessage(.error("Name cannot be empty."))
            return
        }

        do {
            try await userService.updateProfile(
                uid: uid,
                name: cleanName,
                icon: cleanIcon.isEmpty ? "🌸" : cleanIcon,
                bgColour: bgColour
            )
            self.name = cleanName
            self.icon = cleanIcon.isEmpty ? "🌸" : cleanIcon
            self.bgColour = bgColour
            setToastMessage(.success("Profile updated"))
        } catch {
            setToastMessage(.error(error.localizedDescription))
        }
    }

    private func setToastMessage(_ message: ToastMessage) {
        toastMessage = message
        clearMessageTask?.cancel()
        clearMessageTask = ToastMessageAutoClear.schedule(
            for: message,
            currentMessage: { [weak self] in
                self?.toastMessage
            },
            clear: { [weak self] in
                self?.toastMessage = nil
            }
        )
    }

    func clearToastMessage() {
        clearMessageTask?.cancel()
        clearMessageTask = nil
        toastMessage = nil
    }

    private func refreshGoogleConnectionState() {
        let linkedAccount = linkedAccountProvider()
        googleLinkedEmail = linkedAccount.email
        isGoogleLinked = linkedAccount.isLinked
    }
}
