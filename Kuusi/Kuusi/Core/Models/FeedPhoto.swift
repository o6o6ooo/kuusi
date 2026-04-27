import Foundation
import FirebaseFirestore

struct FeedPhoto: Identifiable {
    let id: String
    let photoURL: String?
    let thumbnailURL: String?
    let previewStoragePath: String?
    let thumbnailStoragePath: String?
    let groupID: String?
    let postedBy: String?
    let year: Int?
    let hashtags: [String]
    var isFavourite: Bool
    let sizeMB: Double?
    let aspectRatio: Double?
    let createdAt: Date?
}

extension FeedPhoto {
    func isOwned(by userID: String?) -> Bool {
        guard let userID, let postedBy else { return false }
        return postedBy == userID
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.photoURL = data["photo_url"] as? String
        self.thumbnailURL = data["thumbnail_url"] as? String
        self.previewStoragePath = data["preview_storage_path"] as? String
        self.thumbnailStoragePath = data["thumbnail_storage_path"] as? String
        self.groupID = data["group_id"] as? String
        self.postedBy = data["posted_by"] as? String
        self.year = data["year"] as? Int
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

    func withMetadata(year: Int, hashtags: [String]) -> FeedPhoto {
        FeedPhoto(
            id: id,
            photoURL: photoURL,
            thumbnailURL: thumbnailURL,
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
