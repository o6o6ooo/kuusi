import Combine
import SwiftUI

struct ToastMessage: Equatable {
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
    @Published private(set) var currentMessage: ToastMessage?

    private var clearTask: Task<Void, Never>?
    private var hostOrder: [UUID] = []

    deinit {
        clearTask?.cancel()
    }

    func present(_ message: ToastMessage, clearSource: (@MainActor @Sendable () -> Void)? = nil) {
        clearTask?.cancel()
        currentMessage = message
        clearTask = ToastMessageAutoClear.schedule(
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

    func registerHost(_ id: UUID) {
        hostOrder.removeAll { $0 == id }
        hostOrder.append(id)
        objectWillChange.send()
    }

    func unregisterHost(_ id: UUID) {
        hostOrder.removeAll { $0 == id }
        objectWillChange.send()
    }

    func isActiveHost(_ id: UUID) -> Bool {
        hostOrder.last == id
    }
}

private struct AppToastPresenterModifier: ViewModifier {
    @EnvironmentObject private var toastCenter: AppToastCenter

    let message: ToastMessage?
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

private struct AppToastHost: View {
    @EnvironmentObject private var toastCenter: AppToastCenter
    @Environment(\.colorScheme) private var colorScheme
    @State private var hostID = UUID()

    var body: some View {
        GeometryReader { proxy in
            if toastCenter.isActiveHost(hostID), let message = toastCenter.currentMessage {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10) + 8)
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: toastCenter.currentMessage)
        .onAppear {
            toastCenter.registerHost(hostID)
        }
        .onDisappear {
            toastCenter.unregisterHost(hostID)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum ToastMessageAutoClear {
    @MainActor
    static func schedule(
        for message: ToastMessage?,
        currentMessage: @escaping @MainActor () -> ToastMessage?,
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

private extension ToastMessage.Tone {
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
        overlay(alignment: .bottom) {
            AppToastHost()
        }
    }

    func appToastMessage(
        _ message: ToastMessage?,
        clear: @escaping @MainActor @Sendable () -> Void = {}
    ) -> some View {
        modifier(AppToastPresenterModifier(message: message, clear: clear))
    }
}
