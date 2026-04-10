import Foundation
import Testing
@testable import Kuusi

struct ToastMessageTests {
    @Test
    func successFactoryUsesSuccessDefaults() {
        let message = ToastMessage.success("Saved")

        #expect(message.text == "Saved")
        if case .success = message.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected success tone")
        }
        #expect(message.autoClearAfter == ToastMessage.successAutoClearInterval)
    }

    @Test
    func errorFactoryPreservesExplicitDelay() {
        let message = ToastMessage.error("Failed", autoClearAfter: 4)

        #expect(message.text == "Failed")
        if case .error = message.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected error tone")
        }
        #expect(message.autoClearAfter == 4)
    }

    @Test
    @MainActor
    func autoClearSkipsMessagesWithoutDelay() async {
        var currentMessage: ToastMessage? = ToastMessage.error("Failed")
        let task = ToastMessageAutoClear.schedule(
            for: currentMessage,
            currentMessage: { currentMessage },
            clear: { currentMessage = nil }
        )

        #expect(task == nil)
        #expect(currentMessage?.text == "Failed")
    }

    @Test
    @MainActor
    func autoClearClearsMatchingMessageAfterDelay() async throws {
        let message = ToastMessage.error("Failed", autoClearAfter: 0.01)
        var currentMessage: ToastMessage? = message
        let task = ToastMessageAutoClear.schedule(
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
