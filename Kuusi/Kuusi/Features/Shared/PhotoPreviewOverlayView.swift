import SwiftUI

struct PhotoPreviewOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    let photo: FeedPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: photo.photoURL ?? photo.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .overlay(ProgressView())
                    .frame(height: 260)
            }

            if !photo.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photo.hashtags, id: \.self) { hashtag in
                            Text("#\(hashtag)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text(String(photo.year ?? 0))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .screenTheme()
    }
}
