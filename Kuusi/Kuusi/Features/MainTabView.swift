import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "circle.grid.3x3.fill")
                }
                .accessibilityLabel("Feed")
                .accessibilityIdentifier("tab-feed")

            YearsView()
                .tabItem {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Years")
                .accessibilityIdentifier("tab-years")

            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                }
                .accessibilityLabel("Favorites")
                .accessibilityIdentifier("tab-favorites")

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("tab-settings")
        }
        .accessibilityIdentifier("main-tab-view")
    }
}
