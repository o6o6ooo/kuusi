import SwiftUI

struct AppAlert {
    enum Kind {
        case confirmation
        case prompt
    }

    enum ID {
        case deletePhotoConfirm
        case deleteAccountConfirm
        case createGroupPrompt
        case editGroupPrompt
        case editNamePrompt
        case destructiveGroupConfirm(title: String, message: String, confirmButtonTitle: String)

        var kind: Kind {
            switch self {
            case .deletePhotoConfirm, .deleteAccountConfirm, .destructiveGroupConfirm:
                return .confirmation
            case .createGroupPrompt, .editGroupPrompt, .editNamePrompt:
                return .prompt
            }
        }
    }

    let id: ID
    let text: Binding<String>?
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?

    init(
        _ id: ID,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.id = id
        self.text = nil
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    init(
        _ id: ID,
        text: Binding<String>,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.id = id
        self.text = text
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
}

private extension AppAlert.ID {
    var title: String {
        switch self {
        case .deletePhotoConfirm:
            return "Delete photo?"
        case .deleteAccountConfirm:
            return "Delete account?"
        case .createGroupPrompt:
            return "Create Group"
        case .editGroupPrompt:
            return "Edit Group"
        case .editNamePrompt:
            return "Edit Name"
        case let .destructiveGroupConfirm(title, _, _):
            return title
        }
    }

    var message: String {
        switch self {
        case .deletePhotoConfirm:
            return "This will permanently delete the photo."
        case .deleteAccountConfirm:
            return "This will permanently delete your account, your photos, and any groups you created."
        case .createGroupPrompt:
            return "Enter a name for the new group."
        case .editGroupPrompt:
            return "Enter a new group name."
        case .editNamePrompt:
            return "Enter your display name."
        case let .destructiveGroupConfirm(_, message, _):
            return message
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .deletePhotoConfirm:
            return "Delete"
        case .deleteAccountConfirm:
            return "Delete account"
        case .createGroupPrompt:
            return "Create"
        case .editGroupPrompt:
            return "Save"
        case .editNamePrompt:
            return "OK"
        case let .destructiveGroupConfirm(_, _, confirmButtonTitle):
            return confirmButtonTitle
        }
    }

    var cancelButtonTitle: String {
        "Cancel"
    }

    var confirmButtonRole: ButtonRole? {
        switch self {
        case .deletePhotoConfirm, .deleteAccountConfirm, .destructiveGroupConfirm:
            return .destructive
        case .createGroupPrompt, .editGroupPrompt, .editNamePrompt:
            return nil
        }
    }

    var textFieldTitle: String? {
        switch self {
        case .createGroupPrompt, .editGroupPrompt:
            return "Group name"
        case .editNamePrompt:
            return "Name"
        case .deletePhotoConfirm, .deleteAccountConfirm, .destructiveGroupConfirm:
            return nil
        }
    }
}

private struct AppAlertModifier: ViewModifier {
    @Binding var alert: AppAlert?
    @State private var suppressCancel = false

    func body(content: Content) -> some View {
        content
            .alert(
                confirmationTitle,
                isPresented: confirmationPresented,
                presenting: confirmationAlert
            ) { alert in
                Button(alert.id.cancelButtonTitle, role: .cancel) {
                    dismissCurrentAlert()
                }
                Button(alert.id.confirmButtonTitle, role: alert.id.confirmButtonRole) {
                    confirm(alert)
                }
            } message: { alert in
                Text(alert.id.message)
            }
            .alert(
                promptTitle,
                isPresented: promptPresented,
                presenting: promptAlert
            ) { alert in
                if let text = alert.text, let textFieldTitle = alert.id.textFieldTitle {
                    TextField(textFieldTitle, text: text)
                }
                Button(alert.id.cancelButtonTitle, role: .cancel) {
                    dismissCurrentAlert()
                }
                Button(alert.id.confirmButtonTitle) {
                    confirm(alert)
                }
            } message: { alert in
                Text(alert.id.message)
            }
    }

    private var confirmationAlert: AppAlert? {
        guard alert?.id.kind == .confirmation else { return nil }
        return alert
    }

    private var promptAlert: AppAlert? {
        guard alert?.id.kind == .prompt else { return nil }
        return alert
    }

    private var confirmationTitle: String {
        confirmationAlert?.id.title ?? ""
    }

    private var promptTitle: String {
        promptAlert?.id.title ?? ""
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { confirmationAlert != nil },
            set: { isPresented in
                guard !isPresented else { return }
                dismissCurrentAlert()
            }
        )
    }

    private var promptPresented: Binding<Bool> {
        Binding(
            get: { promptAlert != nil },
            set: { isPresented in
                guard !isPresented else { return }
                dismissCurrentAlert()
            }
        )
    }

    private func confirm(_ currentAlert: AppAlert) {
        suppressCancel = true
        alert = nil
        currentAlert.onConfirm()
    }

    private func dismissCurrentAlert() {
        let currentAlert = alert
        alert = nil

        if suppressCancel {
            suppressCancel = false
            return
        }

        currentAlert?.onCancel?()
    }
}

extension View {
    func appAlert(_ alert: Binding<AppAlert?>) -> some View {
        modifier(AppAlertModifier(alert: alert))
    }
}
