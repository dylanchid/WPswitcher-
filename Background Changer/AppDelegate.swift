//
//  AppDelegate.swift
//  Background Changer
//
//  Created by Dylan Chidambaram on 1/31/25.
//


import Cocoa
import SwiftUI
import Wallpaper
import WallpaperTypes
import OSLog

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.backgroundchanger", category: "app")
    private var statusItemManager: StatusItemManager?
    private var windowManager: WindowManager?
    private var keyboardMonitor: KeyboardMonitor?
    private var wallpaperManager: WallpaperManager = WallpaperManager.create()
    private let themeManager = ThemeManager()
    
    // MARK: - NSApplicationDelegate
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        
        setupStatusItem()
        setupWindowManager()
        setupKeyboardMonitor()
        
        // Check for migration needs
        Task {
            do {
                try await MigrationManager.shared.checkForMigration()
            } catch {
                logger.error("Migration failed: \(error.localizedDescription)")
                handleError(error)
            }
        }
        
        // Setup login/wake monitoring
        setupLoginWakeMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application will terminate")
        cleanup()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Setup Methods
    
    private func setupStatusItem() {
        statusItemManager = StatusItemManager.create()
        statusItemManager?.delegate = self
        statusItemManager?.setupStatusItem()
    }
    
    private func setupWindowManager() {
        windowManager = WindowManager.create()
        windowManager?.delegate = self
    }
    
    private func setupKeyboardMonitor() {
        keyboardMonitor = KeyboardMonitor.create()
        keyboardMonitor?.delegate = self
    }
    
    private func cleanup() {
        keyboardMonitor?.stopMonitoring()
        statusItemManager?.removeStatusItem()
        statusItemManager = nil
    }
    
    // MARK: - Private Methods
    // Appearance monitoring handled by ThemeManager / system defaults for now
    
    private func setupLoginWakeMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleLoginOrWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleLoginOrWake),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }
    
    private func handleError(_ error: Error) {
        if let wallpaperError = error as? WallpaperTypes.WallpaperError {
            logger.error("Wallpaper error: \(wallpaperError.localizedDescription)")
            let title: String
            let message: String
            let suggestion: String

            switch wallpaperError {
            case .invalidScreen:
                title = "Invalid Screen"
                message = "The target screen is invalid."
                suggestion = "Please ensure the target screen is valid."
            case .setWallpaperFailed(let reason):
                title = "Failed to Set Wallpaper"
                message = reason
                suggestion = "Ensure the image is valid and try again."
            case .playlistNotFound:
                title = "Playlist Not Found"
                message = "The specified playlist could not be found."
                suggestion = "Verify the playlist you selected still exists."
            case .invalidURL(let msg):
                title = "Invalid Wallpaper URL"
                message = msg
                suggestion = "Please ensure the file exists and you have permission to access it."
            case .fileNotFound(let msg):
                title = "File Not Found"
                message = msg
                suggestion = "Please verify the file exists and try again."
            case .invalidImage(let msg):
                title = "Invalid Image File"
                message = msg
                suggestion = "Please try with a different image file."
            case .insufficientPermissions(let msg):
                title = "Insufficient Permissions"
                message = msg
                suggestion = "Grant the necessary file access permissions in System Settings."
            case .displayError(let msg):
                title = "Display Error"
                message = msg
                suggestion = "Please check your display settings and try again."
            case .rotationError(let msg):
                title = "Rotation Error"
                message = msg
                suggestion = "Please check your rotation settings and try again."
            case .playlistError(let msg):
                title = "Playlist Error"
                message = msg
                suggestion = "Please check the playlist name or content."
            case .metadataError(let msg):
                title = "Metadata Error"
                message = msg
                suggestion = "The image file might be corrupted or unsupported."
            case .networkError(let msg):
                title = "Network Error"
                message = msg
                suggestion = "Check your internet connection and try again."
            case .systemError(let underlying):
                title = "System Error"
                message = underlying.localizedDescription
                suggestion = "Please try again later or contact support."
            }
            showError(title: title, message: message, suggestion: suggestion)
        } else {
            logger.error("System error: \(error.localizedDescription)")
            showError(
                title: "System Error",
                message: error.localizedDescription,
                suggestion: "Please try again or contact support if the issue persists."
            )
        }
    }
    
    private func showError(title: String, message: String, suggestion: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "\(message)\n\n\(suggestion)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Actions
    @objc private func handleAppearanceChange() {
        // Theming logic is handled within ThemeManager
    }

    @objc private func handleLoginOrWake() {
        logger.info("System did wake or login. Rotating wallpaper.")
        do {
            try wallpaperManager.rotateToNext()
        } catch {
            logger.error("Failed to rotate wallpaper: \(error.localizedDescription)")
        }
    }
}

// MARK: - StatusItemManagerDelegate
extension AppDelegate: StatusItemManagerDelegate {
    func statusItemManager(_ manager: StatusItemManager, didSelectAction action: StatusItemAction) {
        switch action {
        case .openMainWindow:
            windowManager?.showMainWindow()
        case .openSettings:
            windowManager?.showSettingsWindow()
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }
    
    func setWallpaper(from url: URL) async {
        await wallpaperManager.setWallpaper(from: url)
    }
    
    func startPlaylistRotation(playlistId: UUID, interval: TimeInterval) {
        wallpaperManager.startPlaylistRotation(playlistId: playlistId, interval: interval)
    }
    
    func updateSettings(_ settings: UserSettings) async {
        wallpaperManager.updateDisplayMode(settings.defaultDisplayMode)
    }
    
    func rotateToNext() {
        try? wallpaperManager.rotateToNext()
    }
    
    func rotateToPrevious() {
        try? wallpaperManager.rotateToPrevious()
    }
    
    func toggleRotation() {
        if wallpaperManager.isRotating {
            wallpaperManager.stopRotation()
        } else {
            wallpaperManager.startRotation(interval: wallpaperManager.rotationInterval)
        }
    }
    
    func undo() {
        try? wallpaperManager.undo()
    }
    
    func redo() {
        try? wallpaperManager.redo()
    }
}

// MARK: - WindowManagerDelegate
extension AppDelegate: WindowManagerDelegate {
    func windowManager(_ manager: WindowManager, didRequestWallpaperChange url: URL) {
        Task {
            await wallpaperManager.setWallpaper(from: url)
        }
    }
    
    func windowManager(_ manager: WindowManager, didRequestPlaylistRotation playlistId: UUID, interval: TimeInterval) {
        wallpaperManager.startPlaylistRotation(playlistId: playlistId, interval: interval)
    }
    
    func windowManager(_ manager: WindowManager, didRequestSettingsUpdate settings: UserSettings) {
        Task {
            await wallpaperManager.updateDisplayMode(settings.defaultDisplayMode)
        }
    }
}

// MARK: - KeyboardMonitorDelegate
extension AppDelegate: KeyboardMonitorDelegate {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didDetectShortcut shortcut: KeyboardShortcut) {
        switch shortcut.action {
        case .nextWallpaper:
            try? wallpaperManager.rotateToNext()
        case .previousWallpaper:
            try? wallpaperManager.rotateToPrevious()
        case .toggleRotation:
            if wallpaperManager.isRotating {
                wallpaperManager.stopRotation()
            } else {
                wallpaperManager.startRotation(interval: wallpaperManager.rotationInterval)
            }
        case .showPreferences:
            windowManager?.showSettingsWindow()
        case .addWallpaper:
            // Could trigger an open panel via StatusItemManager; for now, open main window
            windowManager?.showMainWindow()
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openMainWindow = Notification.Name("openMainWindow")
}
