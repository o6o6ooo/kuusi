import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var pageBackground: Color { AppTheme.pageBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 56))
                .foregroundStyle(primaryText)
            Text("Unlock Kuusi")
                .font(.title2.bold())
                .foregroundStyle(primaryText)
            Text("Use Face ID or Touch ID")
                .foregroundStyle(primaryText.opacity(0.72))

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
        .background(pageBackground.ignoresSafeArea())
    }
}
