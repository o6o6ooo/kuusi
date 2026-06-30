import SwiftUI

struct AppAlert {
	enum Kind {
		case confirmation
		case prompt
	}

	enum ID {
		case deletePhotoConfirm
		case deleteAccountConfirm
		case removeGroupMemberConfirm(memberName: String)
		case createGroupPrompt
		case editGroupPrompt
		case editNamePrompt
		case destructiveGroupConfirm(
			title: String,
			message: String,
			confirmButtonTitle: String
		)

		var kind: Kind {
			switch self {
			case .deletePhotoConfirm, .deleteAccountConfirm,
				.removeGroupMemberConfirm, .destructiveGroupConfirm:
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

extension AppAlert.ID {
	fileprivate var title: String {
		switch self {
		case .deletePhotoConfirm:
			return String(localized: "alert.delete_photo.title")
		case .deleteAccountConfirm:
			return String(localized: "alert.delete_account.title")
		case .removeGroupMemberConfirm:
			return String(localized: "alert.remove_member.title")
		case .createGroupPrompt:
			return String(localized: "alert.create_group.title")
		case .editGroupPrompt:
			return String(localized: "alert.edit_group.title")
		case .editNamePrompt:
			return String(localized: "alert.edit_name.title")
		case .destructiveGroupConfirm(let title, _, _):
			return title
		}
	}

	fileprivate var message: String {
		switch self {
		case .deletePhotoConfirm:
			return String(localized: "alert.delete_photo.message")
		case .deleteAccountConfirm:
			return String(localized: "alert.delete_account.message")
		case .removeGroupMemberConfirm(let memberName):
			return String(
				format: String(localized: "alert.remove_member.message"),
				memberName
			)
		case .createGroupPrompt:
			return String(localized: "alert.create_group.message")
		case .editGroupPrompt:
			return String(localized: "alert.edit_group.message")
		case .editNamePrompt:
			return String(localized: "alert.edit_name.message")
		case .destructiveGroupConfirm(_, let message, _):
			return message
		}
	}

	fileprivate var confirmButtonTitle: String {
		switch self {
		case .deletePhotoConfirm:
			return String(localized: "alert.delete_photo.confirm")
		case .deleteAccountConfirm:
			return String(localized: "alert.delete_account.confirm")
		case .removeGroupMemberConfirm:
			return String(localized: "alert.remove_member.confirm")
		case .createGroupPrompt:
			return String(localized: "alert.create_group.confirm")
		case .editGroupPrompt:
			return String(localized: "common.save")
		case .editNamePrompt:
			return String(localized: "common.ok")
		case .destructiveGroupConfirm(_, _, let confirmButtonTitle):
			return confirmButtonTitle
		}
	}

	fileprivate var cancelButtonTitle: String {
		String(localized: "common.cancel")
	}

	fileprivate var confirmButtonRole: ButtonRole? {
		switch self {
		case .deletePhotoConfirm, .deleteAccountConfirm, .removeGroupMemberConfirm,
			.destructiveGroupConfirm:
			return .destructive
		case .createGroupPrompt, .editGroupPrompt, .editNamePrompt:
			return nil
		}
	}

	fileprivate var textFieldTitle: String? {
		switch self {
		case .createGroupPrompt, .editGroupPrompt:
			return String(localized: "alert.group_name.placeholder")
		case .editNamePrompt:
			return String(localized: "alert.name.placeholder")
		case .deletePhotoConfirm, .deleteAccountConfirm, .removeGroupMemberConfirm,
			.destructiveGroupConfirm:
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
				.accessibilityIdentifier("app-alert-cancel-button")
				Button(alert.id.confirmButtonTitle, role: alert.id.confirmButtonRole) {
					confirm(alert)
				}
				.accessibilityIdentifier("app-alert-confirm-button")
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
				.accessibilityIdentifier("app-alert-cancel-button")
				Button(alert.id.confirmButtonTitle) {
					confirm(alert)
				}
				.accessibilityIdentifier("app-alert-confirm-button")
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
