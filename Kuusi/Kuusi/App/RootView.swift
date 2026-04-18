import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.route {
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
