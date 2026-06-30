import FirebaseAuth
import Testing
import UIKit

@testable import Kuusi

@MainActor
struct SettingsProfileViewModelTests {
	@Test
	func loadProfilePopulatesFieldsFromFetchedUser() async {
		let userService = UserServiceSpy()
		userService.fetchedUser = AppUser(
			id: "user-1",
			name: "Sakura",
			icon: "🌲",
			bgColour: "#123456",
			usageMB: 42.5,
			groups: []
		)
		let googleService = GoogleAccountServiceSpy()
		googleService.linkedAccount = GoogleLinkedAccount(
			email: "linked@example.com",
			isLinked: true
		)
		let viewModel = makeViewModel(
			userService: userService,
			googleAccountService: googleService
		)

		await viewModel.loadProfile()

		#expect(viewModel.name == "Sakura")
		#expect(viewModel.icon == "🌲")
		#expect(viewModel.bgColour == "#123456")
		#expect(viewModel.usageMB == 42.5)
		#expect(viewModel.googleLinkedEmail == "linked@example.com")
		#expect(viewModel.isGoogleLinked == true)
	}

	@Test
	func loadProfileShowsErrorMessageWhenFetchFails() async {
		let userService = UserServiceSpy()
		userService.fetchError = NSError(domain: "Tests", code: 1)
		let viewModel = makeViewModel(userService: userService)

		await viewModel.loadProfile()

		#expect(viewModel.toastMessage?.id == .failedToLoadProfile)
		if case .error = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error inline message")
		}
	}

	@Test
	func saveProfileRejectsEmptyTrimmedName() async {
		let userService = UserServiceSpy()
		let viewModel = makeViewModel(userService: userService)
		viewModel.name = "   "
		viewModel.icon = "🌲"

		await viewModel.saveProfile()

		#expect(userService.updateCalls.isEmpty)
		#expect(viewModel.toastMessage?.id == .nameCannotBeEmpty)
		if case .error = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error inline message")
		}
	}

	@Test
	func saveProfileTrimsValuesAndKeepsBlankIconWhenBlank() async {
		let userService = UserServiceSpy()
		let viewModel = makeViewModel(userService: userService)
		viewModel.usageMB = 12.5
		viewModel.name = "  Sakura  "
		viewModel.icon = "   "
		viewModel.bgColour = "#abcdef"

		await viewModel.saveProfile()

		#expect(userService.updateCalls.count == 1)
		#expect(userService.updateCalls.first?.uid == "user-1")
		#expect(userService.updateCalls.first?.name == "Sakura")
		#expect(userService.updateCalls.first?.icon == "")
		#expect(userService.updateCalls.first?.bgColour == "#abcdef")
		#expect(userService.cacheUserProfileCalls.count == 1)
		#expect(userService.cacheUserProfileCalls.first?.uid == "user-1")
		#expect(userService.cacheUserProfileCalls.first?.name == "Sakura")
		#expect(userService.cacheUserProfileCalls.first?.usageMB == 12.5)
		#expect(viewModel.toastMessage?.id == .profileUpdated)
		if case .success = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected success inline message")
		}
	}

	@Test
	func saveProfileShowsErrorWhenUpdateFails() async {
		let userService = UserServiceSpy()
		userService.updateError = NSError(domain: "Tests", code: 2)
		let viewModel = makeViewModel(userService: userService)
		viewModel.name = "Sakura"
		viewModel.icon = "🌲"

		await viewModel.saveProfile()

		#expect(viewModel.toastMessage?.id == .failedToSaveProfile)
		if case .error = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error inline message")
		}
	}

	@Test
	func addUploadedUsageUpdatesUsageAndCachesProfile() {
		let userService = UserServiceSpy()
		let viewModel = makeViewModel(userService: userService)
		viewModel.name = "Sakura"
		viewModel.icon = "🌲"
		viewModel.bgColour = "#123456"
		viewModel.usageMB = 10

		viewModel.addUploadedUsage(2.5)

		#expect(viewModel.usageMB == 12.5)
		#expect(userService.cacheUserProfileCalls.count == 1)
		#expect(userService.cacheUserProfileCalls.first?.uid == "user-1")
		#expect(userService.cacheUserProfileCalls.first?.name == "Sakura")
		#expect(userService.cacheUserProfileCalls.first?.icon == "🌲")
		#expect(userService.cacheUserProfileCalls.first?.bgColour == "#123456")
		#expect(userService.cacheUserProfileCalls.first?.usageMB == 12.5)
	}

	@Test
	func clearToastMessageResetsMessage() {
		let viewModel = makeViewModel()
		viewModel.toastMessage = AppMessage(.profileUpdated, .success)

		viewModel.clearToastMessage()

		#expect(viewModel.toastMessage == nil)
	}

	@Test
	func connectGoogleAccountShowsErrorWithoutPresentingController() async {
		let googleService = GoogleAccountServiceSpy()
		let viewModel = makeViewModel(
			googleAccountService: googleService,
			topViewControllerProvider: { nil }
		)

		await viewModel.connectGoogleAccount()

		#expect(googleService.connectCallCount == 0)
		#expect(viewModel.toastMessage?.id == .couldNotOpenGoogleSignIn)
	}

	@Test
	func connectGoogleAccountUpdatesLinkedStateOnSuccess() async {
		let googleService = GoogleAccountServiceSpy()
		googleService.connectResult = GoogleLinkedAccount(
			email: "connected@example.com",
			isLinked: true
		)
		let viewModel = makeViewModel(googleAccountService: googleService)

		await viewModel.connectGoogleAccount()

		#expect(googleService.connectCallCount == 1)
		#expect(viewModel.googleLinkedEmail == "connected@example.com")
		#expect(viewModel.isGoogleLinked == true)
		#expect(viewModel.isGoogleAccountActionInFlight == false)
		#expect(viewModel.toastMessage?.id == .googleAccountConnected)
		if case .success = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected success inline message")
		}
	}

	@Test
	func connectGoogleAccountMapsGoogleAccountErrors() async {
		let cases: [(GoogleAccountError, AppMessage.ID)] = [
			(.missingFirebaseUser, .pleaseSignInFirst),
			(.missingClientID, .googleSignInNotConfigured),
			(.missingGoogleIDToken, .googleSignInReturnedInvalidToken),
			(.missingGoogleEmail, .googleSignInReturnedIncompleteAccount),
			(.noLinkedGoogleAccount, .noLinkedGoogleAccount),
			(
				.mismatchedLinkedAccount(
					expected: "old@example.com",
					actual: "new@example.com"
				), .googleAccountMismatch
			),
		]

		for (error, expectedMessageID) in cases {
			let googleService = GoogleAccountServiceSpy()
			googleService.connectError = error
			let viewModel = makeViewModel(googleAccountService: googleService)

			await viewModel.connectGoogleAccount()

			#expect(googleService.connectCallCount == 1)
			#expect(viewModel.googleLinkedEmail.isEmpty)
			#expect(viewModel.isGoogleLinked == false)
			#expect(viewModel.isGoogleAccountActionInFlight == false)
			#expect(viewModel.toastMessage?.id == expectedMessageID)
			if case .error = viewModel.toastMessage?.tone {
				#expect(Bool(true))
			} else {
				Issue.record("Expected error inline message")
			}
		}
	}

	@Test
	func disconnectGoogleAccountClearsLinkedStateOnSuccess() async {
		let googleService = GoogleAccountServiceSpy()
		let viewModel = makeViewModel(googleAccountService: googleService)
		viewModel.googleLinkedEmail = "linked@example.com"
		viewModel.isGoogleLinked = true

		await viewModel.disconnectGoogleAccount()

		#expect(googleService.disconnectCallCount == 1)
		#expect(viewModel.googleLinkedEmail.isEmpty)
		#expect(viewModel.isGoogleLinked == false)
		#expect(viewModel.toastMessage?.id == .googleAccountDisconnected)
	}

	@Test
	func disconnectGoogleAccountMapsGoogleAccountError() async {
		let googleService = GoogleAccountServiceSpy()
		googleService.disconnectError = GoogleAccountError.noLinkedGoogleAccount
		let viewModel = makeViewModel(googleAccountService: googleService)
		viewModel.googleLinkedEmail = "linked@example.com"
		viewModel.isGoogleLinked = true

		await viewModel.disconnectGoogleAccount()

		#expect(googleService.disconnectCallCount == 1)
		#expect(viewModel.googleLinkedEmail == "linked@example.com")
		#expect(viewModel.isGoogleLinked == true)
		#expect(viewModel.isGoogleAccountActionInFlight == false)
		#expect(viewModel.toastMessage?.id == .noLinkedGoogleAccount)
		if case .error = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error inline message")
		}
	}

	@Test
	func disconnectGoogleAccountShowsGenericErrorWhenDisconnectFails() async {
		let googleService = GoogleAccountServiceSpy()
		googleService.disconnectError = NSError(domain: "Tests", code: 3)
		let viewModel = makeViewModel(googleAccountService: googleService)
		viewModel.googleLinkedEmail = "linked@example.com"
		viewModel.isGoogleLinked = true

		await viewModel.disconnectGoogleAccount()

		#expect(googleService.disconnectCallCount == 1)
		#expect(viewModel.googleLinkedEmail == "linked@example.com")
		#expect(viewModel.isGoogleLinked == true)
		#expect(viewModel.isGoogleAccountActionInFlight == false)
		#expect(viewModel.toastMessage?.id == .failedToDisconnectGoogleAccount)
		if case .error = viewModel.toastMessage?.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error inline message")
		}
	}

	@Test
	func saveProfileDoesNothingWhenSignedOut() async {
		let userService = UserServiceSpy()
		let viewModel = makeViewModel(
			userService: userService,
			currentUserIDProvider: { nil }
		)
		viewModel.name = "Sakura"
		viewModel.icon = "🌲"
		viewModel.bgColour = "#123456"

		await viewModel.saveProfile()

		#expect(userService.updateCalls.isEmpty)
		#expect(userService.cacheUserProfileCalls.isEmpty)
		#expect(viewModel.toastMessage == nil)
	}

	@Test
	func addUploadedUsageDoesNothingWhenSignedOut() {
		let userService = UserServiceSpy()
		let viewModel = makeViewModel(
			userService: userService,
			currentUserIDProvider: { nil }
		)
		viewModel.usageMB = 10

		viewModel.addUploadedUsage(2.5)

		#expect(viewModel.usageMB == 10)
		#expect(userService.cacheUserProfileCalls.isEmpty)
	}

	private func makeViewModel(
		userService: SettingsProfileUserServicing = UserServiceSpy(),
		googleAccountService: SettingsProfileGoogleAccountServicing =
			GoogleAccountServiceSpy(),
		currentUserIDProvider: @escaping @MainActor () -> String? = { "user-1" },
		topViewControllerProvider: @escaping @MainActor () -> UIViewController? = {
			UIViewController()
		}
	) -> SettingsProfileViewModel {
		SettingsProfileViewModel(
			userService: userService,
			googleAccountService: googleAccountService,
			currentUserIDProvider: currentUserIDProvider,
			linkedAccountProvider: {
				googleAccountService.currentLinkedAccount(for: nil)
			},
			topViewControllerProvider: topViewControllerProvider
		)
	}
}

private final class UserServiceSpy: SettingsProfileUserServicing {
	struct UpdateCall {
		let uid: String
		let name: String
		let icon: String
		let bgColour: String
	}

	struct CacheUserProfileCall {
		let uid: String
		let name: String
		let icon: String
		let bgColour: String
		let usageMB: Double
	}

	var fetchedUser: AppUser?
	var fetchError: Error?
	var updateError: Error?
	var updateCalls: [UpdateCall] = []
	var cacheUserProfileCalls: [CacheUserProfileCall] = []

	func fetchCachedUser(uid: String) async throws -> AppUser? {
		if let fetchError {
			throw fetchError
		}
		return fetchedUser
	}

	func updateProfile(uid: String, name: String, icon: String, bgColour: String)
		async throws
	{
		if let updateError {
			throw updateError
		}
		updateCalls.append(
			.init(uid: uid, name: name, icon: icon, bgColour: bgColour)
		)
	}

	func cacheUserProfile(
		uid: String,
		name: String,
		icon: String,
		bgColour: String,
		usageMB: Double
	) {
		cacheUserProfileCalls.append(
			.init(
				uid: uid,
				name: name,
				icon: icon,
				bgColour: bgColour,
				usageMB: usageMB
			)
		)
	}
}

private final class GoogleAccountServiceSpy:
	SettingsProfileGoogleAccountServicing
{
	var linkedAccount = GoogleLinkedAccount(email: "", isLinked: false)
	var connectResult = GoogleLinkedAccount(
		email: "linked@example.com",
		isLinked: true
	)
	var connectError: Error?
	var disconnectError: Error?
	var connectCallCount = 0
	var disconnectCallCount = 0

	func currentLinkedAccount(for user: User?) -> GoogleLinkedAccount {
		linkedAccount
	}

	func connectCurrentUser(presentingViewController: UIViewController)
		async throws -> GoogleLinkedAccount
	{
		connectCallCount += 1
		if let connectError {
			throw connectError
		}
		return connectResult
	}

	func disconnectCurrentUser() async throws {
		disconnectCallCount += 1
		if let disconnectError {
			throw disconnectError
		}
	}
}
