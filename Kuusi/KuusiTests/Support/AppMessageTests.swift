import Foundation
import Testing

@testable import Kuusi

struct AppMessageTests {
	@Test
	func profileUpdatedBuildsSuccessMessage() {
		let message = AppMessage(.profileUpdated, .success)

		guard case .profileUpdated = message.id else {
			Issue.record("Expected profileUpdated message id")
			return
		}
		if case .success = message.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected success tone")
		}
		#expect(message.autoClearAfter == AppMessage.defaultAutoClearInterval)
	}

	@Test
	func failedToDeletePhotoBuildsErrorMessage() {
		let message = AppMessage(.failedToDeletePhoto, .error)

		guard case .failedToDeletePhoto = message.id else {
			Issue.record("Expected failedToDeletePhoto message id")
			return
		}
		if case .error = message.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error tone")
		}
		#expect(message.autoClearAfter == AppMessage.defaultAutoClearInterval)
	}

	@Test
	func photosImportedFromGooglePhotosBuildsInterpolatedText() {
		let message = AppMessage(.photosImportedFromGooglePhotos(3), .success)

		guard case .photosImportedFromGooglePhotos(let count) = message.id else {
			Issue.record("Expected photosImportedFromGooglePhotos message id")
			return
		}
		#expect(count == 3)
		if case .success = message.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected success tone")
		}
	}

	@Test
	func storageLimitReachedBuildsErrorMessage() {
		let message = AppMessage(.storageLimitReached, .error)

		guard case .storageLimitReached = message.id else {
			Issue.record("Expected storageLimitReached message id")
			return
		}
		if case .error = message.tone {
			#expect(Bool(true))
		} else {
			Issue.record("Expected error tone")
		}
	}

	@Test
	@MainActor
	func autoClearSkipsMessagesWithoutDelay() async {
		var currentMessage: AppMessage? = AppMessage(
			.failedToDeletePhoto,
			.error,
			autoClearAfter: nil
		)
		let task = AppMessageAutoClear.schedule(
			for: currentMessage,
			currentMessage: { currentMessage },
			clear: { currentMessage = nil }
		)

		#expect(task == nil)
		guard case .failedToDeletePhoto = currentMessage?.id else {
			Issue.record("Expected failedToDeletePhoto message id")
			return
		}
	}

	@Test
	@MainActor
	func autoClearClearsMatchingMessageAfterDelay() async throws {
		let message = AppMessage(.failedToDeletePhoto, .error, autoClearAfter: 0.01)
		var currentMessage: AppMessage? = message
		let task = AppMessageAutoClear.schedule(
			for: message,
			currentMessage: { currentMessage },
			clear: { currentMessage = nil }
		)

		for _ in 0..<20 where currentMessage != nil {
			try await Task.sleep(nanoseconds: 50_000_000)
		}

		#expect(task != nil)
		if currentMessage != nil {
			Issue.record("Expected current message to clear")
		}
		task?.cancel()
	}
}
