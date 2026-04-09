import Foundation
import Testing
@testable import Kuusi

struct InlineMessageTests {
    @Test
    func successFactoryUsesSuccessDefaults() {
        let message = InlineMessage.success("Saved")

        #expect(message.text == "Saved")
        if case .success = message.tone {
            #expect(Bool(true))
        } else {
            Issue.record("Expected success tone")
        }
        #expect(message.autoClearAfter == InlineMessage.successAutoClearInterval)
    }

    @Test
    func errorFactoryPreservesExplicitDelay() {
        let message = InlineMessage.error("Failed", autoClearAfter: 4)

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
        var currentMessage: InlineMessage? = InlineMessage.error("Failed")
        let task = InlineMessageAutoClear.schedule(
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
        let message = InlineMessage.error("Failed", autoClearAfter: 0.01)
        var currentMessage: InlineMessage? = message
        let task = InlineMessageAutoClear.schedule(
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
