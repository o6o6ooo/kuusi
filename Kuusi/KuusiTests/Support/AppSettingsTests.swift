import Testing
@testable import Kuusi

struct AppSettingsTests {
    @Test
    func biometricsKeyRemainsStable() {
        #expect(AppSettings.biometricsEnabledKey == "biometrics_enabled")
    }
}
