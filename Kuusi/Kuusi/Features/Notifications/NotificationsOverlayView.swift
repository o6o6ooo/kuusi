import SwiftUI

struct NotificationsOverlayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No notifications yet", systemImage: "bell.slash")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .screenTheme()
        }
    }
}
