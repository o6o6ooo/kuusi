import FirebaseAuth
import FirebaseFirestore
import Foundation

private struct CachedAuthorName: Codable {
    let name: String
    let cachedAt: Date
}

@MainActor
final class UserService {
    private let db = Firestore.firestore()
    private static let defaults = UserDefaults.standard
    private static let authorNameCacheKey = "feed_author_name_cache_v1"
    private static let authorNameTTL: TimeInterval = 7 * 24 * 60 * 60
    private static var authorNameMemoryCache: [String: CachedAuthorName] = [:]
    private static var authorNameInFlightTasks: [String: Task<String?, Never>] = [:]
    private static var didLoadAuthorNameDefaults = false

    func ensureUserDocument(for user: User, suggestedName: String?, suggestedEmail: String? = nil) async throws {
        let ref = db.collection("users").document(user.uid)
        let snapshot = try await getDocument(ref)

        if snapshot.exists {
            return
        }

        let name: String
        if let suggestedName, !suggestedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = suggestedName
        } else if let displayName = user.displayName, !displayName.isEmpty {
            name = displayName
        } else {
            name = "Kuusi User"
        }

        let email = suggestedEmail ?? user.email ?? ""
        let payload: [String: Any] = [
            "name": name,
            "email": email,
            "icon": "🌸",
            "bgColour": "#A5C3DE",
            "usage_mb": 0.0,
            "groups": [],
            "favourites": [],
            "created_at": FieldValue.serverTimestamp()
        ]
        try await setDocument(ref, data: payload, merge: false)
    }

    func fetchUser(uid: String) async throws -> AppUser? {
        let ref = db.collection("users").document(uid)
        let snapshot = try await getDocument(ref)
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        return AppUser(id: snapshot.documentID, data: data)
    }

    func cachedAuthorName(uid: String) -> String? {
        loadAuthorNameDefaultsIfNeeded()
        return Self.authorNameMemoryCache[uid]?.name
    }

    func shouldRefreshCachedAuthorName(uid: String) -> Bool {
        loadAuthorNameDefaultsIfNeeded()
        guard let cached = Self.authorNameMemoryCache[uid] else {
            return true
        }
        return Date().timeIntervalSince(cached.cachedAt) > Self.authorNameTTL
    }

    func fetchCachedAuthorName(uid: String) async -> String? {
        if let cached = cachedAuthorName(uid: uid) {
            return cached
        }
        return await refreshAuthorName(uid: uid)
    }

    func refreshAuthorName(uid: String) async -> String? {
        loadAuthorNameDefaultsIfNeeded()
        if let task = Self.authorNameInFlightTasks[uid] {
            return await task.value
        }

        let task = Task<String?, Never> {
            defer { Self.authorNameInFlightTasks[uid] = nil }

            do {
                guard let user = try await self.fetchUser(uid: uid) else {
                    return nil
                }
                self.cacheAuthorName(user.name, for: uid)
                return user.name
            } catch {
                return nil
            }
        }

        Self.authorNameInFlightTasks[uid] = task
        return await task.value
    }

    func cacheAuthorName(_ name: String, for uid: String) {
        loadAuthorNameDefaultsIfNeeded()
        Self.authorNameMemoryCache[uid] = CachedAuthorName(name: name, cachedAt: Date())
        persistAuthorNameCache()
    }

    func updateProfile(uid: String, name: String, icon: String, bgColour: String) async throws {
        let ref = db.collection("users").document(uid)
        let payload: [String: Any] = [
            "name": name,
            "icon": icon,
            "bgColour": bgColour
        ]
        try await setDocument(ref, data: payload, merge: true)
    }

    func deleteUserDocument(uid: String) async throws {
        let ref = db.collection("users").document(uid)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
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

    private func loadAuthorNameDefaultsIfNeeded() {
        guard !Self.didLoadAuthorNameDefaults else { return }
        Self.didLoadAuthorNameDefaults = true

        guard
            let data = Self.defaults.data(forKey: Self.authorNameCacheKey),
            let cached = try? JSONDecoder().decode([String: CachedAuthorName].self, from: data)
        else {
            return
        }

        Self.authorNameMemoryCache = cached
    }

    private func persistAuthorNameCache() {
        guard let data = try? JSONEncoder().encode(Self.authorNameMemoryCache) else {
            return
        }
        Self.defaults.set(data, forKey: Self.authorNameCacheKey)
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
