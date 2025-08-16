//
//  Background_ChangerApp.swift
//

import SwiftUI

@main
struct Background_ChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            EmptyView() // Menu bar UI is handled by AppDelegate
        }
    }
}

class AppState: ObservableObject {
    @Published var isMainWindowVisible = false
}

