import SwiftUI
import FirebaseAuth

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var groupID = ""
    @State private var groupName = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var isCreating = false

    private let groupService = GroupService()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var statusTextColor: Color {
        isError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }
    private var canCreate: Bool {
        !isCreating && !groupID.isEmpty && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Create a group")
										.font(.headline.weight(.semibold))

                    VStack(spacing: 12) {
                        TextField(
                            "",
                            text: $groupID,
                            prompt: Text("group ID")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .onChange(of: groupID) { _, newValue in
                                groupID = sanitizeGroupID(newValue)
                            }

                        TextField(
                            "",
                            text: $groupName,
                            prompt: Text("group name")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        )
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        HStack {
                            Spacer()
                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(statusTextColor)
                            }
                            Button("Create") {
                                Task {
                                    await createGroup()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canCreate)
                        }
                    }
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(16)
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .screenTheme()
        }
    }

    private func sanitizeGroupID(_ raw: String) -> String {
        let lowercased = raw.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return String(lowercased.unicodeScalars.filter { allowed.contains($0) })
    }

    @MainActor
    private func createGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isError = true
            statusMessage = "Please sign in first"
            return
        }

        let cleanID = sanitizeGroupID(groupID)
        let cleanName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty, !cleanName.isEmpty else {
            isError = true
            statusMessage = "Fill in group ID and name"
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            try await groupService.createGroup(groupID: cleanID, groupName: cleanName, ownerUID: uid)
            groupID = ""
            groupName = ""
            isError = false
            statusMessage = "Group created"
        } catch {
            isError = true
            statusMessage = error.localizedDescription
        }
    }
}
