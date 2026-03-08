import SwiftUI

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var pageBackground: Color { AppTheme.pageBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ContentUnavailableView("No groups yet", systemImage: "person.3")
                .foregroundStyle(primaryText)
                .navigationTitle("Groups")
                .navigationBarTitleDisplayMode(.inline)
                .background(pageBackground.ignoresSafeArea())
                .toolbarBackground(pageBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
