import XCTest

final class KuusiUITests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	private func launchSignedIn(extraArguments: [String] = []) -> XCUIApplication
	{
		let app = XCUIApplication()
		app.launchArguments = ["UI_TEST_ROUTE_SIGNED_IN"] + extraArguments
		app.launch()
		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5)
		)
		return app
	}

	private func openSettings(in app: XCUIApplication) {
		let settingsButton = app.buttons["feed-settings-button"]
		XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
		settingsButton.tap()
		XCTAssertTrue(
			app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5)
		)
	}

	private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication)
	{
		for _ in 0..<4 where element.exists && !element.isHittable {
			app.swipeUp()
		}
	}

	@MainActor
	func testLaunchShowsLoginScreen() throws {
		let app = XCUIApplication()
		app.launchArguments = ["UI_TEST_ROUTE_SIGNED_OUT"]
		app.launch()

		let loginScreen = app.descendants(matching: .any)["login-screen"]
		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-out"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(loginScreen.waitForExistence(timeout: 5))
	}

	@MainActor
	func testSignedInLaunchShowsFeed() throws {
		let app = launchSignedIn()

		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.buttons["feed-settings-button"].waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testLockedLaunchCanUnlockIntoFeed() throws {
		let app = XCUIApplication()
		app.launchArguments = ["UI_TEST_ROUTE_LOCKED"]
		app.launch()

		let unlockScreen = app.descendants(matching: .any)["unlock-screen"]
		XCTAssertTrue(
			app.staticTexts["ui-test-route-locked"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(unlockScreen.waitForExistence(timeout: 5))
		let unlockButton = app.descendants(matching: .any)["unlock-button"]
		XCTAssertTrue(unlockButton.waitForExistence(timeout: 5))

		unlockButton.tap()

		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.buttons["feed-settings-button"].waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testSignedInLaunchOpensSettingsFromFeed() throws {
		let app = launchSignedIn()

		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)

		openSettings(in: app)
		XCTAssertTrue(app.buttons["settings-sign-out-button"].exists)
	}

	@MainActor
	func testSignedInLaunchShowsFeedUploadEntryPoint() throws {
		let app = launchSignedIn()

		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.staticTexts["ui-feed-no-groups"].exists
				|| app.buttons["feed-upload-button"].waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testSignedInLaunchShowsFeedNoGroupsState() throws {
		let app = XCUIApplication()
		app.launchArguments = [
			"UI_TEST_ROUTE_SIGNED_IN", "UI_TEST_FORCE_EMPTY_GROUPS",
		]
		app.launch()

		let feedEmptyState = app.descendants(matching: .any)["feed-empty-state"]
		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.staticTexts["ui-feed-no-groups"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(feedEmptyState.waitForExistence(timeout: 5))
	}

	@MainActor
	func testSignedInLaunchHidesFeedActionButtonsWithoutGroups() throws {
		let app = XCUIApplication()
		app.launchArguments = [
			"UI_TEST_ROUTE_SIGNED_IN", "UI_TEST_FORCE_EMPTY_GROUPS",
		]
		app.launch()

		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.staticTexts["ui-feed-no-groups"].waitForExistence(timeout: 5)
		)
		XCTAssertFalse(app.buttons["feed-upload-button"].exists)
		XCTAssertFalse(app.buttons["feed-favourites-filter-button"].exists)
		XCTAssertTrue(app.buttons["feed-settings-button"].exists)
	}

	@MainActor
	func testSignedInLaunchShowsSettingsSections() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		XCTAssertTrue(app.staticTexts["ui-settings-profile-section"].exists)
		XCTAssertTrue(app.staticTexts["ui-settings-groups-section"].exists)
		XCTAssertTrue(app.staticTexts["ui-settings-subscription-section"].exists)
		XCTAssertTrue(app.buttons["settings-sign-out-button"].exists)
	}

	@MainActor
	func testSignedInLaunchShowsGroupsEmptyStateInSettings() throws {
		let app = XCUIApplication()
		app.launchArguments = [
			"UI_TEST_ROUTE_SIGNED_IN", "UI_TEST_FORCE_EMPTY_GROUPS",
		]
		app.launch()

		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-in"].waitForExistence(timeout: 5)
		)

		let settingsButton = app.buttons["feed-settings-button"]
		XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
		settingsButton.tap()

		XCTAssertTrue(
			app.staticTexts["ui-screen-settings"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(app.staticTexts["ui-settings-groups-section"].exists)
		XCTAssertTrue(
			app.buttons["groups-create-button"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(app.staticTexts["groups-empty-state"].exists)
	}

	@MainActor
	func testSignedInLaunchShowsGroupCreateMenuActions() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		let createButton = app.buttons["groups-create-button"]
		XCTAssertTrue(createButton.waitForExistence(timeout: 5))
		createButton.tap()

		XCTAssertTrue(
			app.buttons["groups-create-menu-action"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(app.buttons["groups-join-from-photo-menu-action"].exists)
		XCTAssertTrue(app.buttons["groups-scan-qr-menu-action"].exists)
	}

	@MainActor
	func testSignedInLaunchCanOpenCreateGroupPrompt() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		let createButton = app.buttons["groups-create-button"]
		XCTAssertTrue(createButton.waitForExistence(timeout: 5))
		createButton.tap()

		let createGroupAction = app.buttons["groups-create-menu-action"]
		XCTAssertTrue(createGroupAction.waitForExistence(timeout: 5))
		createGroupAction.tap()

		XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
		XCTAssertTrue(app.alerts.firstMatch.textFields.firstMatch.exists)
	}

	@MainActor
	func testSignedInLaunchShowsSubscriptionFreeState() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		XCTAssertTrue(
			app.staticTexts["ui-screen-subscription"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.staticTexts["ui-subscription-free"].waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testSignedInLaunchShowsSubscriptionEntryPoints() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		XCTAssertTrue(
			app.staticTexts["ui-screen-subscription"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.buttons["subscription-premium-card-button"].waitForExistence(
				timeout: 5
			)
		)
		XCTAssertTrue(app.buttons["subscription-restore-purchases-button"].exists)
	}

	@MainActor
	func testSignedInLaunchCanSwitchFeedGroup() throws {
		let app = launchSignedIn()

		let groupButton = app.buttons["feed-group-button"]
		XCTAssertTrue(groupButton.waitForExistence(timeout: 5))
		groupButton.tap()

		let friendsAction = app.buttons["feed-group-menu-ui-test-group-friends"]
		if friendsAction.waitForExistence(timeout: 2) {
			friendsAction.tap()
		} else {
			let fallbackFriendsAction = app.buttons["Friends"]
			XCTAssertTrue(fallbackFriendsAction.waitForExistence(timeout: 5))
			fallbackFriendsAction.tap()
		}

		XCTAssertTrue(
			app.staticTexts["ui-feed-no-photos"].waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testSignedInLaunchCanUseHashtagFilter() throws {
		let app = launchSignedIn()

		let hashtagButton = app.buttons["feed-hashtag-toggle-button"]
		XCTAssertTrue(hashtagButton.waitForExistence(timeout: 5))
		hashtagButton.tap()

		XCTAssertTrue(
			app.buttons["feed-hashtag-chip-winter"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(app.buttons["feed-hashtag-chip-all"].exists)
	}

	@MainActor
	func testSignedInLaunchCanToggleFavouritesFilter() throws {
		let app = launchSignedIn()

		let favouritesButton = app.buttons["feed-favourites-filter-button"]
		XCTAssertTrue(favouritesButton.waitForExistence(timeout: 5))
		favouritesButton.tap()

		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(favouritesButton.exists)
	}

	@MainActor
	func testSignedInLaunchShowsInlineAdWhenAdsFixtureIsEnabled() throws {
		let app = launchSignedIn(extraArguments: ["UI_TEST_SHOW_INLINE_ADS"])

		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.descendants(matching: .any)["feed-photo-tile-ui-test-photo-9"]
				.waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.descendants(matching: .any)["feed-inline-ad"].waitForExistence(
				timeout: 5
			)
		)
	}

	@MainActor
	func testPremiumSignedInLaunchHidesInlineAdWhenAdsFixtureIsEnabled() throws {
		let app = launchSignedIn(extraArguments: [
			"UI_TEST_SHOW_INLINE_ADS", "UI_TEST_PREMIUM",
		])

		XCTAssertTrue(
			app.staticTexts["ui-screen-feed"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.descendants(matching: .any)["feed-photo-tile-ui-test-photo-9"]
				.waitForExistence(timeout: 5)
		)
		XCTAssertFalse(
			app.descendants(matching: .any)["feed-inline-ad"].waitForExistence(
				timeout: 1
			)
		)
	}

	@MainActor
	func testSignedInLaunchCanOpenGroupMembersOverlay() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		let membersButton = app.buttons[
			"groups-members-button-ui-test-group-family"
		]
		XCTAssertTrue(membersButton.waitForExistence(timeout: 5))
		membersButton.tap()

		XCTAssertTrue(
			app.descendants(matching: .any)["groups-members-overlay"]
				.waitForExistence(timeout: 5)
		)
		XCTAssertTrue(app.buttons["groups-members-refresh-button"].exists)
	}

	@MainActor
	func testSignedInLaunchShowsDeleteAccountReauthentication() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		let deleteAccountButton = app.buttons["settings-delete-account-button"]
		XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 5))
		scrollToElement(deleteAccountButton, in: app)
		deleteAccountButton.tap()

		let alert = app.alerts.firstMatch
		XCTAssertTrue(alert.waitForExistence(timeout: 5))
		let confirmButton = alert.buttons["app-alert-confirm-button"].firstMatch
		XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
		confirmButton.tap()

		XCTAssertTrue(
			app.descendants(matching: .any)["delete-account-reauthentication-sheet"]
				.waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.descendants(matching: .any)["delete-account-reauthenticate-button"]
				.waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testSignedInLaunchShowsGoogleConnectionEntryPoint() throws {
		let app = launchSignedIn()

		openSettings(in: app)

		XCTAssertTrue(
			app.buttons["profile-google-connect-button"].waitForExistence(timeout: 5)
		)
	}

	@MainActor
	func testSignedInLaunchShowsPrivacyChoicesWhenRequired() throws {
		let app = launchSignedIn(extraArguments: [
			"UI_TEST_PRIVACY_CHOICES_REQUIRED"
		])

		openSettings(in: app)

		let privacyChoicesButton = app.buttons["settings-privacy-choices-button"]
		XCTAssertTrue(privacyChoicesButton.waitForExistence(timeout: 5))
		scrollToElement(privacyChoicesButton, in: app)
		privacyChoicesButton.tap()
		XCTAssertTrue(privacyChoicesButton.exists)
	}
}
