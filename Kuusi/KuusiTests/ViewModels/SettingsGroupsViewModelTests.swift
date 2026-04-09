import Testing
@testable import Kuusi

struct SettingsGroupsViewModelTests {
    @Test
    func parserReadsCustomSchemeInvite() {
        let groupID = GroupInvitePayloadParser.extractGroupID(from: "kuusi://invite/ABC123")

        #expect(groupID == "abc123")
    }

    @Test
    func parserReadsInviteFromHttpsURL() {
        let groupID = GroupInvitePayloadParser.extractGroupID(from: "https://kuusi.app/invite/Group-42")

        #expect(groupID == "group-42")
    }

    @Test
    func parserFallsBackToTrimmedLowercasedText() {
        let groupID = GroupInvitePayloadParser.extractGroupID(from: "  MixedCaseGroup  ")

        #expect(groupID == "mixedcasegroup")
    }

    @Test
    func parserRejectsEmptyPayload() {
        let groupID = GroupInvitePayloadParser.extractGroupID(from: "   ")

        #expect(groupID == nil)
    }
}
