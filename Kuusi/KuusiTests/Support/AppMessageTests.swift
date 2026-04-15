import Foundation
import Testing
@testable import Kuusi

struct AppMessageTests {
    @Test
    func profileUpdatedBuildsSuccessMessage() {
        let message = AppMessage(.profileUpdated, .success)

        #expect(message.text == "Profile updated")
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

        #expect(message.text == "Failed to delete photo")
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

        #expect(message.text == "3 photos imported from Google Photos")
        if case .success = message.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected success tone")
        }
    }

    @Test
    func storageLimitReachedBuildsErrorMessage() {
        let message = AppMessage(.storageLimitReached, .error)

        #expect(message.text == "You've reached your storage limit")
        if case .error = message.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected error tone")
        }
    }

    @Test
    @MainActor
    func autoClearSkipsMessagesWithoutDelay() async {
        var currentMessage: AppMessage? = AppMessage(.failedToDeletePhoto, .error, autoClearAfter: nil)
        let task = AppMessageAutoClear.schedule(
            for: currentMessage,
            currentMessage: { currentMessage },
            clear: { currentMessage = nil }
        )

        #expect(task == nil)
        #expect(currentMessage?.text == "Failed to delete photo")
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

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(task != nil)
        #expect(currentMessage == nil)
        task?.cancel()
    }
}
