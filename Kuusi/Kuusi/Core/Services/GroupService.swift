import FirebaseFirestore
import Foundation

final class GroupService {
    private let db = Firestore.firestore()

    func createGroup(groupName: String, ownerUID: String) async throws -> String {
        let groupID = makeGroupID()
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(ownerUID)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            db.runTransaction({ transaction, errorPointer in
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
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: groupID)
            })
        }
    }

    private func makeGroupID() -> String {
        UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
}
