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
        #expect(appState.toastMessage?.text == "Biometric authentication failed.")
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
}

@MainActor
private func makeAppState() -> AppState {
    AppState(
        launchArguments: [],
        biometricAuthService: BiometricAuthServiceSpy(result: true),
        shouldObserveAuthState: false,
        notificationService: NotificationServiceSpy()
    )
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
    func handleSignedInUser(_ uid: String) async {}
    func handleSignedOutUser(_ uid: String?) async {}
    func didRegisterForRemoteNotifications(deviceToken: Data) {}
    func didReceiveRegistrationToken(_ fcmToken: String?) async {}
}
