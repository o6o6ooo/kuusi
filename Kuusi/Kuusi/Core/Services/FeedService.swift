import FirebaseFirestore
import Foundation

final class FeedService {
    private let db = Firestore.firestore()

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
}
