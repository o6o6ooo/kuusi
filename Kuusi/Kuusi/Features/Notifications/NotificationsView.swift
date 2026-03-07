import SwiftUI

struct NotificationsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No notifications yet", systemImage: "bell.slash")
                .navigationTitle("Notifications")
        }
    }
}
