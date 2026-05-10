import Foundation
import FirebaseFirestore

struct FeedPhoto: Identifiable, Sendable {
    let id: String
    let previewStoragePath: String?
    let thumbnailStoragePath: String?
    let groupID: String?
    let postedBy: String?
    let date: Date?
    let hashtags: [String]
    var isFavourite: Bool
    let sizeMB: Double?
    let aspectRatio: Double?
    let createdAt: Date?
}

struct FeedPhotoMetadataUpdate: Sendable {
    let date: Date
    let hashtags: [String]
}

extension FeedPhoto {
    func isOwned(by userID: String?) -> Bool {
        guard let userID, let postedBy else { return false }
        return postedBy == userID
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.previewStoragePath = data["preview_storage_path"] as? String
        self.thumbnailStoragePath = data["thumbnail_storage_path"] as? String
        self.groupID = data["group_id"] as? String
        self.postedBy = data["posted_by"] as? String
        if let ts = data["date"] as? Timestamp {
            self.date = ts.dateValue()
        } else if let ts = data["created_at"] as? Timestamp {
            self.date = ts.dateValue()
        } else {
            self.date = nil
        }
        self.hashtags = (data["hashtags"] as? [String]) ?? []
        self.isFavourite = false
        self.sizeMB = data["size_mb"] as? Double
        self.aspectRatio = data["aspect_ratio"] as? Double
        if let ts = data["created_at"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }
    }

    func withFavourite(_ isFavourite: Bool) -> FeedPhoto {
        var copy = self
        copy.isFavourite = isFavourite
        return copy
    }

    func withMetadata(_ update: FeedPhotoMetadataUpdate) -> FeedPhoto {
        FeedPhoto(
            id: id,
            previewStoragePath: previewStoragePath,
            thumbnailStoragePath: thumbnailStoragePath,
            groupID: groupID,
            postedBy: postedBy,
            date: update.date,
            hashtags: update.hashtags,
            isFavourite: isFavourite,
            sizeMB: sizeMB,
            aspectRatio: aspectRatio,
            createdAt: createdAt
        )
    }
}

extension FeedPhotoMetadataUpdate {
    func firestorePayload() -> [String: Any] {
        [
            "date": Timestamp(date: date),
            "hashtags": hashtags
        ]
    }
}
