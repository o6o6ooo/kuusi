import Testing
@testable import Kuusi

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
}
