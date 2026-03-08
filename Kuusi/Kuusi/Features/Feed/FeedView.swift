import SwiftUI

@MainActor
struct FeedView: View {
    @State private var photos: [FeedPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isNotificationsOverlayPresented = false

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
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isNotificationsOverlayPresented = true
                    } label: {
                        Image(systemName: "bell")
                    }
                }
            }
            .task {
                if photos.isEmpty {
                    await fetchFeed()
                }
            }
            .sheet(isPresented: $isNotificationsOverlayPresented) {
                NotificationsOverlayView()
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
    let photo: FeedPhoto

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
                        .foregroundStyle(.secondary)
                }
                if !photo.hashtags.isEmpty {
                    Text(photo.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
