import Combine
import SwiftUI

@MainActor
private final class FeedAuthorNameStore {
    static let shared = FeedAuthorNameStore()

    private let userService = UserService()
    private let defaults = UserDefaults.standard
    private let cacheKey = "feed_author_name_cache_v1"
    private var memoryCache: [String: String] = [:]
    private var inFlightTasks: [String: Task<String?, Never>] = [:]
    private var didLoadDefaults = false

    func name(for uid: String) async -> String? {
        loadDefaultsIfNeeded()

        if let cached = memoryCache[uid] {
            return cached
        }

        if let task = inFlightTasks[uid] {
            return await task.value
        }

        let task = Task<String?, Never> {
            defer { self.clearTask(for: uid) }

            do {
                guard let user = try await userService.fetchUser(uid: uid) else {
                    return nil
                }
                store(user.name, for: uid)
                return user.name
            } catch {
                return nil
            }
        }

        inFlightTasks[uid] = task
        return await task.value
    }

    private func loadDefaultsIfNeeded() {
        guard !didLoadDefaults else { return }
        didLoadDefaults = true

        guard let cached = defaults.dictionary(forKey: cacheKey) as? [String: String] else {
            return
        }

        memoryCache = cached
    }

    private func store(_ name: String, for uid: String) {
        memoryCache[uid] = name
        defaults.set(memoryCache, forKey: cacheKey)
    }

    private func clearTask(for uid: String) {
        inFlightTasks[uid] = nil
    }
}

@MainActor
private final class PhotoAuthorNameViewModel: ObservableObject {
    @Published private(set) var name: String?

    func loadName(for uid: String?) async {
        guard let uid, !uid.isEmpty else {
            name = nil
            return
        }

        name = await FeedAuthorNameStore.shared.name(for: uid)
    }
}

private struct PhotoAuthorNameView: View {
    let uid: String?

    @StateObject private var viewModel = PhotoAuthorNameViewModel()

    var body: some View {
        Text(viewModel.name ?? " ")
            .opacity(viewModel.name == nil ? 0 : 1)
        .task(id: uid) {
            await viewModel.loadName(for: uid)
        }
    }
}

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
        let expandedHeight = width / ratio
        let imageURL = URL(string: isExpanded ? (photo.photoURL ?? photo.thumbnailURL ?? "") : (photo.thumbnailURL ?? photo.photoURL ?? ""))

        VStack(alignment: .leading, spacing: 0) {
            CachedRemoteImageView(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .overlay(ProgressView())
            }
            .frame(width: width, height: isExpanded ? expandedHeight : collapsedHeight)
            .overlay(alignment: .bottomLeading) {
                if isExpanded {
                    expandedMetaOverlay
                }
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
        .scaleEffect(1)
        .shadow(color: .black.opacity(isExpanded ? 0.1 : 0.08), radius: isExpanded ? 10 : 8, x: 0, y: isExpanded ? 5 : 4)
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
            if photo.isFavourite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
            }
        }
        .padding(12)
    }

    private var expandedMetaOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(photo.year.map(String.init) ?? "Shared memory")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(yearOverlayColor)
                    .shadow(color: overlayShadowColor, radius: 8, x: 0, y: 3)

                PhotoAuthorNameView(uid: photo.postedBy)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(yearOverlayColor)
                    .shadow(color: overlayShadowColor, radius: 8, x: 0, y: 3)
            }

            if !photo.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photo.hashtags, id: \.self) { hashtag in
                            Text("#\(hashtag)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .appFeedGlassCapsule()
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.18 : 0.22),
                    .black.opacity(colorScheme == .dark ? 0.44 : 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var yearOverlayColor: Color {
        Color.white.opacity(0.72)
    }

    private var overlayShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.22)
    }
}
