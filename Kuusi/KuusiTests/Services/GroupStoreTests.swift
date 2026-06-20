import Testing
@testable import Kuusi

@MainActor
struct GroupStoreTests {
    @Test
    func loadCachedThenFetchIfNeededUsesCachedGroupsWithoutFetching() async throws {
        let service = GroupStoreServiceSpy()
        service.cachedGroupsByUID["user-1"] = [
            makeGroup(id: "group-a", name: "Family"),
            makeGroup(id: "group-b", name: "Friends")
        ]
        let store = makeStore(service: service)

        try await store.loadCachedThenFetchIfNeeded()

        #expect(store.groups.map(\.id) == ["group-a", "group-b"])
        #expect(store.selectedGroupID == "group-a")
        #expect(service.cachedGroupCalls == ["user-1"])
        #expect(service.fetchGroupCalls.isEmpty)
        #expect(service.cachedGroupAssignments.last?.uid == "user-1")
        #expect(service.cachedGroupAssignments.last?.groups.map(\.id) == ["group-a", "group-b"])
    }

    @Test
    func loadCachedThenFetchIfNeededFetchesWhenCacheIsEmpty() async throws {
        let service = GroupStoreServiceSpy()
        service.fetchedGroupsByUID["user-1"] = [
            makeGroup(id: "group-fetched", name: "Fetched")
        ]
        let store = makeStore(service: service)

        try await store.loadCachedThenFetchIfNeeded()

        #expect(store.groups.map(\.id) == ["group-fetched"])
        #expect(store.selectedGroupID == "group-fetched")
        #expect(service.cachedGroupCalls == ["user-1"])
        #expect(service.fetchGroupCalls == ["user-1"])
        #expect(service.cachedGroupAssignments.last?.groups.map(\.id) == ["group-fetched"])
        #expect(store.isLoading == false)
    }

    @Test
    func replaceGroupsKeepsValidSelectionAndFallsBackWhenSelectionIsRemoved() {
        let service = GroupStoreServiceSpy()
        let store = makeStore(service: service)
        store.replaceGroups([
            makeGroup(id: "group-a", name: "Family"),
            makeGroup(id: "group-b", name: "Friends")
        ])
        store.selectedGroupID = "group-b"

        store.replaceGroups([
            makeGroup(id: "group-a", name: "Family Updated"),
            makeGroup(id: "group-b", name: "Friends Updated")
        ])

        #expect(store.selectedGroupID == "group-b")
        #expect(store.selectedGroup?.name == "Friends Updated")

        store.replaceGroups([
            makeGroup(id: "group-c", name: "New")
        ])

        #expect(store.selectedGroupID == "group-c")
        #expect(store.selectedGroup?.name == "New")
    }

    @Test
    func handleCurrentUserChangedClearsGroupsSelectionAndLoadingState() async throws {
        let service = GroupStoreServiceSpy()
        service.fetchedGroupsByUID["user-1"] = [
            makeGroup(id: "group-a", name: "Family")
        ]
        let currentUserIDProvider = CurrentUserIDProvider("user-1")
        let store = GroupStore(
            groupService: service,
            currentUserIDProvider: { currentUserIDProvider.currentUserID }
        )
        try await store.refreshFromFirestore()

        store.handleCurrentUserChanged(to: "user-2")

        #expect(store.groups.isEmpty)
        #expect(store.selectedGroupID == nil)
        #expect(store.isLoading == false)

        currentUserIDProvider.currentUserID = "user-2"
        service.fetchedGroupsByUID["user-2"] = [
            makeGroup(id: "group-b", name: "Friends")
        ]
        try await store.refreshFromFirestore()

        #expect(store.groups.map(\.id) == ["group-b"])
        #expect(store.selectedGroupID == "group-b")
        #expect(service.fetchGroupCalls == ["user-1", "user-2"])
    }

    @Test
    func loadCachedThenFetchIfNeededClearsStateWhenUserIsMissing() async throws {
        let service = GroupStoreServiceSpy()
        let store = GroupStore(
            groupService: service,
            currentUserIDProvider: { "user-1" }
        )
        store.replaceGroups([
            makeGroup(id: "group-a", name: "Family")
        ])
        let missingUserStore = GroupStore(
            groupService: service,
            currentUserIDProvider: { nil }
        )
        missingUserStore.replaceGroups(store.groups)

        try await missingUserStore.loadCachedThenFetchIfNeeded()

        #expect(missingUserStore.groups.isEmpty)
        #expect(missingUserStore.selectedGroupID == nil)
        #expect(service.cachedGroupCalls.isEmpty)
        #expect(service.fetchGroupCalls.isEmpty)
    }
}

@MainActor
private func makeStore(
    service: GroupStoreServiceSpy,
    currentUserID: String? = "user-1"
) -> GroupStore {
    GroupStore(
        groupService: service,
        currentUserIDProvider: { currentUserID }
    )
}

private func makeGroup(id: String, name: String) -> GroupSummary {
    GroupSummary(id: id, name: name, ownerUID: "owner", members: [], totalMemberCount: 1)
}

private final class CurrentUserIDProvider {
    var currentUserID: String?

    init(_ currentUserID: String?) {
        self.currentUserID = currentUserID
    }
}

private final class GroupStoreServiceSpy: GroupStoreServicing {
    var cachedGroupsByUID: [String: [GroupSummary]] = [:]
    var fetchedGroupsByUID: [String: [GroupSummary]] = [:]
    var cachedGroupCalls: [String] = []
    var fetchGroupCalls: [String] = []
    var cachedGroupAssignments: [(uid: String, groups: [GroupSummary])] = []

    func cachedGroups(for uid: String) -> [GroupSummary] {
        cachedGroupCalls.append(uid)
        return cachedGroupsByUID[uid] ?? []
    }

    func fetchGroups(for uid: String) async throws -> [GroupSummary] {
        fetchGroupCalls.append(uid)
        return fetchedGroupsByUID[uid] ?? []
    }

    func setCachedGroups(_ groups: [GroupSummary], for uid: String) {
        cachedGroupAssignments.append((uid, groups))
        cachedGroupsByUID[uid] = groups
    }
}
