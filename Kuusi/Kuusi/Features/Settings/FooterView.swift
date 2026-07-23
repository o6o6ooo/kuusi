import SwiftUI

struct FooterView: View {
	@Environment(\.openURL) private var openURL

	var showsPrivacyChoices = false
	let onShowOnboarding: () -> Void
	let onPrivacyChoices: () -> Void
	let onDeleteAccount: () -> Void

	private let feedbackEmail = "hi@kuusi.app"
	private let feedbackSubject = "Kuusi Feedback"
	private let appStoreReviewURL = URL(
		string: "https://apps.apple.com/app/id6761270044?action=write-review"
	)!
	private let faqURL = URL(string: "https://kuusi.app/faq")!
	private let privacyPolicyURL = URL(string: "https://kuusi.app/privacy")!
	private let termsOfServiceURL = URL(string: "https://kuusi.app/terms")!
	private let authorURL = URL(string: "https://github.com/o6o6ooo")!

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Button(action: onDeleteAccount) {
				Text("settings.footer.delete_account")
					.appErrorTextLinkStyle()
			}
			.accessibilityIdentifier("settings-delete-account-button")

			Button(action: openFeedbackEmail) {
				Text("settings.footer.send_feedback")
					.appSecondaryTextLinkStyle()
			}
			.accessibilityIdentifier("settings-send-feedback-button")

			Link("settings.footer.rate_app", destination: appStoreReviewURL)
				.appSecondaryTextLinkStyle()
				.accessibilityIdentifier("settings-rate-app-link")

			Button(action: onShowOnboarding) {
				Text("settings.footer.show_onboarding")
					.appSecondaryTextLinkStyle()
			}
			.accessibilityIdentifier("settings-show-onboarding-button")

			if showsPrivacyChoices {
				Button(action: onPrivacyChoices) {
					Text("settings.footer.privacy_choices")
						.appSecondaryTextLinkStyle()
				}
				.accessibilityIdentifier("settings-privacy-choices-button")
			}

			Link("settings.footer.faq", destination: faqURL)
				.appSecondaryTextLinkStyle()

			Link("settings.footer.privacy_policy", destination: privacyPolicyURL)
				.appSecondaryTextLinkStyle()

			Link("settings.footer.terms_of_service", destination: termsOfServiceURL)
				.appSecondaryTextLinkStyle()

			HStack(spacing: 4) {
				Text("settings.footer.made_by")
					.appSecondaryTextLinkStyle()
				Link("Sakura Wallace", destination: authorURL)
					.appSecondaryTextLinkStyle()
					.foregroundStyle(Color.accentColor)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func openFeedbackEmail() {
		var components = URLComponents()
		components.scheme = "mailto"
		components.path = feedbackEmail
		components.queryItems = [
			URLQueryItem(name: "subject", value: feedbackSubject)
		]

		if let url = components.url {
			openURL(url)
		}
	}
}
