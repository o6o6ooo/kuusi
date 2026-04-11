import AuthenticationServices
import Combine
import FirebaseAuth
import Foundation
import GoogleSignIn
import SwiftUI

protocol BiometricAuthServicing {
    func authenticate(reason: String) async -> Bool
}

extension BiometricAuthService: BiometricAuthServicing {}

enum DebugCredentialsError: LocalizedError {
    case missingEnvironmentVariables

    var errorDescription: String? {
        switch self {
        case .missingEnvironmentVariables:
            return "Set DEBUG_TEST_EMAIL/DEBUG_TEST_PASSWORD or DEBUG_TEST_USER_{N}_EMAIL/_PASSWORD in Xcode Scheme > Run > Environment Variables."
        }
    }
}

private enum UITestRouteOverride {
    case signedOut
    case locked
    case signedIn

    init?(launchArguments: [String]) {
        if launchArguments.contains("UI_TEST_ROUTE_SIGNED_OUT") {
            self = .signedOut
        } else if launchArguments.contains("UI_TEST_ROUTE_LOCKED") {
            self = .locked
        } else if launchArguments.contains("UI_TEST_ROUTE_SIGNED_IN") {
            self = .signedIn
        } else {
            return nil
        }
    }
}

#if DEBUG
struct DebugAccount: Identifiable, Hashable {
    let id: String
    let email: String
    let password: String
    let suggestedName: String?

    var displayLabel: String {
        if let suggestedName, !suggestedName.isEmpty {
            return suggestedName
        }
        return email
    }
}
#endif

@MainActor
final class AppState: ObservableObject {
    enum Route {
        case signedOut
        case locked
        case signedIn
    }

    @Published var route: Route = .signedOut
    @Published var toastMessage: AppMessage?
    @Published private(set) var currentUser: User?
#if DEBUG
    @Published private(set) var debugAccounts: [DebugAccount] = []
    @Published var selectedDebugAccountID: String?
#endif

    private let authService = AppleAuthService()
    private let userService = UserService()
    private let biometricAuthService: BiometricAuthServicing
    private let groupService = GroupService()
    private let photoDeletionService = PhotoDeletionService()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var prefetchedGroupsUID: String?
    private var shouldUnlockAfterInteractiveSignIn = false
    private let uiTestRouteOverride: UITestRouteOverride?

    var isRunningUITests: Bool {
        uiTestRouteOverride != nil
    }

    init(
        launchArguments: [String],
        biometricAuthService: BiometricAuthServicing,
        shouldObserveAuthState: Bool
    ) {
        self.biometricAuthService = biometricAuthService
        self.uiTestRouteOverride = UITestRouteOverride(launchArguments: launchArguments)
#if DEBUG
        let loadedAccounts = AppState.loadDebugAccounts()
        debugAccounts = loadedAccounts
        selectedDebugAccountID = loadedAccounts.first?.id
#endif
        if let uiTestRouteOverride {
            route = switch uiTestRouteOverride {
            case .signedOut:
                .signedOut
            case .locked:
                .locked
            case .signedIn:
                .signedIn
            }
            return
        }
        if shouldObserveAuthState {
            self.observeAuthState()
        }
    }

    convenience init() {
        self.init(
            launchArguments: ProcessInfo.processInfo.arguments,
            biometricAuthService: BiometricAuthService(),
            shouldObserveAuthState: true
        )
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async {
        guard
            let tokenData = credential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else {
            toastMessage = AppMessage(.appleTokenUnavailable, .error)
            return
        }

        do {
            shouldUnlockAfterInteractiveSignIn = true
            let payload = AppleSignInPayload(
                idToken: tokenString,
                rawNonce: rawNonce,
                fullName: credential.fullName
            )
            let user = try await authService.signIn(payload: payload)

            toastMessage = nil
            currentUser = user
            route = .signedIn
        } catch {
            shouldUnlockAfterInteractiveSignIn = false
            toastMessage = AppMessage(.details(error.localizedDescription), .error)
        }
    }

    func unlockApp() async {
        if uiTestRouteOverride != nil {
            route = .signedIn
            toastMessage = nil
            return
        }

        let ok = await biometricAuthService.authenticate(reason: "Unlock Kuusi")
        if ok {
            route = .signedIn
            toastMessage = nil
        } else {
            toastMessage = AppMessage(.biometricAuthenticationFailed, .error)
        }
    }

    func signOut() async {
        do {
            GIDSignIn.sharedInstance.signOut()
            try Auth.auth().signOut()
            currentUser = nil
            route = .signedOut
            toastMessage = nil
            prefetchedGroupsUID = nil
        } catch {
            toastMessage = AppMessage(.details(error.localizedDescription), .error)
        }
    }

    func deleteCurrentUserAccount() async {
        guard let user = currentUser ?? Auth.auth().currentUser else {
            toastMessage = AppMessage(.pleaseSignInFirst, .error)
            return
        }

        let uid = user.uid

        do {
            let groups = try await groupService.fetchGroups(for: uid)
            let ownedGroups = groups.filter { $0.ownerUID == uid }
            let joinedGroups = groups.filter { $0.ownerUID != uid }

            for group in ownedGroups {
                try await groupService.deleteGroup(groupID: group.id)
            }

            for group in joinedGroups {
                try await groupService.leaveGroup(groupID: group.id, uid: uid)
            }

            try await photoDeletionService.deletePhotosPosted(by: uid)
            try await userService.deleteUserDocument(uid: uid)
            try await deleteAuthUser(user)

            GIDSignIn.sharedInstance.signOut()
            groupService.clearCachedGroups(for: uid)
            currentUser = nil
            route = .signedOut
            toastMessage = nil
            prefetchedGroupsUID = nil
        } catch let nsError as NSError
            where nsError.domain == AuthErrorDomain &&
                  nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
            toastMessage = AppMessage(.recentLoginRequired, .error)
        } catch {
            toastMessage = AppMessage(.details(error.localizedDescription), .error)
        }
    }

#if DEBUG
    func refreshDebugAccounts() {
        let loadedAccounts = AppState.loadDebugAccounts()
        debugAccounts = loadedAccounts
        if !loadedAccounts.contains(where: { $0.id == selectedDebugAccountID }) {
            selectedDebugAccountID = loadedAccounts.first?.id
        }
    }

    func debugEnterMainTabs(selectedAccountID: String? = nil) async {
        do {
            let selected = selectedAccountID ?? selectedDebugAccountID
            let account = try resolveDebugAccount(id: selected)
            shouldUnlockAfterInteractiveSignIn = true
            let user = try await signInOrCreateDebugUser(account: account)

            currentUser = user
            toastMessage = nil
            route = .signedIn
        } catch {
            shouldUnlockAfterInteractiveSignIn = false
            if let nsError = error as NSError?, nsError.domain == AuthErrorDomain,
               nsError.code == AuthErrorCode.operationNotAllowed.rawValue {
                toastMessage = AppMessage(.debugEmailPasswordProviderDisabled, .error)
            } else if let nsError = error as NSError?, nsError.domain == AuthErrorDomain,
                      nsError.code == AuthErrorCode.invalidCredential.rawValue {
                toastMessage = AppMessage(.debugInvalidCredentials, .error)
            } else {
                toastMessage = AppMessage(.debugSignInFailed(error.localizedDescription), .error)
            }
        }
    }
#endif

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .background else { return }
        guard currentUser != nil, route == .signedIn else { return }
        route = .locked
        toastMessage = nil
    }

    func clearToastMessage() {
        toastMessage = nil
    }

    private func observeAuthState() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                guard let user else {
                    self.currentUser = nil
                    self.route = .signedOut
                    self.prefetchedGroupsUID = nil
                    return
                }

                let validSession = await self.validateCurrentUserSession(user)
                if !validSession {
                    try? Auth.auth().signOut()
                    self.currentUser = nil
                    self.route = .signedOut
                    self.toastMessage = nil
                    return
                }

                await self.ensureUserDocumentIfNeeded(for: user)
                await self.prefetchGroupsIfNeeded(for: user.uid)
                self.currentUser = user
                if self.shouldUnlockAfterInteractiveSignIn {
                    self.route = .signedIn
                    self.shouldUnlockAfterInteractiveSignIn = false
                } else {
                    self.route = .locked
                }
            }
        }
    }

    private func signInAnonymously() async throws -> User {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: NSError(domain: "Auth", code: -1))
                    return
                }
                continuation.resume(returning: user)
            }
        }
    }

#if DEBUG
    private func resolveDebugAccount(id: String?) throws -> DebugAccount {
        guard !debugAccounts.isEmpty else {
            throw DebugCredentialsError.missingEnvironmentVariables
        }
        if let id, let account = debugAccounts.first(where: { $0.id == id }) {
            return account
        }
        return debugAccounts[0]
    }

    private func signInOrCreateDebugUser(account: DebugAccount) async throws -> User {

        // Ensure a clean auth state before switching to fixed debug credentials.
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
        }

        return try await signInWithEmail(email: account.email, password: account.password)
    }

    private func signInWithEmail(email: String, password: String) async throws -> User {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: NSError(domain: "Auth", code: -2))
                    return
                }
                continuation.resume(returning: user)
            }
        }
    }

    private static func loadDebugAccounts() -> [DebugAccount] {
        let env = ProcessInfo.processInfo.environment
        var accountsByIndex: [Int: DebugAccount] = [:]

        for (key, value) in env where key.hasPrefix("DEBUG_TEST_USER_") && key.hasSuffix("_EMAIL") {
            let prefix = "DEBUG_TEST_USER_"
            let suffix = "_EMAIL"
            let start = key.index(key.startIndex, offsetBy: prefix.count)
            let end = key.index(key.endIndex, offsetBy: -suffix.count)
            let indexString = String(key[start..<end])
            guard let index = Int(indexString), !value.isEmpty else { continue }

            let passwordKey = "DEBUG_TEST_USER_\(index)_PASSWORD"
            guard let password = env[passwordKey], !password.isEmpty else { continue }
            let name = env["DEBUG_TEST_USER_\(index)_NAME"]
            accountsByIndex[index] = DebugAccount(
                id: "debug_user_\(index)",
                email: value,
                password: password,
                suggestedName: name
            )
        }

        let orderedAccounts = accountsByIndex
            .sorted(by: { $0.key < $1.key })
            .map(\.value)
        if !orderedAccounts.isEmpty {
            return orderedAccounts
        }

        if
            let email = env["DEBUG_TEST_EMAIL"],
            let password = env["DEBUG_TEST_PASSWORD"],
            !email.isEmpty,
            !password.isEmpty
        {
            let name = env["DEBUG_TEST_NAME"]
            return [DebugAccount(
                id: "debug_default",
                email: email,
                password: password,
                suggestedName: name
            )]
        }

        return []
    }

#endif

    private func validateCurrentUserSession(_ user: User) async -> Bool {
        await withCheckedContinuation { continuation in
            user.getIDTokenForcingRefresh(true) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private func deleteAuthUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func ensureUserDocumentIfNeeded(for user: User) async {
        let suggestedName = user.displayName?.isEmpty == false ? user.displayName : "Sakura Wallace"
        let suggestedEmail = user.email ?? (user.isAnonymous ? "sakura.wallace@kuusi.local" : nil)
        try? await userService.ensureUserDocument(
            for: user,
            suggestedName: suggestedName,
            suggestedEmail: suggestedEmail
        )
    }

    private func prefetchGroupsIfNeeded(for uid: String) async {
        guard prefetchedGroupsUID != uid else { return }
        do {
            _ = try await groupService.fetchGroups(for: uid)
            prefetchedGroupsUID = uid
        } catch {
            // Keep retrying on next auth-state callback if prefetch fails.
        }
    }
}
