import SwiftUI

struct FooterView: View {
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

            VStack(alignment: .leading, spacing: 10) {
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
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
