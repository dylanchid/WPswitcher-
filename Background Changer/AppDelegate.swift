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
    private var appCoordinator: AppCoordinator?
    private var keyboardMonitor: KeyboardMonitor?
    private let wallpaperManager: WallpaperManager = WallpaperManager.create()
    private let themeManager = ThemeManager()
    private lazy var wallpaperService = AppWallpaperService(manager: wallpaperManager)
    private let playlistService = PlaylistService()
    private let userSettingsService = UserSettingsService()
    
    // MARK: - NSApplicationDelegate
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        
        setupStatusItem()
        setupCoordinator()
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
    
    private func setupCoordinator() {
        appCoordinator = AppCoordinator(
            wallpaperService: wallpaperService,
            playlistService: playlistService,
            wallpaperManager: wallpaperManager,
            themeManager: themeManager,
            userSettingsService: userSettingsService
        )
        appCoordinator?.start()
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
        let alert = ErrorPresenter.alertContent(for: error)
        logger.error("Error presented: \(alert.title) - \(alert.message)")
        showError(title: alert.title, message: alert.message, suggestion: alert.suggestion ?? "")
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
            appCoordinator?.showMainWindow()
        case .openSettings:
            appCoordinator?.showSettings()
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
        appCoordinator?.rotateNext()
    }
    
    func rotateToPrevious() {
        appCoordinator?.rotatePrevious()
    }
    
    func toggleRotation() {
        // Mirror current state via manager for now
        if wallpaperManager.isRotating {
            appCoordinator?.stopRotation()
        } else {
            appCoordinator?.startRotation(interval: wallpaperManager.customInterval == 0 ? 3600 : wallpaperManager.customInterval)
        }
    }
    
    func undo() {
        do {
            try wallpaperManager.undo()
        } catch {
            logger.warning("Undo failed: \(error.localizedDescription)")
        }
    }

    func redo() {
        do {
            try wallpaperManager.redo()
        } catch {
            logger.warning("Redo failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - WindowManagerDelegate
// WindowManagerDelegate no longer used; AppCoordinator owns windows

// MARK: - KeyboardMonitorDelegate
extension AppDelegate: KeyboardMonitorDelegate {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didDetectShortcut shortcut: KeyboardShortcut) {
        switch shortcut.action {
        case .nextWallpaper:
            appCoordinator?.rotateNext()
        case .previousWallpaper:
            appCoordinator?.rotatePrevious()
        case .toggleRotation:
            toggleRotation()
        case .showPreferences:
            appCoordinator?.showSettings()
        case .addWallpaper:
            // Could trigger an open panel via StatusItemManager; for now, open main window
            appCoordinator?.showMainWindow()
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openMainWindow = Notification.Name("openMainWindow")
}
