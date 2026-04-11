import FirebaseAuth
import FirebaseFirestore
import Foundation

final class UserService {
    private let db = Firestore.firestore()

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

    func updateProfile(uid: String, name: String, icon: String, bgColour: String) async throws {
        let ref = db.collection("users").document(uid)
        let payload: [String: Any] = [
            "name": name,
            "icon": icon,
            "bgColour": bgColour
        ]
        try await setDocument(ref, data: payload, merge: true)
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
