import SwiftUI

struct HashtagsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No photos yet", systemImage: "number")
                .screenTheme()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
