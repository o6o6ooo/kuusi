import Testing
@testable import Kuusi

struct GroupServiceTests {
    @Test
    func cachedGroupsRoundTripThroughCacheStore() {
        let service = GroupService()
        let uid = "group-cache-tests-round-trip"
        let groups = [
            GroupSummary(
                id: "group-a",
                name: "Family",
                ownerUID: "owner-1",
                members: [
                    GroupMemberPreview(id: "owner-1", name: "Sakura", icon: "🌲", bgColour: "#123456", isOwner: true),
                    GroupMemberPreview(id: "member-1", name: "Mika", icon: "🌸", bgColour: "#abcdef", isOwner: false)
                ],
                totalMemberCount: 2
            )
        ]

        service.clearCachedGroups(for: uid)
        service.setCachedGroups(groups, for: uid)
        let cached = service.cachedGroups(for: uid)

        #expect(cached.count == 1)
        #expect(cached.first?.id == "group-a")
        #expect(cached.first?.name == "Family")
        #expect(cached.first?.ownerUID == "owner-1")
        #expect(cached.first?.totalMemberCount == 2)
        #expect(cached.first?.members.count == 2)
        #expect(cached.first?.members.first?.name == "Sakura")

        service.clearCachedGroups(for: uid)
    }

    @Test
    func clearCachedGroupsRemovesStoredValue() {
        let service = GroupService()
        let uid = "group-cache-tests-clear"

        service.setCachedGroups([
            GroupSummary(id: "group-a", name: "Family", ownerUID: "owner-1", members: [], totalMemberCount: 1)
        ], for: uid)
        service.clearCachedGroups(for: uid)

        #expect(service.cachedGroups(for: uid).isEmpty)
    }
}
