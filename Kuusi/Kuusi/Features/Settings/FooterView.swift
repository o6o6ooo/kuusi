import SwiftUI

struct FooterView: View {
    var showsPrivacyChoices = false
    let onPrivacyChoices: () -> Void
    let onDeleteAccount: () -> Void

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
}
