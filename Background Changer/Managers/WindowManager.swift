import AppKit
import SwiftUI

@MainActor
protocol WindowManagerDelegate: AnyObject {
    func windowManager(_ manager: WindowManager, didRequestWallpaperChange url: URL)
    func windowManager(_ manager: WindowManager, didRequestPlaylistRotation playlistId: UUID, interval: TimeInterval)
    func windowManager(_ manager: WindowManager, didRequestSettingsUpdate settings: UserSettings)
}

class WindowManager {
    // MARK: - Properties
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let wallpaperManager: WallpaperManager
    private let themeManager: ThemeManager
    weak var delegate: WindowManagerDelegate?
    
    // MARK: - Initialization
    init(wallpaperManager: WallpaperManager, themeManager: ThemeManager) {
        self.wallpaperManager = wallpaperManager
        self.themeManager = themeManager
        setupNotifications()
    }
    
    // MARK: - Public Methods
    static func create() -> WindowManager {
        let wallpaperManager = WallpaperManager.create()
        let themeManager = ThemeManager()
        return WindowManager(wallpaperManager: wallpaperManager, themeManager: themeManager)
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
                .environmentObject(wallpaperManager)
                .environmentObject(themeManager)
        )
        self.mainWindow = window
    }
    
    func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }
    
    func showSettingsWindow() {
        if settingsWindow == nil {
            createSettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func createSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Settings Window")
        window.title = "Settings"
        
        let contentView = SettingsView()
            .environmentObject(wallpaperManager)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.settingsWindow = window
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindow),
            name: .openMainWindow,
            object: nil
        )
    }
    
    // MARK: - Actions
    @objc private func handleOpenSettings() {
        showSettingsWindow()
    }
    
    @objc private func handleOpenMainWindow() {
        showMainWindow()
    }
} 