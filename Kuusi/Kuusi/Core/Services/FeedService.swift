import FirebaseFirestore
import FirebaseStorage
import Foundation

final class FeedService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let favouritesField = "favourites"

    func fetchRecentPhotos(userID: String, groupIDs: [String], limit: Int = 15) async throws -> [FeedPhoto] {
        let visibleGroupIDs = Array(Set(groupIDs)).prefix(10)
        guard !visibleGroupIDs.isEmpty else { return [] }
        let favouriteIDs = try await fetchFavouriteIDs(userID: userID)
        let fetchLimit = max(limit + 4, limit)

        let query = db.collection("photos")
            .whereField("group_id", in: Array(visibleGroupIDs))
            .limit(to: fetchLimit)

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }

        let photos = snapshot.documents.map { doc in
            FeedPhoto(id: doc.documentID, data: doc.data())
        }

        return photos
            .map { $0.withFavourite(favouriteIDs.contains($0.id)) }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    func fetchFavouritePhotos(userID: String, groupIDs: [String], limit: Int = 10) async throws -> [FeedPhoto] {
        let visibleGroupIDs = Array(Set(groupIDs)).prefix(10)
        guard !visibleGroupIDs.isEmpty else { return [] }
        let favouriteIDs = Array(try await fetchFavouriteIDs(userID: userID))
        guard !favouriteIDs.isEmpty else { return [] }

        let chunks = favouriteIDs.chunked(into: 10)
        var docs: [QueryDocumentSnapshot] = []
        docs.reserveCapacity(favouriteIDs.count)

        for chunk in chunks {
            let query = db.collection("photos")
                .whereField(FieldPath.documentID(), in: chunk)
            let snapshot = try await fetchQuery(query)
            docs.append(contentsOf: snapshot.documents)
        }

        let visibleGroups = Set(visibleGroupIDs)
        let photos = docs
            .map { FeedPhoto(id: $0.documentID, data: $0.data()) }
            .filter { photo in
                guard let groupID = photo.groupID else { return false }
                return visibleGroups.contains(groupID)
            }

        return photos
            .map { $0.withFavourite(true) }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    func setFavourite(photoID: String, userID: String, isFavourite: Bool) async throws {
        let ref = db.collection("users").document(userID)
        let payload: [String: Any] = [
            favouritesField: isFavourite
                ? FieldValue.arrayUnion([photoID])
                : FieldValue.arrayRemove([photoID])
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(payload, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func updatePhotoMetadata(_ photo: FeedPhoto, requesterUID: String, year: Int, hashtags: [String]) async throws {
        if let postedBy = photo.postedBy, postedBy != requesterUID {
            throw NSError(domain: "FeedService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "You can only edit your own photos."
            ])
        }

        let ref = db.collection("photos").document(photo.id)
        let payload: [String: Any] = [
            "year": year,
            "hashtags": hashtags
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(payload, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func deletePhoto(_ photo: FeedPhoto, requesterUID: String) async throws {
        if let postedBy = photo.postedBy, postedBy != requesterUID {
            throw NSError(domain: "FeedService", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "You can only delete your own photos."
            ])
        }

        if let urlString = photo.photoURL {
            try await deleteStorageObject(urlString: urlString)
        }
        if let urlString = photo.thumbnailURL {
            try await deleteStorageObject(urlString: urlString)
        }

        let ownerUID = photo.postedBy ?? requesterUID
        let photoRef = db.collection("photos").document(photo.id)
        let userRef = db.collection("users").document(ownerUID)
        let batch = db.batch()
        batch.deleteDocument(photoRef)

        if let sizeMB = photo.sizeMB, sizeMB > 0 {
            batch.setData(
                ["usage_mb": FieldValue.increment(-sizeMB)],
                forDocument: userRef,
                merge: true
            )
        }

        try await commitBatch(batch)
        try await setFavourite(photoID: photo.id, userID: requesterUID, isFavourite: false)
    }

    private func deleteStorageObject(urlString: String) async throws {
        guard let url = URL(string: urlString) else { return }
        let ref = storage.reference(forURL: url.absoluteString)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let nsError = error as NSError?,
                   nsError.domain == StorageErrorDomain,
                   nsError.code == StorageErrorCode.objectNotFound.rawValue {
                    continuation.resume(returning: ())
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func commitBatch(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func fetchQuery(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func fetchFavouriteIDs(userID: String) async throws -> Set<String> {
        let ref = db.collection("users").document(userID)
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            ref.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
        let ids = (snapshot.data()?[favouritesField] as? [String]) ?? []
        return Set(ids)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index += size
        }
        return result
    }
}
