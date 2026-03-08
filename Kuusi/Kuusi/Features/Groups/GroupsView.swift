import SwiftUI

struct GroupsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No groups yet", systemImage: "person.3")
                .navigationTitle("Groups")
                .navigationBarTitleDisplayMode(.inline)
                .screenTheme()
        }
    }
}
