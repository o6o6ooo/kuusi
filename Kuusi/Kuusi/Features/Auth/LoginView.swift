import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentNonce: String?
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 32)
            Image("BrandTree")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .accessibilityHidden(true)

            Text("Kuusi")
                .font(.system(size: 30, weight: .bold))
            Text("Share photos with your loved ones")
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    let nonce = CryptoNonce.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = CryptoNonce.sha256(nonce)
                }, onCompletion: { result in
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
                })
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle("Use \(appState.biometricDisplayName)", isOn: Binding(
                    get: { appState.biometricsEnabled },
                    set: { appState.setBiometricsEnabled($0) }
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)
            .frame(maxWidth: 460)

#if DEBUG
            Button("Dev: skip sign in") {
                Task {
                    await appState.debugEnterMainTabs()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
#endif

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.errorText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 24)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenTheme()
    }
}
