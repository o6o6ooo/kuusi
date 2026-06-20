//
//  KuusiApp.swift
//  Kuusi
//
//  Created by Sakura Wallace on 06/03/2026.
//

import GoogleSignIn
import GoogleMobileAds
import FirebaseAuth
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

    init() {
        _appState = StateObject(wrappedValue: AppState())
        _consentStore = StateObject(wrappedValue: ConsentStore())
        _toastCenter = StateObject(wrappedValue: AppToastCenter())
#if DEBUG
        if let groupService = UITestEnvironment.makeGroupService() {
            _groupStore = StateObject(wrappedValue: GroupStore(
                groupService: groupService,
                currentUserIDProvider: { UITestEnvironment.currentUserID }
            ))
        } else {
            _groupStore = StateObject(wrappedValue: GroupStore())
        }

        if let isPremiumActive = UITestEnvironment.subscriptionIsPremiumActive {
            _subscriptionStore = StateObject(wrappedValue: SubscriptionStore(uiTestIsPremiumActive: isPremiumActive))
        } else {
            _subscriptionStore = StateObject(wrappedValue: SubscriptionStore())
        }

        if !UITestEnvironment.isRunningUITests {
            MobileAds.shared.start()
        }
#else
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
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    appState.handleScenePhaseChange(newPhase)
                }
                .onChange(of: appState.currentUser?.uid) { _, uid in
                    groupStore.handleCurrentUserChanged(to: uid)
                }
        }
    }
}
