import SwiftUI

@MainActor
struct FeedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var photos: [FeedPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isUploadOverlayPresented = false

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
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(photos) { photo in
                                PhotoRow(photo: photo)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        await fetchFeed()
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
                UploadView()
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
            photos = try await feedService.fetchRecentPhotos(limit: 15)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PhotoRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let photo: FeedPhoto
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: photo.thumbnailURL ?? photo.photoURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(ProgressView())
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack {
                if let year = photo.year {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundStyle(primaryText.opacity(0.7))
                }
                if !photo.hashtags.isEmpty {
                    Text(photo.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(primaryText.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
