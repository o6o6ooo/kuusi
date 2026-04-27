import FirebaseFirestore
import Foundation
import Testing
@testable import Kuusi

struct FeedPhotoTests {
    @Test
    func initMapsFirestoreFields() {
        let createdAt = Date(timeIntervalSince1970: 1_710_000_000)
        let photo = FeedPhoto(
            id: "photo-1",
            data: [
                "preview_storage_path": "photos/user-1/full.jpg",
                "thumbnail_storage_path": "photos/user-1/thumb.jpg",
                "group_id": "group-a",
                "posted_by": "user-1",
                "year": 2024,
                "hashtags": ["spring", "family"],
                "size_mb": 4.5,
                "aspect_ratio": 1.25,
                "created_at": Timestamp(date: createdAt)
            ]
        )

        #expect(photo.id == "photo-1")
        #expect(photo.previewStoragePath == "photos/user-1/full.jpg")
        #expect(photo.thumbnailStoragePath == "photos/user-1/thumb.jpg")
        #expect(photo.groupID == "group-a")
        #expect(photo.postedBy == "user-1")
        #expect(photo.year == 2024)
        #expect(photo.hashtags == ["spring", "family"])
        #expect(photo.isFavourite == false)
        #expect(photo.sizeMB == 4.5)
        #expect(photo.aspectRatio == 1.25)
        #expect(photo.createdAt == createdAt)
    }

    @Test
    func initDefaultsOptionalFields() {
        let photo = FeedPhoto(id: "photo-1", data: [:])

        #expect(photo.previewStoragePath == nil)
        #expect(photo.thumbnailStoragePath == nil)
        #expect(photo.groupID == nil)
        #expect(photo.postedBy == nil)
        #expect(photo.year == nil)
        #expect(photo.hashtags == [])
        #expect(photo.isFavourite == false)
        #expect(photo.sizeMB == nil)
        #expect(photo.aspectRatio == nil)
        #expect(photo.createdAt == nil)
    }

    @Test
    func withFavouriteReturnsUpdatedCopy() {
        let original = FeedPhoto(
            id: "photo-1",
            previewStoragePath: "photos/user-1/full.jpg",
            thumbnailStoragePath: nil,
            groupID: "group-a",
            postedBy: "user-1",
            year: 2024,
            hashtags: ["spring"],
            isFavourite: false,
            sizeMB: 4.5,
            aspectRatio: 1.0,
            createdAt: nil
        )

        let updated = original.withFavourite(true)

        #expect(updated.isFavourite == true)
        #expect(original.isFavourite == false)
        #expect(updated.id == original.id)
    }

    @Test
    func withMetadataReturnsUpdatedCopy() {
        let original = FeedPhoto(
            id: "photo-1",
            previewStoragePath: "photos/user-1/full.jpg",
            thumbnailStoragePath: nil,
            groupID: "group-a",
            postedBy: "user-1",
            year: 2024,
            hashtags: ["spring"],
            isFavourite: true,
            sizeMB: 4.5,
            aspectRatio: 1.0,
            createdAt: nil
        )

        let updated = original.withMetadata(year: 2025, hashtags: ["winter", "family"])

        #expect(updated.year == 2025)
        #expect(updated.hashtags == ["winter", "family"])
        #expect(updated.isFavourite == true)
        #expect(updated.previewStoragePath == original.previewStoragePath)
        #expect(updated.groupID == original.groupID)
    }

    @Test
    func isOwnedMatchesPostedByAgainstCurrentUser() {
        let photo = FeedPhoto(
            id: "photo-1",
            previewStoragePath: "photos/user-1/full.jpg",
            thumbnailStoragePath: nil,
            groupID: "group-a",
            postedBy: "user-1",
            year: 2024,
            hashtags: ["spring"],
            isFavourite: false,
            sizeMB: 4.5,
            aspectRatio: 1.0,
            createdAt: nil
        )

        #expect(photo.isOwned(by: "user-1"))
        #expect(!photo.isOwned(by: "user-2"))
        #expect(!photo.isOwned(by: nil))
    }
}
