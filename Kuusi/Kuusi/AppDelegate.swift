import FirebaseAppCheck
import FirebaseCore
import UIKit

private final class KuusiAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
#if DEBUG
        return AppCheckDebugProviderFactory().createProvider(with: app)
#else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
#endif
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppCheck.setAppCheckProviderFactory(KuusiAppCheckProviderFactory())
        FirebaseApp.configure()
        return true
    }
}
