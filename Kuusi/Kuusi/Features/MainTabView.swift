import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "square.grid.3x3")
                }

            UploadView()
                .tabItem {
                    Label("Upload", systemImage: "photo.badge.plus")
                }

            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
