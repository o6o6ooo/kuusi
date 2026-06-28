import FirebaseCrashlytics
import Foundation

enum AppTelemetry {
    enum Screen: String {
        case feed
        case login
        case settings
        case subscription
        case unlock
    }

    enum Operation: String {
        case googlePhotosImport = "google_photos_import"
        case groupJoin = "group_join"
        case none
        case photoUpload = "photo_upload"
        case subscriptionManage = "subscription_manage"
        case subscriptionPurchase = "subscription_purchase"
        case subscriptionRestore = "subscription_restore"
    }

    static func configureAppVersion(bundle: Bundle = .main) {
        Crashlytics.crashlytics().setCustomValue(appVersion(from: bundle), forKey: "app_version")
        clearOperation()
    }

    static func setScreen(_ screen: Screen) {
        Crashlytics.crashlytics().setCustomValue(screen.rawValue, forKey: "screen")
    }

    static func setOperation(_ operation: Operation) {
        Crashlytics.crashlytics().setCustomValue(operation.rawValue, forKey: "operation")
    }

    static func clearOperation() {
        setOperation(.none)
    }

    private static func appVersion(from bundle: Bundle) -> String {
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
