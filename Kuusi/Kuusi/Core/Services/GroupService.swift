import FirebaseFirestore
import Foundation

enum GroupServiceError: LocalizedError {
    case groupAlreadyExists

    var errorDescription: String? {
        switch self {
        case .groupAlreadyExists:
            return "This group ID is already in use."
        }
    }
}

final class GroupService {
    private let db = Firestore.firestore()

    func createGroup(groupID: String, groupName: String, ownerUID: String) async throws {
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(ownerUID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(groupRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                if snapshot.exists {
                    errorPointer?.pointee = NSError(domain: "GroupService", code: 409, userInfo: [
                        NSLocalizedDescriptionKey: GroupServiceError.groupAlreadyExists.localizedDescription
                    ])
                    return nil
                }

                let groupPayload: [String: Any] = [
                    "id": groupID,
                    "name": groupName,
                    "owner_uid": ownerUID,
                    "members": [ownerUID],
                    "created_at": FieldValue.serverTimestamp()
                ]

                transaction.setData(groupPayload, forDocument: groupRef, merge: false)
                transaction.setData([
                    "groups": FieldValue.arrayUnion([groupID])
                ], forDocument: userRef, merge: true)

                return nil
            }, completion: { _, error in
                if let error {
                    if let nsError = error as NSError?, nsError.domain == "GroupService", nsError.code == 409 {
                        continuation.resume(throwing: GroupServiceError.groupAlreadyExists)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            })
        }
    }
}
