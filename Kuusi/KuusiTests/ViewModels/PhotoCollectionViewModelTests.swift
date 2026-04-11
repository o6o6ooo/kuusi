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
        feedService.photosByGroupID["group-b"] = expected
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

    private func makeViewModel(
        feedService: PhotoCollectionFeedServicing = FeedServiceSpy(),
        groupService: PhotoCollectionGroupServicing = GroupServiceSpy()
    ) -> PhotoCollectionViewModel {
        PhotoCollectionViewModel(
            feedService: feedService,
            groupService: groupService,
            currentUserIDProvider: { "test-user" }
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
        aspectRatio: Double? = 1.0
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
            createdAt: nil
        )
    }
}

private final class FeedServiceSpy: PhotoCollectionFeedServicing {
    struct FetchCall {
        let userID: String
        let groupIDs: [String]
        let limit: Int
    }

    var photosByGroupID: [String: [FeedPhoto]] = [:]
    var fetchCalls: [FetchCall] = []

    func fetchRecentPhotos(userID: String, groupIDs: [String], limit: Int) async throws -> [FeedPhoto] {
        fetchCalls.append(.init(userID: userID, groupIDs: groupIDs, limit: limit))
        guard let groupID = groupIDs.first else { return [] }
        return photosByGroupID[groupID] ?? []
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
