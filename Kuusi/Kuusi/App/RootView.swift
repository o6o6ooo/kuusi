import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.route {
            case .checkingAuth:
                AuthLoadingView()
            case .signedOut:
                LoginView()
            case .locked:
                signedInContent
            case .signedIn:
                signedInContent
            }
        }
        .overlay(alignment: .topLeading) {
            switch appState.route {
            case .checkingAuth:
                uiTestMarker("ui-test-route-checking-auth")
            case .signedOut:
                uiTestMarker("ui-test-route-signed-out")
            case .locked:
                uiTestMarker("ui-test-route-locked")
            case .signedIn:
                uiTestMarker("ui-test-route-signed-in")
            }
        }
        .overlay {
            if appState.route == .locked {
                UnlockView()
            }
        }
        .appToastMessage(appState.toastMessage) {
            appState.clearToastMessage()
        }
        .appToastHost()
    }

    private var signedInContent: some View {
        FeedView()
            .id(appState.signedInContentResetToken)
    }

    @ViewBuilder
    private func uiTestMarker(_ identifier: String) -> some View {
        if appState.isRunningUITests {
            Text(identifier)
                .font(.caption2)
                .foregroundStyle(.clear)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(identifier)
                .padding(1)
        }
    }
}

private struct AuthLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 18) {
            Image("BrandTree")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .accessibilityHidden(true)

            loadingDots
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenTheme()
        .appFeedBackground()
        .accessibilityIdentifier("auth-loading-screen")
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
    }

    private var loadingDots: some View {
        let accent = AppTheme.accent(for: colorScheme)

        return HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(accent.opacity(reduceMotion ? 0.75 : 0.45 + Double(index) * 0.15))
                    .frame(width: 8, height: 8)
                    .offset(y: isAnimating && !reduceMotion ? -7 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.46)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.16),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}
