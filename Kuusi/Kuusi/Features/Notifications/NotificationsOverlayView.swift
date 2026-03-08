import SwiftUI

struct NotificationsOverlayView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            Label("Notifications", systemImage: "bell")
                .font(.headline)

            Divider()

            ContentUnavailableView("No notifications yet", systemImage: "bell.slash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
    }
}
