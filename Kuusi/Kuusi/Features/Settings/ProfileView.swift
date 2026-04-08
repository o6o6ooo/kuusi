import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: SettingsProfileViewModel
    let onPickEmoji: () -> Void

    private let avatarColours = [
        "#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#B7D7C9",
        "#F1C994", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E"
    ]

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var cardBorder: Color { AppTheme.cardBorder(for: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                if viewModel.isEditingName {
                    Text("Hi,")
                        .font(.title3.weight(.bold))
                    TextField("Name", text: $viewModel.name)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(primaryText)
                } else {
                    Text("Hi, \(viewModel.name)")
                        .font(.title3.weight(.bold))
                }

                Button {
                    viewModel.isEditingName.toggle()
                } label: {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Spacer()

                if let inlineMessage = viewModel.inlineMessage, inlineMessage.tone == .success {
                    InlineMessageView(message: inlineMessage)
                }

                Button("Save") {
                    Task {
                        await viewModel.saveProfile()
                    }
                }
                .buttonStyle(.appPrimaryCapsule)
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: onPickEmoji) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: viewModel.bgColour))
                                .frame(width: 84, height: 84)
                            Text(viewModel.icon.isEmpty ? "🌸" : viewModel.icon)
                                .font(.system(size: 42))
                        }
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 26, maximum: 36)), count: 5),
                        spacing: 10
                    ) {
                        ForEach(avatarColours, id: \.self) { colour in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    viewModel.bgColour = colour
                                }
                            } label: {
                                Circle()
                                    .fill(Color(hex: colour))
                                    .frame(width: 36, height: 36)
                                    .scaleEffect(viewModel.bgColour == colour ? 1.07 : 1.0)
                                    .overlay {
                                        if viewModel.bgColour == colour {
                                            Circle()
                                                .stroke(.black.opacity(0.16), lineWidth: 1.2)
                                        }
                                    }
                                    .shadow(
                                        color: .black.opacity(viewModel.bgColour == colour ? 0.12 : 0.05),
                                        radius: viewModel.bgColour == colour ? 5 : 2,
                                        x: 0,
                                        y: 1
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Photos")
                                .font(.subheadline.weight(.semibold))
                            Text(viewModel.isGoogleLinked ? "Connected as \(viewModel.googleLinkedEmail)" : "Not connected")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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

                    Text("Connect once to import photos from Google Photos without changing your Apple sign-in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if let inlineMessage = viewModel.inlineMessage, inlineMessage.tone == .error {
                InlineMessageView(message: inlineMessage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
