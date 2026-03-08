import FirebaseFirestore
import Foundation

struct GroupMemberPreview: Identifiable {
    let id: String
    let icon: String
    let bgColour: String
}

struct GroupSummary: Identifiable {
    let id: String
    let name: String
    let members: [GroupMemberPreview]
}

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

    func fetchGroups(for uid: String) async throws -> [GroupSummary] {
        let userSnapshot = try await getDocument(db.collection("users").document(uid))
        let groupIDs = (userSnapshot.data()?["groups"] as? [String]) ?? []
        guard !groupIDs.isEmpty else { return [] }

        var summaries: [GroupSummary] = []
        for groupID in groupIDs {
            let groupSnapshot = try await getDocument(db.collection("groups").document(groupID))
            guard let groupData = groupSnapshot.data() else { continue }

            let name = (groupData["name"] as? String) ?? "Untitled group"
            let memberIDs = (groupData["members"] as? [String]) ?? []
            var members: [GroupMemberPreview] = []

            for memberID in memberIDs.prefix(5) {
                let memberSnapshot = try await getDocument(db.collection("users").document(memberID))
                let memberData = memberSnapshot.data() ?? [:]
                members.append(
                    GroupMemberPreview(
                        id: memberID,
                        icon: (memberData["icon"] as? String) ?? "🌸",
                        bgColour: (memberData["bgColour"] as? String) ?? "#A5C3DE"
                    )
                )
            }

            summaries.append(GroupSummary(id: groupID, name: name, members: members))
        }

        return summaries
    }

    func updateGroupName(groupID: String, name: String) async throws {
        let ref = db.collection("groups").document(groupID)
        try await setDocument(ref, data: ["name": name], merge: true)
    }

    private func getDocument(_ ref: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
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
    }

    private func setDocument(_ ref: DocumentReference, data: [String: Any], merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
