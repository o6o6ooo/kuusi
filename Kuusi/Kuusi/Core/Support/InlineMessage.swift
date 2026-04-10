import Combine
import SwiftUI

struct InlineMessage: Equatable {
    static let defaultAutoClearInterval: TimeInterval = 2.5
    static let successAutoClearInterval: TimeInterval = defaultAutoClearInterval

    enum Tone: Equatable {
        case success
        case error
    }

    let id = UUID()
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

@MainActor
final class AppToastCenter: ObservableObject {
    @Published private(set) var currentMessage: InlineMessage?

    private var clearTask: Task<Void, Never>?

    deinit {
        clearTask?.cancel()
    }

    func present(_ message: InlineMessage, clearSource: (@MainActor @Sendable () -> Void)? = nil) {
        clearTask?.cancel()
        currentMessage = message
        clearTask = InlineMessageAutoClear.schedule(
            for: message,
            currentMessage: { [weak self] in
                self?.currentMessage
            },
            clear: { [weak self] in
                self?.currentMessage = nil
                clearSource?()
            }
        )
    }
}

private struct AppToastPresenterModifier: ViewModifier {
    @EnvironmentObject private var toastCenter: AppToastCenter

    let message: InlineMessage?
    let clear: @MainActor @Sendable () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let message else { return }
                toastCenter.present(message, clearSource: { @MainActor @Sendable in
                    clear()
                })
            }
            .onChange(of: message) { _, newValue in
                guard let newValue else { return }
                toastCenter.present(newValue, clearSource: { @MainActor @Sendable in
                    clear()
                })
            }
    }
}

private struct AppToastErrorPresenterModifier: ViewModifier {
    @EnvironmentObject private var toastCenter: AppToastCenter

    let text: String?
    let clear: @MainActor @Sendable () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard let text, !text.isEmpty else { return }
                toastCenter.present(.error(text), clearSource: { @MainActor @Sendable in
                    clear()
                })
            }
            .onChange(of: text) { _, newValue in
                guard let newValue, !newValue.isEmpty else { return }
                toastCenter.present(.error(newValue), clearSource: { @MainActor @Sendable in
                    clear()
                })
            }
    }
}

private struct AppToastHost: View {
    @EnvironmentObject private var toastCenter: AppToastCenter
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            if let message = toastCenter.currentMessage {
                HStack(spacing: 10) {
                    Image(systemName: message.tone.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(message.tone.symbolColor(for: colorScheme))

                    Text(message.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: min(max(proxy.size.width - 24, 0), 420))
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 18, x: 0, y: 10)
                .frame(maxWidth: .infinity)
                .padding(.top, max(proxy.safeAreaInsets.top, 10) + 8)
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: toastCenter.currentMessage)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum InlineMessageAutoClear {
    @MainActor
    static func schedule(
        for message: InlineMessage?,
        currentMessage: @escaping @MainActor () -> InlineMessage?,
        clear: @escaping @MainActor @Sendable () -> Void
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

private extension InlineMessage.Tone {
    var symbolName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    func symbolColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .success:
            return AppTheme.accent(for: colorScheme)
        case .error:
            return AppTheme.errorText
        }
    }
}

extension View {
    func appToastHost() -> some View {
        overlay(alignment: .top) {
            AppToastHost()
        }
    }

    func appToastMessage(
        _ message: InlineMessage?,
        clear: @escaping @MainActor @Sendable () -> Void = {}
    ) -> some View {
        modifier(AppToastPresenterModifier(message: message, clear: clear))
    }

    func appToastErrorMessage(
        _ text: String?,
        clear: @escaping @MainActor @Sendable () -> Void = {}
    ) -> some View {
        modifier(AppToastErrorPresenterModifier(text: text, clear: clear))
    }
}
