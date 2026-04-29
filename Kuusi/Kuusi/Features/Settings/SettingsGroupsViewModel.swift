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
        case .ownerCannotBeRemoved:
            return .ownerCannotBeRemoved
        case let .memberLimitReached(maxMembers):
            return .groupMemberLimitReached(maxMembers: maxMembers)
        case .onlyOwnerCanRemoveMembers:
            return .onlyOwnerCanRemoveMembers
        case .invalidInvite:
            return .invalidInviteQR
        case .inviteExpired:
            return .inviteQRCodeExpired
        }
    }
}

enum GroupInvitePayloadParser {
    static func extractInviteToken(from payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed) {
            if url.scheme?.lowercased() == "kuusi", url.host?.lowercased() == "invite" {
                let inviteToken = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return inviteToken.isEmpty ? nil : inviteToken.lowercased()
            }

            let parts = url.pathComponents.filter { $0 != "/" }
            if let idx = parts.firstIndex(of: "invite"), idx + 1 < parts.count {
                let inviteToken = parts[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                return inviteToken.isEmpty ? nil : inviteToken.lowercased()
            }
        }

        return trimmed.lowercased()
    }
}

protocol SettingsGroupsServicing {
    func createInvitePayload(groupID: String) async throws -> String
    func loadMemberPreviews(groupID: String, limit: Int?) async throws -> [GroupMemberPreview]
    func createGroup(groupName: String, ownerUID: String) async throws -> GroupSummary
    func fetchGroups(for uid: String) async throws -> [GroupSummary]
    func updateGroupName(groupID: String, name: String) async throws
    func deleteGroup(groupID: String) async throws
    func leaveGroup(groupID: String, uid: String) async throws
    func joinGroup(inviteToken: String) async throws
    func removeMember(groupID: String, memberUID: String, requesterUID: String) async throws
    func setCachedGroups(_ groups: [GroupSummary], for uid: String)
}

extension GroupService: SettingsGroupsServicing {}

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
    @Published var isQRCodeScannerPresented = false
    @Published var isGroupQRCodeOverlayPresented = false
    @Published var isMemberListPresented = false
    @Published var isJoiningGroup = false
    @Published private(set) var selectedGroupInvitePayload: String?
    @Published private(set) var removingMemberID: String?
    @Published private(set) var currentPlan: AppPlan = .free
    @Published private(set) var selectedGroupMembers: [GroupMemberPreview] = []

    private let groupService: SettingsGroupsServicing
    private let currentUserIDProvider: @MainActor () -> String?
    private var clearCreateMessageTask: Task<Void, Never>?
    private var clearSaveMessageTask: Task<Void, Never>?
    private var previewLoadedGroupIDs: Set<String> = []

    init(
        groupService: SettingsGroupsServicing,
        currentUserIDProvider: @escaping @MainActor () -> String?
    ) {
        self.groupService = groupService
        self.currentUserIDProvider = currentUserIDProvider
    }

    convenience init() {
        self.init(
            groupService: GroupService(),
            currentUserIDProvider: { Auth.auth().currentUser?.uid }
        )
    }

    var selectedGroup: GroupSummary? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }

    var currentUserIsSelectedGroupOwner: Bool {
        guard
            let uid = currentUserIDProvider(),
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

    func presentGroupQRCode(for group: GroupSummary) async {
        selectedGroupID = group.id
        editableGroupName = group.name

        do {
            selectedGroupInvitePayload = try await groupService.createInvitePayload(groupID: group.id)
            isGroupQRCodeOverlayPresented = true
        } catch let error as GroupServiceError {
            selectedGroupInvitePayload = nil
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            selectedGroupInvitePayload = nil
            setSaveStatus(AppMessage(.failedToGenerateQRCode, .error))
        }
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
        guard let uid = currentUserIDProvider() else {
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
        guard let uid = currentUserIDProvider() else { return }
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
            let uid = currentUserIDProvider()
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

    func handleQRCodeScannerError(_ error: QRCodeScannerError) {
        switch error {
        case .cameraAccessDenied:
            setSaveStatus(AppMessage(.cameraAccessDenied, .error))
        case .cameraUnavailable:
            setSaveStatus(AppMessage(.cameraUnavailable, .error))
        }
    }

    func joinGroupFromQRCodePayload(_ payload: String) async {
        guard currentUserIDProvider() != nil else {
            setSaveStatus(AppMessage(.pleaseSignInFirst, .error))
            return
        }
        guard let inviteToken = GroupInvitePayloadParser.extractInviteToken(from: payload) else {
            setSaveStatus(AppMessage(.invalidInviteQR, .error))
            return
        }
        guard groups.count < currentPlan.maxGroups else {
            setSaveStatus(AppMessage(.groupLimitReached(title: currentPlan.title, maxGroups: currentPlan.maxGroups), .error))
            return
        }

        isJoiningGroup = true
        defer { isJoiningGroup = false }

        do {
            try await groupService.joinGroup(inviteToken: inviteToken)
            await loadGroups()
            setSaveStatus(AppMessage(.joinedGroup, .success))
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToJoinGroup, .error))
        }
    }

    func removeMemberFromSelectedGroup(_ member: GroupMemberPreview) async {
        guard
            let selectedGroupID,
            let requesterUID = currentUserIDProvider()
        else {
            return
        }

        removingMemberID = member.id
        defer { removingMemberID = nil }

        do {
            try await groupService.removeMember(
                groupID: selectedGroupID,
                memberUID: member.id,
                requesterUID: requesterUID
            )

            selectedGroupMembers.removeAll { $0.id == member.id }

            if let index = groups.firstIndex(where: { $0.id == selectedGroupID }) {
                let existing = groups[index]
                groups[index] = GroupSummary(
                    id: existing.id,
                    name: existing.name,
                    ownerUID: existing.ownerUID,
                    members: existing.members.filter { $0.id != member.id },
                    totalMemberCount: max(existing.totalMemberCount - 1, 0)
                )
            }

            cacheGroupsForCurrentUser()
            await loadGroupPreviewIfNeeded(for: selectedGroupID, force: true)
            setSaveStatus(AppMessage(.memberRemoved, .success))
        } catch let error as GroupServiceError {
            setSaveStatus(AppMessage(error.appMessageID, .error))
        } catch {
            setSaveStatus(AppMessage(.failedToRemoveMember, .error))
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

        do {
            let previews = try await groupService.loadMemberPreviews(groupID: groupID, limit: 3)
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
        } catch {
            previewLoadedGroupIDs.remove(groupID)
        }
    }

    private func cacheGroupsForCurrentUser() {
        guard let uid = currentUserIDProvider() else { return }
        groupService.setCachedGroups(groups, for: uid)
    }
}
