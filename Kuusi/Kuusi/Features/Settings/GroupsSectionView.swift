import FirebaseAuth
import SwiftUI

struct GroupsSectionView: View {
    @ObservedObject var viewModel: SettingsGroupsViewModel

    @State private var appAlert: AppAlert?
    @State private var pendingCreateGroupName = ""
    @State private var pendingRenameGroupName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("Groups")
                    .font(.title3.weight(.bold))

                Menu {
                    Button("Create a group", systemImage: "plus") {
                        pendingCreateGroupName = ""
                        appAlert = AppAlert(.createGroupPrompt, text: $pendingCreateGroupName) {
                            viewModel.createGroupName = pendingCreateGroupName
                            Task { await viewModel.createGroup() }
                        }
                    }

                    Button("Join a group", systemImage: "photo.badge.magnifyingglass") {
                        viewModel.isPhotoPickerPresented = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .regular))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("groups-create-button")

                Spacer()
            }

            if viewModel.isLoadingGroups {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.groups.isEmpty {
                Text("No groups")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 168, height: 120, alignment: .topLeading)
        .appCardSurface(cornerRadius: 22)
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
    }

    private func groupMenu(for group: GroupSummary) -> some View {
        Menu {
            Button("Edit group", systemImage: "pencil") {
                viewModel.selectedGroupID = group.id
                viewModel.editableGroupName = group.name
                pendingRenameGroupName = group.name
                appAlert = AppAlert(.editGroupPrompt, text: $pendingRenameGroupName) {
                    viewModel.editableGroupName = pendingRenameGroupName
                    Task { await viewModel.saveGroupName() }
                }
            }

            Button(viewModel.selectedGroupID == group.id ? viewModel.destructiveActionButtonTitle : destructiveLabel(for: group), systemImage: destructiveSymbol(for: group), role: .destructive) {
                viewModel.selectedGroupID = group.id
                viewModel.editableGroupName = group.name
                viewModel.isDeleteConfirmPresented = true
            }

            Button("QR code", systemImage: "qrcode") {
                viewModel.selectedGroupID = group.id
                viewModel.editableGroupName = group.name
                viewModel.isGroupQRCodeOverlayPresented = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .bold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func destructiveLabel(for group: GroupSummary) -> String {
        guard let uid = Auth.auth().currentUser?.uid else { return "Leave group" }
        return group.ownerUID == uid ? "Delete group" : "Leave group"
    }

    private func destructiveSymbol(for group: GroupSummary) -> String {
        guard let uid = Auth.auth().currentUser?.uid else { return "rectangle.portrait.and.arrow.right" }
        return group.ownerUID == uid ? "trash" : "rectangle.portrait.and.arrow.right"
    }

    private var groupActionLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShareLink(item: viewModel.appShareURL) {
                Text("Tell your friends about this app?")
                    .appSecondaryTextLinkStyle()
            }
            .buttonStyle(.plain)
        }
    }
}
