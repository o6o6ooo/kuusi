import SwiftUI

struct FooterView: View {
    var showsPrivacyChoices = false
    let onPrivacyChoices: () -> Void
    let onDeleteAccount: () -> Void

    private let faqURL = URL(string: "https://getkuusi.vercel.app/faq")!
    private let privacyPolicyURL = URL(string: "https://getkuusi.vercel.app/privacy")!
    private let termsOfServiceURL = URL(string: "https://getkuusi.vercel.app/terms")!
    private let authorURL = URL(string: "https://github.com/o6o6ooo")!

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onDeleteAccount) {
                Text("Delete account")
                    .appErrorTextLinkStyle()
            }
            .accessibilityIdentifier("settings-delete-account-button")

            if showsPrivacyChoices {
                Button(action: onPrivacyChoices) {
                    Text("Privacy choices")
                        .appSecondaryTextLinkStyle()
                }
                .accessibilityIdentifier("settings-privacy-choices-button")
            }

            Link("FAQ", destination: faqURL)
                .appSecondaryTextLinkStyle()

            Link("Privacy policy", destination: privacyPolicyURL)
                .appSecondaryTextLinkStyle()

            Link("Terms of service", destination: termsOfServiceURL)
                .appSecondaryTextLinkStyle()

            HStack(spacing: 4) {
                Text("Made with love by")
                    .appSecondaryTextLinkStyle()
                Link("Sakura Wallace", destination: authorURL)
                    .appSecondaryTextLinkStyle()
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
