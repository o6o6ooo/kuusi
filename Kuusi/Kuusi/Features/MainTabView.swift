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

            GroupsView()
                .tabItem {
                    Label("Groups", systemImage: "person.3")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
