import FirebaseFirestore
import FirebaseStorage
import Foundation

final class FeedService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func fetchRecentPhotos(limit: Int = 15) async throws -> [FeedPhoto] {
        let query = db.collection("photos")
            .order(by: "created_at", descending: true)
            .limit(to: limit)

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

        return snapshot.documents.map { doc in
            FeedPhoto(id: doc.documentID, data: doc.data())
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
}
