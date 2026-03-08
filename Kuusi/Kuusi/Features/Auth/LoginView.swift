import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentNonce: String?

    private var pageBackground: Color { AppTheme.pageBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Kuusi")
                .font(.largeTitle.bold())
                .foregroundStyle(primaryText)
            Text("Sign in with Apple to continue")
                .foregroundStyle(primaryText.opacity(0.72))

            Toggle("Use \(appState.biometricDisplayName)", isOn: Binding(
                get: { appState.biometricsEnabled },
                set: { appState.setBiometricsEnabled($0) }
            ))
            .foregroundStyle(primaryText)
            .padding(.horizontal, 24)

            SignInWithAppleButton(.signIn) { request in
                let nonce = CryptoNonce.randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = CryptoNonce.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case let .success(authResults):
                    guard
                        let credential = authResults.credential as? ASAuthorizationAppleIDCredential,
                        let nonce = currentNonce
                    else {
                        appState.errorMessage = "Apple Sign-In failed."
                        return
                    }
                    Task {
                        await appState.signInWithApple(credential: credential, rawNonce: nonce)
                    }
                case let .failure(error):
                    appState.errorMessage = error.localizedDescription
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 24)

#if DEBUG
            Button("開発用: サインインをスキップ") {
                Task {
                    await appState.debugEnterMainTabs()
                }
            }
            .buttonStyle(.bordered)
#endif

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.errorText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground.ignoresSafeArea())
    }
}
