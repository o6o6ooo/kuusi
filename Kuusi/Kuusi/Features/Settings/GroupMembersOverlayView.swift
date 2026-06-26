import SwiftUI

struct GroupMembersOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appAlert: AppAlert?

    let groupName: String
    let members: [GroupMemberPreview]
    let currentUserIsOwner: Bool
    let removingMemberID: String?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onRemoveMember: (GroupMemberPreview) -> Void

    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var ownerBadgeBackground: Color { AppTheme.accent(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(groupName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(primaryText)

                        Spacer()

                        Button(action: onRefresh) {
                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(primaryText)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(primaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                        .frame(width: 32, height: 32)
                        .accessibilityLabel(String(localized: "groups.members.refresh"))
                        .accessibilityIdentifier("groups-members-refresh-button")
                    }

                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                ZStack {
                                    Color.clear
                                        .glassEffect(.regular.tint(Color(hex: member.bgColour)), in: Circle())

                                    Text(member.icon)
                                        .font(.system(size: 22))
                                }
                                    .frame(width: 42, height: 42)

                                if member.isOwner {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 7, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 14, height: 14)
                                        .background(ownerBadgeBackground)
                                        .clipShape(Circle())
                                        .offset(x: 3, y: -3)
                                }
                            }

                            Text(member.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(primaryText)

                            Spacer()

                            if currentUserIsOwner, !member.isOwner {
                                Button {
                                    appAlert = AppAlert(.removeGroupMemberConfirm(memberName: member.name)) {
                                        onRemoveMember(member)
                                    }
                                } label: {
                                    if removingMemberID == member.id {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(AppTheme.errorText)
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(AppTheme.errorText)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(removingMemberID != nil)
                                .accessibilityLabel(String(format: String(localized: "groups.members.remove_accessibility"), member.name))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(cardBackground)
            .appOverlayTheme()
            .toolbar(.hidden, for: .navigationBar)
            .appAlert($appAlert)
            .accessibilityIdentifier("groups-members-overlay")
        }
    }
}
