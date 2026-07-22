import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
protocol NotificationServicing {
    func handleSignedInUser(_ uid: String) async
    func handleSignedOutUser(_ uid: String?) async
    func didRegisterForRemoteNotifications(deviceToken: Data)
    func didReceiveRegistrationToken(_ fcmToken: String?) async
}

@MainActor
final class NotificationService: NotificationServicing {
    @MainActor
    static let shared = NotificationService(
        userService: UserService(),
        notificationCenter: .current(),
        application: .shared,
        userDefaults: .standard,
        bundle: .main
    )

    private let userService: UserService
    private let notificationCenter: UNUserNotificationCenter
    private let application: UIApplication
    private let userDefaults: UserDefaults
    private let bundle: Bundle

    private var currentUserID: String?
    private var currentFCMToken: String?

    init(
        userService: UserService,
        notificationCenter: UNUserNotificationCenter,
        application: UIApplication,
        userDefaults: UserDefaults,
        bundle: Bundle
    ) {
        self.userService = userService
        self.notificationCenter = notificationCenter
        self.application = application
        self.userDefaults = userDefaults
        self.bundle = bundle
    }

    func handleSignedInUser(_ uid: String) async {
        currentUserID = uid
        currentFCMToken = sanitizedToken(Messaging.messaging().fcmToken) ?? currentFCMToken

        let settings = await ensureNotificationAuthorization()
        if isAuthorized(settings.authorizationStatus) {
            application.registerForRemoteNotifications()
        }

        await persistCurrentDevice(for: uid, authorizationStatus: settings.authorizationStatus)
    }

    func handleSignedOutUser(_ uid: String?) async {
        let resolvedUID = uid ?? currentUserID
        currentUserID = nil
        currentFCMToken = nil

        guard let resolvedUID else { return }

        do {
            try await userService.deleteNotificationDevice(uid: resolvedUID, deviceID: deviceID)
        } catch {
            // Keep sign-out resilient even if device cleanup fails.
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func didReceiveRegistrationToken(_ fcmToken: String?) async {
        currentFCMToken = sanitizedToken(fcmToken)

        guard let currentUserID else { return }
        let settings = await notificationSettings()
        await persistCurrentDevice(for: currentUserID, authorizationStatus: settings.authorizationStatus)
    }

    private func persistCurrentDevice(for uid: String, authorizationStatus: UNAuthorizationStatus) async {
        do {
            try await userService.upsertNotificationDevice(
                uid: uid,
                deviceID: deviceID,
                fcmToken: isAuthorized(authorizationStatus) ? currentFCMToken : nil,
                notificationsEnabled: isAuthorized(authorizationStatus),
                deviceName: UIDevice.current.model,
                appVersion: appVersion
            )
        } catch {
            // Skip surfacing a toast here so auth and feed flows stay calm.
        }
    }

    private func ensureNotificationAuthorization() async -> UNNotificationSettings {
        let settings = await notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings
        }

        _ = await requestAuthorization()
        return await notificationSettings()
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func sanitizedToken(_ token: String?) -> String? {
        guard let token else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var deviceID: String {
        if let existing = userDefaults.string(forKey: AppSettings.notificationDeviceIDKey), !existing.isEmpty {
            return existing
        }

        let generatedID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        userDefaults.set(generatedID, forKey: AppSettings.notificationDeviceIDKey)
        return generatedID
    }

    private var appVersion: String {
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String

        switch (shortVersion, build) {
        case let (.some(shortVersion), .some(build)) where !shortVersion.isEmpty && !build.isEmpty:
            return "\(shortVersion) (\(build))"
        case let (.some(shortVersion), _) where !shortVersion.isEmpty:
            return shortVersion
        case let (_, .some(build)) where !build.isEmpty:
            return build
        default:
            return "unknown"
        }
    }
}
