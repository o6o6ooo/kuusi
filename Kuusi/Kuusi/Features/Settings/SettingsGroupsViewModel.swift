import Combine
import CoreImage
import FirebaseAuth
import Foundation

private extension GroupServiceError {
    var appMessageID: AppMessage.ID {
        switch self {
        case .groupNotFound:
            return .groupNotFound
        case .ownerCannotLeave:
            return .ownerCannotLeave
        case let .memberLimitReached(maxMembers):
            return .groupMemberLimitReached(maxMembers: maxMembers)
        }
    }
}

enum GroupInvitePayloadParser {
    static func extractGroupID(from payload: String) -> String? {
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
}

@MainActor
final class SettingsGroupsViewModel: ObservableObject {
    @Published var createGroupName = ""
    @Published var selectedGroupID: String?
    @Published var editableGroupName = ""
    @Published var groups: [GroupSummary] = []
    @Published var createStatusMessage: AppMessage?
    @Published var saveStatusMessage: AppMessage?
    @Published var isCreating = false
    @Published var isLoadingGroups = false
    @Published var isSavingGroupName = false
    @Published var isDeletingGroup = false
    @Published var isDeleteConfirmPresented = false
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
            ? "This will remove the group for all members and permanently delete all photos in it."
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
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToLoadGroupMembers, .error))
        }
    }

    func createGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            setCreateStatus(AppMessage(.pleaseSignInFirst, .error))
            return
        }
        guard groups.count < currentPlan.maxGroups else {
            setCreateStatus(AppMessage(.groupLimitReached(title: currentPlan.title, maxGroups: currentPlan.maxGroups), .error))
            return
        }

        let cleanName = createGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            setCreateStatus(AppMessage(.fillInGroupName, .error))
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
            await loadGroupPreviewIfNeeded(for: created.id, force: true)
            setCreateStatus(AppMessage(.groupCreated, .success))
        } catch {
            setCreateStatus(AppMessage(.failedToCreateGroup, .error))
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
            } else {
                editableGroupName = ""
            }
            await loadAllGroupPreviews(force: true)
        } catch {
            setCreateStatus(AppMessage(.failedToLoadGroups, .error))
        }
    }

    func selectGroup(_ id: String) async {
        guard selectedGroupID != id else { return }
        selectedGroupID = id
        if let selected = groups.first(where: { $0.id == id }) {
            editableGroupName = selected.name
        }
        await loadGroupPreviewIfNeeded(for: id, force: false)
    }

    func saveGroupName() async {
        guard let selectedGroupID else { return }
        let trimmed = editableGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setSaveStatus(AppMessage(.fillInGroupName, .error))
            return
        }

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
            setSaveStatus(AppMessage(.groupUpdated, .success))
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToUpdateGroup, .error))
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
            if let nextGroupID = self.selectedGroupID {
                await loadGroupPreviewIfNeeded(for: nextGroupID, force: false)
            }
            setSaveStatus(AppMessage(.groupDeleted, .success))
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToDeleteGroup, .error))
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
            if let nextGroupID = self.selectedGroupID {
                await loadGroupPreviewIfNeeded(for: nextGroupID, force: false)
            }
            setSaveStatus(AppMessage(.leftGroup, .success))
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToLeaveGroup, .error))
        }
    }

    func handleSelectedQRCodePhotoData(_ data: Data?) async {
        guard let data else {
            setSaveStatus(AppMessage(.failedToLoadImage, .error))
            return
        }
        guard let payload = decodeQRCodePayload(from: data) else {
            setSaveStatus(AppMessage(.qrCodeNotFoundInImage, .error))
            return
        }
        await joinGroupFromQRCodePayload(payload)
    }

    func joinGroupFromQRCodePayload(_ payload: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            setSaveStatus(AppMessage(.pleaseSignInFirst, .error))
            return
        }
        guard let groupID = GroupInvitePayloadParser.extractGroupID(from: payload) else {
            setSaveStatus(AppMessage(.invalidInviteQR, .error))
            return
        }
        guard groups.contains(where: { $0.id == groupID }) || groups.count < currentPlan.maxGroups else {
            setSaveStatus(AppMessage(.groupLimitReached(title: currentPlan.title, maxGroups: currentPlan.maxGroups), .error))
            return
        }

        isJoiningGroup = true
        defer { isJoiningGroup = false }

        do {
            try await groupService.joinGroup(groupID: groupID, uid: uid)
            setSaveStatus(AppMessage(.joinedGroup, .success))
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToJoinGroup, .error))
        }
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

    private func setCreateStatus(_ message: AppMessage) {
        clearCreateMessageTask?.cancel()
        createStatusMessage = message
        clearCreateMessageTask = AppMessageAutoClear.schedule(
            for: message,
            currentMessage: { [weak self] in
                self?.createStatusMessage
            },
            clear: { [weak self] in
                self?.createStatusMessage = nil
            }
        )
    }

    private func setSaveStatus(_ message: AppMessage) {
        clearSaveMessageTask?.cancel()
        saveStatusMessage = message
        clearSaveMessageTask = AppMessageAutoClear.schedule(
            for: message,
            currentMessage: { [weak self] in
                self?.saveStatusMessage
            },
            clear: { [weak self] in
                self?.saveStatusMessage = nil
            }
        )
    }

    private func loadAllGroupPreviews(force: Bool) async {
        for group in groups {
            await loadGroupPreviewIfNeeded(for: group.id, force: force)
        }
    }

    private func loadGroupPreviewIfNeeded(for groupID: String, force: Bool) async {
        if !force && previewLoadedGroupIDs.contains(groupID) { return }
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }

        let previews = (try? await groupService.loadMemberPreviews(groupID: groupID, limit: 3)) ?? []
        let existing = groups[index]
        groups[index] = GroupSummary(
            id: existing.id,
            name: existing.name,
            ownerUID: existing.ownerUID,
            members: previews,
            totalMemberCount: existing.totalMemberCount
        )
        previewLoadedGroupIDs.insert(groupID)
        cacheGroupsForCurrentUser()
    }

    private func cacheGroupsForCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        groupService.setCachedGroups(groups, for: uid)
    }
}
