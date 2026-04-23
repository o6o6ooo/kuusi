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
        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["feed-settings-button"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["feed-settings-button"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignedInLaunchAllowsMainTabNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))

        let settingsButton = app.buttons["feed-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-sign-out-button"].exists)
    }

    @MainActor
    func testSignedInLaunchShowsFeedUploadEntryPoint() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["ui-feed-no-groups"].exists
            || app.buttons["feed-upload-button"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testSignedInLaunchShowsFeedNoGroupsState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-feed-no-groups"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No groups yet"].exists)
        XCTAssertTrue(app.staticTexts["Create or join a group in Settings to start sharing."].exists)
    }

    @MainActor
    func testSignedInLaunchHidesFeedActionButtonsWithoutGroups() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-feed-no-groups"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["feed-upload-button"].exists)
        XCTAssertFalse(app.buttons["feed-favourites-filter-button"].exists)
        XCTAssertTrue(app.buttons["feed-settings-button"].exists)
    }

    @MainActor
    func testSignedInLaunchShowsSettingsSections() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))

        let settingsButton = app.buttons["feed-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-settings-profile-section"].exists)
        XCTAssertTrue(app.staticTexts["ui-settings-groups-section"].exists)
        XCTAssertTrue(app.staticTexts["ui-settings-subscription-section"].exists)
        XCTAssertTrue(app.buttons["settings-sign-out-button"].exists)
    }

    @MainActor
    func testSignedInLaunchShowsGroupsEmptyStateInSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))

        let settingsButton = app.buttons["feed-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-settings-groups-section"].exists)
        XCTAssertTrue(app.buttons["groups-create-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No groups"].exists)
    }

    @MainActor
    func testSignedInLaunchShowsGroupCreateMenuActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))

        let settingsButton = app.buttons["feed-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let createButton = app.buttons["groups-create-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        XCTAssertTrue(app.buttons["Create a group"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Join a group"].exists)
    }

    @MainActor
    func testSignedInLaunchCanOpenCreateGroupPrompt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5))

        let settingsButton = app.buttons["feed-settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let createButton = app.buttons["groups-create-button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let createGroupAction = app.buttons["Create a group"]
        XCTAssertTrue(createGroupAction.waitForExistence(timeout: 5))
        createGroupAction.tap()

        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.firstMatch.textFields.firstMatch.exists)
    }
}
