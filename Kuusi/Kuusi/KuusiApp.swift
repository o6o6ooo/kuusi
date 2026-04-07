//
//  KuusiApp.swift
//  Kuusi
//
//  Created by Sakura Wallace on 06/03/2026.
//

import SwiftUI

@main
struct KuusiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .controlSize(.small)
                .environmentObject(appState)
                .environmentObject(subscriptionStore)
                .onChange(of: scenePhase) { _, newPhase in
                    appState.handleScenePhaseChange(newPhase)
                }
        }
    }
}
