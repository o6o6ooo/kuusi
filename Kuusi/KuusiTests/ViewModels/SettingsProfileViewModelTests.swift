import FirebaseAuth
import UIKit
import Testing
@testable import Kuusi

@MainActor
struct SettingsProfileViewModelTests {
    @Test
    func loadProfilePopulatesFieldsFromFetchedUser() async {
        let userService = UserServiceSpy()
        userService.fetchedUser = AppUser(
            id: "user-1",
            name: "Sakura",
            email: "sakura@example.com",
            icon: "🌲",
            bgColour: "#123456",
            usageMB: 42.5,
            groups: []
        )
        let googleService = GoogleAccountServiceSpy()
        googleService.linkedAccount = GoogleLinkedAccount(email: "linked@example.com", isLinked: true)
        let viewModel = makeViewModel(userService: userService, googleAccountService: googleService)

        await viewModel.loadProfile()

        #expect(viewModel.name == "Sakura")
        #expect(viewModel.icon == "🌲")
        #expect(viewModel.bgColour == "#123456")
        #expect(viewModel.usageMB == 42.5)
        #expect(viewModel.googleLinkedEmail == "linked@example.com")
        #expect(viewModel.isGoogleLinked == true)
    }

    @Test
    func loadProfileShowsErrorMessageWhenFetchFails() async {
        let userService = UserServiceSpy()
        userService.fetchError = NSError(domain: "Tests", code: 1)
        let viewModel = makeViewModel(userService: userService)

        await viewModel.loadProfile()

        #expect(viewModel.toastMessage?.id == .failedToLoadProfile)
        if case .error = viewModel.toastMessage?.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected error inline message")
        }
    }

    @Test
    func saveProfileRejectsEmptyTrimmedName() async {
        let userService = UserServiceSpy()
        let viewModel = makeViewModel(userService: userService)
        viewModel.name = "   "
        viewModel.icon = "🌲"

        await viewModel.saveProfile()

        #expect(userService.updateCalls.isEmpty)
        #expect(viewModel.toastMessage?.text == "Name cannot be empty.")
        if case .error = viewModel.toastMessage?.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected error inline message")
        }
    }

    @Test
    func saveProfileTrimsValuesAndKeepsBlankIconWhenBlank() async {
        let userService = UserServiceSpy()
        let viewModel = makeViewModel(userService: userService)
        viewModel.name = "  Sakura  "
        viewModel.icon = "   "
        viewModel.bgColour = "#abcdef"

        await viewModel.saveProfile()

        #expect(userService.updateCalls.count == 1)
        #expect(userService.updateCalls.first?.uid == "user-1")
        #expect(userService.updateCalls.first?.name == "Sakura")
        #expect(userService.updateCalls.first?.icon == "")
        #expect(userService.updateCalls.first?.bgColour == "#abcdef")
        #expect(viewModel.toastMessage?.text == "Profile updated")
        if case .success = viewModel.toastMessage?.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected success inline message")
        }
    }

    @Test
    func saveProfileShowsErrorWhenUpdateFails() async {
        let userService = UserServiceSpy()
        userService.updateError = NSError(domain: "Tests", code: 2)
        let viewModel = makeViewModel(userService: userService)
        viewModel.name = "Sakura"
        viewModel.icon = "🌲"

        await viewModel.saveProfile()

        #expect(viewModel.toastMessage?.id == .failedToSaveProfile)
        if case .error = viewModel.toastMessage?.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected error inline message")
        }
    }

    @Test
    func clearToastMessageResetsMessage() {
        let viewModel = makeViewModel()
        viewModel.toastMessage = AppMessage(.profileUpdated, .success)

        viewModel.clearToastMessage()

        #expect(viewModel.toastMessage == nil)
    }

    @Test
    func connectGoogleAccountShowsErrorWithoutPresentingController() async {
        let googleService = GoogleAccountServiceSpy()
        let viewModel = makeViewModel(
            googleAccountService: googleService,
            topViewControllerProvider: { nil }
        )

        await viewModel.connectGoogleAccount()

        #expect(googleService.connectCallCount == 0)
        #expect(viewModel.toastMessage?.text == "Could not open Google Sign-In.")
    }

    @Test
    func disconnectGoogleAccountClearsLinkedStateOnSuccess() async {
        let googleService = GoogleAccountServiceSpy()
        let viewModel = makeViewModel(googleAccountService: googleService)
        viewModel.googleLinkedEmail = "linked@example.com"
        viewModel.isGoogleLinked = true

        await viewModel.disconnectGoogleAccount()

        #expect(googleService.disconnectCallCount == 1)
        #expect(viewModel.googleLinkedEmail.isEmpty)
        #expect(viewModel.isGoogleLinked == false)
        #expect(viewModel.toastMessage?.text == "Google account disconnected")
    }

    private func makeViewModel(
        userService: SettingsProfileUserServicing = UserServiceSpy(),
        googleAccountService: SettingsProfileGoogleAccountServicing = GoogleAccountServiceSpy(),
        topViewControllerProvider: @escaping @MainActor () -> UIViewController? = { UIViewController() }
    ) -> SettingsProfileViewModel {
        SettingsProfileViewModel(
            userService: userService,
            googleAccountService: googleAccountService,
            currentUserIDProvider: { "user-1" },
            linkedAccountProvider: { googleAccountService.currentLinkedAccount(for: nil) },
            topViewControllerProvider: topViewControllerProvider
        )
    }
}

private final class UserServiceSpy: SettingsProfileUserServicing {
    struct UpdateCall {
        let uid: String
        let name: String
        let icon: String
        let bgColour: String
    }

    var fetchedUser: AppUser?
    var fetchError: Error?
    var updateError: Error?
    var updateCalls: [UpdateCall] = []

    func fetchUser(uid: String) async throws -> AppUser? {
        if let fetchError {
            throw fetchError
        }
        return fetchedUser
    }

    func updateProfile(uid: String, name: String, icon: String, bgColour: String) async throws {
        if let updateError {
            throw updateError
        }
        updateCalls.append(.init(uid: uid, name: name, icon: icon, bgColour: bgColour))
    }
}

private final class GoogleAccountServiceSpy: SettingsProfileGoogleAccountServicing {
    var linkedAccount = GoogleLinkedAccount(email: "", isLinked: false)
    var connectResult = GoogleLinkedAccount(email: "linked@example.com", isLinked: true)
    var connectError: Error?
    var disconnectError: Error?
    var connectCallCount = 0
    var disconnectCallCount = 0

    func currentLinkedAccount(for user: User?) -> GoogleLinkedAccount {
        linkedAccount
    }

    func connectCurrentUser(presentingViewController: UIViewController) async throws -> GoogleLinkedAccount {
        connectCallCount += 1
        if let connectError {
            throw connectError
        }
        return connectResult
    }

    func disconnectCurrentUser() async throws {
        disconnectCallCount += 1
        if let disconnectError {
            throw disconnectError
        }
    }
}
