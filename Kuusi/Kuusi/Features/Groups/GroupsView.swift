import SwiftUI
import FirebaseAuth

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var createGroupName = ""
    @State private var selectedGroupID: String?
    @State private var editableGroupName = ""
    @State private var groups: [GroupSummary] = []
    @State private var createStatusMessage: String?
    @State private var isCreateError = false
    @State private var saveStatusMessage: String?
    @State private var isSaveError = false
    @State private var isCreating = false
    @State private var isLoadingGroups = false
    @State private var isSavingGroupName = false
    @State private var isDeletingGroup = false
    @State private var clearCreateMessageTask: Task<Void, Never>?
    @State private var clearSaveMessageTask: Task<Void, Never>?

    private let groupService = GroupService()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var memberBorderColor: Color { AppTheme.cardBorder(for: colorScheme) }
    private var createStatusTextColor: Color {
        isCreateError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }
    private var saveStatusTextColor: Color {
        isSaveError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }
    private var canCreate: Bool {
        !isCreating && !createGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var selectedGroup: GroupSummary? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }
    private var canSaveSelectedGroupName: Bool {
        guard let selectedGroup else { return false }
        let trimmed = editableGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isSavingGroupName && !trimmed.isEmpty && trimmed != selectedGroup.name
    }
    private var canDeleteSelectedGroup: Bool {
        selectedGroupID != nil && !isDeletingGroup
    }
    private var selectedGroupInviteURL: URL? {
        guard let selectedGroupID else { return nil }
        return URL(string: "https://kuusi.app/invite/\(selectedGroupID)")
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
                            text: $createGroupName,
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
                            if let createStatusMessage {
                                Text(createStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(createStatusTextColor)
                            }
                            Button {
                                Task {
                                    await createGroup()
                                }
                            } label: {
                                Image(systemName: "person.fill.badge.plus")
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

                    Text("Your groups")
                        .font(.headline.weight(.semibold))

                    VStack(spacing: 12) {
                        if isLoadingGroups {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if groups.isEmpty {
                            Text("No groups yet. Pull down to refresh.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 10) {
                                    ForEach(groups) { group in
                                        let isSelected = selectedGroupID == group.id
                                        Button(group.name) {
                                            selectedGroupID = group.id
                                            editableGroupName = group.name
                                        }
                                        .font(.body)
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
                                text: $editableGroupName,
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

                            HStack(spacing: 10) {
                                if let selectedGroupInviteURL {
                                    ShareLink(item: selectedGroupInviteURL) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                }

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

                                if let saveStatusMessage {
                                    Text(saveStatusMessage)
                                        .font(.footnote)
                                        .foregroundStyle(saveStatusTextColor)
                                }

                                Button {
                                    Task {
                                        await deleteSelectedGroup()
                                    }
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
                                        await saveGroupName()
                                    }
                                } label: {
                                    Image(systemName: "checkmark.icloud.fill")
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
                .padding(16)
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .screenTheme()
            .refreshable {
                await loadGroups()
            }
            .onChange(of: createStatusMessage) { _, newValue in
                scheduleCreateMessageAutoClear(for: newValue)
            }
            .onChange(of: saveStatusMessage) { _, newValue in
                scheduleSaveMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearCreateMessageTask?.cancel()
                clearCreateMessageTask = nil
                clearSaveMessageTask?.cancel()
                clearSaveMessageTask = nil
            }
        }
    }

    @MainActor
    private func createGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isCreateError = true
            createStatusMessage = "Please sign in first"
            return
        }

        let cleanName = createGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            isCreateError = true
            createStatusMessage = "Fill in group name"
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let createdGroup = try await groupService.createGroup(groupName: cleanName, ownerUID: uid)
            createGroupName = ""
            isCreateError = false
            createStatusMessage = "Group created"
            groups.insert(createdGroup, at: 0)
            selectedGroupID = createdGroup.id
            editableGroupName = createdGroup.name
        } catch {
            isCreateError = true
            createStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadGroups() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingGroups = true
        defer { isLoadingGroups = false }

        do {
            let fetched = try await groupService.fetchGroups(for: uid)
            groups = fetched

            if selectedGroupID == nil || !fetched.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = fetched.first?.id
            }

            if let selectedGroup {
                editableGroupName = selectedGroup.name
            } else {
                editableGroupName = ""
            }
        } catch {
            isCreateError = true
            createStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveGroupName() async {
        guard let selectedGroupID else { return }
        let trimmed = editableGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSavingGroupName = true
        defer { isSavingGroupName = false }

        do {
            try await groupService.updateGroupName(groupID: selectedGroupID, name: trimmed)
            if let index = groups.firstIndex(where: { $0.id == selectedGroupID }) {
                groups[index] = GroupSummary(
                    id: groups[index].id,
                    name: trimmed,
                    members: groups[index].members,
                    totalMemberCount: groups[index].totalMemberCount
                )
            }
            isSaveError = false
            saveStatusMessage = "Group updated"
        } catch {
            isSaveError = true
            saveStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteSelectedGroup() async {
        guard let selectedGroupID else { return }

        isDeletingGroup = true
        defer { isDeletingGroup = false }

        do {
            try await groupService.deleteGroup(groupID: selectedGroupID)
            groups.removeAll { $0.id == selectedGroupID }
            self.selectedGroupID = groups.first?.id
            editableGroupName = groups.first?.name ?? ""
            isSaveError = false
            saveStatusMessage = "Group deleted"
        } catch {
            isSaveError = true
            saveStatusMessage = error.localizedDescription
        }
    }

    private func scheduleCreateMessageAutoClear(for value: String?) {
        clearCreateMessageTask?.cancel()
        guard value != nil, !isCreateError else { return }

        let currentValue = value
        clearCreateMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, createStatusMessage == currentValue, !isCreateError {
                createStatusMessage = nil
            }
        }
    }

    private func scheduleSaveMessageAutoClear(for value: String?) {
        clearSaveMessageTask?.cancel()
        guard value != nil, !isSaveError else { return }

        let currentValue = value
        clearSaveMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, saveStatusMessage == currentValue, !isSaveError {
                saveStatusMessage = nil
            }
        }
    }
}
