import Combine
import FirebaseAuth
import Foundation

protocol GroupStoreServicing {
    func cachedGroups(for uid: String) -> [GroupSummary]
    func fetchGroups(for uid: String) async throws -> [GroupSummary]
    func setCachedGroups(_ groups: [GroupSummary], for uid: String)
}

extension GroupService: GroupStoreServicing {}

@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var groups: [GroupSummary] = []
    @Published var selectedGroupID: String?
    @Published private(set) var isLoading = false

    private let groupService: GroupStoreServicing
    private let currentUserIDProvider: @MainActor () -> String?
    private var loadedUID: String?

    init(
        groupService: GroupStoreServicing? = nil,
        currentUserIDProvider: @escaping @MainActor () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.groupService = groupService ?? GroupService()
        self.currentUserIDProvider = currentUserIDProvider
    }

    var selectedGroup: GroupSummary? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }

    func handleCurrentUserChanged(to uid: String?) {
        guard loadedUID != uid else { return }
        loadedUID = uid
        groups = []
        selectedGroupID = nil
        isLoading = false
    }

    func loadCachedThenFetchIfNeeded() async throws {
        guard let uid = currentUserIDProvider() else {
            loadedUID = nil
            replaceGroups([])
            return
        }
        prepareForUser(uid)

        let cached = groupService.cachedGroups(for: uid)
        replaceGroups(cached)

        if cached.isEmpty {
            try await refreshFromFirestore()
        }
    }

    func refreshFromFirestore() async throws {
        guard let uid = currentUserIDProvider() else {
            loadedUID = nil
            replaceGroups([])
            return
        }
        prepareForUser(uid)

        isLoading = true
        defer { isLoading = false }

        let fetched = try await groupService.fetchGroups(for: uid)
        replaceGroups(fetched)
    }

    func replaceGroups(_ newGroups: [GroupSummary]) {
        groups = newGroups
        reconcileSelection()
        cacheGroupsForCurrentUser()
    }

    func appendGroup(_ group: GroupSummary) {
        if !groups.contains(where: { $0.id == group.id }) {
            groups.append(group)
        }
        selectedGroupID = group.id
        cacheGroupsForCurrentUser()
    }

    func updateGroup(_ group: GroupSummary) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        reconcileSelection()
        cacheGroupsForCurrentUser()
    }

    func renameGroup(id: String, name: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        let existing = groups[index]
        groups[index] = GroupSummary(
            id: existing.id,
            name: name,
            ownerUID: existing.ownerUID,
            members: existing.members,
            totalMemberCount: existing.totalMemberCount
        )
        cacheGroupsForCurrentUser()
    }

    func removeGroup(id: String) {
        groups.removeAll { $0.id == id }
        reconcileSelection()
        cacheGroupsForCurrentUser()
    }

    func updateMembers(groupID: String, members: [GroupMemberPreview], totalMemberCount: Int? = nil) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let existing = groups[index]
        groups[index] = GroupSummary(
            id: existing.id,
            name: existing.name,
            ownerUID: existing.ownerUID,
            members: members,
            totalMemberCount: totalMemberCount ?? existing.totalMemberCount
        )
        cacheGroupsForCurrentUser()
    }

    private func reconcileSelection() {
        if let selectedGroupID, groups.contains(where: { $0.id == selectedGroupID }) {
            return
        }
        selectedGroupID = groups.first?.id
    }

    private func prepareForUser(_ uid: String) {
        guard loadedUID != uid else { return }
        loadedUID = uid
        groups = []
        selectedGroupID = nil
    }

    private func cacheGroupsForCurrentUser() {
        guard let uid = currentUserIDProvider() else { return }
        loadedUID = uid
        groupService.setCachedGroups(groups, for: uid)
    }
}
