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

    @MainActor
    func testSignedInLaunchAllowsMainTabNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(tabBar.buttons.count, 4)

        let yearsTab = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(yearsTab.waitForExistence(timeout: 5))
        yearsTab.tap()
        XCTAssertTrue(app.staticTexts["ui-screen-years"].waitForExistence(timeout: 5))

        let favoritesTab = tabBar.buttons.element(boundBy: 2)
        XCTAssertTrue(favoritesTab.exists)
        favoritesTab.tap()
        XCTAssertTrue(app.staticTexts["ui-screen-favorites"].waitForExistence(timeout: 5))

        let settingsTab = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-sign-out-button"].exists)

        let feedTab = tabBar.buttons.element(boundBy: 0)
        XCTAssertTrue(feedTab.exists)
        feedTab.tap()
        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignedInLaunchShowsFeedUploadEntryPoint() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let feedTab = tabBar.buttons.element(boundBy: 0)
        XCTAssertTrue(feedTab.waitForExistence(timeout: 5))
        feedTab.tap()

        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["feed-upload-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["ui-feed-no-groups"].exists
            || app.staticTexts["ui-feed-no-photos"].exists
            || app.buttons["feed-upload-button"].exists
        )
    }

    @MainActor
    func testSignedInLaunchShowsSettingsSections() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let settingsTab = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        XCTAssertTrue(app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-settings-profile-section"].exists)
        XCTAssertTrue(app.staticTexts["ui-settings-groups-section"].exists)
        XCTAssertTrue(app.staticTexts["ui-settings-subscription-section"].exists)
        XCTAssertTrue(app.buttons["settings-sign-out-button"].exists)
    }
}
