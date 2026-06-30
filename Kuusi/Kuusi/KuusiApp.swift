//
//  KuusiApp.swift
//  Kuusi
//
//  Created by Sakura Wallace on 06/03/2026.
//

import FirebaseAuth
import GoogleMobileAds
import GoogleSignIn
import SwiftUI

@main
struct KuusiApp: App {
	@Environment(\.scenePhase) private var scenePhase
	@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
	@StateObject private var appState: AppState
	@StateObject private var consentStore: ConsentStore
	@StateObject private var groupStore: GroupStore
	@StateObject private var toastCenter: AppToastCenter
	@StateObject private var subscriptionStore: SubscriptionStore
	@State private var pendingInvitePayload: String?

	init() {
		_appState = StateObject(wrappedValue: AppState())
		_toastCenter = StateObject(wrappedValue: AppToastCenter())
		#if DEBUG
			if let consentFixture = UITestEnvironment.consentFixture {
				_consentStore = StateObject(
					wrappedValue: ConsentStore(uiTestFixture: consentFixture)
				)
			} else {
				_consentStore = StateObject(wrappedValue: ConsentStore())
			}

			if let groupService = UITestEnvironment.makeGroupService() {
				_groupStore = StateObject(
					wrappedValue: GroupStore(
						groupService: groupService,
						currentUserIDProvider: { UITestEnvironment.currentUserID }
					)
				)
			} else {
				_groupStore = StateObject(wrappedValue: GroupStore())
			}

			if let isPremiumActive = UITestEnvironment.subscriptionIsPremiumActive {
				_subscriptionStore = StateObject(
					wrappedValue: SubscriptionStore(
						uiTestIsPremiumActive: isPremiumActive
					)
				)
			} else {
				_subscriptionStore = StateObject(wrappedValue: SubscriptionStore())
			}

			if !UITestEnvironment.isRunningUITests {
				MobileAds.shared.start()
			}
		#else
			_consentStore = StateObject(wrappedValue: ConsentStore())
			_groupStore = StateObject(wrappedValue: GroupStore())
			_subscriptionStore = StateObject(wrappedValue: SubscriptionStore())
			MobileAds.shared.start()
		#endif
	}

	var body: some Scene {
		WindowGroup {
			RootView()
				.controlSize(.small)
				.environmentObject(appState)
				.environmentObject(consentStore)
				.environmentObject(groupStore)
				.environmentObject(toastCenter)
				.environmentObject(subscriptionStore)
				.onOpenURL { url in
					handleOpenURL(url)
				}
				.onChange(of: scenePhase) { _, newPhase in
					appState.handleScenePhaseChange(newPhase)
				}
				.onChange(of: appState.currentUser?.uid) { _, uid in
					groupStore.handleCurrentUserChanged(to: uid)
				}
				.onChange(of: appState.route) { _, route in
					guard route == .signedIn else { return }
					joinPendingInviteIfNeeded()
				}
		}
	}

	private func handleOpenURL(_ url: URL) {
		if GIDSignIn.sharedInstance.handle(url) {
			return
		}

		guard
			GroupInvitePayloadParser.extractInviteToken(from: url.absoluteString)
				!= nil
		else { return }
		pendingInvitePayload = url.absoluteString
		joinPendingInviteIfNeeded()
	}

	private func joinPendingInviteIfNeeded() {
		guard appState.route == .signedIn else { return }
		guard let payload = pendingInvitePayload else { return }
		pendingInvitePayload = nil

		Task {
			await joinGroup(from: payload)
		}
	}

	@MainActor
	private func joinGroup(from payload: String) async {
		guard
			let inviteToken = GroupInvitePayloadParser.extractInviteToken(
				from: payload
			)
		else {
			appState.toastMessage = AppMessage(.invalidInviteQR, .error)
			return
		}

		let currentPlan = PlanAccessPolicy.currentPlan(
			isPremiumActive: subscriptionStore.isPremiumActive
		)
		guard groupStore.groups.count < currentPlan.maxGroups else {
			appState.toastMessage = AppMessage(
				.groupLimitReached(
					title: currentPlan.title,
					maxGroups: currentPlan.maxGroups
				),
				.error
			)
			return
		}

		AppTelemetry.setOperation(.groupJoin)
		defer { AppTelemetry.clearOperation() }

		do {
			let inviteGroupService = GroupService()
			let result = try await inviteGroupService.joinGroup(
				inviteToken: inviteToken
			)
			groupStore.appendGroup(result.group)
			appState.toastMessage = AppMessage(
				result.didJoin ? .joinedGroup : .alreadyJoinedGroup,
				.success
			)
		} catch let error as GroupServiceError {
			appState.toastMessage = AppMessage(error.appMessageID, .error)
		} catch {
			appState.toastMessage = AppMessage(.failedToJoinGroup, .error)
		}
	}
}
