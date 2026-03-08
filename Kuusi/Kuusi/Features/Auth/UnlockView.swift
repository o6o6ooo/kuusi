import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 56))
            Text("Unlock Kuusi")
                .font(.title2.bold())
            Text("Use Face ID or Touch ID")
                .foregroundStyle(.secondary)

            Button("Unlock") {
                Task {
                    await appState.unlockApp()
                }
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.errorText)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenTheme()
    }
}
