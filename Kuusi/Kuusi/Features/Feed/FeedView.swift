import SwiftUI
import UIKit

@MainActor
struct FeedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var photos: [FeedPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isUploadOverlayPresented = false
    @State private var selectedPhoto: FeedPhoto?
    @State private var feedMessage: String?
    @State private var measuredAspectRatios: [String: CGFloat] = [:]
    @State private var measuringAspectRatioIDs: Set<String> = []

    private let feedService = FeedService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading feed...")
                } else if let errorMessage {
                    ContentUnavailableView("Failed to load feed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if photos.isEmpty {
                    ContentUnavailableView("No photos yet", systemImage: "photo")
                } else {
                    GeometryReader { proxy in
                        let spacing: CGFloat = 8
                        let horizontalPadding: CGFloat = 12
                        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
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
                                            PhotoTile(
                                                photo: photo,
                                                width: columnWidth,
                                                displayAspectRatio: CGFloat(
                                                    photo.aspectRatio ?? Double(measuredAspectRatios[photo.id] ?? 1.0)
                                                ),
                                                onTap: { selectedPhoto = photo },
                                                onEdit: { feedMessage = "Edit is coming soon." },
                                                onDelete: { feedMessage = "Delete is coming soon." },
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

                            if let feedMessage {
                                Text(feedMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                    .padding(.bottom, 8)
                            }
                        }
                        .refreshable {
                            await fetchFeed()
                        }
                    }
                }
            }
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                Button {
                    isUploadOverlayPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.leading, 14)
            }
            .task {
                if photos.isEmpty {
                    await fetchFeed()
                }
            }
            .sheet(isPresented: $isUploadOverlayPresented) {
                UploadOverlayView()
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedPhoto) { photo in
                FeedPreviewSheet(photo: photo)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @MainActor
    private func fetchFeed() async {
        isLoading = true
        defer { isLoading = false }
        do {
            photos = try await feedService.fetchRecentPhotos(limit: 10)
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

private struct PhotoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let photo: FeedPhoto
    let width: CGFloat
    let displayAspectRatio: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
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
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .task {
            onRequireAspectRatio()
        }
    }
}

private struct FeedPreviewSheet: View {
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
