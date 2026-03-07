import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Kuusi")
                .font(.largeTitle.bold())
            Text("Sign in with Apple to continue")
                .foregroundStyle(.secondary)

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

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding()
    }
}
