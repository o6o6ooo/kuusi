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
    @StateObject private var appState = AppState()
    @StateObject private var consentStore = ConsentStore()
    @StateObject private var groupStore = GroupStore()
    @StateObject private var toastCenter = AppToastCenter()
    @StateObject private var subscriptionStore = SubscriptionStore()

    init() {
        MobileAds.shared.start()
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
