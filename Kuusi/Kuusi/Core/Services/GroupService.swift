import FirebaseFirestore
import Foundation

enum GroupServiceError: Error {
    case groupNotFound
    case ownerCannotLeave
    case memberLimitReached(maxMembers: Int)
}

struct GroupMemberPreview: Identifiable {
    let id: String
    let name: String
    let icon: String
    let bgColour: String
    let isOwner: Bool
}

struct GroupSummary: Identifiable {
    let id: String
    let name: String
    let ownerUID: String
    let members: [GroupMemberPreview]
    let totalMemberCount: Int
}

final class GroupService {
    static let maxGroupMembers = 50

    private let db = Firestore.firestore()
    private let photoDeletionService = PhotoDeletionService()
    private static var groupsCacheByUID: [String: [GroupSummary]] = [:]
    private static let cacheLock = NSLock()
    private static let defaults = UserDefaults.standard
    private static let cacheKeyPrefix = "groups_cache_v1_"

    func createGroup(groupName: String, ownerUID: String) async throws -> GroupSummary {
        let groupID = makeGroupID()
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(ownerUID)

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

        let created = GroupSummary(id: groupID, name: groupName, ownerUID: ownerUID, members: [], totalMemberCount: 1)
        appendCachedGroup(created, for: ownerUID)
        return created
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

        let groups = snapshot.documents.map(makeGroupSummaryWithoutPreviews(from:))
        setCachedGroups(groups, for: uid)
        return groups
    }

    func loadMemberPreviews(groupID: String, limit: Int? = nil) async throws -> [GroupMemberPreview] {
        let snapshot = try await getDocument(db.collection("groups").document(groupID))
        let data = snapshot.data() ?? [:]
        let memberIDs = (data["members"] as? [String]) ?? []
        let ownerUID = data["owner_uid"] as? String
        let previewIDs: [String]
        if let limit {
            previewIDs = Array(memberIDs.prefix(limit))
        } else {
            previewIDs = memberIDs
        }
        return (try? await loadMemberPreviews(uids: previewIDs, ownerUID: ownerUID)) ?? []
    }

    func updateGroupName(groupID: String, name: String) async throws {
        let ref = db.collection("groups").document(groupID)
        try await setDocument(ref, data: ["name": name], merge: true)
    }

    func joinGroup(groupID: String, uid: String) async throws {
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(uid)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                do {
                    let groupSnapshot = try transaction.getDocument(groupRef)
                    guard groupSnapshot.exists else {
                        errorPointer?.pointee = GroupServiceError.groupNotFound as NSError
                        return nil
                    }

                    let members = (groupSnapshot.data()?["members"] as? [String]) ?? []
                    if !members.contains(uid), members.count >= Self.maxGroupMembers {
                        errorPointer?.pointee = GroupServiceError.memberLimitReached(maxMembers: Self.maxGroupMembers) as NSError
                        return nil
                    }
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                transaction.updateData(["members": FieldValue.arrayUnion([uid])], forDocument: groupRef)
                transaction.setData(["groups": FieldValue.arrayUnion([groupID])], forDocument: userRef, merge: true)
                return nil
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            })
        }
    }

    func deleteGroup(groupID: String) async throws {
        let groupRef = db.collection("groups").document(groupID)
        let groupSnapshot = try await getDocument(groupRef)
        guard groupSnapshot.exists else {
            throw GroupServiceError.groupNotFound
        }

        let memberIDs = (groupSnapshot.data()?["members"] as? [String]) ?? []
        let photos = try await loadGroupPhotos(groupID: groupID)
        try await photoDeletionService.deletePhotos(photos, favouriteCleanupScope: .allUsers)
        var operations: [(WriteBatch) -> Void] = []

        operations.append { batch in
            batch.deleteDocument(groupRef)
        }

        for memberID in memberIDs {
            let userRef = db.collection("users").document(memberID)
            operations.append { batch in
                batch.setData(["groups": FieldValue.arrayRemove([groupID])], forDocument: userRef, merge: true)
            }
        }

        try await commitBatchedOperations(operations)

        for memberID in memberIDs {
            removeCachedGroup(groupID: groupID, for: memberID)
        }
    }

    func leaveGroup(groupID: String, uid: String) async throws {
        let groupRef = db.collection("groups").document(groupID)
        let userRef = db.collection("users").document(uid)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                do {
                    let groupSnapshot = try transaction.getDocument(groupRef)
                    guard groupSnapshot.exists else {
                        errorPointer?.pointee = GroupServiceError.groupNotFound as NSError
                        return nil
                    }

                    let ownerUID = groupSnapshot.data()?["owner_uid"] as? String
                    if ownerUID == uid {
                        errorPointer?.pointee = GroupServiceError.ownerCannotLeave as NSError
                        return nil
                    }
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                transaction.updateData(["members": FieldValue.arrayRemove([uid])], forDocument: groupRef)
                transaction.setData(["groups": FieldValue.arrayRemove([groupID])], forDocument: userRef, merge: true)
                return nil
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            })
        }

        removeCachedGroup(groupID: groupID, for: uid)
    }

    func cachedGroups(for uid: String) -> [GroupSummary] {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        if let cached = Self.groupsCacheByUID[uid] {
            return cached
        }

        guard
            let data = Self.defaults.data(forKey: Self.cacheKey(for: uid)),
            let decoded = try? JSONDecoder().decode([CachedGroup].self, from: data)
        else {
            return []
        }

        let groups = decoded.map { $0.toGroupSummary() }
        Self.groupsCacheByUID[uid] = groups
        return groups
    }

    func setCachedGroups(_ groups: [GroupSummary], for uid: String) {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        Self.groupsCacheByUID[uid] = groups
        let encodable = groups.map { cachedGroup(from: $0) }
        if let data = try? JSONEncoder().encode(encodable) {
            Self.defaults.set(data, forKey: Self.cacheKey(for: uid))
        }
    }

    func clearCachedGroups(for uid: String) {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        Self.groupsCacheByUID[uid] = nil
        Self.defaults.removeObject(forKey: Self.cacheKey(for: uid))
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

    private func loadGroupPhotos(groupID: String) async throws -> [FeedPhoto] {
        let query = db.collection("photos")
            .whereField("group_id", isEqualTo: groupID)
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
        return snapshot.documents.map { FeedPhoto(id: $0.documentID, data: $0.data()) }
    }

    private func commitBatchedOperations(_ operations: [(WriteBatch) -> Void]) async throws {
        guard !operations.isEmpty else { return }

        let batch = db.batch()
        for operation in operations {
            operation(batch)
        }
        try await commitBatch(batch)
    }

    private func loadMemberPreview(uid: String, ownerUID: String?) async throws -> GroupMemberPreview {
        let snapshot = try await getDocument(db.collection("users").document(uid))
        let data = snapshot.data() ?? [:]
        return GroupMemberPreview(
            id: uid,
            name: (data["name"] as? String) ?? "Kuusi User",
            icon: (data["icon"] as? String) ?? "🌸",
            bgColour: (data["bgColour"] as? String) ?? "#A5C3DE",
            isOwner: uid == ownerUID
        )
    }

    private func loadMemberPreviews(uids: [String], ownerUID: String?) async throws -> [GroupMemberPreview] {
        var previews: [GroupMemberPreview] = []
        previews.reserveCapacity(uids.count)
        for uid in uids {
            previews.append(try await loadMemberPreview(uid: uid, ownerUID: ownerUID))
        }
        return previews
    }

    private func makeGroupSummaryWithoutPreviews(from document: QueryDocumentSnapshot) -> GroupSummary {
        let data = document.data()
        let name = (data["name"] as? String) ?? "Untitled group"
        let ownerUID = (data["owner_uid"] as? String) ?? ""
        let memberIDs = (data["members"] as? [String]) ?? []
        return GroupSummary(
            id: document.documentID,
            name: name,
            ownerUID: ownerUID,
            members: [],
            totalMemberCount: memberIDs.count
        )
    }

    private func appendCachedGroup(_ group: GroupSummary, for uid: String) {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        var groups = Self.groupsCacheByUID[uid] ?? loadPersistedGroupsLocked(for: uid)
        if !groups.contains(where: { $0.id == group.id }) {
            groups.append(group)
            Self.groupsCacheByUID[uid] = groups
            savePersistedGroupsLocked(groups, for: uid)
        }
    }

    private func removeCachedGroup(groupID: String, for uid: String) {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        var groups = Self.groupsCacheByUID[uid] ?? loadPersistedGroupsLocked(for: uid)
        groups.removeAll { $0.id == groupID }
        Self.groupsCacheByUID[uid] = groups
        savePersistedGroupsLocked(groups, for: uid)
    }

    private static func cacheKey(for uid: String) -> String {
        "\(cacheKeyPrefix)\(uid)"
    }

    private func loadPersistedGroupsLocked(for uid: String) -> [GroupSummary] {
        guard
            let data = Self.defaults.data(forKey: Self.cacheKey(for: uid)),
            let decoded = try? JSONDecoder().decode([CachedGroup].self, from: data)
        else {
            return []
        }
        return decoded.map { $0.toGroupSummary() }
    }

    private func savePersistedGroupsLocked(_ groups: [GroupSummary], for uid: String) {
        let encodable = groups.map { cachedGroup(from: $0) }
        if let data = try? JSONEncoder().encode(encodable) {
            Self.defaults.set(data, forKey: Self.cacheKey(for: uid))
        }
    }

    private func cachedGroup(from group: GroupSummary) -> CachedGroup {
        CachedGroup(
            id: group.id,
            name: group.name,
            ownerUID: group.ownerUID,
            members: group.members.map {
                CachedMember(
                    id: $0.id,
                    name: $0.name,
                    icon: $0.icon,
                    bgColour: $0.bgColour,
                    isOwner: $0.isOwner
                )
            },
            totalMemberCount: group.totalMemberCount
        )
    }
}

private struct CachedGroup: Codable {
    let id: String
    let name: String
    let ownerUID: String?
    let members: [CachedMember]
    let totalMemberCount: Int

    func toGroupSummary() -> GroupSummary {
        GroupSummary(
            id: id,
            name: name,
            ownerUID: ownerUID ?? "",
            members: members.map { $0.toPreview() },
            totalMemberCount: totalMemberCount
        )
    }
}

private struct CachedMember: Codable {
    let id: String
    let name: String?
    let icon: String
    let bgColour: String
    let isOwner: Bool?

    func toPreview() -> GroupMemberPreview {
        GroupMemberPreview(
            id: id,
            name: name ?? "Kuusi User",
            icon: icon,
            bgColour: bgColour,
            isOwner: isOwner ?? false
        )
    }
}
