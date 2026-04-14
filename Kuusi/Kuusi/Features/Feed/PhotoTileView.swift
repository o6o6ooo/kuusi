import SwiftUI

struct PhotoTileView: View {
    @Environment(\.colorScheme) private var colorScheme

    let photo: FeedPhoto
    let width: CGFloat
    let displayAspectRatio: CGFloat
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavourite: () -> Void
    let isDeleting: Bool
    let isFavouriting: Bool
    let isEditing: Bool

    var body: some View {
        let ratio = max(displayAspectRatio, 0.35)
        let collapsedHeight = width / ratio
        let expandedHeight = min(max(collapsedHeight * 1.58, width * 1.05), width * 2.1)
        let imageURL = URL(string: isExpanded ? (photo.photoURL ?? photo.thumbnailURL ?? "") : (photo.thumbnailURL ?? photo.photoURL ?? ""))

        VStack(alignment: .leading, spacing: 0) {
            CachedRemoteImageView(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .overlay(ProgressView())
            }
            .frame(width: width, height: isExpanded ? expandedHeight : collapsedHeight)

            if isExpanded {
                expandedMeta
            }
        }
        .background(tileBackground)
        .contentShape(RoundedRectangle(cornerRadius: isExpanded ? 26 : 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 26 : 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: isExpanded ? 26 : 18, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            statusBadge
        }
        .overlay {
            if isDeleting || isEditing {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    ProgressView()
                }
            }
        }
        .scaleEffect(isExpanded ? 1.015 : 1)
        .shadow(color: .black.opacity(isExpanded ? 0.18 : 0.08), radius: isExpanded ? 16 : 8, x: 0, y: isExpanded ? 10 : 4)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: isExpanded)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onToggleFavourite()
            } label: {
                Label(
                    photo.isFavourite ? "Remove from favourites" : "Add to favourites",
                    systemImage: photo.isFavourite ? "heart.slash" : "heart"
                )
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .disabled(isDeleting || isEditing || isFavouriting)
    }

    private var tileBackground: some View {
        Group {
            if isExpanded {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.96),
                        Color.white.opacity(colorScheme == .dark ? 0.03 : 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.42), in: Capsule())
            }

            if photo.isFavourite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
            }
        }
        .padding(12)
    }

    private var expandedMeta: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(photo.year.map(String.init) ?? "Shared memory")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if !photo.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photo.hashtags, id: \.self) { hashtag in
                            Text("#\(hashtag)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
    }
}
