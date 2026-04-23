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
    func joinGroupFromQRCodePayloadMapsInviteExpiredError() async {
        let groupService = SettingsGroupsServiceSpy()
        groupService.joinGroupError = GroupServiceError.inviteExpired
        let viewModel = makeViewModel(groupService: groupService)

        await viewModel.joinGroupFromQRCodePayload("kuusi://invite/ABC123")

        #expect(viewModel.saveStatusMessage?.id == .inviteQRCodeExpired)
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

    private func makeViewModel(
        groupService: SettingsGroupsServicing = SettingsGroupsServiceSpy(),
        currentUserID: String? = "user-1"
    ) -> SettingsGroupsViewModel {
        SettingsGroupsViewModel(
            groupService: groupService,
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

    func createInvitePayload(groupID: String) async throws -> String {
        if let createInvitePayloadError { throw createInvitePayloadError }
        return "kuusi://invite/\(groupID)"
    }

    func loadMemberPreviews(groupID: String, limit: Int?) async throws -> [GroupMemberPreview] {
        if let loadMemberPreviewsError { throw loadMemberPreviewsError }
        return []
    }

    func createGroup(groupName: String, ownerUID: String) async throws -> GroupSummary {
        if let createGroupError { throw createGroupError }
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
    }

    func leaveGroup(groupID: String, uid: String) async throws {
        if let leaveGroupError { throw leaveGroupError }
    }

    func joinGroup(inviteToken: String) async throws {
        if let joinGroupError { throw joinGroupError }
    }

    func removeMember(groupID: String, memberUID: String, requesterUID: String) async throws {
        if let removeMemberError { throw removeMemberError }
    }

    func setCachedGroups(_ groups: [GroupSummary], for uid: String) {}
}
