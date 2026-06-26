import FirebaseAuth
import SwiftUI

struct GroupsSectionView: View {
    @ObservedObject var viewModel: SettingsGroupsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var appAlert: AppAlert?
    @State private var pendingCreateGroupName = ""
    @State private var pendingRenameGroupName = ""

    private var groupCardWidth: CGFloat {
        168 + groupCardWidthIncrement
    }

    private var groupCardHeight: CGFloat {
        120 + groupCardHeightIncrement
    }

    private var groupCardWidthIncrement: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1:
            return 20
        case .accessibility2:
            return 36
        case .accessibility3:
            return 52
        case .accessibility4:
            return 68
        case .accessibility5:
            return 84
        default:
            return 0
        }
    }

    private var groupCardHeightIncrement: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1:
            return 16
        case .accessibility2:
            return 28
        case .accessibility3:
            return 40
        case .accessibility4:
            return 52
        case .accessibility5:
            return 64
        default:
            return 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("groups.title")
                    .font(.title3.weight(.bold))

                Menu {
                    Button("groups.create", systemImage: "plus") {
                        pendingCreateGroupName = ""
                        appAlert = AppAlert(.createGroupPrompt, text: $pendingCreateGroupName) {
                            viewModel.createGroupName = pendingCreateGroupName
                            Task { await viewModel.createGroup() }
                        }
                    }
                    .accessibilityIdentifier("groups-create-menu-action")

                    Button("groups.join_from_photo", systemImage: "photo.badge.magnifyingglass") {
                        viewModel.isPhotoPickerPresented = true
                    }
                    .accessibilityIdentifier("groups-join-from-photo-menu-action")

                    Button("groups.scan_qr", systemImage: "qrcode.viewfinder") {
                        viewModel.isQRCodeScannerPresented = true
                    }
                    .accessibilityIdentifier("groups-scan-qr-menu-action")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("groups-create-button")

                Button {
                    Task {
                        await viewModel.refreshGroups()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingGroups)
                .accessibilityLabel(Text("groups.refresh"))
                .accessibilityIdentifier("groups-refresh-button")

                Spacer()
            }

            if viewModel.isLoadingGroups {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.groups.isEmpty {
                Text("groups.empty")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("groups-empty-state")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.groups) { group in
                            groupCard(group)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            groupActionLinks
        }
        .appAlert($appAlert)
    }

    private func groupCard(_ group: GroupSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                memberStack(for: group)

                Spacer(minLength: 12)
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 12) {
                Text(group.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .offset(y: -4)

                Spacer(minLength: 0)

                groupMenu(for: group)
            }
            .offset(y: -6)
        }
        .padding(16)
        .frame(width: groupCardWidth, height: groupCardHeight, alignment: .topLeading)
        .appGlassCard()
    }

    private func memberStack(for group: GroupSummary) -> some View {
        Button {
            viewModel.selectedGroupID = group.id
            viewModel.editableGroupName = group.name
            Task {
                await viewModel.presentMemberList()
            }
        } label: {
            HStack(spacing: -10) {
                if group.members.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.18))
                            .frame(width: 46, height: 46)
                    }
                } else {
                    ForEach(Array(group.members.prefix(3))) { member in
                        Text(member.icon)
                            .font(.system(size: 22))
                            .frame(width: 46, height: 46)
                            .background(Color(hex: member.bgColour))
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                            }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("groups-members-button-\(group.id)")
    }

    private func groupMenu(for group: GroupSummary) -> some View {
        Menu {
            Button("groups.menu.edit", systemImage: "pencil") {
                viewModel.selectedGroupID = group.id
                viewModel.editableGroupName = group.name
                pendingRenameGroupName = group.name
                appAlert = AppAlert(.editGroupPrompt, text: $pendingRenameGroupName) {
                    viewModel.editableGroupName = pendingRenameGroupName
                    Task { await viewModel.saveGroupName() }
                }
            }

            if currentUserOwns(group) && group.totalMemberCount <= 1 {
                Button("groups.menu.delete", systemImage: "trash", role: .destructive) {
                    presentDestructiveConfirmation(for: group, action: .delete)
                }
            } else if currentUserOwns(group) {
                Button("groups.menu.delete", systemImage: "trash", role: .destructive) {
                    presentDestructiveConfirmation(for: group, action: .delete)
                }

                Button("groups.menu.leave", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    presentDestructiveConfirmation(for: group, action: .leave)
                }
            } else {
                Button("groups.menu.leave", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    presentDestructiveConfirmation(for: group, action: .leave)
                }
            }

            Button("groups.menu.qr_code", systemImage: "qrcode") {
                Task {
                    await viewModel.presentGroupQRCode(for: group)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func currentUserOwns(_ group: GroupSummary) -> Bool {
        let uid: String?
#if DEBUG
        uid = UITestEnvironment.currentUserID ?? Auth.auth().currentUser?.uid
#else
        uid = Auth.auth().currentUser?.uid
#endif
        guard let uid else { return false }
        return group.ownerUID == uid
    }

    private func presentDestructiveConfirmation(for group: GroupSummary, action: GroupDestructiveAction) {
        viewModel.selectedGroupID = group.id
        viewModel.editableGroupName = group.name
        viewModel.selectedDestructiveAction = action
        viewModel.isDeleteConfirmPresented = true
    }

    private var groupActionLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShareLink(item: viewModel.appShareURL) {
                Text("groups.share_app")
                    .appSecondaryTextLinkStyle()
            }
            .buttonStyle(.plain)
        }
    }
}
