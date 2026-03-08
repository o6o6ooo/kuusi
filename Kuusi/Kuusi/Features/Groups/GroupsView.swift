import SwiftUI
import FirebaseAuth

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var groupName = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var isCreating = false
    @State private var clearMessageTask: Task<Void, Never>?

    private let groupService = GroupService()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var statusTextColor: Color {
        isError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }
    private var canCreate: Bool {
        !isCreating && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            .onChange(of: statusMessage) { _, newValue in
                scheduleMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearMessageTask?.cancel()
                clearMessageTask = nil
            }
        }
    }

    @MainActor
    private func createGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isError = true
            statusMessage = "Please sign in first"
            return
        }

        let cleanName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            isError = true
            statusMessage = "Fill in group name"
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            _ = try await groupService.createGroup(groupName: cleanName, ownerUID: uid)
            groupName = ""
            isError = false
            statusMessage = "Group created"
        } catch {
            isError = true
            statusMessage = error.localizedDescription
        }
    }

    private func scheduleMessageAutoClear(for value: String?) {
        clearMessageTask?.cancel()
        guard value != nil, !isError else { return }

        let currentValue = value
        clearMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, statusMessage == currentValue, !isError {
                statusMessage = nil
            }
        }
    }
}
