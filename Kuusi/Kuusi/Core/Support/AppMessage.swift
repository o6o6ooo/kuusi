import Combine
import SwiftUI

struct AppMessage: Equatable {
    static let defaultAutoClearInterval: TimeInterval = 2.5

    enum Tone: Equatable {
        case success
        case error
    }

    enum ID: Equatable {
        case appleSignInFailed
        case appleTokenUnavailable
        case biometricAuthenticationFailed
        case couldNotOpenGooglePhotos
        case couldNotOpenGoogleSignIn
        case googleAccountMismatch
        case googlePhotosPickerReturnedInvalidLink
        case googlePhotosPickerTimedOut
        case googlePhotosRequestFailed
        case googleSignInNotConfigured
        case googleSignInReturnedIncompleteAccount
        case googleSignInReturnedInvalidToken
        case noLinkedGoogleAccount
        case noPhotosSelectedFromGooglePhotos
        case failedToGenerateQRCode
        case cannotDeleteOthersPhotos
        case cannotEditOthersPhotos
        case debugEmailPasswordProviderDisabled
        case debugInvalidCredentials
        case debugSignInFailed
        case enterValidYear
        case failedToLoadImage
        case failedToLoadGroupMembers
        case failedToLoadGroups
        case failedToLoadProfile
        case failedToConnectGoogleAccount
        case failedToCreateGroup
        case failedToDeleteGroup
        case failedToDeleteAccount
        case failedToDeletePhoto
        case failedToDisconnectGoogleAccount
        case failedToImportFromGooglePhotos
        case failedToLoadFeed
        case failedToJoinGroup
        case failedToLeaveGroup
        case failedToOpenManageSubscriptions
        case failedToRestorePurchases
        case failedToSaveProfile
        case failedToSignOut
        case failedToUpdateGroup
        case failedToUpdatePhoto
        case failedToUpdateFavourite
        case fillInGroupName
        case googleAccountConnected
        case googleAccountDisconnected
        case groupNotFound
        case groupCreated
        case groupDeleted
        case ownerCannotLeave
        case groupUpdated
        case invalidInviteQR
        case joinedGroup
        case leftGroup
        case nameCannotBeEmpty
        case noActivePurchasesFound
        case photoAlreadyBeingUpdated
        case photoDeleted
        case photoUpdated
        case photosImportedFromGooglePhotos(Int)
        case pleaseSignInFirst
        case purchaseCouldNotBeVerified
        case purchaseFailed
        case purchasePendingApproval
        case premiumUnlocked
        case profileUpdated
        case purchasesRestored
        case qrCodeNotFoundInImage
        case recentLoginRequired
        case removedFromFavourites
        case addedToFavourites
        case selectGroup
        case subscriptionUnavailable
        case uploadCompleted
        case groupLimitReached(title: String, maxGroups: Int)
    }

    let id: ID
    let tone: Tone
    let text: String
    let autoClearAfter: TimeInterval?

    init(_ id: ID, _ tone: Tone, autoClearAfter: TimeInterval? = defaultAutoClearInterval) {
        self.id = id
        self.tone = tone
        self.text = id.text
        self.autoClearAfter = autoClearAfter
    }
}

extension AppMessage.ID {
    var text: String {
        switch self {
        case .appleSignInFailed:
            return "Apple Sign-In failed"
        case .appleTokenUnavailable:
            return "Apple ID token was not available"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .couldNotOpenGooglePhotos:
            return "Could not open Google Photos"
        case .couldNotOpenGoogleSignIn:
            return "Could not open Google Sign-In"
        case .googleAccountMismatch:
            return "This Google account does not match the linked account"
        case .googlePhotosPickerReturnedInvalidLink:
            return "Google Photos did not return a valid picker link"
        case .googlePhotosPickerTimedOut:
            return "Google Photos selection took too long"
        case .googlePhotosRequestFailed:
            return "Google Photos request failed"
        case .googleSignInNotConfigured:
            return "Google Sign-In is not configured yet"
        case .googleSignInReturnedIncompleteAccount:
            return "Google Sign-In did not return a valid email address"
        case .googleSignInReturnedInvalidToken:
            return "Google Sign-In did not return a valid token"
        case .noLinkedGoogleAccount:
            return "Connect a Google account in Settings first"
        case .noPhotosSelectedFromGooglePhotos:
            return "No photos were selected from Google Photos"
        case .failedToGenerateQRCode:
            return "Failed to generate QR code"
        case .cannotDeleteOthersPhotos:
            return "You can only delete your own photos"
        case .cannotEditOthersPhotos:
            return "You can only edit your own photos"
        case .debugEmailPasswordProviderDisabled:
            return "Enable Email/Password provider in Firebase Authentication for debug login"
        case .debugInvalidCredentials:
            return "Debug user credentials are invalid, check email/password"
        case .debugSignInFailed:
            return "Debug sign-in failed"
        case .enterValidYear:
            return "Enter a valid year"
        case .failedToLoadImage:
            return "Failed to load image"
        case .failedToLoadGroupMembers:
            return "Failed to load group members"
        case .failedToLoadGroups:
            return "Failed to load groups"
        case .failedToLoadProfile:
            return "Failed to load profile"
        case .failedToConnectGoogleAccount:
            return "Failed to connect Google account"
        case .failedToCreateGroup:
            return "Failed to create group"
        case .failedToDeleteGroup:
            return "Failed to delete group"
        case .failedToDeleteAccount:
            return "Failed to delete account"
        case .failedToDeletePhoto:
            return "Failed to delete photo"
        case .failedToDisconnectGoogleAccount:
            return "Failed to disconnect Google account"
        case .failedToImportFromGooglePhotos:
            return "Failed to import from Google Photos"
        case .failedToLoadFeed:
            return "Failed to load photos"
        case .failedToJoinGroup:
            return "Failed to join group"
        case .failedToLeaveGroup:
            return "Failed to leave group"
        case .failedToOpenManageSubscriptions:
            return "Could not open subscription management"
        case .failedToRestorePurchases:
            return "Failed to restore purchases"
        case .failedToSaveProfile:
            return "Failed to save profile"
        case .failedToSignOut:
            return "Failed to sign out"
        case .failedToUpdateGroup:
            return "Failed to update group"
        case .failedToUpdatePhoto:
            return "Failed to update photo"
        case .failedToUpdateFavourite:
            return "Failed to update favourite"
        case .fillInGroupName:
            return "Fill in group name"
        case .googleAccountConnected:
            return "Google account connected"
        case .googleAccountDisconnected:
            return "Google account disconnected"
        case .groupNotFound:
            return "Group not found"
        case .groupCreated:
            return "Group created"
        case .groupDeleted:
            return "Group deleted"
        case .ownerCannotLeave:
            return "Group owners cannot leave their group"
        case .groupUpdated:
            return "Group updated"
        case .invalidInviteQR:
            return "Invalid invite QR"
        case .joinedGroup:
            return "Joined group"
        case .leftGroup:
            return "Left group"
        case .nameCannotBeEmpty:
            return "Name cannot be empty"
        case .noActivePurchasesFound:
            return "No active purchases found"
        case .photoAlreadyBeingUpdated:
            return "Photo is already being updated"
        case .photoDeleted:
            return "Photo deleted"
        case .photoUpdated:
            return "Photo updated"
        case let .photosImportedFromGooglePhotos(count):
            return "\(count) photos imported from Google Photos"
        case .pleaseSignInFirst:
            return "Please sign in first"
        case .purchaseCouldNotBeVerified:
            return "Purchase could not be verified"
        case .purchaseFailed:
            return "Purchase failed"
        case .purchasePendingApproval:
            return "Purchase is pending approval"
        case .premiumUnlocked:
            return "Premium unlocked"
        case .profileUpdated:
            return "Profile updated"
        case .purchasesRestored:
            return "Purchases restored"
        case .qrCodeNotFoundInImage:
            return "QR code was not found in the image"
        case .recentLoginRequired:
            return "Please sign in again before deleting your account"
        case .removedFromFavourites:
            return "Removed from favourites"
        case .addedToFavourites:
            return "Added to favourites"
        case .selectGroup:
            return "Select a group"
        case .subscriptionUnavailable:
            return "Premium subscription is not available right now"
        case .uploadCompleted:
            return "Upload completed"
        case let .groupLimitReached(title, maxGroups):
            return "\(title) supports up to \(maxGroups) groups"
        }
    }
}

@MainActor
final class AppToastCenter: ObservableObject {
    @Published private(set) var currentMessage: AppMessage?

    private var clearTask: Task<Void, Never>?
    private var hostOrder: [UUID] = []

    deinit {
        clearTask?.cancel()
    }

    func present(_ message: AppMessage, clearSource: (@MainActor @Sendable () -> Void)? = nil) {
        clearTask?.cancel()
        currentMessage = message
        clearTask = AppMessageAutoClear.schedule(
            for: message,
            currentMessage: { [weak self] in
                self?.currentMessage
            },
            clear: { [weak self] in
                self?.currentMessage = nil
                clearSource?()
            }
        )
    }

    func registerHost(_ id: UUID) {
        hostOrder.removeAll { $0 == id }
        hostOrder.append(id)
        objectWillChange.send()
    }

    func unregisterHost(_ id: UUID) {
        hostOrder.removeAll { $0 == id }
        objectWillChange.send()
    }

    func isActiveHost(_ id: UUID) -> Bool {
        hostOrder.last == id
    }
}

private struct AppToastPresenterModifier: ViewModifier {
    @EnvironmentObject private var toastCenter: AppToastCenter

    let message: AppMessage?
    let clear: @MainActor @Sendable () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let message else { return }
                toastCenter.present(message, clearSource: { @MainActor @Sendable in
                    clear()
                })
            }
            .onChange(of: message) { _, newValue in
                guard let newValue else { return }
                toastCenter.present(newValue, clearSource: { @MainActor @Sendable in
                    clear()
                })
            }
    }
}

private struct AppToastHost: View {
    @EnvironmentObject private var toastCenter: AppToastCenter
    @Environment(\.colorScheme) private var colorScheme
    @State private var hostID = UUID()

    var body: some View {
        GeometryReader { proxy in
            if toastCenter.isActiveHost(hostID), let message = toastCenter.currentMessage {
                HStack(spacing: 10) {
                    Image(systemName: message.tone.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(message.tone.symbolColor(for: colorScheme))

                    Text(message.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: min(max(proxy.size.width - 24, 0), 420))
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, x: 0, y: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10) + 8)
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: toastCenter.currentMessage)
        .onAppear {
            toastCenter.registerHost(hostID)
        }
        .onDisappear {
            toastCenter.unregisterHost(hostID)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum AppMessageAutoClear {
    @MainActor
    static func schedule(
        for message: AppMessage?,
        currentMessage: @escaping @MainActor () -> AppMessage?,
        clear: @escaping @MainActor @Sendable () -> Void
    ) -> Task<Void, Never>? {
        guard let message, let delay = message.autoClearAfter else { return nil }

        return Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled, currentMessage() == message {
                clear()
            }
        }
    }
}

private extension AppMessage.Tone {
    var symbolName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    func symbolColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .success:
            return AppTheme.accent(for: colorScheme)
        case .error:
            return AppTheme.errorText
        }
    }
}

extension View {
    func appToastHost() -> some View {
        overlay(alignment: .bottom) {
            AppToastHost()
        }
    }

    func appToastMessage(
        _ message: AppMessage?,
        clear: @escaping @MainActor @Sendable () -> Void = {}
    ) -> some View {
        modifier(AppToastPresenterModifier(message: message, clear: clear))
    }
}
