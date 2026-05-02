import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: SettingsProfileViewModel
    let onSignOut: () -> Void

    @State private var appAlert: AppAlert?
    @State private var pendingName = ""
    @State private var isEmojiPickerPresented = false
    @State private var isBackgroundPickerPresented = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                Menu {
                    Button("profile.menu.edit_name", systemImage: "pencil") {
                        pendingName = viewModel.name
                        appAlert = AppAlert(.editNamePrompt, text: $pendingName) {
                            let updatedName = pendingName
                            Task {
                                await viewModel.saveProfile(
                                    name: updatedName,
                                    icon: viewModel.icon,
                                    bgColour: viewModel.bgColour
                                )
                            }
                        }
                    }

                    Button("profile.menu.edit_icon", systemImage: "face.smiling") {
                        isEmojiPickerPresented = true
                    }

                    Button("profile.menu.edit_background", systemImage: "paintpalette") {
                        isBackgroundPickerPresented = true
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
                    Text("profile.sign_out")
                        .appTextLinkStyle()
                }
                .accessibilityIdentifier("settings-sign-out-button")
            }

            googlePhotosSection
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .sheet(isPresented: $isEmojiPickerPresented) {
            EmojiPickerSheet(
                selectedEmoji: Binding(
                    get: { viewModel.icon },
                    set: { newValue in
                        Task {
                            await viewModel.saveProfile(
                                name: viewModel.name,
                                icon: newValue,
                                bgColour: viewModel.bgColour
                            )
                        }
                    }
                )
            )
        }
        .sheet(isPresented: $isBackgroundPickerPresented) {
            BackgroundColorPickerSheet(selectedColour: viewModel.bgColour) { colour in
                Task {
                    await viewModel.saveProfile(
                        name: viewModel.name,
                        icon: viewModel.icon,
                        bgColour: colour
                    )
                }
            }
        }
        .appAlert($appAlert)
    }

    private var googlePhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.google_photos.title")
                .font(.title3.weight(.bold))

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isGoogleLinked ? String(format: String(localized: "profile.google_photos.connected_as"), viewModel.googleLinkedEmail) : String(localized: "profile.google_photos.not_connected"))
                        .font(.subheadline.weight(.semibold))

                    if !viewModel.isGoogleLinked {
                        Text("profile.google_photos.connect_description")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if viewModel.isGoogleAccountActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                } else if viewModel.isGoogleLinked {
                    Button("profile.google_photos.disconnect") {
                        Task {
                            await viewModel.disconnectGoogleAccount()
                        }
                    }
                    .buttonStyle(.appPrimaryCapsule)
                    .controlSize(.small)
                } else {
                    Button("profile.google_photos.connect") {
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
