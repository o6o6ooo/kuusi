import AuthenticationServices
import FirebaseAuth
import Foundation

struct AppleSignInPayload {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
}

enum AuthServiceError: LocalizedError {
    case missingResult

    var errorDescription: String? {
        switch self {
        case .missingResult:
            return "Failed to sign in."
        }
    }
}

final class AppleAuthService {
    func signIn(payload: AppleSignInPayload) async throws -> User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: payload.idToken,
            rawNonce: payload.rawNonce,
            fullName: payload.fullName
        )

        let authResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthServiceError.missingResult)
                    return
                }
                continuation.resume(returning: result)
            }
        }

        if let fullName = payload.fullName {
            let formatter = PersonNameComponentsFormatter()
            let displayName = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            if !displayName.isEmpty {
                let change = authResult.user.createProfileChangeRequest()
                change.displayName = displayName
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    change.commitChanges { error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume(returning: ())
                    }
                }
            }
        }

        return authResult.user
    }
}
