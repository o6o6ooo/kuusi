import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import UIKit

struct GoogleLinkedAccount: Equatable {
    let email: String
    let isLinked: Bool
}

struct GoogleAuthorizedSession {
    let accessToken: String
}

enum GoogleAccountError: LocalizedError {
    case missingFirebaseUser
    case missingClientID
    case missingGoogleIDToken
    case missingGoogleEmail
    case noLinkedGoogleAccount
    case mismatchedLinkedAccount(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .missingFirebaseUser:
            return "Please sign in to Kuusi first."
        case .missingClientID:
            return "Google Sign-In is not configured yet."
        case .missingGoogleIDToken:
            return "Google Sign-In did not return a valid token."
        case .missingGoogleEmail:
            return "Google Sign-In did not return an email address."
        case .noLinkedGoogleAccount:
            return "Connect a Google account in Settings first."
        case let .mismatchedLinkedAccount(expected, actual):
            return "This Google account does not match the one linked to Kuusi. Expected \(expected), got \(actual)."
        }
    }
}

@MainActor
final class GoogleAccountService {
    static let pickerScope = "https://www.googleapis.com/auth/photospicker.mediaitems.readonly"
    private let googleProviderID = "google.com"

    func currentLinkedAccount(for user: User?) -> GoogleLinkedAccount {
        guard let provider = user?.providerData.first(where: { $0.providerID == googleProviderID }) else {
            return GoogleLinkedAccount(email: "", isLinked: false)
        }

        return GoogleLinkedAccount(
            email: provider.email ?? "",
            isLinked: true
        )
    }

    func connectCurrentUser(presentingViewController: UIViewController) async throws -> GoogleLinkedAccount {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw GoogleAccountError.missingFirebaseUser
        }

        try configureIfNeeded()
        let existingAccount = currentLinkedAccount(for: firebaseUser)
        let googleUser = try await ensureAuthorizedGoogleUser(
            matchingEmail: existingAccount.isLinked ? existingAccount.email : nil,
            presentingViewController: presentingViewController,
            scopes: []
        )
        let googleEmail = try resolvedEmail(from: googleUser)

        if existingAccount.isLinked {
            guard existingAccount.email.caseInsensitiveCompare(googleEmail) == .orderedSame else {
                throw GoogleAccountError.mismatchedLinkedAccount(expected: existingAccount.email, actual: googleEmail)
            }
            return GoogleLinkedAccount(email: googleEmail, isLinked: true)
        }

        try await link(firebaseUser: firebaseUser, with: googleUser)
        return GoogleLinkedAccount(email: googleEmail, isLinked: true)
    }

    func disconnectCurrentUser() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw GoogleAccountError.missingFirebaseUser
        }

        guard currentLinkedAccount(for: firebaseUser).isLinked else { return }
        _ = try await unlink(firebaseUser: firebaseUser)
        GIDSignIn.sharedInstance.signOut()
    }

    func preparePickerAuthorization(presentingViewController: UIViewController) async throws -> GoogleAuthorizedSession {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw GoogleAccountError.missingFirebaseUser
        }

        let linkedAccount = currentLinkedAccount(for: firebaseUser)
        guard linkedAccount.isLinked else {
            throw GoogleAccountError.noLinkedGoogleAccount
        }

        try configureIfNeeded()
        let googleUser = try await ensureAuthorizedGoogleUser(
            matchingEmail: linkedAccount.email,
            presentingViewController: presentingViewController,
            scopes: [Self.pickerScope]
        )
        let googleEmail = try resolvedEmail(from: googleUser)

        guard linkedAccount.email.caseInsensitiveCompare(googleEmail) == .orderedSame else {
            throw GoogleAccountError.mismatchedLinkedAccount(expected: linkedAccount.email, actual: googleEmail)
        }

        return GoogleAuthorizedSession(
            accessToken: googleUser.accessToken.tokenString
        )
    }

    private func configureIfNeeded() throws {
        guard GIDSignIn.sharedInstance.configuration == nil else { return }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw GoogleAccountError.missingClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    private func ensureAuthorizedGoogleUser(
        matchingEmail: String?,
        presentingViewController: UIViewController,
        scopes: [String]
    ) async throws -> GIDGoogleUser {
        if let currentUser = GIDSignIn.sharedInstance.currentUser,
           matchesExpectedEmail(currentUser, expectedEmail: matchingEmail) {
            return try await addScopesIfNeeded(scopes, to: currentUser, presentingViewController: presentingViewController)
        }

        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            let restoredUser = try await restorePreviousGoogleUser()
            if matchesExpectedEmail(restoredUser, expectedEmail: matchingEmail) {
                return try await addScopesIfNeeded(scopes, to: restoredUser, presentingViewController: presentingViewController)
            }
            GIDSignIn.sharedInstance.signOut()
        }

        let signInResult = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: matchingEmail,
            additionalScopes: scopes
        )
        let googleUser = signInResult.user
        let actualEmail = try resolvedEmail(from: googleUser)

        if let matchingEmail,
           matchingEmail.caseInsensitiveCompare(actualEmail) != .orderedSame {
            GIDSignIn.sharedInstance.signOut()
            throw GoogleAccountError.mismatchedLinkedAccount(expected: matchingEmail, actual: actualEmail)
        }

        return googleUser
    }

    private func restorePreviousGoogleUser() async throws -> GIDGoogleUser {
        try await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    private func addScopesIfNeeded(
        _ scopes: [String],
        to googleUser: GIDGoogleUser,
        presentingViewController: UIViewController
    ) async throws -> GIDGoogleUser {
        let grantedScopes = Set(googleUser.grantedScopes ?? [])
        let missingScopes = scopes.filter { !grantedScopes.contains($0) }

        guard !missingScopes.isEmpty else { return googleUser }

        let result = try await googleUser.addScopes(missingScopes, presenting: presentingViewController)
        return result.user
    }

    private func link(firebaseUser: User, with googleUser: GIDGoogleUser) async throws {
        guard let idToken = googleUser.idToken?.tokenString else {
            throw GoogleAccountError.missingGoogleIDToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            firebaseUser.link(with: credential) { result, error in
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
    }

    private func unlink(firebaseUser: User) async throws -> User {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<User, Error>) in
            firebaseUser.unlink(fromProvider: googleProviderID) { user, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let user else {
                    continuation.resume(throwing: GoogleAccountError.noLinkedGoogleAccount)
                    return
                }
                continuation.resume(returning: user)
            }
        }
    }

    private func resolvedEmail(from googleUser: GIDGoogleUser) throws -> String {
        guard let email = googleUser.profile?.email, !email.isEmpty else {
            throw GoogleAccountError.missingGoogleEmail
        }
        return email
    }

    private func matchesExpectedEmail(_ googleUser: GIDGoogleUser, expectedEmail: String?) -> Bool {
        guard let expectedEmail, !expectedEmail.isEmpty else { return true }
        return (googleUser.profile?.email ?? "").caseInsensitiveCompare(expectedEmail) == .orderedSame
    }
}
