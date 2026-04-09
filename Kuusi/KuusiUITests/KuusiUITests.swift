import XCTest

final class KuusiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsLoginScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_OUT"]
        app.launch()

        XCTAssertTrue(app.otherElements["login-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["login-title"].exists)
        XCTAssertTrue(app.buttons["apple-sign-in-button"].exists)
    }

    @MainActor
    func testSignedInLaunchShowsMainTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Feed"].exists)
        XCTAssertTrue(app.buttons["Years"].exists)
        XCTAssertTrue(app.buttons["Favorites"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
    }

    @MainActor
    func testLockedLaunchCanUnlockIntoMainTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_LOCKED"]
        app.launch()

        XCTAssertTrue(app.otherElements["unlock-screen"].waitForExistence(timeout: 5))

        app.buttons["unlock-button"].tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Feed"].exists)
    }
}
