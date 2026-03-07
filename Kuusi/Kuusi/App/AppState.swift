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
    func debugEnterMainTabs() {
        errorMessage = nil
        route = .signedIn
    }
#endif

    private func observeAuthState() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser = user
                if user == nil {
                    self.route = .signedOut
                } else {
                    self.route = self.biometricsEnabled ? .locked : .signedIn
                }
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
}
