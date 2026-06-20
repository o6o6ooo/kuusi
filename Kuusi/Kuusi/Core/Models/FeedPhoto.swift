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
    let caption: String?
    var isFavourite: Bool
    let sizeMB: Double?
    let aspectRatio: Double?
    let createdAt: Date?

    nonisolated init(
        id: String,
        previewStoragePath: String?,
        thumbnailStoragePath: String?,
        groupID: String?,
        postedBy: String?,
        date: Date?,
        hashtags: [String],
        caption: String? = nil,
        isFavourite: Bool,
        sizeMB: Double?,
        aspectRatio: Double?,
        createdAt: Date?
    ) {
        self.id = id
        self.previewStoragePath = previewStoragePath
        self.thumbnailStoragePath = thumbnailStoragePath
        self.groupID = groupID
        self.postedBy = postedBy
        self.date = date
        self.hashtags = hashtags
        self.caption = FeedPhotoMetadataUpdate.normalizedCaption(caption)
        self.isFavourite = isFavourite
        self.sizeMB = sizeMB
        self.aspectRatio = aspectRatio
        self.createdAt = createdAt
    }
}

struct FeedPhotoMetadataUpdate: Sendable {
    let date: Date
    let hashtags: [String]
    let caption: String?

    init(date: Date, hashtags: [String], caption: String? = nil) {
        self.date = date
        self.hashtags = hashtags
        self.caption = Self.normalizedCaption(caption)
    }
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
        self.caption = FeedPhotoMetadataUpdate.normalizedCaption(data["caption"] as? String)
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
            caption: update.caption,
            isFavourite: isFavourite,
            sizeMB: sizeMB,
            aspectRatio: aspectRatio,
            createdAt: createdAt
        )
    }
}

extension FeedPhotoMetadataUpdate {
    nonisolated static let captionCharacterLimit = 140

    init(date: Date, hashtags: [String], rawCaption: String?) {
        self.date = date
        self.hashtags = hashtags
        self.caption = Self.normalizedCaption(rawCaption)
    }

    nonisolated static func normalizedCaption(_ value: String?) -> String? {
        guard let value else { return nil }

        let normalizedWhitespace = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = normalizedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return String(trimmed.prefix(captionCharacterLimit))
    }

    func firestorePayload() -> [String: Any] {
        var payload: [String: Any] = [
            "date": Timestamp(date: date),
            "hashtags": hashtags
        ]
        payload["caption"] = caption ?? FieldValue.delete()
        return payload
    }
}
