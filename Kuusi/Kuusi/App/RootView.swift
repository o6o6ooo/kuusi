import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.route {
        case .signedOut:
            LoginView()
                .overlay(alignment: .topLeading) {
                    uiTestMarker("ui-test-route-signed-out")
                }
        case .locked:
            UnlockView()
                .overlay(alignment: .topLeading) {
                    uiTestMarker("ui-test-route-locked")
                }
        case .signedIn:
            MainTabView()
                .overlay(alignment: .topLeading) {
                    uiTestMarker("ui-test-route-signed-in")
                }
        }
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
