import Foundation
import Testing
@testable import Kuusi

struct FeedServiceTests {
    @Test
    func visibleGroupIDsDeduplicatesAndCapsAtTen() {
        let groupIDs = [
            "g1", "g2", "g3", "g4", "g5",
            "g6", "g7", "g8", "g9", "g10",
            "g11", "g1", "g2"
        ]

        let visibleGroupIDs = FeedService.visibleGroupIDs(from: groupIDs)

        #expect(visibleGroupIDs.count == 10)
        #expect(Set(visibleGroupIDs).count == visibleGroupIDs.count)
        #expect(!visibleGroupIDs.contains("g11"))
    }

    @Test
    func presentRecentPhotosMarksFavouritesAndLimitsPreservingQueryOrder() {
        let photos = [
            makePhoto(id: "new", groupID: "g1", createdAt: Date(timeIntervalSince1970: 300)),
            makePhoto(id: "mid", groupID: "g1", createdAt: Date(timeIntervalSince1970: 200)),
            makePhoto(id: "old", groupID: "g1", createdAt: Date(timeIntervalSince1970: 100))
        ]

        let result = FeedService.presentRecentPhotos(photos, favouriteIDs: ["mid"], limit: 2)

        #expect(result.map(\.id) == ["new", "mid"])
        #expect(result.first?.isFavourite == false)
        #expect(result.last?.isFavourite == true)
    }

    @Test
    func presentFavouritePhotosFiltersVisibleGroupsSortsAndLimits() {
        let photos = [
            makePhoto(id: "a", groupID: "g1", createdAt: Date(timeIntervalSince1970: 100)),
            makePhoto(id: "b", groupID: "g2", createdAt: Date(timeIntervalSince1970: 300)),
            makePhoto(id: "c", groupID: "g3", createdAt: Date(timeIntervalSince1970: 200)),
            makePhoto(id: "d", groupID: nil, createdAt: Date(timeIntervalSince1970: 400))
        ]

        let result = FeedService.presentFavouritePhotos(photos, visibleGroupIDs: ["g1", "g3"], limit: 5)

        if result.map(\.id) != ["c", "a"] {
            Issue.record("Expected favourite photos to be sorted newest-first and filtered to visible groups.")
        }
        if result.contains(where: { !$0.isFavourite }) {
            Issue.record("Expected favourite photos presentation to mark every photo as favourite.")
        }
    }

    @Test
    func presentRecentPhotosFromUnorderedResultsRespectsCursor() {
        let photos = [
            makePhoto(id: "c", groupID: "g1", createdAt: Date(timeIntervalSince1970: 300)),
            makePhoto(id: "b", groupID: "g1", createdAt: Date(timeIntervalSince1970: 200)),
            makePhoto(id: "a", groupID: "g1", createdAt: Date(timeIntervalSince1970: 100))
        ]
        let cursor = FeedPageCursor(createdAt: Date(timeIntervalSince1970: 200), documentID: "b")

        let result = FeedService.presentRecentPhotosFromUnorderedResults(
            photos,
            favouriteIDs: [],
            limit: 5,
            startAfter: cursor
        )

        #expect(result.map(\.id) == ["a"])
    }

    @Test
    @MainActor
    func deletePhotoRejectsDeletingOtherUsersPhoto() async {
        let service = FeedService()
        let photo = makePhoto(
            id: "photo-1",
            groupID: "g1",
            postedBy: "owner-1",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        do {
            try await service.deletePhoto(photo, requesterUID: "owner-2")
            Issue.record("Expected deletePhoto to reject deletes from a different owner.")
        } catch let error as FeedServiceError {
            switch error {
            case .cannotDeleteOthersPhotos:
                break
            default:
                Issue.record("Unexpected FeedServiceError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makePhoto(
        id: String,
        groupID: String?,
        postedBy: String? = "owner-1",
        createdAt: Date
    ) -> FeedPhoto {
        FeedPhoto(
            id: id,
            previewStoragePath: "photos/owner-1/\(id)_preview.jpg",
            thumbnailStoragePath: "photos/owner-1/\(id)_thumb.jpg",
            groupID: groupID,
            postedBy: postedBy,
            year: 2024,
            hashtags: ["spring"],
            isFavourite: false,
            sizeMB: 2.0,
            aspectRatio: 1.0,
            createdAt: createdAt
        )
    }
}
