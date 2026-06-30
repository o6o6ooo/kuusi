import XCTest

final class KuusiUITestsLaunchTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	@MainActor
	func testLaunchShowsSignedOutRoute() throws {
		let app = XCUIApplication()
		app.launchArguments = ["UI_TEST_ROUTE_SIGNED_OUT"]
		app.launch()

		XCTAssertTrue(
			app.staticTexts["ui-test-route-signed-out"].waitForExistence(timeout: 5)
		)
		XCTAssertTrue(
			app.descendants(matching: .any)["login-screen"].waitForExistence(
				timeout: 5
			)
		)
	}
}
