import AppKit
import SwiftUI

@MainActor
protocol StatusItemManagerDelegate: AnyObject {
    func statusItemManager(_ manager: StatusItemManager, didSelectAction action: StatusItemAction)
}

enum StatusItemAction {
    case openMainWindow
    case openSettings
    case quit
}

@MainActor
class StatusItemManager {
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private let wallpaperManager: WallpaperManager
    weak var delegate: StatusItemManagerDelegate?
    
    // MARK: - Initialization
    init(wallpaperManager: WallpaperManager) {
        self.wallpaperManager = wallpaperManager
    }
    
    // MARK: - Public Methods
    static func create() -> StatusItemManager {
        let wallpaperManager = WallpaperManager.create()
        return StatusItemManager(wallpaperManager: wallpaperManager)
    }
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Background Changer")
        }
        
        setupMenu()
    }
    
    func removeStatusItem() {
        statusItem = nil
    }
    
    // MARK: - Private Methods
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
    
    // MARK: - Actions
    @objc private func addWallpaper() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        panel.begin { [weak self] response in
            if response == .OK {
                Task {
                    await self?.wallpaperManager.addGlobalWallpapers(panel.urls)
                }
            }
        }
    }
    
    @objc private func managePlaylists() {
        delegate?.statusItemManager(self, didSelectAction: .openMainWindow)
    }
    
    @objc private func openSettings() {
        delegate?.statusItemManager(self, didSelectAction: .openSettings)
    }
} 