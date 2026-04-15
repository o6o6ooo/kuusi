import SwiftUI

struct GroupMembersOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appAlert: AppAlert?

    let members: [GroupMemberPreview]
    let currentUserIsOwner: Bool
    let removingMemberID: String?
    let onRemoveMember: (GroupMemberPreview) -> Void

    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var ownerBadgeBackground: Color { AppTheme.accent(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                Text(member.icon)
                                    .font(.system(size: 22))
                                    .frame(width: 42, height: 42)
                                    .background(Color(hex: member.bgColour))
                                    .clipShape(Circle())

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
                                .accessibilityLabel("Remove \(member.name)")
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(cardBackground)
            .appOverlayTheme()
            .toolbar(.hidden, for: .navigationBar)
            .appAlert($appAlert)
        }
    }
}
