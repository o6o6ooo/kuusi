import SwiftUI

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var groupID = ""
    @State private var groupName = ""
    @State private var statusMessage: String?

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var canCreate: Bool { !groupID.isEmpty && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
                                    .foregroundStyle(.secondary)
                            }
                            Button("Create") {
                                statusMessage = "Group ready"
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
}
