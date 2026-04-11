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
        case debugEmailPasswordProviderDisabled
        case debugInvalidCredentials
        case debugSignInFailed(String)
        case enterValidYear
        case failedToLoadImage
        case fillInGroupName
        case googleAccountConnected
        case googleAccountDisconnected
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
        case photosImportedFromGooglePhotos(Int)
        case pleaseSignInFirst
        case premiumUnlocked
        case profileUpdated
        case purchasesRestored
        case qrCodeNotFoundInImage
        case recentLoginRequired
        case removedFromFavourites
        case addedToFavourites
        case selectGroup
        case uploadCompleted
        case groupLimitReached(title: String, maxGroups: Int)
        case details(String)
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

private extension AppMessage.ID {
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
        case .debugEmailPasswordProviderDisabled:
            return "Enable Email/Password provider in Firebase Authentication for debug login"
        case .debugInvalidCredentials:
            return "Debug user credentials are invalid, check email/password"
        case let .debugSignInFailed(description):
            return "Debug sign-in failed: \(description)"
        case .enterValidYear:
            return "Enter a valid year"
        case .failedToLoadImage:
            return "Failed to load image"
        case .fillInGroupName:
            return "Fill in group name"
        case .googleAccountConnected:
            return "Google account connected"
        case .googleAccountDisconnected:
            return "Google account disconnected"
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
        case let .photosImportedFromGooglePhotos(count):
            return "\(count) photos imported from Google Photos"
        case .pleaseSignInFirst:
            return "Please sign in first"
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
        case .uploadCompleted:
            return "Upload completed"
        case let .groupLimitReached(title, maxGroups):
            return "\(title) supports up to \(maxGroups) groups"
        case let .details(message):
            return message
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
