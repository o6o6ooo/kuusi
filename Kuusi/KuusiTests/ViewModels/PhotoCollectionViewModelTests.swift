import SwiftUI
import Testing
@testable import Kuusi

@MainActor
struct PhotoCollectionViewModelTests {
    @Test
    func currentGroupPhotosAndSignatureFollowSelection() {
        let groupA = makeGroup(id: "group-a", name: "Family")
        let groupB = makeGroup(id: "group-b", name: "Friends")
        let photoA = makePhoto(id: "photo-a", groupID: "group-a", year: 2024)
        let photoB = makePhoto(id: "photo-b", groupID: "group-b", year: 2023)
        let viewModel = makeViewModel()

        viewModel.groups = [groupA, groupB]
        viewModel.photosByGroupID = [
            "group-a": [photoA],
            "group-b": [photoB]
        ]
        viewModel.selectedGroupID = "group-b"

        #expect(viewModel.currentGroupPhotos.map(\.id) == ["photo-b"])
        #expect(viewModel.currentGroupPhotoSignature == ["photo-b-2023"])
    }

    @Test
    func currentGroupAvailableHashtagsFollowsLoadedGroupPhotos() async {
        let spring = makePhoto(id: "photo-a", groupID: "group-a", year: 2024, hashtags: ["spring", "family"])
        let winter = makePhoto(id: "photo-b", groupID: "group-b", year: 2023, hashtags: ["winter", "Family"])
        let feedService = FeedServiceSpy()
        feedService.resultsByGroupID = [
            "group-a": [RecentPhotoFetchResult(photos: [spring], hasMore: false, nextCursor: nil, favouriteIDs: [])],
            "group-b": [RecentPhotoFetchResult(photos: [winter], hasMore: false, nextCursor: nil, favouriteIDs: [])]
        ]
        let groupService = GroupServiceSpy()
        groupService.cachedGroupsValue = [
            makeGroup(id: "group-a", name: "Family"),
            makeGroup(id: "group-b", name: "Friends")
        ]
        let viewModel = makeViewModel(feedService: feedService, groupService: groupService)

        await viewModel.loadInitial(limit: 6)

        #expect(viewModel.currentGroupAvailableHashtags == ["spring", "family"])

        viewModel.selectedGroupID = "group-b"
        viewModel.selectGroup("group-b", limit: 6)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.currentGroupAvailableHashtags == ["winter", "Family"])
    }

    @Test
    func replacePhotoUpdatesOnlySelectedGroupPhoto() {
        let original = makePhoto(
            id: "photo-a",
            groupID: "group-a",
            year: 2024,
            hashtags: ["spring"],
            isFavourite: false
        )
        let updated = original.withMetadata(year: 2025, hashtags: ["winter"]).withFavourite(true)
        let viewModel = makeViewModel()

        viewModel.selectedGroupID = "group-a"
        viewModel.photosByGroupID = ["group-a": [original]]

        viewModel.replacePhoto(updated)

        #expect(viewModel.currentGroupPhotos.count == 1)
        #expect(viewModel.currentGroupPhotos.first?.year == 2025)
        #expect(viewModel.currentGroupPhotos.first?.hashtags == ["winter"])
        #expect(viewModel.currentGroupPhotos.first?.isFavourite == true)
    }

    @Test
    func removePhotoDeletesOnlyMatchingPhoto() {
        let photoA = makePhoto(id: "photo-a", groupID: "group-a", year: 2024)
        let photoB = makePhoto(id: "photo-b", groupID: "group-a", year: 2023)
        let viewModel = makeViewModel()

        viewModel.selectedGroupID = "group-a"
        viewModel.photosByGroupID = ["group-a": [photoA, photoB]]

        viewModel.removePhoto(id: "photo-a")

        #expect(viewModel.currentGroupPhotos.map(\.id) == ["photo-b"])
    }

    @Test
    func selectGroupLoadsPhotosWhenMissingFromCache() async throws {
        let feedService = FeedServiceSpy()
        let expected = [makePhoto(id: "photo-b", groupID: "group-b", year: 2022)]
        feedService.resultsByGroupID["group-b"] = [
            RecentPhotoFetchResult(photos: expected, hasMore: false, nextCursor: nil, favouriteIDs: [])
        ]
        let viewModel = makeViewModel(feedService: feedService)

        viewModel.groups = [
            makeGroup(id: "group-a", name: "Family"),
            makeGroup(id: "group-b", name: "Friends")
        ]

        viewModel.selectGroup("group-b", limit: 6)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.selectedGroupID == "group-b")
        #expect(viewModel.currentGroupPhotos.map(\.id) == ["photo-b"])
        #expect(feedService.fetchCalls.count == 1)
        #expect(feedService.fetchCalls.first?.groupIDs == ["group-b"])
        #expect(feedService.fetchCalls.first?.limit == 6)
    }

    @Test
    func selectGroupSkipsFetchWhenPhotosAlreadyCached() async throws {
        let feedService = FeedServiceSpy()
        let cached = [makePhoto(id: "photo-a", groupID: "group-a", year: 2024)]
        let viewModel = makeViewModel(feedService: feedService)

        viewModel.photosByGroupID = ["group-a": cached]

        viewModel.selectGroup("group-a", limit: 6)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.currentGroupPhotos.map(\.id) == ["photo-a"])
        #expect(feedService.fetchCalls.isEmpty)
    }

    @Test
    func loadMoreIfNeededFetchesNextExpandedBatch() async throws {
        let feedService = FeedServiceSpy()
        let firstBatch = (0..<6).map {
            makePhoto(
                id: "photo-\($0)",
                groupID: "group-a",
                year: 2024 - $0,
                createdAt: Date(timeIntervalSince1970: TimeInterval(300 - $0))
            )
        }
        let nextBatch = (6..<12).map {
            makePhoto(
                id: "photo-\($0)",
                groupID: "group-a",
                year: 2024 - $0,
                createdAt: Date(timeIntervalSince1970: TimeInterval(300 - $0))
            )
        }
        feedService.resultsByGroupID["group-a"] = [
            RecentPhotoFetchResult(
                photos: firstBatch,
                hasMore: true,
                nextCursor: FeedPageCursor(createdAt: Date(timeIntervalSince1970: 295), documentID: "photo-5"),
                favouriteIDs: ["photo-1", "photo-4"]
            ),
            RecentPhotoFetchResult(photos: nextBatch, hasMore: false, nextCursor: nil, favouriteIDs: ["photo-1", "photo-4"])
        ]
        let groupService = GroupServiceSpy()
        groupService.cachedGroupsValue = [makeGroup(id: "group-a", name: "Family")]
        let viewModel = makeViewModel(feedService: feedService, groupService: groupService)

        await viewModel.loadInitial(limit: 6)
        viewModel.loadMoreIfNeeded(pageSize: 6)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.currentGroupPhotos.count == 12)
        #expect(feedService.fetchCalls.count == 2)
        #expect(feedService.fetchCalls.last?.limit == 6)
        #expect(feedService.fetchCalls.last?.cursor == FeedPageCursor(createdAt: Date(timeIntervalSince1970: 295), documentID: "photo-5"))
        #expect(feedService.fetchCalls.first?.favouriteIDs == nil)
        #expect(feedService.fetchCalls.last?.favouriteIDs == ["photo-1", "photo-4"])
    }

    @Test
    func loadInitialRestoresPersistedPhotoCacheBeforeFetching() async throws {
        let userID = "persisted-cache-user"
        PhotoCollectionViewModel.clearCachedPhotos(for: userID)

        let cachedPhoto = makePhoto(id: "photo-a", groupID: "group-a", year: 2024)
        let firstViewModel = makeViewModel(userID: userID)
        firstViewModel.groups = [makeGroup(id: "group-a", name: "Family")]
        firstViewModel.selectedGroupID = "group-a"
        firstViewModel.photosByGroupID = ["group-a": [cachedPhoto]]
        firstViewModel.replacePhoto(cachedPhoto)

        let feedService = FeedServiceSpy()
        let groupService = GroupServiceSpy()
        groupService.cachedGroupsValue = [makeGroup(id: "group-a", name: "Family")]
        let secondViewModel = makeViewModel(
            feedService: feedService,
            groupService: groupService,
            userID: userID
        )

        await secondViewModel.loadInitial(limit: 6)

        #expect(secondViewModel.currentGroupPhotos.map(\.id) == ["photo-a"])
        #expect(feedService.fetchCalls.isEmpty)

        PhotoCollectionViewModel.clearCachedPhotos(for: userID)
    }

    private func makeViewModel(
        feedService: PhotoCollectionFeedServicing = FeedServiceSpy(),
        groupService: PhotoCollectionGroupServicing = GroupServiceSpy(),
        userID: String = "test-user"
    ) -> PhotoCollectionViewModel {
        PhotoCollectionViewModel(
            feedService: feedService,
            groupService: groupService,
            currentUserIDProvider: { userID }
        )
    }

    private func makeGroup(id: String, name: String) -> GroupSummary {
        GroupSummary(id: id, name: name, ownerUID: "owner", members: [], totalMemberCount: 1)
    }

    private func makePhoto(
        id: String,
        groupID: String,
        year: Int,
        hashtags: [String] = [],
        isFavourite: Bool = false,
        thumbnailURL: String? = nil,
        aspectRatio: Double? = 1.0,
        createdAt: Date? = nil
    ) -> FeedPhoto {
        FeedPhoto(
            id: id,
            photoURL: "https://example.com/\(id).jpg",
            thumbnailURL: thumbnailURL,
            groupID: groupID,
            postedBy: "user",
            year: year,
            hashtags: hashtags,
            isFavourite: isFavourite,
            sizeMB: 2.0,
            aspectRatio: aspectRatio,
            createdAt: createdAt
        )
    }
}

private final class FeedServiceSpy: PhotoCollectionFeedServicing {
    struct FetchCall {
        let userID: String
        let groupIDs: [String]
        let limit: Int
        let cursor: FeedPageCursor?
        let favouriteIDs: Set<String>?
    }

    var photosByGroupID: [String: [FeedPhoto]] = [:]
    var resultsByGroupID: [String: [RecentPhotoFetchResult]] = [:]
    var fetchCalls: [FetchCall] = []
    private var batchFetchCountByGroupID: [String: Int] = [:]

    func fetchRecentPhotoBatch(
        userID: String,
        groupIDs: [String],
        limit: Int,
        startAfter cursor: FeedPageCursor?,
        favouriteIDs: Set<String>?
    ) async throws -> RecentPhotoFetchResult {
        fetchCalls.append(.init(userID: userID, groupIDs: groupIDs, limit: limit, cursor: cursor, favouriteIDs: favouriteIDs))
        guard let groupID = groupIDs.first else {
            return RecentPhotoFetchResult(photos: [], hasMore: false, nextCursor: nil, favouriteIDs: favouriteIDs ?? [])
        }
        let index = batchFetchCountByGroupID[groupID, default: 0]
        batchFetchCountByGroupID[groupID] = index + 1
        let results = resultsByGroupID[groupID] ?? []
        if index < results.count {
            return results[index]
        }
        if let fallback = photosByGroupID[groupID] {
            return RecentPhotoFetchResult(photos: fallback, hasMore: false, nextCursor: nil, favouriteIDs: favouriteIDs ?? [])
        }
        return RecentPhotoFetchResult(photos: [], hasMore: false, nextCursor: nil, favouriteIDs: favouriteIDs ?? [])
    }
}

private final class GroupServiceSpy: PhotoCollectionGroupServicing {
    var cachedGroupsValue: [GroupSummary] = []
    var fetchedGroupsValue: [GroupSummary] = []

    func cachedGroups(for uid: String) -> [GroupSummary] {
        cachedGroupsValue
    }

    func fetchGroups(for uid: String) async throws -> [GroupSummary] {
        fetchedGroupsValue
    }
}
