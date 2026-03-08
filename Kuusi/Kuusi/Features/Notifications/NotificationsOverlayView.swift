import SwiftUI

struct NotificationsOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var pageBackground: Color { AppTheme.pageBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ContentUnavailableView("No notifications yet", systemImage: "bell.slash")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(primaryText)
                .background(pageBackground)
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(pageBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
