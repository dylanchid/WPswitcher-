import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: "Wallpaper Changer")
            button.action = #selector(togglePopover)
        }

        // Create the popover UI
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 250)
        popover.behavior = .transient
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