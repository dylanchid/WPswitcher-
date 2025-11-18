//
//  AppCoordinator.swift
//  Background Changer
//
//  Root coordinator wiring services and root views.
//

import AppKit
import SwiftUI
import Wallpaper

@MainActor
final class AppCoordinator: BaseCoordinator {
    // MARK: - Dependencies
    private let wallpaperService: AppWallpaperServiceProtocol
    private let playlistService: Wallpaper.PlaylistServiceProtocol
    private let wallpaperManager: WallpaperManager
    private let themeManager: ThemeManager
    private let userSettingsService: UserSettingsServiceProtocol

    // Windows
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var playlistCoordinator: PlaylistCoordinator?
    private let playlistFlowRouter = PlaylistFlowRouter()

    init(wallpaperService: AppWallpaperServiceProtocol,
         playlistService: Wallpaper.PlaylistServiceProtocol,
         wallpaperManager: WallpaperManager,
         themeManager: ThemeManager = ThemeManager(),
         userSettingsService: UserSettingsServiceProtocol) {
        self.wallpaperService = wallpaperService
        self.playlistService = playlistService
        self.wallpaperManager = wallpaperManager
        self.themeManager = themeManager
        self.userSettingsService = userSettingsService
        super.init()
    }

    override func start() {
        // Prepare root windows lazily
        createMainWindowIfNeeded()
        createSettingsWindowIfNeeded()
    }

    // MARK: - Windows
    func showMainWindow() {
        createMainWindowIfNeeded()
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        createSettingsWindowIfNeeded()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createMainWindowIfNeeded() {
        guard mainWindow == nil else { return }
        let vm = RotationViewModel(wallpaperService: wallpaperService,
                                   playlistService: playlistService,
                                   userSettingsService: userSettingsService)
        // Setup child coordinator for playlist flows
        playlistFlowRouter.coordinator = nil // will set after init
        let plc = PlaylistCoordinator(appCoordinator: self, viewModel: vm, router: playlistFlowRouter)
        playlistFlowRouter.coordinator = plc
        addChild(plc)
        playlistCoordinator = plc
        let content = MainAppView()
            .environmentObject(vm)
            .environmentObject(themeManager)
            .environmentObject(wallpaperManager)
            .environmentObject(playlistFlowRouter)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Background Changer"
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: content)
        mainWindow = window
    }

    private func createSettingsWindowIfNeeded() {
        guard settingsWindow == nil else { return }
        let vm = RotationViewModel(
            wallpaperService: wallpaperService,
            playlistService: playlistService,
            userSettingsService: userSettingsService
        )
        let content = SettingsView()
            .environmentObject(vm)
            .environmentObject(themeManager)
            .environmentObject(wallpaperManager)
            .environmentObject(playlistFlowRouter)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Settings Window")
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: content)
        settingsWindow = window
    }

    // MARK: - Wallpaper controls
    func rotateNext() {
        do { try wallpaperService.rotateToNext() } catch { /* surface later if needed */ }
    }

    func rotatePrevious() {
        do { try wallpaperService.rotateToPrevious() } catch { /* surface later if needed */ }
    }

    func startRotation(interval: TimeInterval) {
        wallpaperService.startRotation(interval: interval)
    }

    func stopRotation() {
        wallpaperService.stopRotation()
    }
}
