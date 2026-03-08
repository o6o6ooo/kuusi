import AuthenticationServices
import Combine
import FirebaseAuth
import Foundation
import LocalAuthentication

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
    @Published private(set) var biometricsEnabled: Bool = AppState.initialBiometricsEnabled()
    var biometricDisplayName: String { AppState.detectBiometricName() }

    private let authService = AppleAuthService()
    private let userService = UserService()
    private let biometricAuthService = BiometricAuthService()
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
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
            route = biometricsEnabled ? .locked : .signedIn
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

    func setBiometricsEnabled(_ enabled: Bool) {
        biometricsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: AppSettings.biometricsEnabledKey)
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
    func debugEnterMainTabs() async {
        do {
            let user = try await signInOrCreateDebugUser()

            try await userService.ensureUserDocument(
                for: user,
                suggestedName: "Sakura Wallace",
                suggestedEmail: "sakura.wallace@kuusi.local"
            )

            currentUser = user
            errorMessage = nil
            route = .signedIn
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
                self.route = self.biometricsEnabled ? .locked : .signedIn
            }
        }
    }

    private static func initialBiometricsEnabled() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: AppSettings.biometricsEnabledKey) == nil {
            defaults.set(true, forKey: AppSettings.biometricsEnabledKey)
            return true
        }
        return defaults.bool(forKey: AppSettings.biometricsEnabledKey)
    }

    private static func detectBiometricName() -> String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric"
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
    private func signInOrCreateDebugUser() async throws -> User {
        // Fixed debug user: create this account in Firebase Console beforehand.
        let email = "sakura.wallace.test@example.com"
        let password = "KuusiDebug#2026"

        // Ensure a clean auth state before switching to fixed debug credentials.
        if Auth.auth().currentUser != nil {
            try? Auth.auth().signOut()
        }

        return try await signInWithEmail(email: email, password: password)
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
