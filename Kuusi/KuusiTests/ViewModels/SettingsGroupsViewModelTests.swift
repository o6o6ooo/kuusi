import Foundation
import Testing
@testable import Kuusi

@MainActor
struct SettingsGroupsViewModelTests {
    @Test
    func parserReadsCustomSchemeInvite() {
        let inviteToken = GroupInvitePayloadParser.extractInviteToken(from: "kuusi://invite/ABC123")

        #expect(inviteToken == "abc123")
    }

    @Test
    func parserReadsInviteFromHttpsURL() {
        let inviteToken = GroupInvitePayloadParser.extractInviteToken(from: "https://kuusi.app/invite/Group-42")

        #expect(inviteToken == "group-42")
    }

    @Test
    func parserFallsBackToTrimmedLowercasedText() {
        let inviteToken = GroupInvitePayloadParser.extractInviteToken(from: "  MixedCaseGroup  ")

        #expect(inviteToken == "mixedcasegroup")
    }

    @Test
    func parserRejectsEmptyPayload() {
        let inviteToken = GroupInvitePayloadParser.extractInviteToken(from: "   ")

        #expect(inviteToken == nil)
    }

    @Test
    func createGroupRequiresSignedInUser() async {
        let viewModel = makeViewModel(currentUserID: nil)
        viewModel.createGroupName = "Family"

        await viewModel.createGroup()

        #expect(viewModel.createStatusMessage?.id == .pleaseSignInFirst)
    }

    @Test
    func createGroupRejectsPlanLimit() async {
        let viewModel = makeViewModel()
        viewModel.updateCurrentPlan(.free)
        viewModel.groups = [
            makeGroup(id: "g1", name: "One"),
            makeGroup(id: "g2", name: "Two"),
            makeGroup(id: "g3", name: "Three")
        ]
        viewModel.createGroupName = "Overflow"

        await viewModel.createGroup()

        #expect(viewModel.createStatusMessage?.id == .groupLimitReached(title: "Free", maxGroups: 3))
    }

    @Test
    func createGroupAppendsSelectedGroupCachesAndShowsSuccess() async {
        let groupService = SettingsGroupsServiceSpy()
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.createGroupName = "Family"

        await viewModel.createGroup()

        #expect(groupService.createdGroups.count == 1)
        #expect(groupService.createdGroups.first?.groupName == "Family")
        #expect(groupService.createdGroups.first?.ownerUID == "user-1")
        #expect(viewModel.groups.map(\.id) == ["created-group"])
        #expect(viewModel.selectedGroupID == "created-group")
        #expect(viewModel.editableGroupName == "Family")
        #expect(viewModel.createGroupName.isEmpty)
        #expect(viewModel.createStatusMessage?.id == .groupCreated)
        #expect(groupService.cachedGroupsAssignments.last?.uid == "user-1")
        #expect(groupService.cachedGroupsAssignments.last?.groups.map(\.id) == ["created-group"])
        #expect(groupService.loadMemberPreviewsCalls.contains { $0.groupID == "created-group" && $0.limit == 3 })
    }

    @Test
    func saveGroupNameMapsGroupServiceError() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.updateGroupNameError = GroupServiceError.groupNotFound
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.groups = [makeGroup(id: "group-1", name: "Family")]
        viewModel.selectedGroupID = "group-1"
        viewModel.editableGroupName = "Updated"

        await viewModel.saveGroupName()

        #expect(viewModel.saveStatusMessage?.id == .groupNotFound)
    }

    @Test
    func leaveSelectedGroupMapsOwnerCannotLeaveError() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.leaveGroupError = GroupServiceError.ownerCannotLeave
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.groups = [makeGroup(id: "group-1", name: "Family")]
        viewModel.selectedGroupID = "group-1"

        await viewModel.leaveSelectedGroup()

        #expect(viewModel.saveStatusMessage?.id == .ownerCannotLeave)
    }

    @Test
    func leaveSelectedGroupRemovesCurrentGroupSelectsNextAndShowsSuccess() async {
        let groupService = SettingsGroupsServiceSpy()
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.groups = [
            makeGroup(id: "group-1", name: "Family"),
            makeGroup(id: "group-2", name: "Friends")
        ]
        viewModel.selectedGroupID = "group-1"
        viewModel.editableGroupName = "Family"

        await viewModel.leaveSelectedGroup()

        #expect(groupService.leaveGroupCalls.count == 1)
        #expect(groupService.leaveGroupCalls.first?.groupID == "group-1")
        #expect(groupService.leaveGroupCalls.first?.uid == "user-1")
        #expect(viewModel.groups.map(\.id) == ["group-2"])
        #expect(viewModel.selectedGroupID == "group-2")
        #expect(viewModel.editableGroupName == "Friends")
        #expect(viewModel.saveStatusMessage?.id == .leftGroup)
        #expect(groupService.cachedGroupsAssignments.last?.groups.map(\.id) == ["group-2"])
        #expect(groupService.loadMemberPreviewsCalls.contains { $0.groupID == "group-2" && $0.limit == 3 })
    }

    @Test
    func joinGroupFromQRCodePayloadMapsInviteExpiredError() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.joinGroupError = GroupServiceError.inviteExpired
        let viewModel = makeViewModel(groupService: groupService)

        await viewModel.joinGroupFromQRCodePayload("kuusi://invite/ABC123")

        #expect(viewModel.saveStatusMessage?.id == .inviteQRCodeExpired)
    }

    @Test
    func joinGroupFromQRCodePayloadAddsJoinedGroupAndShowsSuccess() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.joinGroupResult = JoinGroupResult(
            group: makeGroup(id: "group-2", name: "Friends"),
            didJoin: true
        )
        let viewModel = makeViewModel(groupService: groupService)

        await viewModel.joinGroupFromQRCodePayload("kuusi://invite/ABC123")

        #expect(groupService.joinGroupInviteTokens == ["abc123"])
        #expect(viewModel.groups.map(\.id) == ["group-2"])
        #expect(viewModel.selectedGroupID == "group-2")
        #expect(viewModel.editableGroupName == "Friends")
        #expect(viewModel.saveStatusMessage?.id == .joinedGroup)
        #expect(groupService.cachedGroupsAssignments.last?.groups.map(\.id) == ["group-2"])
        #expect(groupService.loadMemberPreviewsCalls.count == 1)
        #expect(groupService.loadMemberPreviewsCalls.first?.groupID == "group-2")
    }

    @Test
    func joinGroupFromQRCodePayloadShowsAlreadyJoinedMessage() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.joinGroupResult = JoinGroupResult(
            group: makeGroup(id: "group-2", name: "Friends"),
            didJoin: false
        )
        let viewModel = makeViewModel(groupService: groupService)

        await viewModel.joinGroupFromQRCodePayload("kuusi://invite/ABC123")

        #expect(viewModel.groups.map(\.id) == ["group-2"])
        #expect(viewModel.selectedGroupID == "group-2")
        #expect(viewModel.saveStatusMessage?.id == .alreadyJoinedGroup)
    }

    @Test
    func handleSelectedQRCodePhotoDataMapsMissingQRCode() async {
        let viewModel = makeViewModel()

        await viewModel.handleSelectedQRCodePhotoData(Data())

        #expect(viewModel.saveStatusMessage?.id == .qrCodeNotFoundInImage)
    }

    @Test
    func handleQRCodeScannerErrorMapsCameraAccessDenied() {
        let viewModel = makeViewModel()

        viewModel.handleQRCodeScannerError(.cameraAccessDenied)

        #expect(viewModel.saveStatusMessage?.id == .cameraAccessDenied)
    }

    @Test
    func handleQRCodeScannerErrorMapsCameraUnavailable() {
        let viewModel = makeViewModel()

        viewModel.handleQRCodeScannerError(.cameraUnavailable)

        #expect(viewModel.saveStatusMessage?.id == .cameraUnavailable)
    }

    @Test
    func removeMemberFromSelectedGroupMapsPermissionError() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.removeMemberError = GroupServiceError.onlyOwnerCanRemoveMembers
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.groups = [
            GroupSummary(
                id: "group-1",
                name: "Family",
                ownerUID: "owner",
                members: [GroupMemberPreview(id: "member-1", name: "Mia", icon: "🌸", bgColour: "#fff", isOwner: false)],
                totalMemberCount: 1
            )
        ]
        viewModel.selectedGroupID = "group-1"

        await viewModel.removeMemberFromSelectedGroup(
            GroupMemberPreview(id: "member-1", name: "Mia", icon: "🌸", bgColour: "#fff", isOwner: false)
        )

        #expect(viewModel.saveStatusMessage?.id == .onlyOwnerCanRemoveMembers)
    }

    @Test
    func deleteSelectedGroupRemovesCurrentGroupSelectsNextAndShowsSuccess() async {
        let groupService = SettingsGroupsServiceSpy()
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.groups = [
            makeGroup(id: "group-1", name: "Family"),
            makeGroup(id: "group-2", name: "Friends")
        ]
        viewModel.selectedGroupID = "group-1"
        viewModel.editableGroupName = "Family"

        await viewModel.deleteSelectedGroup()

        #expect(groupService.deletedGroupIDs == ["group-1"])
        #expect(viewModel.groups.map(\.id) == ["group-2"])
        #expect(viewModel.selectedGroupID == "group-2")
        #expect(viewModel.editableGroupName == "Friends")
        #expect(viewModel.saveStatusMessage?.id == .groupDeleted)
        #expect(groupService.cachedGroupsAssignments.last?.groups.map(\.id) == ["group-2"])
        #expect(groupService.loadMemberPreviewsCalls.contains { $0.groupID == "group-2" && $0.limit == 3 })
    }

    @Test
    func removeMemberFromSelectedGroupUpdatesMembersCachesAndShowsSuccess() async {
        let groupService = SettingsGroupsServiceSpy()
        let targetMember = GroupMemberPreview(id: "member-1", name: "Mia", icon: "🌸", bgColour: "#fff", isOwner: false)
        let remainingMember = GroupMemberPreview(id: "member-2", name: "Noah", icon: "🌿", bgColour: "#eee", isOwner: false)
        groupService.memberPreviewsByGroupID["group-1"] = [targetMember, remainingMember]
        let viewModel = makeViewModel(groupService: groupService)
        viewModel.groups = [
            GroupSummary(
                id: "group-1",
                name: "Family",
                ownerUID: "owner",
                members: [targetMember, remainingMember],
                totalMemberCount: 2
            )
        ]
        viewModel.selectedGroupID = "group-1"
        await viewModel.presentMemberList()

        await viewModel.removeMemberFromSelectedGroup(targetMember)

        #expect(groupService.removeMemberCalls.count == 1)
        #expect(groupService.removeMemberCalls.first?.groupID == "group-1")
        #expect(groupService.removeMemberCalls.first?.memberUID == "member-1")
        #expect(groupService.removeMemberCalls.first?.requesterUID == "user-1")
        #expect(viewModel.selectedGroupMembers.map(\.id) == ["member-2"])
        #expect(viewModel.groups.first?.members.map(\.id) == ["member-2"])
        #expect(viewModel.groups.first?.totalMemberCount == 1)
        #expect(viewModel.saveStatusMessage?.id == .memberRemoved)
        #expect(groupService.cachedGroupsAssignments.last?.groups.first?.totalMemberCount == 1)
        #expect(groupService.loadMemberPreviewsCalls.contains { $0.groupID == "group-1" && $0.limit == 3 })
    }

    private func makeViewModel(
        groupService: SettingsGroupsServicing? = nil,
        currentUserID: String? = "user-1"
    ) -> SettingsGroupsViewModel {
        let groupService = groupService ?? SettingsGroupsServiceSpy()
        let groupStore = GroupStore(
            groupService: groupService,
            currentUserIDProvider: { currentUserID }
        )
        return SettingsGroupsViewModel(
            groupService: groupService,
            groupStore: groupStore,
            currentUserIDProvider: { currentUserID }
        )
    }

    private func makeGroup(id: String, name: String) -> GroupSummary {
        GroupSummary(id: id, name: name, ownerUID: "owner", members: [], totalMemberCount: 1)
    }
}

private final class SettingsGroupsServiceSpy: SettingsGroupsServicing {
    var createInvitePayloadError: Error?
    var loadMemberPreviewsError: Error?
    var createGroupError: Error?
    var fetchGroupsError: Error?
    var updateGroupNameError: Error?
    var deleteGroupError: Error?
    var leaveGroupError: Error?
    var joinGroupError: Error?
    var removeMemberError: Error?
    var fetchedGroups: [GroupSummary] = []
    var createdGroups: [(groupName: String, ownerUID: String)] = []
    var loadMemberPreviewsCalls: [(groupID: String, limit: Int?)] = []
    var deletedGroupIDs: [String] = []
    var leaveGroupCalls: [(groupID: String, uid: String)] = []
    var joinGroupInviteTokens: [String] = []
    var joinGroupResult: JoinGroupResult?
    var removeMemberCalls: [(groupID: String, memberUID: String, requesterUID: String)] = []
    var cachedGroupsAssignments: [(uid: String, groups: [GroupSummary])] = []
    var memberPreviewsByGroupID: [String: [GroupMemberPreview]] = [:]

    func cachedGroups(for uid: String) -> [GroupSummary] {
        cachedGroupsAssignments.last(where: { $0.uid == uid })?.groups ?? fetchedGroups
    }

    func createInvitePayload(groupID: String) async throws -> String {
        if let createInvitePayloadError { throw createInvitePayloadError }
        return "kuusi://invite/\(groupID)"
    }

    func loadMemberPreviews(groupID: String, limit: Int?) async throws -> [GroupMemberPreview] {
        if let loadMemberPreviewsError { throw loadMemberPreviewsError }
        loadMemberPreviewsCalls.append((groupID, limit))
        return memberPreviewsByGroupID[groupID] ?? []
    }

    func createGroup(groupName: String, ownerUID: String) async throws -> GroupSummary {
        if let createGroupError { throw createGroupError }
        createdGroups.append((groupName, ownerUID))
        return GroupSummary(id: "created-group", name: groupName, ownerUID: ownerUID, members: [], totalMemberCount: 1)
    }

    func fetchGroups(for uid: String) async throws -> [GroupSummary] {
        if let fetchGroupsError { throw fetchGroupsError }
        return fetchedGroups
    }

    func updateGroupName(groupID: String, name: String) async throws {
        if let updateGroupNameError { throw updateGroupNameError }
    }

    func deleteGroup(groupID: String) async throws {
        if let deleteGroupError { throw deleteGroupError }
        deletedGroupIDs.append(groupID)
    }

    func leaveGroup(groupID: String, uid: String) async throws {
        if let leaveGroupError { throw leaveGroupError }
        leaveGroupCalls.append((groupID, uid))
    }

    func joinGroup(inviteToken: String) async throws -> JoinGroupResult {
        if let joinGroupError { throw joinGroupError }
        joinGroupInviteTokens.append(inviteToken)
        return joinGroupResult ?? JoinGroupResult(
            group: GroupSummary(id: "joined-group", name: "Joined", ownerUID: "owner", members: [], totalMemberCount: 1),
            didJoin: true
        )
    }

    func removeMember(groupID: String, memberUID: String, requesterUID: String) async throws {
        if let removeMemberError { throw removeMemberError }
        removeMemberCalls.append((groupID, memberUID, requesterUID))
        if var previews = memberPreviewsByGroupID[groupID] {
            previews.removeAll { $0.id == memberUID }
            memberPreviewsByGroupID[groupID] = previews
        }
    }

    func setCachedGroups(_ groups: [GroupSummary], for uid: String) {
        cachedGroupsAssignments.append((uid, groups))
    }
}
