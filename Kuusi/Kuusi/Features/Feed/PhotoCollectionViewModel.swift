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

extension FeedService: PhotoCollectionFeedServicing {}

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
    private let currentUserIDProvider: @MainActor () -> String?
    private static var photosCacheByUID: [String: [String: [FeedPhoto]]] = [:]
    private static let cacheLock = NSLock()
    private static let defaults = UserDefaults.standard
    private static let photoCacheKeyPrefix = "feed_photos_cache_v1_"
    private static let favouriteIDsCacheKeyPrefix = "feed_favourite_ids_cache_v1_"
    private var nextCursorByGroupID: [String: FeedPageCursor] = [:]
    private var hasMorePhotosByGroupID: [String: Bool] = [:]
    private var favouriteIDs: Set<String>?
    private var removedPhotoIDsByGroupID: [String: Set<String>] = [:]

    init(
        feedService: PhotoCollectionFeedServicing,
        currentUserIDProvider: @escaping @MainActor () -> String?
    ) {
        self.feedService = feedService
        self.currentUserIDProvider = currentUserIDProvider
    }

    convenience init() {
        let launchArguments = ProcessInfo.processInfo.arguments
        self.init(
            feedService: FeedService(),
            currentUserIDProvider: {
                guard !launchArguments.contains("UI_TEST_FORCE_EMPTY_GROUPS") else { return nil }
                return Auth.auth().currentUser?.uid
            }
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

    func loadInitial(groups: [GroupSummary], selectedGroupID: String?, limit: Int) async {
        guard let uid = currentUserIDProvider() else {
            resetState()
            return
        }

        syncGroups(groups, selectedGroupID: selectedGroupID)
        favouriteIDs = loadCachedFavouriteIDs(for: uid)
        photosByGroupID = loadCachedPhotos(for: uid, validGroupIDs: Set(groups.map(\.id)))
        if let favouriteIDs {
            photosByGroupID = Self.applyFavouriteIDs(favouriteIDs, to: photosByGroupID)
            if !photosByGroupID.isEmpty {
                persistCachedPhotos(for: uid)
            }
        }
        availableHashtagsByGroupID = photosByGroupID.mapValues(Self.makeAvailableHashtags(from:))
        hasMorePhotosByGroupID = photosByGroupID.mapValues { !$0.isEmpty }
        nextCursorByGroupID = photosByGroupID.compactMapValues(Self.makeNextCursor(from:))
        errorMessageID = nil
        await fetchPhotosForSelectedGroup(forceReload: false, limit: limit)
    }

    func syncGroups(_ groups: [GroupSummary], selectedGroupID: String?) {
        self.groups = groups
        if let selectedGroupID, groups.contains(where: { $0.id == selectedGroupID }) {
            self.selectedGroupID = selectedGroupID
        } else if let current = self.selectedGroupID, groups.contains(where: { $0.id == current }) {
            self.selectedGroupID = current
        } else {
            self.selectedGroupID = groups.first?.id
        }

        let validGroupIDs = Set(groups.map(\.id))
        photosByGroupID = photosByGroupID.filter { validGroupIDs.contains($0.key) }
        availableHashtagsByGroupID = availableHashtagsByGroupID.filter { validGroupIDs.contains($0.key) }
        nextCursorByGroupID = nextCursorByGroupID.filter { validGroupIDs.contains($0.key) }
        hasMorePhotosByGroupID = hasMorePhotosByGroupID.filter { validGroupIDs.contains($0.key) }
        removedPhotoIDsByGroupID = removedPhotoIDsByGroupID.filter { validGroupIDs.contains($0.key) }
        if !photosByGroupID.isEmpty {
            persistCachedPhotosIfPossible()
        }
    }

    func refreshPhotos(limit: Int) async {
        guard let uid = currentUserIDProvider() else { return }

        persistCachedPhotos(for: uid)
        await fetchPhotosForSelectedGroup(forceReload: true, limit: limit)
    }

    func reloadPhotosFromSource(limit: Int) async {
        await fetchPhotosForSelectedGroup(forceReload: true, limit: limit)
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
        cachedPhotos.sort(by: Self.photosAreOrderedBefore)
        photosByGroupID[selectedGroupID] = cachedPhotos
        availableHashtagsByGroupID[selectedGroupID] = Self.makeAvailableHashtags(from: cachedPhotos)
        updateFavouriteIDs(for: updatedPhoto)
        persistFavouriteIDsIfPossible()
        persistCachedPhotosIfPossible()
    }

    func prependUploadedPhotos(_ uploadedPhotos: [FeedPhoto]) {
        guard !uploadedPhotos.isEmpty else { return }

        for groupID in Set(uploadedPhotos.compactMap(\.groupID)) {
            let newPhotos = uploadedPhotos.filter { $0.groupID == groupID }
            let removedPhotoIDs = removedPhotoIDsByGroupID[groupID] ?? []
            let existingPhotos = (photosByGroupID[groupID] ?? [])
                .filter { !removedPhotoIDs.contains($0.id) }
            photosByGroupID[groupID] = Self.mergeFreshPhotos(newPhotos, withExistingPhotos: existingPhotos)
                .sorted(by: Self.photosAreOrderedBefore)
            availableHashtagsByGroupID[groupID] = Self.makeAvailableHashtags(from: photosByGroupID[groupID] ?? [])
            nextCursorByGroupID[groupID] = Self.makeNextCursor(from: photosByGroupID[groupID] ?? [])
            hasMorePhotosByGroupID[groupID] = hasMorePhotosByGroupID[groupID] ?? false
        }

        persistCachedPhotosIfPossible()
    }

    func replaceWithUploadedPhotosPendingReload(_ uploadedPhotos: [FeedPhoto]) {
        guard !uploadedPhotos.isEmpty else { return }

        for groupID in Set(uploadedPhotos.compactMap(\.groupID)) {
            let newPhotos = uploadedPhotos
                .filter { $0.groupID == groupID }
                .sorted(by: Self.photosAreOrderedBefore)
            photosByGroupID[groupID] = newPhotos
            availableHashtagsByGroupID[groupID] = Self.makeAvailableHashtags(from: newPhotos)
            nextCursorByGroupID[groupID] = Self.makeNextCursor(from: newPhotos)
            hasMorePhotosByGroupID[groupID] = true
        }

        persistCachedPhotosIfPossible()
    }

    func removePhoto(id: String) {
        guard let selectedGroupID else { return }
        guard var cachedPhotos = photosByGroupID[selectedGroupID] else { return }

        cachedPhotos.removeAll { $0.id == id }
        photosByGroupID[selectedGroupID] = cachedPhotos
        availableHashtagsByGroupID[selectedGroupID] = Self.makeAvailableHashtags(from: cachedPhotos)
        removedPhotoIDsByGroupID[selectedGroupID, default: []].insert(id)
        favouriteIDs?.remove(id)
        persistFavouriteIDsIfPossible()
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
        isLoadMore: Bool = false
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
                favouriteIDs: favouriteIDs
            )
            let mergedPhotos: [FeedPhoto]
            let nextCursor: FeedPageCursor?
            let hasMorePhotos: Bool
            if isLoadMore {
                let existingPhotos = photosByGroupID[selectedGroupID] ?? []
                mergedPhotos = Self.mergePhotos(existingPhotos, with: result.photos)
                nextCursor = result.nextCursor
                hasMorePhotos = result.hasMore
            } else {
                mergedPhotos = result.photos
                nextCursor = result.nextCursor
                hasMorePhotos = result.hasMore
            }

            favouriteIDs = result.favouriteIDs
            let presentedPhotos = Self.applyFavouriteIDs(result.favouriteIDs, to: mergedPhotos)
            photosByGroupID[selectedGroupID] = presentedPhotos
            availableHashtagsByGroupID[selectedGroupID] = Self.makeAvailableHashtags(from: presentedPhotos)
            nextCursorByGroupID[selectedGroupID] = nextCursor
            hasMorePhotosByGroupID[selectedGroupID] = hasMorePhotos
            persistFavouriteIDs(result.favouriteIDs, for: uid)
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
        removedPhotoIDsByGroupID = [:]
        errorMessageID = nil
    }

    private func persistCachedPhotosIfPossible() {
        guard let uid = currentUserIDProvider() else { return }
        persistCachedPhotos(for: uid)
    }

    private func persistFavouriteIDsIfPossible() {
        guard let uid = currentUserIDProvider(), let favouriteIDs else { return }
        persistFavouriteIDs(favouriteIDs, for: uid)
    }

    private func updateFavouriteIDs(for photo: FeedPhoto) {
        if favouriteIDs == nil {
            favouriteIDs = Self.makeFavouriteIDs(from: photosByGroupID)
        }
        if photo.isFavourite {
            favouriteIDs?.insert(photo.id)
        } else {
            favouriteIDs?.remove(photo.id)
        }
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

    private static func favouriteIDsCacheKey(for uid: String) -> String {
        "\(favouriteIDsCacheKeyPrefix)\(uid)"
    }

    private func loadCachedFavouriteIDs(for uid: String) -> Set<String>? {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }

        guard
            let data = Self.defaults.data(forKey: Self.favouriteIDsCacheKey(for: uid)),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return nil
        }

        return Set(decoded)
    }

    private func persistFavouriteIDs(_ favouriteIDs: Set<String>, for uid: String) {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }

        if let data = try? JSONEncoder().encode(Array(favouriteIDs).sorted()) {
            Self.defaults.set(data, forKey: Self.favouriteIDsCacheKey(for: uid))
        }
    }

    static func clearCachedPhotos(for uid: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        photosCacheByUID[uid] = nil
        defaults.removeObject(forKey: photoCacheKey(for: uid))
        defaults.removeObject(forKey: favouriteIDsCacheKey(for: uid))
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

    private static func applyFavouriteIDs(_ favouriteIDs: Set<String>, to photosByGroupID: [String: [FeedPhoto]]) -> [String: [FeedPhoto]] {
        photosByGroupID.mapValues { photos in
            applyFavouriteIDs(favouriteIDs, to: photos)
        }
    }

    private static func applyFavouriteIDs(_ favouriteIDs: Set<String>, to photos: [FeedPhoto]) -> [FeedPhoto] {
        photos.map { photo in
            photo.withFavourite(favouriteIDs.contains(photo.id))
        }
    }

    private static func makeFavouriteIDs(from photosByGroupID: [String: [FeedPhoto]]) -> Set<String> {
        Set(photosByGroupID.values.flatMap { photos in
            photos.compactMap { photo in
                photo.isFavourite ? photo.id : nil
            }
        })
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

    private static func makeNextCursor(from photos: [FeedPhoto]) -> FeedPageCursor? {
        guard let lastPhoto = photos.last, let createdAt = lastPhoto.createdAt else { return nil }
        return FeedPageCursor(createdAt: createdAt, documentID: lastPhoto.id)
    }

    private static func photosAreOrderedBefore(_ lhs: FeedPhoto, _ rhs: FeedPhoto) -> Bool {
        let lhsCreatedAt = lhs.createdAt ?? .distantPast
        let rhsCreatedAt = rhs.createdAt ?? .distantPast
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt > rhsCreatedAt
        }
        return lhs.id > rhs.id
    }
}
