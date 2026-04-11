import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: SettingsProfileViewModel
    let onEditName: () -> Void
    let onEditIcon: () -> Void
    let onEditBackground: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                Menu {
                    Button("Edit name", systemImage: "pencil") {
                        onEditName()
                    }

                    Button("Edit icon", systemImage: "face.smiling") {
                        onEditIcon()
                    }

                    Button("Edit background", systemImage: "paintpalette") {
                        onEditBackground()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: viewModel.bgColour))
                            .frame(width: 112, height: 112)

                        Text(viewModel.icon)
                            .font(.system(size: 58))
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Text(viewModel.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Button(action: onSignOut) {
                    Text("Sign out")
                        .appTextLinkStyle()
                }
                .accessibilityIdentifier("settings-sign-out-button")
            }

            googlePhotosSection
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var googlePhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Google Photos")
                .font(.title3.weight(.bold))

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isGoogleLinked ? "Connected as \(viewModel.googleLinkedEmail)" : "Not connected")
                        .font(.subheadline.weight(.semibold))

                    if !viewModel.isGoogleLinked {
                        Text("Connect to your Google account to import photos from Google Photos.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if viewModel.isGoogleAccountActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                } else if viewModel.isGoogleLinked {
                    Button("Disconnect") {
                        Task {
                            await viewModel.disconnectGoogleAccount()
                        }
                    }
                        .buttonStyle(.appPrimaryCapsule)
                        .controlSize(.small)
                } else {
                    Button("Connect") {
                        Task {
                            await viewModel.connectGoogleAccount()
                        }
                    }
                        .buttonStyle(.appPrimaryCapsule)
                        .controlSize(.small)
                }
            }
        }
    }
}
