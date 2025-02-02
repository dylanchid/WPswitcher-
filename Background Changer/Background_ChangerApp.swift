//
//  Background_ChangerApp.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
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
