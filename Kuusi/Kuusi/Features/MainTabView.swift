import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "square.grid.3x3")
                }
                .accessibilityLabel("Feed")

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
        }
    }
}
