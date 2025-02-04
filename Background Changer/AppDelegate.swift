//
//  AppDelegate.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
//


import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: "Wallpaper Changer")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover UI
        popover = NSPopover()
        popover.contentSize = NSSize(width: 530, height: 400)  // Reduced from 800 to 530
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    /// Toggles the popover when clicking the menu bar icon
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
