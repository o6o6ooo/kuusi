import FirebaseAuth
import SwiftUI
import Testing
@testable import Kuusi

@MainActor
struct AppStateTests {
    @Test
    func defaultsToSignedOutWhenNoUiTestRouteIsProvided() {
        let appState = makeAppState()

        #expect(appState.route == .signedOut)
        #expect(appState.isRunningUITests == false)
    }

    @Test
    func uiTestSignedOutRouteStartsSignedOut() {
        let appState = AppState(
            launchArguments: ["UI_TEST_ROUTE_SIGNED_OUT"],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )

        #expect(appState.route == .signedOut)
        #expect(appState.isRunningUITests == true)
    }

    @Test
    func uiTestLockedRouteStartsLocked() {
        let appState = AppState(
            launchArguments: ["UI_TEST_ROUTE_LOCKED"],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )

        #expect(appState.route == .locked)
        #expect(appState.isRunningUITests == true)
    }

    @Test
    func uiTestSignedInRouteStartsSignedIn() {
        let appState = AppState(
            launchArguments: ["UI_TEST_ROUTE_SIGNED_IN"],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )

        #expect(appState.route == .signedIn)
        #expect(appState.isRunningUITests == true)
    }

    @Test
    func unlockAppMovesToSignedInWhenBiometricsSucceed() async {
        let biometricService = BiometricAuthServiceSpy(result: true)
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: biometricService,
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )
        appState.route = .locked

        await appState.unlockApp()

        #expect(appState.route == .signedIn)
        #expect(appState.toastMessage == nil)
        #expect(biometricService.authenticateCallCount == 1)
        #expect(biometricService.lastReason == "Unlock Kuusi")
    }

    @Test
    func unlockAppShowsErrorWhenBiometricsFail() async {
        let biometricService = BiometricAuthServiceSpy(result: false)
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: biometricService,
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )
        appState.route = .locked

        await appState.unlockApp()

        #expect(appState.route == .locked)
        #expect(appState.toastMessage?.id == .biometricAuthenticationFailed)
        #expect(biometricService.authenticateCallCount == 1)
    }

    @Test
    func unlockAppBypassesBiometricsDuringUiTests() async {
        let biometricService = BiometricAuthServiceSpy(result: false)
        let appState = AppState(
            launchArguments: ["UI_TEST_ROUTE_LOCKED"],
            biometricAuthService: biometricService,
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )

        await appState.unlockApp()

        #expect(appState.route == .signedIn)
        #expect(appState.toastMessage == nil)
        #expect(biometricService.authenticateCallCount == 0)
    }

    @Test
    func handleScenePhaseChangeLeavesSignedOutStateUnchanged() {
        let appState = makeAppState()
        appState.route = .signedOut
        appState.toastMessage = AppMessage(.failedToSignOut, .error)

        appState.handleScenePhaseChange(.background)

        #expect(appState.route == .signedOut)
        #expect(appState.toastMessage?.id == .failedToSignOut)
    }

    @Test
    func handleScenePhaseChangeKeepsSignedInSessionWithinRelockWindow() {
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            now: { currentDate },
            relockInterval: 300,
            notificationService: NotificationServiceSpy()
        )
        appState.route = .signedIn

        appState.handleScenePhaseChange(.background)
        currentDate = currentDate.addingTimeInterval(299)
        appState.handleScenePhaseChange(.active)

        #expect(appState.route == .signedIn)
    }

    @Test
    func handleScenePhaseChangeLocksSignedInSessionAfterRelockWindow() {
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            now: { currentDate },
            relockInterval: 300,
            notificationService: NotificationServiceSpy()
        )
        appState.route = .signedIn

        appState.handleScenePhaseChange(.background)
        currentDate = currentDate.addingTimeInterval(301)
        appState.handleScenePhaseChange(.active)

        #expect(appState.route == .locked)
    }

    @Test
    func unlockAppResetsSignedInContentAfterRelock() async {
        let biometricService = BiometricAuthServiceSpy(result: true)
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: biometricService,
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy()
        )
        appState.route = .locked

        await appState.unlockApp()

        #expect(appState.route == .signedIn)
        #expect(appState.signedInContentResetToken == 1)
    }

    @Test
    func reauthenticateWithAppleAndDeleteDeletesAccountWithoutRoutingToSignedIn() async {
        let authService = AppleAuthServiceSpy(reauthenticatedUID: "user-1")
        let accountDeletionService = AccountDeletionServiceSpy()
        let notificationService = NotificationServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: notificationService,
            authService: authService,
            accountDeletionService: accountDeletionService
        )
        appState.route = .signedIn

        let didDelete = await appState.reauthenticateWithAppleAndDelete(payload: deleteAccountPayload())

        #expect(didDelete == true)
        #expect(appState.route == .signedOut)
        #expect(appState.toastMessage == nil)
        #expect(authService.reauthenticateCallCount == 1)
        #expect(accountDeletionService.deleteCurrentUserDataCallCount == 1)
        #expect(accountDeletionService.deleteAuthCurrentUserCallCount == 1)
        #expect(notificationService.signedOutUIDs == ["user-1"])
        #expect(appState.isDeletingAccount == false)
    }

    @Test
    func reauthenticateWithAppleAndDeleteDoesNotDeleteWhenReauthenticationFails() async {
        let authService = AppleAuthServiceSpy(reauthenticationError: AuthServiceError.missingCurrentUser)
        let accountDeletionService = AccountDeletionServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy(),
            authService: authService,
            accountDeletionService: accountDeletionService
        )
        appState.route = .signedIn

        let didDelete = await appState.reauthenticateWithAppleAndDelete(payload: deleteAccountPayload())

        #expect(didDelete == false)
        #expect(appState.route == .signedIn)
        #expect(appState.toastMessage?.id == .failedToDeleteAccount)
        #expect(authService.reauthenticateCallCount == 1)
        #expect(accountDeletionService.deleteCurrentUserDataCallCount == 0)
        #expect(accountDeletionService.deleteAuthCurrentUserCallCount == 0)
        #expect(appState.isDeletingAccount == false)
    }

    @Test
    func reauthenticateWithAppleAndDeleteShowsRecentLoginMessageWhenAuthRequiresIt() async {
        let authService = AppleAuthServiceSpy(reauthenticationError: recentLoginError())
        let accountDeletionService = AccountDeletionServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy(),
            authService: authService,
            accountDeletionService: accountDeletionService
        )
        appState.route = .signedIn

        let didDelete = await appState.reauthenticateWithAppleAndDelete(payload: deleteAccountPayload())

        #expect(didDelete == false)
        #expect(appState.route == .signedIn)
        #expect(appState.toastMessage?.id == .recentLoginRequired)
        #expect(authService.reauthenticateCallCount == 1)
        #expect(accountDeletionService.deleteCurrentUserDataCallCount == 0)
        #expect(accountDeletionService.deleteAuthCurrentUserCallCount == 0)
        #expect(appState.isDeletingAccount == false)
    }

    @Test
    func signOutRoutesToSignedOutAndClearsStateWhenServiceSucceeds() async {
        let notificationService = NotificationServiceSpy()
        let signOutService = SignOutServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: notificationService,
            currentAuthUserID: { nil },
            signOutService: signOutService
        )
        appState.route = .signedIn
        appState.toastMessage = AppMessage(.failedToSignOut, .error)

        await appState.signOut()

        #expect(appState.route == .signedOut)
        #expect(appState.toastMessage == nil)
        #expect(signOutService.signOutCallCount == 1)
        #expect(notificationService.signedOutUIDs == [nil])
    }

    @Test
    func signOutShowsToastWhenServiceFails() async {
        let notificationService = NotificationServiceSpy()
        let signOutService = SignOutServiceSpy(error: SignOutServiceSpyError.failed)
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: notificationService,
            currentAuthUserID: { nil },
            signOutService: signOutService
        )
        appState.route = .signedIn

        await appState.signOut()

        #expect(appState.route == .signedIn)
        #expect(appState.toastMessage?.id == .failedToSignOut)
        #expect(signOutService.signOutCallCount == 1)
        #expect(notificationService.signedOutUIDs == [nil])
    }

    @Test
    func deleteCurrentUserAccountRequiresSignedInUser() async {
        let accountDeletionService = AccountDeletionServiceSpy()
        let notificationService = NotificationServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: notificationService,
            accountDeletionService: accountDeletionService,
            currentAuthUserID: { nil }
        )

        await appState.deleteCurrentUserAccount()

        #expect(appState.toastMessage?.id == .pleaseSignInFirst)
        #expect(accountDeletionService.deleteCurrentUserDataCallCount == 0)
        #expect(accountDeletionService.deleteAuthCurrentUserCallCount == 0)
        #expect(notificationService.signedOutUIDs.isEmpty)
    }

    @Test
    func deleteCurrentUserAccountShowsRecentLoginMessageWhenAuthRequiresIt() async {
        let accountDeletionService = AccountDeletionServiceSpy(deleteAuthCurrentUserError: recentLoginError())
        let notificationService = NotificationServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: notificationService,
            accountDeletionService: accountDeletionService,
            currentAuthUserID: { "user-1" }
        )
        appState.route = .signedIn

        await appState.deleteCurrentUserAccount()

        #expect(appState.route == .signedIn)
        #expect(appState.toastMessage?.id == .recentLoginRequired)
        #expect(accountDeletionService.deleteCurrentUserDataCallCount == 1)
        #expect(accountDeletionService.deleteAuthCurrentUserCallCount == 1)
        #expect(notificationService.signedOutUIDs == ["user-1"])
    }

    @Test
    func clearToastMessageClearsCurrentToast() {
        let appState = makeAppState()
        appState.toastMessage = AppMessage(.failedToSignOut, .error)

        appState.clearToastMessage()

        #expect(appState.toastMessage == nil)
    }

#if DEBUG
    @Test
    func refreshDebugAccountsReloadsAccountsAndSelection() {
        let loader = DebugAccountsLoaderSpy(accounts: [debugAccount(id: "debug-1")])
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: NotificationServiceSpy(),
            debugAccountsLoader: { loader.accounts }
        )
        appState.selectedDebugAccountID = "missing"
        loader.accounts = [debugAccount(id: "debug-2")]

        appState.refreshDebugAccounts()

        #expect(appState.debugAccounts.map(\.id) == ["debug-2"])
        #expect(appState.selectedDebugAccountID == "debug-2")
    }

    @Test
    func debugEnterMainTabsShowsToastWhenNoDebugAccountsAreConfigured() async {
        let notificationService = NotificationServiceSpy()
        let appState = AppState(
            launchArguments: [],
            biometricAuthService: BiometricAuthServiceSpy(result: true),
            shouldObserveAuthState: false,
            notificationService: notificationService,
            debugAccountsLoader: { [] }
        )
        appState.route = .signedOut

        await appState.debugEnterMainTabs()

        #expect(appState.route == .signedOut)
        #expect(appState.toastMessage?.id == .debugSignInFailed)
        #expect(notificationService.signedInUIDs.isEmpty)
    }
#endif
}

private func deleteAccountPayload() -> AppleSignInPayload {
    AppleSignInPayload(
        idToken: "token",
        rawNonce: "nonce",
        fullName: nil
    )
}

private func recentLoginError() -> NSError {
    NSError(domain: AuthErrorDomain, code: AuthErrorCode.requiresRecentLogin.rawValue)
}

@MainActor
private func makeAppState() -> AppState {
    AppState(
        launchArguments: [],
        biometricAuthService: BiometricAuthServiceSpy(result: true),
        shouldObserveAuthState: false,
        notificationService: NotificationServiceSpy(),
        currentAuthUserID: { nil }
    )
}

private final class AppleAuthServiceSpy: AppleAuthServicing {
    let reauthenticatedUID: String
    let reauthenticationError: Error?
    var signInCallCount = 0
    var reauthenticateCallCount = 0

    init(reauthenticatedUID: String = "user", reauthenticationError: Error? = nil) {
        self.reauthenticatedUID = reauthenticatedUID
        self.reauthenticationError = reauthenticationError
    }

    func signIn(payload: AppleSignInPayload) async throws -> User {
        signInCallCount += 1
        throw AuthServiceError.missingResult
    }

    func reauthenticateCurrentUser(payload: AppleSignInPayload) async throws -> String {
        reauthenticateCallCount += 1
        if let reauthenticationError {
            throw reauthenticationError
        }
        return reauthenticatedUID
    }
}

private enum SignOutServiceSpyError: Error {
    case failed
}

private final class SignOutServiceSpy: SignOutServicing {
    let error: Error?
    var signOutCallCount = 0

    init(error: Error? = nil) {
        self.error = error
    }

    func signOut() throws {
        signOutCallCount += 1
        if let error {
            throw error
        }
    }
}

private final class AccountDeletionServiceSpy: AccountDeletionServicing {
    let deleteCurrentUserDataError: Error?
    let deleteAuthCurrentUserError: Error?
    var deleteCurrentUserDataCallCount = 0
    var deleteAuthCurrentUserCallCount = 0

    init(deleteCurrentUserDataError: Error? = nil, deleteAuthCurrentUserError: Error? = nil) {
        self.deleteCurrentUserDataError = deleteCurrentUserDataError
        self.deleteAuthCurrentUserError = deleteAuthCurrentUserError
    }

    func deleteCurrentUserData() async throws {
        deleteCurrentUserDataCallCount += 1
        if let deleteCurrentUserDataError {
            throw deleteCurrentUserDataError
        }
    }

    func deleteAuthCurrentUser() async throws {
        deleteAuthCurrentUserCallCount += 1
        if let deleteAuthCurrentUserError {
            throw deleteAuthCurrentUserError
        }
    }
}

private final class BiometricAuthServiceSpy: BiometricAuthServicing {
    let result: Bool
    var authenticateCallCount = 0
    var lastReason: String?

    init(result: Bool) {
        self.result = result
    }

    func authenticate(reason: String) async -> Bool {
        authenticateCallCount += 1
        lastReason = reason
        return result
    }
}

@MainActor
private final class NotificationServiceSpy: NotificationServicing {
    var signedInUIDs: [String] = []
    var signedOutUIDs: [String?] = []

    func handleSignedInUser(_ uid: String) async {
        signedInUIDs.append(uid)
    }

    func handleSignedOutUser(_ uid: String?) async {
        signedOutUIDs.append(uid)
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {}
    func didReceiveRegistrationToken(_ fcmToken: String?) async {}
}

#if DEBUG
private func debugAccount(id: String) -> DebugAccount {
    DebugAccount(
        id: id,
        email: "\(id)@example.com",
        password: "password",
        suggestedName: nil
    )
}

@MainActor
private final class DebugAccountsLoaderSpy {
    var accounts: [DebugAccount]

    init(accounts: [DebugAccount]) {
        self.accounts = accounts
    }
}
#endif
