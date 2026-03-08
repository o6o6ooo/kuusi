import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "square.grid.3x3")
                }
                .accessibilityLabel("Feed")

            UploadView()
                .tabItem {
                    Image(systemName: "photo.badge.plus")
                }
                .accessibilityLabel("Upload")

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
        }
    }
}
