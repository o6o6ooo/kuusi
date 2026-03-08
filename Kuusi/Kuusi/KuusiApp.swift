//
//  KuusiApp.swift
//  Kuusi
//
//  Created by Sakura Wallace on 06/03/2026.
//

import SwiftUI

@main
struct KuusiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .controlSize(.small)
                .environmentObject(appState)
        }
    }
}
