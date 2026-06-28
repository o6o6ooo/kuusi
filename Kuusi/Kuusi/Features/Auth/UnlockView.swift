import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            uiTestMarker("unlock-screen")

            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "faceid")
                    .font(.system(size: 56))
                Text("auth.unlock.title")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("unlock-title")
                Text("auth.unlock.subtitle")
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await appState.unlockApp()
                    }
                } label: {
                    Text("auth.unlock.button")
                }
                .buttonStyle(.appPrimaryCapsule)
                .accessibilityIdentifier("unlock-button")
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenTheme()
        .appFeedBackground()
        .onAppear {
            AppTelemetry.setScreen(.unlock)
        }
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
