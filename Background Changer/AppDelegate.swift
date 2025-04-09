//
//  AppDelegate.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
//


import Cocoa
import SwiftUI
import Wallpaper

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var wallpaperManager: WallpaperManager!
    private var window: NSWindow?
    @ObservedObject var appState = AppState()
    @StateObject var themeManager = ThemeManager()
    private var keyboardMonitor: Any?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize WallpaperManager with dependencies
        wallpaperManager = WallpaperManager.create()
        
        // Setup menu bar item
        setupStatusItem()
        
        // Check for migration needs
        Task {
            do {
                try await MigrationManager.shared.checkForMigration()
            } catch {
                // Handle migration error
                print("Migration failed: \(error.localizedDescription)")
            }
        }
        
        // Create popover UI with proper size constraints
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 650, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        )
        
        // Create main window
        createMainWindow()
        
        // Setup keyboard monitoring
        setupKeyboardMonitoring()
        
        // Setup notifications
        setupNotifications()
        
        // Setup appearance monitoring
        setupAppearanceMonitoring()
    }
    
    private func setupAppearanceMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: NSApp.effectiveAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAppearanceChange() {
        if themeManager.theme.colorScheme == .system {
            themeManager.theme = Theme.current
        }
    }
    
    private func setupKeyboardMonitoring() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Check for custom shortcuts
            for shortcut in WallpaperManager.shared.userProfile.preferences.customShortcuts {
                if event.keyCode == shortcut.keyCode && event.modifierFlags.contains(shortcut.modifiers) {
                    WallpaperManager.shared.handleKeyboardShortcut(shortcut)
                    return nil
                }
            }
            
            return event
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMainWindow),
            name: .openMainWindow,
            object: nil
        )
    }
    
    func createMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Background Changer"
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(
            rootView: MainAppView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        )
        self.window = window
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup
        wallpaperManager.stopRotation()
        
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Background Changer")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Add Wallpaper
        menu.addItem(withTitle: "Add Wallpaper...", action: #selector(addWallpaper), keyEquivalent: "n")
        
        // Manage Playlists
        menu.addItem(withTitle: "Manage Playlists...", action: #selector(managePlaylists), keyEquivalent: "p")
        
        // Settings
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        
        // Quit
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Background Changer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        statusItem?.menu = menu
    }
    
    @objc private func addWallpaper() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        panel.begin { [weak self] response in
            if response == .OK {
                Task {
                    await self?.wallpaperManager.addWallpapers(panel.urls)
                }
            }
        }
    }
    
    @objc private func managePlaylists() {
        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.center()
            window?.setFrameAutosaveName("Main Window")
            window?.title = "Background Changer"
            
            let contentView = PlaylistManagerView()
                .environmentObject(wallpaperManager)
            window?.contentView = NSHostingView(rootView: contentView)
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openSettings() {
        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window?.center()
            window?.setFrameAutosaveName("Settings Window")
            window?.title = "Settings"
            
            let contentView = SettingsView()
                .environmentObject(wallpaperManager)
            window?.contentView = NSHostingView(rootView: contentView)
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showMainWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func hideMainWindow() {
        window?.orderOut(nil)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openMainWindow = Notification.Name("openMainWindow")
}
