import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentNonce: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            uiTestMarker("login-screen")

            VStack(spacing: 18) {
                Spacer(minLength: 32)
                Image("BrandTree")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .accessibilityHidden(true)

                Text("Kuusi")
                    .font(.title.weight(.bold))
                    .accessibilityIdentifier("login-title")
                Text("auth.login.subtitle")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("login-subtitle")

                VStack(spacing: 12) {
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
                                appState.toastMessage = AppMessage(.appleSignInFailed, .error)
                                return
                            }
                            Task {
                                await appState.signInWithApple(credential: credential, rawNonce: nonce)
                            }
                        case let .failure(error):
                            _ = error
                            appState.toastMessage = AppMessage(.appleSignInFailed, .error)
                        }
                    })
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    .accessibilityIdentifier("apple-sign-in-button")
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 420)

#if DEBUG
                if !appState.debugAccounts.isEmpty {
                    HStack(spacing: 10) {
                        Picker("auth.login.dev_user_picker", selection: Binding(
                            get: { appState.selectedDebugAccountID ?? "" },
                            set: { appState.selectedDebugAccountID = $0 }
                        )) {
                            ForEach(appState.debugAccounts) { account in
                                Text(account.displayLabel).tag(account.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .controlSize(.small)

                        Button("auth.login.dev_sign_in") {
                            Task {
                                await appState.debugEnterMainTabs(selectedAccountID: appState.selectedDebugAccountID)
                            }
                        }
                        .buttonStyle(.appPrimaryCapsule)
                        .controlSize(.small)
                        .accessibilityIdentifier("debug-sign-in-button")
                    }
                    .padding(.horizontal, 24)
                } else {
                    Button("auth.login.dev_sign_in") {
                        Task {
                            await appState.debugEnterMainTabs()
                        }
                    }
                    .buttonStyle(.appPrimaryCapsule)
                    .controlSize(.small)
                    .accessibilityIdentifier("debug-sign-in-button")
                }
#endif
                Spacer(minLength: 24)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenTheme()
        .appFeedBackground()
#if DEBUG
        .onAppear {
            appState.refreshDebugAccounts()
        }
#endif
    }

    private func uiTestMarker(_ identifier: String) -> some View {
        Text(identifier)
            .font(.caption2)
            .foregroundStyle(.clear)
            .accessibilityIdentifier(identifier)
            .frame(width: 0, height: 0)
            .clipped()
            .allowsHitTesting(false)
    }
}
