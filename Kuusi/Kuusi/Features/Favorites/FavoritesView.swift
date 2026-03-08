import SwiftUI

struct FavoritesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No photos yet", systemImage: "heart.fill")
                .screenTheme()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
