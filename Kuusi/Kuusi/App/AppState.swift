import AuthenticationServices
import Combine
import FirebaseAuth
import Foundation

enum DebugCredentialsError: LocalizedError {
    case missingEnvironmentVariables

    var errorDescription: String? {
        switch self {
        case .missingEnvironmentVariables:
            return "Set DEBUG_TEST_EMAIL/DEBUG_TEST_PASSWORD or DEBUG_TEST_USER_{N}_EMAIL/_PASSWORD in Xcode Scheme > Run > Environment Variables."
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
    @Published var errorMessage: String?
    @Published private(set) var currentUser: User?
#if DEBUG
    @Published private(set) var debugAccounts: [DebugAccount] = []
    @Published var selectedDebugAccountID: String?
#endif

    private let authService = AppleAuthService()
    private let userService = UserService()
    private let biometricAuthService = BiometricAuthService()
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
#if DEBUG
        let loadedAccounts = AppState.loadDebugAccounts()
        debugAccounts = loadedAccounts
        selectedDebugAccountID = loadedAccounts.first?.id
#endif
        observeAuthState()
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
            errorMessage = "Apple ID token was not available."
            return
        }

        do {
            let payload = AppleSignInPayload(
                idToken: tokenString,
                rawNonce: rawNonce,
                fullName: credential.fullName
            )
            let user = try await authService.signIn(payload: payload)

            let formatter = PersonNameComponentsFormatter()
            let suggestedName = credential.fullName.map { formatter.string(from: $0) }
            try await userService.ensureUserDocument(for: user, suggestedName: suggestedName)

            errorMessage = nil
            currentUser = user
            route = .locked
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlockApp() async {
        let ok = await biometricAuthService.authenticate(reason: "Unlock Kuusi")
        if ok {
            route = .signedIn
            errorMessage = nil
        } else {
            errorMessage = "Biometric authentication failed."
        }
    }

    func signOut() async {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            route = .signedOut
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
            let user = try await signInOrCreateDebugUser(account: account)

            try await userService.ensureUserDocument(
                for: user,
                suggestedName: account.suggestedName ?? "Sakura Wallace",
                suggestedEmail: user.email
            )

            currentUser = user
            errorMessage = nil
            route = .locked
        } catch {
            if let nsError = error as NSError?, nsError.domain == AuthErrorDomain,
               nsError.code == AuthErrorCode.operationNotAllowed.rawValue {
                errorMessage = "Enable Email/Password provider in Firebase Authentication for debug login."
            } else if let nsError = error as NSError?, nsError.domain == AuthErrorDomain,
                      nsError.code == AuthErrorCode.invalidCredential.rawValue {
                errorMessage = "Debug user credentials are invalid. Check email/password in AppState and Firebase Console."
            } else {
                errorMessage = "Debug sign-in failed: \(error.localizedDescription)"
            }
        }
    }
#endif

    private func observeAuthState() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                guard let user else {
                    self.currentUser = nil
                    self.route = .signedOut
                    return
                }

                let validSession = await self.validateCurrentUserSession(user)
                if !validSession {
                    try? Auth.auth().signOut()
                    self.currentUser = nil
                    self.route = .signedOut
                    self.errorMessage = nil
                    return
                }

                await self.ensureUserDocumentIfNeeded(for: user)
                self.currentUser = user
                self.route = .locked
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

    private func ensureUserDocumentIfNeeded(for user: User) async {
        let suggestedName = user.displayName?.isEmpty == false ? user.displayName : "Sakura Wallace"
        let suggestedEmail = user.email ?? (user.isAnonymous ? "sakura.wallace@kuusi.local" : nil)
        try? await userService.ensureUserDocument(
            for: user,
            suggestedName: suggestedName,
            suggestedEmail: suggestedEmail
        )
    }
}
