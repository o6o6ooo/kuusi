import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.route {
        case .signedOut:
            LoginView()
        case .locked:
            UnlockView()
        case .signedIn:
            MainTabView()
        }
    }
}
