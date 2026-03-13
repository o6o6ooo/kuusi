import SwiftUI

struct GroupMembersOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let members: [GroupMemberPreview]

    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            Text(member.icon)
                                .font(.system(size: 22))
                                .frame(width: 42, height: 42)
                                .background(Color(hex: member.bgColour))
                                .clipShape(Circle())

                            Text(member.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(primaryText)

                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .background(cardBackground)
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
