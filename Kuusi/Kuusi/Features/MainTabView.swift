import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "circle.grid.3x3.fill")
                }
                .accessibilityLabel("Feed")

            HashtagsView()
                .tabItem {
                    Image(systemName: "number")
                }
                .accessibilityLabel("Hashtags")

            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                }
                .accessibilityLabel("Favorites")

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
        }
    }
}
