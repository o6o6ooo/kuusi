import FirebaseAuth
import SwiftUI
import UIKit

@MainActor
struct FavoritesView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var photos: [FeedPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: FeedPhoto?
    @State private var measuredAspectRatios: [String: CGFloat] = [:]
    @State private var measuringAspectRatioIDs: Set<String> = []

    private let feedService = FeedService()
    private let groupService = GroupService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading favourites...")
                } else if let errorMessage {
                    ContentUnavailableView("Failed to load favourites", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if photos.isEmpty {
                    ContentUnavailableView("No favourites yet", systemImage: "heart")
                } else {
                    GeometryReader { proxy in
                        let spacing: CGFloat = 8
                        let horizontalPadding: CGFloat = 12
                        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
                        let totalSpacing = spacing * CGFloat(columnCount - 1)
                        let contentWidth = proxy.size.width - (horizontalPadding * 2)
                        let columnWidth = max(80, (contentWidth - totalSpacing) / CGFloat(columnCount))
                        let columns = makeWaterfallColumns(
                            photos: photos,
                            columnCount: columnCount,
                            columnWidth: columnWidth,
                            spacing: spacing
                        )

                        ScrollView {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(0..<columnCount, id: \.self) { columnIndex in
                                    LazyVStack(spacing: spacing) {
                                        ForEach(columns[columnIndex]) { photo in
                                            FavoritesPhotoTile(
                                                photo: photo,
                                                width: columnWidth,
                                                displayAspectRatio: CGFloat(
                                                    photo.aspectRatio ?? Double(measuredAspectRatios[photo.id] ?? 1.0)
                                                ),
                                                onTap: { selectedPhoto = photo },
                                                onRequireAspectRatio: {
                                                    requestAspectRatioIfNeeded(for: photo)
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, 8)
                        }
                        .refreshable {
                            await fetchFavourites()
                        }
                    }
                }
            }
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if photos.isEmpty {
                    await fetchFavourites()
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                FavoritesPreviewSheet(photo: photo)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func fetchFavourites() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                photos = []
                errorMessage = nil
                return
            }
            let groupIDs = groupService.cachedGroups(for: uid).map(\.id)
            photos = try await feedService.fetchFavouritePhotos(userID: uid, groupIDs: groupIDs, limit: 6)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeWaterfallColumns(
        photos: [FeedPhoto],
        columnCount: Int,
        columnWidth: CGFloat,
        spacing: CGFloat
    ) -> [[FeedPhoto]] {
        guard columnCount > 0 else { return [] }
        var columns = Array(repeating: [FeedPhoto](), count: columnCount)
        var heights = Array(repeating: CGFloat.zero, count: columnCount)

        for photo in photos {
            let ratio = max(
                CGFloat(photo.aspectRatio ?? Double(measuredAspectRatios[photo.id] ?? 1.0)),
                0.35
            )
            let tileHeight = columnWidth / ratio
            let shortest = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortest].append(photo)
            heights[shortest] += tileHeight + spacing
        }
        return columns
    }

    private func requestAspectRatioIfNeeded(for photo: FeedPhoto) {
        // TODO: Remove this fallback after all legacy photos have aspect_ratio.
        if photo.aspectRatio != nil { return }
        if measuredAspectRatios[photo.id] != nil { return }
        if measuringAspectRatioIDs.contains(photo.id) { return }
        guard let urlString = photo.thumbnailURL ?? photo.photoURL else { return }

        measuringAspectRatioIDs.insert(photo.id)
        Task {
            let ratio = await measureAspectRatio(from: urlString)
            measuringAspectRatioIDs.remove(photo.id)
            guard let ratio else { return }
            measuredAspectRatios[photo.id] = ratio
        }
    }

    nonisolated private func measureAspectRatio(from urlString: String) async -> CGFloat? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), image.size.height > 0 else { return nil }
            return CGFloat(image.size.width / image.size.height)
        } catch {
            return nil
        }
    }
}

private struct FavoritesPhotoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let photo: FeedPhoto
    let width: CGFloat
    let displayAspectRatio: CGFloat
    let onTap: () -> Void
    let onRequireAspectRatio: () -> Void

    var body: some View {
        let ratio = max(displayAspectRatio, 0.35)
        AsyncImage(url: URL(string: photo.thumbnailURL ?? photo.photoURL ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                .overlay(ProgressView())
        }
        .frame(width: width, height: width / ratio)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onTap()
        }
        .task {
            onRequireAspectRatio()
        }
    }
}

private struct FavoritesPreviewSheet: View {
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
                Text(photo.hashtags.prefix(6).map { "#\($0)" }.joined(separator: " "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No hashtags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .screenTheme()
    }
}
