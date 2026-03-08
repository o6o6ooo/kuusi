import SwiftUI

@MainActor
struct FeedView: View {
    @State private var photos: [FeedPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isNotificationsOverlayPresented = false
    @State private var notificationsDragOffset: CGFloat = 0

    private let feedService = FeedService()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                notificationsDragOffset = 0
                                isNotificationsOverlayPresented = true
                            }
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

                if isNotificationsOverlayPresented {
                    NotificationsOverlayView {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isNotificationsOverlayPresented = false
                            notificationsDragOffset = 0
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .offset(y: notificationsDragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                notificationsDragOffset = max(0, value.translation.height)
                            }
                            .onEnded { value in
                                if value.translation.height > 8 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        isNotificationsOverlayPresented = false
                                        notificationsDragOffset = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        notificationsDragOffset = 0
                                    }
                                }
                            }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
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
