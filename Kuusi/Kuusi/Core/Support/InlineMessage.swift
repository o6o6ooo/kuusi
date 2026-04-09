import SwiftUI

struct InlineMessage: Equatable {
    static let defaultAutoClearInterval: TimeInterval = 2.5

    enum Tone: Equatable {
        case success
        case error
    }

    let text: String
    let tone: Tone
    let autoClearAfter: TimeInterval?

    static func success(_ text: String) -> Self {
        .init(text: text, tone: .success, autoClearAfter: defaultAutoClearInterval)
    }

    static func error(_ text: String, autoClearAfter: TimeInterval? = defaultAutoClearInterval) -> Self {
        .init(text: text, tone: .error, autoClearAfter: autoClearAfter)
    }
}

struct InlineMessageView: View {
    let message: InlineMessage

    var body: some View {
        Text(message.text)
            .font(.footnote)
            .foregroundStyle(message.tone == .error ? AppTheme.errorText : .secondary)
    }
}

enum InlineMessageAutoClear {
    @MainActor
    static func schedule(
        for message: InlineMessage?,
        currentMessage: @escaping @MainActor () -> InlineMessage?,
        clear: @escaping @MainActor () -> Void
    ) -> Task<Void, Never>? {
        guard let message, let delay = message.autoClearAfter else { return nil }

        return Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled, currentMessage() == message {
                clear()
            }
        }
    }
}
