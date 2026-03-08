import SwiftUI

struct CalendarView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No photos yet", systemImage: "calendar")
                .screenTheme()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
