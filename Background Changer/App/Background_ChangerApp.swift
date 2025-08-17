//
//  Background_ChangerApp.swift
//

import SwiftUI
import Wallpaper

@main
struct Background_ChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        #if DEBUG
        // In production we use AppCoordinator windows; this WindowGroup is preview/dev-only.
        WindowGroup {
            Text("Background Changer")
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #endif
        
        Settings {
            EmptyView() // Menu bar UI is handled by AppDelegate
        }
    }
}

class AppState: ObservableObject {
    @Published var isMainWindowVisible = false
}

