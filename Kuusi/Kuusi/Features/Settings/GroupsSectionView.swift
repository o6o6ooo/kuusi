import SwiftUI

struct GroupsSectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: SettingsGroupsViewModel

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var memberBorderColor: Color { AppTheme.cardBorder(for: colorScheme) }

    private var createStatusTextColor: Color {
        viewModel.isCreateError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }

    private var saveStatusTextColor: Color {
        viewModel.isSaveError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }

    private var canCreate: Bool {
        !viewModel.isCreating && !viewModel.createGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedGroup: GroupSummary? {
        guard let selectedGroupID = viewModel.selectedGroupID else { return nil }
        return viewModel.groups.first(where: { $0.id == selectedGroupID })
    }

    private var canSaveSelectedGroupName: Bool {
        guard let selectedGroup else { return false }
        let trimmed = viewModel.editableGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !viewModel.isSavingGroupName && !trimmed.isEmpty && trimmed != selectedGroup.name
    }

    private var canDeleteSelectedGroup: Bool {
        viewModel.selectedGroupID != nil && !viewModel.isDeletingGroup
    }

    private var canAddMemberByQRCode: Bool {
        !viewModel.isJoiningGroup
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create a group")
                .font(.title3.weight(.bold))

            createGroupCard

            if let createStatusMessage = viewModel.createStatusMessage {
                Text(createStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(createStatusTextColor)
            }

            Text("Your groups")
                .font(.title3.weight(.bold))
                .padding(.top, 8)

            yourGroupsCard
            groupActionLinks
        }
    }

    private var createGroupCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $viewModel.createGroupName,
                    prompt: Text("group name")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                )
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    Task {
                        await viewModel.createGroup()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var yourGroupsCard: some View {
        VStack(spacing: 12) {
            if viewModel.isLoadingGroups {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.groups.isEmpty {
                Text("No groups yet. Pull down to refresh.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(viewModel.groups) { group in
                            let isSelected = viewModel.selectedGroupID == group.id
                            Button(group.name) {
                                viewModel.selectedGroupID = group.id
                                viewModel.editableGroupName = group.name
                            }
                            .font(.footnote)
                            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color.clear)
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.accentColor, lineWidth: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField(
                    "",
                    text: $viewModel.editableGroupName,
                    prompt: Text("group name")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                )
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 10) {
                    Button {
                        viewModel.isGroupQRCodeOverlayPresented = true
                    } label: {
                        Image(systemName: "qrcode")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedGroupInvitePayload == nil)

                    if let selectedGroup {
                        HStack(spacing: -8) {
                            ForEach(selectedGroup.members) { member in
                                Text(member.icon)
                                    .font(.system(size: 18))
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: member.bgColour))
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(memberBorderColor, lineWidth: 2)
                                    }
                            }
                            let remainingCount = max(0, selectedGroup.totalMemberCount - selectedGroup.members.count)
                            if remainingCount > 0 {
                                Text("+\(remainingCount)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText(for: colorScheme).opacity(0.85))
                                    .frame(width: 36, height: 36)
                                    .background(fieldBackground)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(memberBorderColor, lineWidth: 2)
                                    }
                            }
                        }
                    }

                    Spacer()

                    if let saveStatusMessage = viewModel.saveStatusMessage {
                        Text(saveStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(saveStatusTextColor)
                    }

                    Button {
                        viewModel.isDeleteConfirmPresented = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.errorText.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDeleteSelectedGroup)

                    Button {
                        Task {
                            await viewModel.saveGroupName()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveSelectedGroupName)
                }
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var groupActionLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button {
                    viewModel.isQRScannerPresented = true
                } label: {
                    Label("Scan QR code", systemImage: "camera")
                }

                Button {
                    viewModel.isPhotoPickerPresented = true
                } label: {
                    Label("Choose from Photos", systemImage: "photo.badge.magnifyingglass")
                }
            } label: {
                Text("Join a group")
                    .appTextLinkStyle()
            }
            .buttonStyle(.plain)
            .disabled(!canAddMemberByQRCode)

            ShareLink(item: viewModel.appShareURL) {
                Text("Tell your friends about this app?")
                    .appSecondaryTextLinkStyle()
            }
            .buttonStyle(.plain)
        }
    }
}
