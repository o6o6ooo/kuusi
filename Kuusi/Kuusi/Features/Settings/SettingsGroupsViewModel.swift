import Combine
import CoreImage
import FirebaseAuth
import Foundation

@MainActor
final class SettingsGroupsViewModel: ObservableObject {
    @Published var createGroupName = ""
    @Published var selectedGroupID: String?
    @Published var editableGroupName = ""
    @Published var groups: [GroupSummary] = []
    @Published var createStatusMessage: String?
    @Published var isCreateError = false
    @Published var saveStatusMessage: String?
    @Published var isSaveError = false
    @Published var isCreating = false
    @Published var isLoadingGroups = false
    @Published var isSavingGroupName = false
    @Published var isDeletingGroup = false
    @Published var isDeleteConfirmPresented = false
    @Published var isQRScannerPresented = false
    @Published var isPhotoPickerPresented = false
    @Published var isGroupQRCodeOverlayPresented = false
    @Published var isMemberListPresented = false
    @Published var isJoiningGroup = false
    @Published private(set) var currentPlan: AppPlan = .free
    @Published private(set) var selectedGroupMembers: [GroupMemberPreview] = []

    private let groupService = GroupService()
    private var clearCreateMessageTask: Task<Void, Never>?
    private var clearSaveMessageTask: Task<Void, Never>?
    private var previewLoadedGroupIDs: Set<String> = []

    var selectedGroup: GroupSummary? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }

    var currentUserIsSelectedGroupOwner: Bool {
        guard
            let uid = Auth.auth().currentUser?.uid,
            let selectedGroup
        else {
            return false
        }
        return selectedGroup.ownerUID == uid
    }

    var destructiveActionTitle: String {
        currentUserIsSelectedGroupOwner ? "Delete group?" : "Leave group?"
    }

    var destructiveActionMessage: String {
        currentUserIsSelectedGroupOwner
            ? "This will remove the group for all members."
            : "You will be removed from this group."
    }

    var destructiveActionButtonTitle: String {
        currentUserIsSelectedGroupOwner ? "Delete" : "Leave"
    }

    var selectedGroupInvitePayload: String? {
        guard let selectedGroupID else { return nil }
        return "kuusi://invite/\(selectedGroupID)"
    }

    let appShareURL = URL(string: "https://apps.apple.com/app/id1234567890")!

    func onDisappear() {
        clearCreateMessageTask?.cancel()
        clearCreateMessageTask = nil
        clearSaveMessageTask?.cancel()
        clearSaveMessageTask = nil
    }

    func updateCurrentPlan(_ plan: AppPlan) {
        currentPlan = plan
    }

    func presentMemberList() async {
        guard let selectedGroupID else { return }
        do {
            selectedGroupMembers = try await groupService.loadMemberPreviews(groupID: selectedGroupID, limit: nil)
            isMemberListPresented = true
        } catch {
            setSaveStatus(error.localizedDescription, isError: true)
        }
    }

    func createGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            setCreateStatus("Please sign in first", isError: true)
            return
        }
        guard groups.count < currentPlan.maxGroups else {
            setCreateStatus("\(currentPlan.title) supports up to \(currentPlan.maxGroups) groups.", isError: true)
            return
        }

        let cleanName = createGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            setCreateStatus("Fill in group name", isError: true)
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let created = try await groupService.createGroup(groupName: cleanName, ownerUID: uid)
            createGroupName = ""
            groups.append(created)
            selectedGroupID = created.id
            editableGroupName = created.name
            previewLoadedGroupIDs.remove(created.id)
            cacheGroupsForCurrentUser()
            await loadSelectedGroupPreviewIfNeeded(force: true)
            setCreateStatus("Group created. Pull down to refresh.", isError: false)
        } catch {
            setCreateStatus(error.localizedDescription, isError: true)
        }
    }

    func loadGroups() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingGroups = true
        defer { isLoadingGroups = false }

        do {
            let fetched = try await groupService.fetchGroups(for: uid)
            groups = fetched
            previewLoadedGroupIDs.removeAll()

            if selectedGroupID == nil || !fetched.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = fetched.first?.id
            }

            if let selectedGroupID,
               let selectedGroup = fetched.first(where: { $0.id == selectedGroupID }) {
                editableGroupName = selectedGroup.name
                await loadSelectedGroupPreviewIfNeeded(force: true)
            } else {
                editableGroupName = ""
            }
        } catch {
            setCreateStatus(error.localizedDescription, isError: true)
        }
    }

    func selectGroup(_ id: String) async {
        guard selectedGroupID != id else { return }
        selectedGroupID = id
        if let selected = groups.first(where: { $0.id == id }) {
            editableGroupName = selected.name
        }
        await loadSelectedGroupPreviewIfNeeded(force: false)
    }

    func saveGroupName() async {
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
                    ownerUID: groups[index].ownerUID,
                    members: groups[index].members,
                    totalMemberCount: groups[index].totalMemberCount
                )
            }
            cacheGroupsForCurrentUser()
            setSaveStatus("Group updated", isError: false)
        } catch {
            setSaveStatus(error.localizedDescription, isError: true)
        }
    }

    func deleteSelectedGroup() async {
        guard let selectedGroupID else { return }

        isDeletingGroup = true
        defer { isDeletingGroup = false }

        do {
            try await groupService.deleteGroup(groupID: selectedGroupID)
            groups.removeAll { $0.id == selectedGroupID }
            previewLoadedGroupIDs.remove(selectedGroupID)
            self.selectedGroupID = groups.first?.id
            editableGroupName = groups.first?.name ?? ""
            cacheGroupsForCurrentUser()
            await loadSelectedGroupPreviewIfNeeded(force: false)
            setSaveStatus("Group deleted. Pull down to refresh.", isError: false)
        } catch {
            setSaveStatus(error.localizedDescription, isError: true)
        }
    }

    func leaveSelectedGroup() async {
        guard
            let selectedGroupID,
            let uid = Auth.auth().currentUser?.uid
        else {
            return
        }

        isDeletingGroup = true
        defer { isDeletingGroup = false }

        do {
            try await groupService.leaveGroup(groupID: selectedGroupID, uid: uid)
            groups.removeAll { $0.id == selectedGroupID }
            previewLoadedGroupIDs.remove(selectedGroupID)
            self.selectedGroupID = groups.first?.id
            editableGroupName = groups.first?.name ?? ""
            cacheGroupsForCurrentUser()
            await loadSelectedGroupPreviewIfNeeded(force: false)
            setSaveStatus("Left group. Pull down to refresh.", isError: false)
        } catch {
            setSaveStatus(error.localizedDescription, isError: true)
        }
    }

    func handleSelectedQRCodePhotoData(_ data: Data?) async {
        guard let data else {
            setSaveStatus("Failed to load image", isError: true)
            return
        }
        guard let payload = decodeQRCodePayload(from: data) else {
            setSaveStatus("QR code was not found in the image", isError: true)
            return
        }
        await joinGroupFromQRCodePayload(payload)
    }

    func joinGroupFromQRCodePayload(_ payload: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            setSaveStatus("Please sign in first", isError: true)
            return
        }
        guard let groupID = extractGroupID(from: payload) else {
            setSaveStatus("Invalid invite QR", isError: true)
            return
        }
        guard groups.contains(where: { $0.id == groupID }) || groups.count < currentPlan.maxGroups else {
            setSaveStatus("\(currentPlan.title) supports up to \(currentPlan.maxGroups) groups.", isError: true)
            return
        }

        isJoiningGroup = true
        defer { isJoiningGroup = false }

        do {
            try await groupService.joinGroup(groupID: groupID, uid: uid)
            setSaveStatus("Joined group. Pull down to refresh.", isError: false)
        } catch {
            setSaveStatus(error.localizedDescription, isError: true)
        }
    }

    func loadCachedGroupsOnly() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cached = groupService.cachedGroups(for: uid)
        groups = cached
        if selectedGroupID == nil || !cached.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = cached.first?.id
        }
        if let selectedGroupID,
           let selected = cached.first(where: { $0.id == selectedGroupID }) {
            editableGroupName = selected.name
        }
    }

    private func extractGroupID(from payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed) {
            if url.scheme?.lowercased() == "kuusi", url.host?.lowercased() == "invite" {
                let groupID = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return groupID.isEmpty ? nil : groupID.lowercased()
            }

            let parts = url.pathComponents.filter { $0 != "/" }
            if let idx = parts.firstIndex(of: "invite"), idx + 1 < parts.count {
                let groupID = parts[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                return groupID.isEmpty ? nil : groupID.lowercased()
            }
        }

        return trimmed.lowercased()
    }

    private func decodeQRCodePayload(from data: Data) -> String? {
        guard let ciImage = CIImage(data: data) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }

    private func setCreateStatus(_ message: String, isError: Bool) {
        isCreateError = isError
        createStatusMessage = message

        clearCreateMessageTask?.cancel()
        guard !isError else { return }

        let current = message
        clearCreateMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, createStatusMessage == current, !isCreateError {
                createStatusMessage = nil
            }
        }
    }

    private func setSaveStatus(_ message: String, isError: Bool) {
        isSaveError = isError
        saveStatusMessage = message

        clearSaveMessageTask?.cancel()
        guard !isError else { return }

        let current = message
        clearSaveMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, saveStatusMessage == current, !isSaveError {
                saveStatusMessage = nil
            }
        }
    }

    private func loadSelectedGroupPreviewIfNeeded(force: Bool) async {
        guard let selectedGroupID else { return }
        if !force && previewLoadedGroupIDs.contains(selectedGroupID) { return }
        guard let index = groups.firstIndex(where: { $0.id == selectedGroupID }) else { return }

        let previews = (try? await groupService.loadMemberPreviews(groupID: selectedGroupID, limit: 3)) ?? []
        let existing = groups[index]
        groups[index] = GroupSummary(
            id: existing.id,
            name: existing.name,
            ownerUID: existing.ownerUID,
            members: previews,
            totalMemberCount: existing.totalMemberCount
        )
        previewLoadedGroupIDs.insert(selectedGroupID)
        cacheGroupsForCurrentUser()
    }

    private func cacheGroupsForCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        groupService.setCachedGroups(groups, for: uid)
    }
}
