#if DEBUG
	import Foundation
	import UIKit

	enum UITestEnvironment {
		private static let userID = "ui-test-user-\(UUID().uuidString)"

		private static var launchArguments: [String] {
			ProcessInfo.processInfo.arguments
		}

		static var isRunningUITests: Bool {
			launchArguments.contains("UI_TEST_ROUTE_SIGNED_OUT")
				|| launchArguments.contains("UI_TEST_ROUTE_LOCKED")
				|| launchArguments.contains("UI_TEST_ROUTE_SIGNED_IN")
		}

		static var forcesEmptyGroups: Bool {
			launchArguments.contains("UI_TEST_FORCE_EMPTY_GROUPS")
		}

		static var currentUserID: String? {
			guard
				launchArguments.contains("UI_TEST_ROUTE_LOCKED")
					|| launchArguments.contains("UI_TEST_ROUTE_SIGNED_IN")
			else {
				return nil
			}
			return userID
		}

		static var subscriptionIsPremiumActive: Bool? {
			guard isRunningUITests else { return nil }
			return launchArguments.contains("UI_TEST_PREMIUM")
		}

		static var consentFixture: ConsentStore.UITestFixture? {
			guard isRunningUITests else { return nil }
			return ConsentStore.UITestFixture(
				canRequestAds: launchArguments.contains("UI_TEST_SHOW_INLINE_ADS"),
				isPrivacyOptionsRequired: launchArguments.contains(
					"UI_TEST_PRIVACY_CHOICES_REQUIRED"
				)
			)
		}

		static var user: AppUser {
			AppUser(
				id: userID,
				name: "UI Test User",
				icon: "🌲",
				bgColour: "#A5C3DE",
				usageMB: 128,
				groups: groups.map(\.id)
			)
		}

		static var groups: [GroupSummary] {
			guard !forcesEmptyGroups else { return [] }
			return [
				GroupSummary(
					id: "ui-test-group-family",
					name: "Family",
					ownerUID: userID,
					members: [
						GroupMemberPreview(
							id: userID,
							name: "UI Test User",
							icon: "🌲",
							bgColour: "#A5C3DE",
							isOwner: true
						),
						GroupMemberPreview(
							id: "ui-test-member",
							name: "Mika",
							icon: "🌸",
							bgColour: "#F7C8D8",
							isOwner: false
						),
					],
					totalMemberCount: 2
				),
				GroupSummary(
					id: "ui-test-group-friends",
					name: "Friends",
					ownerUID: userID,
					members: [
						GroupMemberPreview(
							id: userID,
							name: "UI Test User",
							icon: "🌲",
							bgColour: "#A5C3DE",
							isOwner: true
						)
					],
					totalMemberCount: 1
				),
			]
		}

		static var photos: [FeedPhoto] {
			(0..<12).map { index in
				let timestamp = 1_750_000_000 - TimeInterval(index * 10_000)
				return FeedPhoto(
					id: "ui-test-photo-\(index + 1)",
					previewStoragePath: nil,
					thumbnailStoragePath: nil,
					groupID: "ui-test-group-family",
					postedBy: userID,
					date: Date(timeIntervalSince1970: timestamp),
					hashtags: index.isMultiple(of: 2)
						? ["family", "spring"] : ["winter"],
					caption: index == 0 ? "UI test photo" : nil,
					isFavourite: index == 0 || index == 3,
					sizeMB: 1,
					aspectRatio: 1,
					createdAt: Date(timeIntervalSince1970: timestamp)
				)
			}
		}

		static func makeGroupService() -> UITestGroupService? {
			guard isRunningUITests else { return nil }
			return UITestGroupService()
		}

		static func makePhotoCollectionFeedService()
			-> UITestPhotoCollectionFeedService?
		{
			guard isRunningUITests else { return nil }
			return UITestPhotoCollectionFeedService()
		}

		static func makeProfileUserService() -> UITestProfileUserService? {
			guard isRunningUITests else { return nil }
			return UITestProfileUserService()
		}
	}

	final class UITestGroupService: SettingsGroupsServicing {
		private var cachedGroupsByUID: [String: [GroupSummary]] = [:]
		private var cachedMemberListsByGroupID: [String: [GroupMemberPreview]] = [:]

		func cachedGroups(for uid: String) -> [GroupSummary] {
			cachedGroupsByUID[uid] ?? UITestEnvironment.groups
		}

		func fetchGroups(for uid: String) async throws -> [GroupSummary] {
			UITestEnvironment.groups
		}

		func setCachedGroups(_ groups: [GroupSummary], for uid: String) {
			cachedGroupsByUID[uid] = groups
		}

		func createInvitePayload(groupID: String) async throws -> String {
			"kuusi://invite/\(groupID)"
		}

		func loadMemberPreviews(groupID: String, limit: Int?) async throws
			-> [GroupMemberPreview]
		{
			let members =
				UITestEnvironment.groups.first(where: { $0.id == groupID })?.members
				?? []
			if let limit {
				return Array(members.prefix(limit))
			}
			return members
		}

		func cachedMemberList(for groupID: String) -> [GroupMemberPreview]? {
			cachedMemberListsByGroupID[groupID]
		}

		func setCachedMemberList(
			_ members: [GroupMemberPreview],
			for groupID: String
		) {
			cachedMemberListsByGroupID[groupID] = members
		}

		func createGroup(groupName: String, ownerUID: String) async throws
			-> GroupSummary
		{
			GroupSummary(
				id: "ui-test-created-group",
				name: groupName,
				ownerUID: ownerUID,
				members: [],
				totalMemberCount: 1
			)
		}

		func updateGroupName(groupID: String, name: String) async throws {}
		func deleteGroup(groupID: String) async throws {}
		func leaveGroup(groupID: String, uid: String) async throws {}

		func joinGroup(inviteToken: String) async throws -> JoinGroupResult {
			JoinGroupResult(
				group: GroupSummary(
					id: "ui-test-joined-group",
					name: "Joined",
					ownerUID: "ui-test-owner",
					members: [],
					totalMemberCount: 1
				),
				didJoin: true
			)
		}

		func removeMember(groupID: String, memberUID: String, requesterUID: String)
			async throws
		{}
	}

	final class UITestPhotoCollectionFeedService: PhotoCollectionFeedServicing {
		func fetchRecentPhotoBatch(
			userID: String,
			groupIDs: [String],
			limit: Int,
			startAfter cursor: FeedPageCursor?,
			favouriteIDs: Set<String>?
		) async throws -> RecentPhotoFetchResult {
			let photos = UITestEnvironment.photos
				.filter { photo in
					guard let groupID = photo.groupID else { return false }
					return groupIDs.contains(groupID)
				}
				.filter { photo in
					guard let cursor else { return true }
					return (photo.date ?? photo.createdAt ?? .distantPast) < cursor.date
				}
			return RecentPhotoFetchResult(
				photos: Array(photos.prefix(limit)),
				hasMore: photos.count > limit,
				nextCursor: nil,
				favouriteIDs: favouriteIDs
					?? Set(photos.filter { $0.isFavourite }.map(\.id))
			)
		}

		func fetchPhotoCount(groupID: String) async throws -> Int {
			UITestEnvironment.photos.filter { $0.groupID == groupID }.count
		}
	}

	final class UITestProfileUserService: SettingsProfileUserServicing {
		func fetchCachedUser(uid: String) async throws -> AppUser? {
			UITestEnvironment.user
		}

		func updateProfile(
			uid: String,
			name: String,
			icon: String,
			bgColour: String
		) async throws {}
		func cacheUserProfile(
			uid: String,
			name: String,
			icon: String,
			bgColour: String,
			usageMB: Double
		) {}
	}
#endif
