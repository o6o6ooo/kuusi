import Combine
import SwiftUI

struct AppMessage: Equatable {
    static let defaultAutoClearInterval: TimeInterval = 2.5

    enum Tone: Equatable {
        case success
        case error
    }

    enum ID: Equatable {
        case alreadyJoinedGroup
        case appleSignInFailed
        case appleTokenUnavailable
        case biometricAuthenticationFailed
        case cameraAccessDenied
        case cameraUnavailable
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
        case failedToRemoveMember
        case failedToDisconnectGoogleAccount
        case failedToImportFromGooglePhotos
        case failedToLoadFeed
        case failedToJoinGroup
        case failedToLeaveGroup
        case failedToOpenManageSubscriptions
        case failedToOpenPrivacyChoices
        case failedToRestorePurchases
        case failedToSetUpAccount
        case failedToSaveProfile
        case failedToSignOut
        case failedToUpdateGroup
        case failedToUpdatePhoto
        case failedToUpdateFavourite
        case fillInGroupName
        case googleAccountConnected
        case googleAccountDisconnected
        case groupNotFound
        case groupMemberLimitReached(maxMembers: Int)
        case groupCreated
        case groupDeleted
        case inviteQRCodeExpired
        case ownerCannotLeave
        case groupUpdated
        case invalidInviteQR
        case joinedGroup
        case leftGroup
        case memberRemoved
        case nameCannotBeEmpty
        case noActivePurchasesFound
        case onlyOwnerCanRemoveMembers
        case ownerCannotBeRemoved
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
        case subscriptionCancelled
        case subscriptionResumed
        case subscriptionUnavailable
        case storageLimitReached
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
        case .alreadyJoinedGroup:
            return String(localized: "message.already_joined_group")
        case .appleSignInFailed:
            return String(localized: "message.apple_sign_in_failed")
        case .appleTokenUnavailable:
            return String(localized: "message.apple_token_unavailable")
        case .biometricAuthenticationFailed:
            return String(localized: "message.biometric_authentication_failed")
        case .cameraAccessDenied:
            return String(localized: "message.camera_access_denied")
        case .cameraUnavailable:
            return String(localized: "message.camera_unavailable")
        case .couldNotOpenGooglePhotos:
            return String(localized: "message.could_not_open_google_photos")
        case .couldNotOpenGoogleSignIn:
            return String(localized: "message.could_not_open_google_sign_in")
        case .googleAccountMismatch:
            return String(localized: "message.google_account_mismatch")
        case .googlePhotosPickerReturnedInvalidLink:
            return String(localized: "message.google_photos_picker_returned_invalid_link")
        case .googlePhotosPickerTimedOut:
            return String(localized: "message.google_photos_picker_timed_out")
        case .googlePhotosRequestFailed:
            return String(localized: "message.google_photos_request_failed")
        case .googleSignInNotConfigured:
            return String(localized: "message.google_sign_in_not_configured")
        case .googleSignInReturnedIncompleteAccount:
            return String(localized: "message.google_sign_in_returned_incomplete_account")
        case .googleSignInReturnedInvalidToken:
            return String(localized: "message.google_sign_in_returned_invalid_token")
        case .noLinkedGoogleAccount:
            return String(localized: "message.no_linked_google_account")
        case .noPhotosSelectedFromGooglePhotos:
            return String(localized: "message.no_photos_selected_from_google_photos")
        case .failedToGenerateQRCode:
            return String(localized: "message.failed_to_generate_qr_code")
        case .cannotDeleteOthersPhotos:
            return String(localized: "message.cannot_delete_others_photos")
        case .debugEmailPasswordProviderDisabled:
            return String(localized: "message.debug_email_password_provider_disabled")
        case .debugInvalidCredentials:
            return String(localized: "message.debug_invalid_credentials")
        case .debugSignInFailed:
            return String(localized: "message.debug_sign_in_failed")
        case .enterValidYear:
            return String(localized: "message.enter_valid_year")
        case .failedToLoadImage:
            return String(localized: "message.failed_to_load_image")
        case .failedToLoadGroupMembers:
            return String(localized: "message.failed_to_load_group_members")
        case .failedToLoadGroups:
            return String(localized: "message.failed_to_load_groups")
        case .failedToLoadProfile:
            return String(localized: "message.failed_to_load_profile")
        case .failedToConnectGoogleAccount:
            return String(localized: "message.failed_to_connect_google_account")
        case .failedToCreateGroup:
            return String(localized: "message.failed_to_create_group")
        case .failedToDeleteGroup:
            return String(localized: "message.failed_to_delete_group")
        case .failedToDeleteAccount:
            return String(localized: "message.failed_to_delete_account")
        case .failedToDeletePhoto:
            return String(localized: "message.failed_to_delete_photo")
        case .failedToRemoveMember:
            return String(localized: "message.failed_to_remove_member")
        case .failedToDisconnectGoogleAccount:
            return String(localized: "message.failed_to_disconnect_google_account")
        case .failedToImportFromGooglePhotos:
            return String(localized: "message.failed_to_import_from_google_photos")
        case .failedToLoadFeed:
            return String(localized: "message.failed_to_load_feed")
        case .failedToJoinGroup:
            return String(localized: "message.failed_to_join_group")
        case .failedToLeaveGroup:
            return String(localized: "message.failed_to_leave_group")
        case .failedToOpenManageSubscriptions:
            return String(localized: "message.failed_to_open_manage_subscriptions")
        case .failedToOpenPrivacyChoices:
            return String(localized: "message.failed_to_open_privacy_choices")
        case .failedToRestorePurchases:
            return String(localized: "message.failed_to_restore_purchases")
        case .failedToSetUpAccount:
            return String(localized: "message.failed_to_set_up_account")
        case .failedToSaveProfile:
            return String(localized: "message.failed_to_save_profile")
        case .failedToSignOut:
            return String(localized: "message.failed_to_sign_out")
        case .failedToUpdateGroup:
            return String(localized: "message.failed_to_update_group")
        case .failedToUpdatePhoto:
            return String(localized: "message.failed_to_update_photo")
        case .failedToUpdateFavourite:
            return String(localized: "message.failed_to_update_favourite")
        case .fillInGroupName:
            return String(localized: "message.fill_in_group_name")
        case .googleAccountConnected:
            return String(localized: "message.google_account_connected")
        case .googleAccountDisconnected:
            return String(localized: "message.google_account_disconnected")
        case .groupNotFound:
            return String(localized: "message.group_not_found")
        case let .groupMemberLimitReached(maxMembers):
            return String(format: String(localized: "message.group_member_limit_reached"), maxMembers)
        case .groupCreated:
            return String(localized: "message.group_created")
        case .groupDeleted:
            return String(localized: "message.group_deleted")
        case .inviteQRCodeExpired:
            return String(localized: "message.invite_qr_code_expired")
        case .ownerCannotLeave:
            return String(localized: "message.owner_cannot_leave")
        case .groupUpdated:
            return String(localized: "message.group_updated")
        case .invalidInviteQR:
            return String(localized: "message.invalid_invite_qr")
        case .joinedGroup:
            return String(localized: "message.joined_group")
        case .leftGroup:
            return String(localized: "message.left_group")
        case .memberRemoved:
            return String(localized: "message.member_removed")
        case .nameCannotBeEmpty:
            return String(localized: "message.name_cannot_be_empty")
        case .noActivePurchasesFound:
            return String(localized: "message.no_active_purchases_found")
        case .onlyOwnerCanRemoveMembers:
            return String(localized: "message.only_owner_can_remove_members")
        case .ownerCannotBeRemoved:
            return String(localized: "message.owner_cannot_be_removed")
        case .photoAlreadyBeingUpdated:
            return String(localized: "message.photo_already_being_updated")
        case .photoDeleted:
            return String(localized: "message.photo_deleted")
        case .photoUpdated:
            return String(localized: "message.photo_updated")
        case let .photosImportedFromGooglePhotos(count):
            return String(format: String(localized: "message.photos_imported_from_google_photos"), count)
        case .pleaseSignInFirst:
            return String(localized: "message.please_sign_in_first")
        case .purchaseCouldNotBeVerified:
            return String(localized: "message.purchase_could_not_be_verified")
        case .purchaseFailed:
            return String(localized: "message.purchase_failed")
        case .purchasePendingApproval:
            return String(localized: "message.purchase_pending_approval")
        case .premiumUnlocked:
            return String(localized: "message.premium_unlocked")
        case .profileUpdated:
            return String(localized: "message.profile_updated")
        case .purchasesRestored:
            return String(localized: "message.purchases_restored")
        case .qrCodeNotFoundInImage:
            return String(localized: "message.qr_code_not_found_in_image")
        case .recentLoginRequired:
            return String(localized: "message.recent_login_required")
        case .removedFromFavourites:
            return String(localized: "message.removed_from_favourites")
        case .addedToFavourites:
            return String(localized: "message.added_to_favourites")
        case .selectGroup:
            return String(localized: "message.select_group")
        case .subscriptionCancelled:
            return String(localized: "message.subscription_cancelled")
        case .subscriptionResumed:
            return String(localized: "message.subscription_resumed")
        case .subscriptionUnavailable:
            return String(localized: "message.subscription_unavailable")
        case .storageLimitReached:
            return String(localized: "message.storage_limit_reached")
        case .uploadCompleted:
            return String(localized: "message.upload_completed")
        case let .groupLimitReached(title, maxGroups):
            return String(format: String(localized: "message.group_limit_reached"), title, maxGroups)
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
