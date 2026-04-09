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

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-out"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kuusi"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Share photos with your loved ones"].exists)
    }

    @MainActor
    func testSignedInLaunchShowsMainTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.tabBars.buttons.count, 4)
    }

    @MainActor
    func testLockedLaunchCanUnlockIntoMainTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_LOCKED"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-locked"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Unlock"].waitForExistence(timeout: 5))

        app.buttons["Unlock"].tap()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.tabBars.buttons.count, 4)
    }
}
