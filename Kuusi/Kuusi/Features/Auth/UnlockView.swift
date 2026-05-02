import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 56))
            Text("auth.unlock.title")
                .font(.title2.weight(.bold))
                .accessibilityIdentifier("unlock-title")
            Text("auth.unlock.subtitle")
                .foregroundStyle(.secondary)

            Button("auth.unlock.button") {
                Task {
                    await appState.unlockApp()
                }
            }
            .buttonStyle(.appPrimaryCapsule)
            .controlSize(.regular)
            .accessibilityIdentifier("unlock-button")
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenTheme()
        .appFeedBackground()
        .accessibilityIdentifier("unlock-screen")
    }
}
