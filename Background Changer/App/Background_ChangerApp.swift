//
//  Background_ChangerApp.swift
//

import SwiftUI

@main
struct Background_ChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No window needed, only menu bar UI
        }
    }
}

