import SwiftUI

struct FooterView: View {
    let onDeleteAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onDeleteAccount) {
                Text("Delete account")
                    .appErrorTextLinkStyle()
            }
            .accessibilityIdentifier("settings-delete-account-button")

            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy policy")
                    .appSecondaryTextLinkStyle()

                Text("Terms of service")
                    .appSecondaryTextLinkStyle()

                HStack(spacing: 4) {
                    Text("Made with love by")
                        .appSecondaryTextLinkStyle()
                    Link("Sakura Wallace", destination: URL(string: "https://github.com/o6o6ooo")!)
                        .appSecondaryTextLinkStyle()
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
