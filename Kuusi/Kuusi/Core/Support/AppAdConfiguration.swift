import Foundation

enum AppAdConfiguration {
    static let admobAppID = "ca-app-pub-4715092551737630~6071116764"

    static var feedNativeAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/3986624511"
        #else
        return "ca-app-pub-4715092551737630/2531416296"
        #endif
    }
}
