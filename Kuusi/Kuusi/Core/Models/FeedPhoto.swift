import Foundation
import FirebaseFirestore

struct FeedPhoto: Identifiable {
    let id: String
    let photoURL: String?
    let thumbnailURL: String?
    let groupID: String?
    let postedBy: String?
    let year: Int?
    let hashtags: [String]
    let isFavourite: Bool
    let sizeMB: Double?
    let aspectRatio: Double?
    let createdAt: Date?
}

extension FeedPhoto {
    init(id: String, data: [String: Any]) {
        self.id = id
        self.photoURL = data["photo_url"] as? String
        self.thumbnailURL = data["thumbnail_url"] as? String
        self.groupID = data["group_id"] as? String
        self.postedBy = data["posted_by"] as? String
        self.year = data["year"] as? Int
        self.hashtags = (data["hashtags"] as? [String]) ?? []
        self.isFavourite = (data["favourite"] as? Bool) ?? (data["Favourite"] as? Bool) ?? false
        self.sizeMB = data["size_mb"] as? Double
        self.aspectRatio = data["aspect_ratio"] as? Double
        if let ts = data["created_at"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
