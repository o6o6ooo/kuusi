import Combine
import FirebaseAuth
import SwiftUI

protocol PhotoCollectionFeedServicing {
    func fetchRecentPhotoBatch(
        userID: String,
        groupIDs: [String],
        limit: Int,
        startAfter cursor: FeedPageCursor?,
        favouriteIDs: Set<String>?
    ) async throws -> RecentPhotoFetchResult
}

protocol PhotoCollectionGroupServicing {
    func cachedGroups(for uid: String) -> [GroupSummary]
    func fetchGroups(for uid: String) async throws -> [GroupSummary]
}

extension FeedService: PhotoCollectionFeedServicing {}
extension GroupService: PhotoCollectionGroupServicing {}

private struct CachedFeedPhoto: Codable {
    let id: String
    let previewStoragePath: String?
    let thumbnailStoragePath: String?
    let groupID: String?
    let postedBy: String?
    let year: Int?
    let hashtags: [String]
    let isFavourite: Bool
    let sizeMB: Double?
    let aspectRatio: Double?
    let createdAt: Date?

    init(photo: FeedPhoto) {
        id = photo.id
        previewStoragePath = photo.previewStoragePath
        thumbnailStoragePath = photo.thumbnailStoragePath
        groupID = photo.groupID
        postedBy = photo.postedBy
        year = photo.year
        hashtags = photo.hashtags
        isFavourite = photo.isFavourite
        sizeMB = photo.sizeMB
        aspectRatio = photo.aspectRatio
        createdAt = photo.createdAt
    }

    func toFeedPhoto() -> FeedPhoto {
        FeedPhoto(
            id: id,
            previewStoragePath: previewStoragePath,
            thumbnailStoragePath: thumbnailStoragePath,
            groupID: groupID,
            postedBy: postedBy,
            year: year,
            hashtags: hashtags,
            isFavourite: isFavourite,
            sizeMB: sizeMB,
            aspectRatio: aspectRatio,
            createdAt: createdAt
        )
    }
}

@MainActor
final class PhotoCollectionViewModel: ObservableObject {
    @Published var groups: [GroupSummary] = []
    @Published var selectedGroupID: String?
    @Published var photosByGroupID: [String: [FeedPhoto]] = [:]
    @Published private(set) var availableHashtagsByGroupID: [String: [String]] = [:]
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessageID: AppMessage.ID?

    private let feedService: PhotoCollectionFeedServicing
    private let groupService: PhotoCollectionGroupServicing
    private let currentUserIDProvider: @MainActor () -> String?
    private static var photosCacheByUID: [String: [String: [FeedPhoto]]] = [:]
    private static let cacheLock = NSLock()
    private static let defaults = UserDefaults.standard
    private static let photoCacheKeyPrefix = "feed_photos_cache_v1_"
    private var nextCursorByGroupID: [String: FeedPageCursor] = [:]
    private var hasMorePhotosByGroupID: [String: Bool] = [:]
    private var favouriteIDs: Set<String>?

    init(
        feedService: PhotoCollectionFeedServicing,
        groupService: PhotoCollectionGroupServicing,
        currentUserIDProvider: @escaping @MainActor () -> String?
    ) {
        self.feedService = feedService
        self.groupService = groupService
        self.currentUserIDProvider = currentUserIDProvider
    }

    convenience init() {
        self.init(
            feedService: FeedService(),
            groupService: GroupService(),
            currentUserIDProvider: { Auth.auth().currentUser?.uid }
        )
    }

    var currentGroupPhotos: [FeedPhoto] {
        guard let selectedGroupID else { return [] }
        return photosByGroupID[selectedGroupID] ?? []
    }

    var currentGroupPhotoSignature: [String] {
        currentGroupPhotos.map { "\($0.id)-\($0.year ?? 0)" }
    }

    var currentGroupAvailableHashtags: [String] {
        guard let selectedGroupID else { return [] }
        if let cached = availableHashtagsByGroupID[selectedGroupID] {
            return cached
        }
        return Self.makeAvailableHashtags(from: currentGroupPhotos)
    }

    var canLoadMoreCurrentGroupPhotos: Bool {
        guard let selectedGroupID else { return false }
        return hasMorePhotosByGroupID[selectedGroupID] ?? false
    }

    func loadInitial(limit: Int) async {
        guard let uid = currentUserIDProvider() else {
            resetState()
            return
        }

        var cachedGroups = groupService.cachedGroups(for: uid)
        if cachedGroups.isEmpty {
            do {
                cachedGroups = try await groupService.fetchGroups(for: uid)
            } catch {
                resetState()
                errorMessageID = .failedToLoadGroups
                return
            }
        }

        groups = cachedGroups
        selectedGroupID = cachedGroups.first?.id
        photosByGroupID = loadCachedPhotos(for: uid, validGroupIDs: Set(cachedGroups.map(\.id)))
        availableHashtagsByGroupID = photosByGroupID.mapValues(Self.makeAvailableHashtags(from:))
        hasMorePhotosByGroupID = photosByGroupID.mapValues { !$0.isEmpty }
        nextCursorByGroupID = [:]
        errorMessageID = nil
        await fetchPhotosForSelectedGroup(forceReload: false, limit: limit)
    }

    func refresh(limit: Int) async {
        guard let uid = currentUserIDProvider() else { return }

        do {
            let freshGroups = try await groupService.fetchGroups(for: uid)
            groups = freshGroups
            if let selectedGroupID, freshGroups.contains(where: { $0.id == selectedGroupID }) {
                self.selectedGroupID = selectedGroupID
            } else {
                selectedGroupID = freshGroups.first?.id
            }
            let validGroupIDs = Set(freshGroups.map(\.id))
            photosByGroupID = photosByGroupID.filter { validGroupIDs.contains($0.key) }
            availableHashtagsByGroupID = availableHashtagsByGroupID.filter { validGroupIDs.contains($0.key) }
            nextCursorByGroupID = nextCursorByGroupID.filter { validGroupIDs.contains($0.key) }
            hasMorePhotosByGroupID = hasMorePhotosByGroupID.filter { validGroupIDs.contains($0.key) }
            persistCachedPhotos(for: uid)
            await fetchPhotosForSelectedGroup(forceReload: true, limit: limit, shouldPreserveLoadedPhotos: true)
        } catch {
            errorMessageID = .failedToLoadGroups
        }
    }

    func selectGroup(_ groupID: String, limit: Int) {
        selectedGroupID = groupID
        errorMessageID = nil
        Task {
            await fetchPhotosForSelectedGroup(forceReload: false, limit: limit)
        }
    }

    func replacePhoto(_ updatedPhoto: FeedPhoto) {
        guard let selectedGroupID else { return }
        guard var cachedPhotos = photosByGroupID[selectedGroupID],
              let index = cachedPhotos.firstIndex(where: { $0.id == updatedPhoto.id }) else {
            return
        }

        cachedPhotos[index] = updatedPhoto
        photosByGroupID[selectedGroupID] = cachedPhotos
        availableHashtagsByGroupID[selectedGroupID] = Self.makeAvailableHashtags(from: cachedPhotos)
        persistCachedPhotosIfPossible()
    }

    func removePhoto(id: String) {
        guard let selectedGroupID else { return }
        guard var cachedPhotos = photosByGroupID[selectedGroupID] else { return }

        cachedPhotos.removeAll { $0.id == id }
        photosByGroupID[selectedGroupID] = cachedPhotos
        availableHashtagsByGroupID[selectedGroupID] = Self.makeAvailableHashtags(from: cachedPhotos)
        persistCachedPhotosIfPossible()
    }

    func clearErrorMessage() {
        errorMessageID = nil
    }

    func loadMoreIfNeeded(pageSize: Int) {
        guard let selectedGroupID else { return }
        guard !isLoading, !isLoadingMore else { return }
        guard hasMorePhotosByGroupID[selectedGroupID] ?? false else { return }

        Task {
            await fetchPhotosForSelectedGroup(
                forceReload: false,
                limit: pageSize,
                isLoadMore: true
            )
        }
    }

    private func fetchPhotosForSelectedGroup(
        forceReload: Bool,
        limit: Int,
        isLoadMore: Bool = false,
        shouldPreserveLoadedPhotos: Bool = false
    ) async {
        if isLoadMore {
            isLoadingMore = true
        } else {
            isLoading = true
        }
        defer {
            if isLoadMore {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        }

        do {
            guard let uid = currentUserIDProvider() else {
                errorMessageID = nil
                return
            }
            guard let selectedGroupID else {
                errorMessageID = nil
                return
            }

            if !forceReload, !isLoadMore, photosByGroupID[selectedGroupID] != nil {
                errorMessageID = nil
                return
            }

            if forceReload {
                nextCursorByGroupID[selectedGroupID] = nil
            }

            let cursor = isLoadMore ? nextCursorByGroupID[selectedGroupID] : nil

            let result = try await feedService.fetchRecentPhotoBatch(
                userID: uid,
                groupIDs: [selectedGroupID],
                limit: limit,
                startAfter: cursor,
                favouriteIDs: forceReload ? nil : favouriteIDs
            )
            let mergedPhotos: [FeedPhoto]
            if isLoadMore {
                let existingPhotos = photosByGroupID[selectedGroupID] ?? []
                mergedPhotos = Self.mergePhotos(existingPhotos, with: result.photos)
            } else if shouldPreserveLoadedPhotos {
                let existingPhotos = photosByGroupID[selectedGroupID] ?? []
                mergedPhotos = Self.mergeFreshPhotos(result.photos, withExistingPhotos: existingPhotos)
            } else {
                mergedPhotos = result.photos
            }

            photosByGroupID[selectedGroupID] = mergedPhotos
            availableHashtagsByGroupID[selectedGroupID] = Self.makeAvailableHashtags(from: mergedPhotos)
            nextCursorByGroupID[selectedGroupID] = result.nextCursor
            hasMorePhotosByGroupID[selectedGroupID] = result.hasMore
            favouriteIDs = result.favouriteIDs
            persistCachedPhotos(for: uid)
            errorMessageID = nil
        } catch {
            errorMessageID = .failedToLoadFeed
        }
    }

    private func resetState() {
        groups = []
        selectedGroupID = nil
        photosByGroupID = [:]
        availableHashtagsByGroupID = [:]
        nextCursorByGroupID = [:]
        hasMorePhotosByGroupID = [:]
        favouriteIDs = nil
        errorMessageID = nil
    }

    private func persistCachedPhotosIfPossible() {
        guard let uid = currentUserIDProvider() else { return }
        persistCachedPhotos(for: uid)
    }

    private func persistCachedPhotos(for uid: String) {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }

        Self.photosCacheByUID[uid] = photosByGroupID
        let encodable = photosByGroupID.mapValues { photos in
            photos.map(CachedFeedPhoto.init(photo:))
        }
        if let data = try? JSONEncoder().encode(encodable) {
            Self.defaults.set(data, forKey: Self.photoCacheKey(for: uid))
        }
    }

    private func loadCachedPhotos(for uid: String, validGroupIDs: Set<String>) -> [String: [FeedPhoto]] {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }

        let cachedPhotos: [String: [FeedPhoto]]
        if let inMemory = Self.photosCacheByUID[uid] {
            cachedPhotos = inMemory
        } else if
            let data = Self.defaults.data(forKey: Self.photoCacheKey(for: uid)),
            let decoded = try? JSONDecoder().decode([String: [CachedFeedPhoto]].self, from: data) {
            cachedPhotos = decoded.mapValues { cached in
                cached.map { $0.toFeedPhoto() }
            }
            Self.photosCacheByUID[uid] = cachedPhotos
        } else {
            return [:]
        }

        let filtered = cachedPhotos.filter { validGroupIDs.contains($0.key) }
        Self.photosCacheByUID[uid] = filtered
        if filtered.count != cachedPhotos.count {
            let encodable = filtered.mapValues { photos in
                photos.map(CachedFeedPhoto.init(photo:))
            }
            if let data = try? JSONEncoder().encode(encodable) {
                Self.defaults.set(data, forKey: Self.photoCacheKey(for: uid))
            }
        }
        return filtered
    }

    private static func photoCacheKey(for uid: String) -> String {
        "\(photoCacheKeyPrefix)\(uid)"
    }

    static func clearCachedPhotos(for uid: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        photosCacheByUID[uid] = nil
        defaults.removeObject(forKey: photoCacheKey(for: uid))
    }

    private static func makeAvailableHashtags(from photos: [FeedPhoto]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for photo in photos {
            for hashtag in photo.hashtags {
                let trimmed = hashtag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let normalized = trimmed.lowercased()
                guard seen.insert(normalized).inserted else { continue }
                ordered.append(trimmed)
            }
        }

        return ordered
    }

    private static func mergePhotos(_ existingPhotos: [FeedPhoto], with newPhotos: [FeedPhoto]) -> [FeedPhoto] {
        guard !existingPhotos.isEmpty else { return newPhotos }
        guard !newPhotos.isEmpty else { return existingPhotos }

        var merged = existingPhotos
        var seenIDs = Set(existingPhotos.map(\.id))
        for photo in newPhotos where !seenIDs.contains(photo.id) {
            merged.append(photo)
            seenIDs.insert(photo.id)
        }
        return merged
    }

    private static func mergeFreshPhotos(_ freshPhotos: [FeedPhoto], withExistingPhotos existingPhotos: [FeedPhoto]) -> [FeedPhoto] {
        guard !freshPhotos.isEmpty else { return existingPhotos }
        guard !existingPhotos.isEmpty else { return freshPhotos }

        var merged = freshPhotos
        var seenIDs = Set(freshPhotos.map(\.id))
        for photo in existingPhotos where !seenIDs.contains(photo.id) {
            merged.append(photo)
            seenIDs.insert(photo.id)
        }
        return merged
    }
}
