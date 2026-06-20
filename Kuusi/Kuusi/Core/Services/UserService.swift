import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

private struct CachedAppUser: Codable {
    let id: String
    let name: String
    let icon: String
    let bgColour: String
    let usageMB: Double
    let groups: [String]
    let cachedAt: Date

    init(user: AppUser, cachedAt: Date = Date()) {
        id = user.id
        name = user.name
        icon = user.icon
        bgColour = user.bgColour
        usageMB = user.usageMB
        groups = user.groups
        self.cachedAt = cachedAt
    }

    func toAppUser() -> AppUser {
        AppUser(
            id: id,
            name: name,
            icon: icon,
            bgColour: bgColour,
            usageMB: usageMB,
            groups: groups
        )
    }
}

@MainActor
final class UserService {
    private static let functionsRegion = "europe-west2"
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: UserService.functionsRegion)
    private static let defaults = UserDefaults.standard
    private static let authorProfileTTL: TimeInterval = 7 * 24 * 60 * 60
    private static var authorProfileInFlightTasks: [String: Task<AppUser?, Never>] = [:]
    private static let profileCacheKey = "current_user_profile_cache_v1"
    private static var profileMemoryCache: [String: CachedAppUser] = [:]
    private static var didLoadProfileDefaults = false

    func ensureUserDocument(for user: User, suggestedName: String?) async throws {
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

        let payload: [String: Any] = [
            "name": name,
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
        let user = AppUser(id: snapshot.documentID, data: data)
        if let user {
            cacheUser(user)
        }
        return user
    }

    func fetchCachedUser(uid: String) async throws -> AppUser? {
        if let cached = cachedUser(uid: uid) {
            return cached
        }
        return try await fetchUser(uid: uid)
    }

    func cachedUser(uid: String) -> AppUser? {
        loadProfileDefaultsIfNeeded()
        return Self.profileMemoryCache[uid]?.toAppUser()
    }

    func cachedAuthorProfile(uid: String) -> AppUser? {
        cachedUser(uid: uid)
    }

    func shouldRefreshCachedAuthorProfile(uid: String) -> Bool {
        loadProfileDefaultsIfNeeded()
        guard let cached = Self.profileMemoryCache[uid] else {
            return true
        }
        return Date().timeIntervalSince(cached.cachedAt) > Self.authorProfileTTL
    }

    func fetchCachedAuthorProfile(uid: String) async -> AppUser? {
        if let cached = cachedAuthorProfile(uid: uid) {
            return cached
        }
        return await refreshAuthorProfile(uid: uid)
    }

    func refreshAuthorProfile(uid: String) async -> AppUser? {
        loadProfileDefaultsIfNeeded()
        if let task = Self.authorProfileInFlightTasks[uid] {
            return await task.value
        }

        let task = Task<AppUser?, Never> {
            defer { Self.authorProfileInFlightTasks[uid] = nil }

            do {
                return try await self.fetchUser(uid: uid)
            } catch {
                return nil
            }
        }

        Self.authorProfileInFlightTasks[uid] = task
        return await task.value
    }

    func cacheUser(_ user: AppUser) {
        loadProfileDefaultsIfNeeded()
        Self.profileMemoryCache[user.id] = CachedAppUser(user: user)
        persistProfileCache()
    }

    func clearCachedUserProfile(for uid: String) {
        loadProfileDefaultsIfNeeded()
        Self.profileMemoryCache[uid] = nil
        persistProfileCache()
    }

    func cacheUserProfile(uid: String, name: String, icon: String, bgColour: String, usageMB: Double) {
        let existing = cachedUser(uid: uid)
        let user = AppUser(
            id: uid,
            name: name,
            icon: icon,
            bgColour: bgColour,
            usageMB: usageMB,
            groups: existing?.groups ?? []
        )
        cacheUser(user)
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

    func deleteCurrentUserData() async throws {
        _ = try await functions.httpsCallable("deleteCurrentUserData").call([:])
    }

    func upsertNotificationDevice(
        uid: String,
        deviceID: String,
        fcmToken: String?,
        notificationsEnabled: Bool,
        platform: String = "ios",
        deviceName: String?,
        appVersion: String
    ) async throws {
        let ref = db.collection("users").document(uid).collection("devices").document(deviceID)

        var payload: [String: Any] = [
            "platform": platform,
            "app_version": appVersion,
            "notifications_enabled": notificationsEnabled,
            "last_seen_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        if let deviceName, !deviceName.isEmpty {
            payload["device_name"] = deviceName
        }

        if let fcmToken, !fcmToken.isEmpty {
            payload["fcm_token"] = fcmToken
        } else {
            payload["fcm_token"] = FieldValue.delete()
        }

        try await setDocument(ref, data: payload, merge: true)
    }

    func deleteNotificationDevice(uid: String, deviceID: String) async throws {
        let ref = db.collection("users").document(uid).collection("devices").document(deviceID)
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

    private func loadProfileDefaultsIfNeeded() {
        guard !Self.didLoadProfileDefaults else { return }
        Self.didLoadProfileDefaults = true

        guard
            let data = Self.defaults.data(forKey: Self.profileCacheKey),
            let cached = try? JSONDecoder().decode([String: CachedAppUser].self, from: data)
        else {
            return
        }

        Self.profileMemoryCache = cached
    }

    private func persistProfileCache() {
        guard let data = try? JSONEncoder().encode(Self.profileMemoryCache) else {
            return
        }
        Self.defaults.set(data, forKey: Self.profileCacheKey)
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
