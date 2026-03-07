import Foundation
import FirebaseFirestore

struct FeedPhoto: Identifiable {
    let id: String
    let photoURL: String?
    let thumbnailURL: String?
    let groupID: String?
    let year: Int?
    let hashtags: [String]
    let createdAt: Date?
}

extension FeedPhoto {
    init(id: String, data: [String: Any]) {
        self.id = id
        self.photoURL = data["photo_url"] as? String
        self.thumbnailURL = data["thumbnail_url"] as? String
        self.groupID = data["group_id"] as? String
        self.year = data["year"] as? Int
        self.hashtags = (data["hashtags"] as? [String]) ?? []
        if let ts = data["created_at"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
