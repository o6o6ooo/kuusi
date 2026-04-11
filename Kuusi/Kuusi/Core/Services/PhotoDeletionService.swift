import FirebaseFirestore
import FirebaseStorage
import Foundation

enum PhotoFavouriteCleanupScope {
    case allUsers
    case user(String)
    case none
}

final class PhotoDeletionService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let maxBatchWriteCount = 450

    func deletePhotos(
        _ photos: [FeedPhoto],
        favouriteCleanupScope: PhotoFavouriteCleanupScope,
        fallbackOwnerUID: String? = nil
    ) async throws {
        guard !photos.isEmpty else { return }

        try await deleteStorageAssets(for: photos)

        var usageByUserID: [String: Double] = [:]
        for photo in photos {
            guard let ownerUID = photo.postedBy ?? fallbackOwnerUID,
                  let sizeMB = photo.sizeMB,
                  sizeMB > 0 else {
                continue
            }
            usageByUserID[ownerUID, default: 0] += sizeMB
        }

        let favouriteRemovals = try await loadFavouriteRemovals(
            for: photos.map(\.id),
            scope: favouriteCleanupScope
        )

        var operations: [(WriteBatch) -> Void] = []

        for photo in photos {
            let photoRef = db.collection("photos").document(photo.id)
            operations.append { batch in
                batch.deleteDocument(photoRef)
            }
        }

        for (userID, sizeMB) in usageByUserID {
            let userRef = db.collection("users").document(userID)
            operations.append { batch in
                batch.setData(["usage_mb": FieldValue.increment(-sizeMB)], forDocument: userRef, merge: true)
            }
        }

        for (userID, photoIDs) in favouriteRemovals {
            let userRef = db.collection("users").document(userID)
            let ids = Array(photoIDs)
            operations.append { batch in
                batch.setData(["favourites": FieldValue.arrayRemove(ids)], forDocument: userRef, merge: true)
            }
        }

        try await commitBatchedOperations(operations)
    }

    private func deleteStorageAssets(for photos: [FeedPhoto]) async throws {
        for photo in photos {
            if let urlString = photo.photoURL {
                try await deleteStorageObject(urlString: urlString)
            }
            if let urlString = photo.thumbnailURL {
                try await deleteStorageObject(urlString: urlString)
            }
        }
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

    private func loadFavouriteRemovals(
        for photoIDs: [String],
        scope: PhotoFavouriteCleanupScope
    ) async throws -> [String: Set<String>] {
        guard !photoIDs.isEmpty else { return [:] }

        switch scope {
        case .none:
            return [:]
        case let .user(userID):
            return [userID: Set(photoIDs)]
        case .allUsers:
            var favouriteRemovals: [String: Set<String>] = [:]
            for chunk in photoIDs.chunked(into: 10) where !chunk.isEmpty {
                let query = db.collection("users")
                    .whereField("favourites", arrayContainsAny: chunk)
                let snapshot = try await fetchQuery(query)
                for document in snapshot.documents {
                    favouriteRemovals[document.documentID, default: []].formUnion(chunk)
                }
            }
            return favouriteRemovals
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

    private func commitBatchedOperations(_ operations: [(WriteBatch) -> Void]) async throws {
        guard !operations.isEmpty else { return }

        for chunk in operations.chunked(into: maxBatchWriteCount) {
            let batch = db.batch()
            for operation in chunk {
                operation(batch)
            }
            try await commitBatch(batch)
        }
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
