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
    let totalMemberCount: Int
}

final class GroupService {
    private let db = Firestore.firestore()

    func createGroup(groupName: String, ownerUID: String) async throws -> GroupSummary {
        let groupID = makeGroupID()
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(ownerUID)
        let ownerPreview = try await loadMemberPreview(uid: ownerUID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
                continuation.resume(returning: ())
            })
        }

        return GroupSummary(id: groupID, name: groupName, members: [ownerPreview], totalMemberCount: 1)
    }

    private func makeGroupID() -> String {
        UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    func fetchGroups(for uid: String) async throws -> [GroupSummary] {
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            db.collection("groups")
                .whereField("members", arrayContains: uid)
                .getDocuments { snapshot, error in
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

        var groups: [GroupSummary] = []
        groups.reserveCapacity(snapshot.documents.count)

        for document in snapshot.documents {
            let data = document.data()
            let name = (data["name"] as? String) ?? "Untitled group"
            let memberIDs = (data["members"] as? [String]) ?? []
            let previews = (try? await loadMemberPreviews(uids: Array(memberIDs.prefix(5)))) ?? []

            groups.append(
                GroupSummary(
                    id: document.documentID,
                    name: name,
                    members: previews,
                    totalMemberCount: memberIDs.count
                )
            )
        }

        return groups
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

    private func loadMemberPreview(uid: String) async throws -> GroupMemberPreview {
        let snapshot = try await getDocument(db.collection("users").document(uid))
        let data = snapshot.data() ?? [:]
        return GroupMemberPreview(
            id: uid,
            icon: (data["icon"] as? String) ?? "🌸",
            bgColour: (data["bgColour"] as? String) ?? "#A5C3DE"
        )
    }

    private func loadMemberPreviews(uids: [String]) async throws -> [GroupMemberPreview] {
        var previews: [GroupMemberPreview] = []
        previews.reserveCapacity(uids.count)
        for uid in uids {
            previews.append(try await loadMemberPreview(uid: uid))
        }
        return previews
    }
}
