import AppKit
import Foundation
import SwiftUI
import Wallpaper
import WallpaperTypes

@MainActor
public class WallpaperManager: ObservableObject {
    // MARK: - Types
    public enum RotationInterval: Int, CaseIterable {
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        case custom = 0
        
        var displayName: String {
            switch self {
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            case .custom: return "Custom"
            }
        }
    }
    
    // MARK: - Shared Instance
    static let shared = WallpaperManager.create()
    
    // MARK: - Dependencies
    private let wallpaperService: WallpaperTypes.WallpaperServiceProtocol
    private let persistenceController: PersistenceController
    private let playlistService: Wallpaper.PlaylistServiceProtocol

    // MARK: - Published Properties
    @Published private(set) var currentWallpaperPath: String
    @Published private(set) var globalWallpapers: [URL]
    @Published private(set) var playlists: [PlaylistEntity]
    // Unified playlists used by UI (Wallpaper module types)
    @Published private(set) var userPlaylists: [Wallpaper.Playlist] = []
    @Published var displayMode: WallpaperTypes.DisplayMode
    @Published var showOnAllSpaces: Bool
    @Published var isRotating: Bool
    @Published var rotationInterval: RotationInterval
    @Published var customInterval: TimeInterval
    @Published var currentError: WallpaperTypes.WallpaperError?
    @Published var playbackMode: Wallpaper.PlaybackMode // New property
    @Published var userProfile: UserProfile
    @Published var currentVersionIndex: Int = -1
    @Published var versionHistory: [PlaylistVersion] = []
    @Published var wallpapers: [WallpaperTypes.WallpaperItem] = []
    
    // Convenience for views expecting this name
    var allWallpapers: [WallpaperTypes.WallpaperItem] { wallpapers }

    // MARK: - Private Properties
    private var timer: Timer?
    private var activePlaylistId: UUID?
    private var appearanceObserver: NSObjectProtocol?
    private var isUsingGlobalWallpapers: Bool {
        activePlaylistId == nil
    }
    private var shuffledIndices: [Int] = [] // For shuffle mode
    private var currentShuffleIndex: Int = 0 // For shuffle mode
    
    // UserDefaults keys
    private let displayModeKey = "displayMode"
    private let rotationIntervalKey = "rotationInterval"
    private let customIntervalKey = "customInterval"
    
    private var currentWallpaper: URL? {
        currentWallpaperPath.isEmpty ? nil : URL(fileURLWithPath: currentWallpaperPath)
    }

    // MARK: - Initialization
    init(wallpaperService: WallpaperTypes.WallpaperServiceProtocol, persistenceController: PersistenceController) {
        self.wallpaperService = wallpaperService
        self.persistenceController = persistenceController
        self.playlistService = PlaylistService()

        // Initialize with saved values
        self.currentWallpaperPath = ""
        self.globalWallpapers = []
        self.playlists = []
    self.displayMode = wallpaperService.displayMode
    self.showOnAllSpaces = wallpaperService.showOnAllSpaces
        self.rotationInterval = .thirtyMinutes
        self.customInterval = 0
        self.isRotating = false
        self.playbackMode = .sequential // Initialize playbackMode
        self.userProfile = UserProfile() // Initialize userProfile

        loadPlaylists()
        Task { @MainActor in
            await refreshUserPlaylists()
        }
        setupAppearanceObserver()
    }

    deinit {
        if let observer = appearanceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Sets wallpaper for specific screen with options
    public func setWallpaper(from url: URL, for screen: NSScreen? = NSScreen.main) async {
        do {
            try await wallpaperService.setWallpaper(from: url, for: screen, mode: displayMode)
            currentWallpaperPath = url.path
            currentError = nil
        } catch {
            currentError = WallpaperError.displayError(error.localizedDescription)
        }
    }

    /// Updates display mode
    public func updateDisplayMode(_ mode: WallpaperTypes.DisplayMode) {
        displayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)

        // Reapply current wallpaper with new mode
        if let currentWallpaper = currentWallpaper {
            Task {
                await setWallpaper(from: currentWallpaper)
            }
        }
    }

    /// Updates whether to show wallpaper on all spaces
    public func updateShowOnAllSpaces(_ show: Bool) {
        showOnAllSpaces = show
        UserDefaults.standard.set(show, forKey: "showOnAllSpaces")
        wallpaperService.showOnAllSpaces = show
    }

    /// Starts wallpaper rotation
    public func startRotation(interval: RotationInterval = .thirtyMinutes, customInterval: TimeInterval? = nil) {
        stopRotation()
        isRotating = true
        self.rotationInterval = interval
        self.customInterval = customInterval ?? self.customInterval

        UserDefaults.standard.set(interval.rawValue, forKey: rotationIntervalKey)
        UserDefaults.standard.set(Int(self.customInterval), forKey: customIntervalKey)

        let actualInterval = interval == .custom ? self.customInterval : TimeInterval(interval.rawValue)

        timer = Timer.scheduledTimer(withTimeInterval: actualInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.rotateToNextWallpaper()
            }
        }
    }

    /// Stops wallpaper rotation
    public func stopRotation() {
        isRotating = false
        timer?.invalidate()
        timer = nil
    }

    /// Starts playlist rotation for the specified playlist
    public func startPlaylistRotation(playlistId: UUID, interval: TimeInterval) {
        activePlaylistId = playlistId
        startRotation(interval: RotationInterval.custom, customInterval: interval)
    }
    
    /// Manually rotate to next wallpaper
    public func rotateToNext() throws {
        Task {
            await rotateToNextWallpaper()
        }
    }
    
    /// Manually rotate to previous wallpaper  
    public func rotateToPrevious() throws {
        // Implementation for rotating to previous wallpaper
        // This would require keeping track of wallpaper history
    }
    
    /// Undo last wallpaper change
    public func undo() throws {
        // Implementation for undo functionality
        // This would require keeping track of wallpaper history
    }
    
    /// Redo last undone wallpaper change
    public func redo() throws {
        // Implementation for redo functionality
        // This would require keeping track of wallpaper history
    }

    // MARK: - Shims for legacy view calls
    public func loadWallpapers() async throws {
        // Placeholder: in a full implementation, populate self.wallpapers
    }

    public func nextWallpaper() throws {
        try rotateToNext()
    }

    public func previousWallpaper() throws {
        try rotateToPrevious()
    }

    public func randomWallpaper() throws {
        Task {
            await rotateToNextWallpaper(random: true)
        }
    }

    public func getCurrentSystemWallpaper() -> (URL, NSScreen)? {
        return nil
    }

    public func addWallpapers(_ urls: [URL]) async throws {
        await addGlobalWallpapers(urls)
    }

    /// Adds wallpapers to global list
    public func addGlobalWallpapers(_ urls: [URL]) async {
        var downloadedURLs = [URL]()
        for url in urls {
            if url.scheme == "http" || url.scheme == "https" {
                do {
                    let fileURL = try await downloadImage(from: url)
                    downloadedURLs.append(fileURL)
                } catch {
                    currentError = .networkError("Failed to download image from \(url.absoluteString)")
                }
            } else {
                downloadedURLs.append(url)
            }
        }
        globalWallpapers.append(contentsOf: downloadedURLs)
        saveGlobalWallpapers()
    }

    /// Removes wallpapers from global list
    public func removeGlobalWallpapers(_ urls: [URL]) {
        globalWallpapers.removeAll { urls.contains($0) }
        saveGlobalWallpapers()
    }

    /// Clears all global wallpapers
    public func clearGlobalWallpapers() {
        globalWallpapers.removeAll()
        if isUsingGlobalWallpapers {
            stopRotation()
        }
    }

    /// Creates a new playlist (Unified service)
    public func createPlaylist(name: String) async throws {
        _ = try await playlistService.createPlaylist(name: name)
        await refreshUserPlaylists()
    }

    /// Deletes a playlist (Unified service)
    public func deletePlaylist(id: UUID) async {
        guard let p = userPlaylists.first(where: { $0.id == id }) else { return }
        do {
            try await playlistService.deletePlaylist(p)
            await refreshUserPlaylists()
        } catch {
            // Propagate via currentError for now
            currentError = .playlistError(error.localizedDescription)
        }
    }

    /// Renames a playlist (Unified service)
    public func renamePlaylist(id: UUID, newName: String) async throws {
        guard let p = userPlaylists.first(where: { $0.id == id }) else {
            throw WallpaperTypes.WallpaperError.playlistNotFound
        }
        try await playlistService.renamePlaylist(p, to: newName)
        await refreshUserPlaylists()
    }

    /// Adds wallpapers to a playlist (Unified service)
    public func addWallpaperToPlaylist(playlistId: UUID, urls: [URL]) async {
        guard let p = userPlaylists.first(where: { $0.id == playlistId }) else { return }
        do {
            for url in urls {
                let item = WallpaperTypes.WallpaperItem(id: UUID(), url: url, name: url.lastPathComponent)
                try await playlistService.addWallpaper(item, to: p)
            }
            await refreshUserPlaylists()
        } catch {
            currentError = .playlistError(error.localizedDescription)
        }
    }

    /// Removes wallpapers from a playlist (Unified service)
    public func removeWallpapers(_ urls: [URL], from playlistId: UUID) async {
        guard let p = userPlaylists.first(where: { $0.id == playlistId }) else { return }
        do {
            let playlistWallpapers = try await playlistService.getWallpapers(for: p)
            let itemsToRemove = playlistWallpapers.filter { urls.contains($0.url) }
            for item in itemsToRemove {
                try await playlistService.removeWallpaper(item, from: p)
            }
            await refreshUserPlaylists()
        } catch {
            currentError = .playlistError(error.localizedDescription)
        }
    }

    public func restoreFromBackup(id: UUID) throws {
        try persistenceController.restoreBackup(for: id)
    }

    public func deleteBackup(id: UUID) throws {
        try persistenceController.deleteBackup(for: id)
    }

    // MARK: - Private Methods
    private func loadPlaylists() {
        let context = persistenceController.container.viewContext
        let request = PlaylistEntity.fetchRequest()
        do {
            playlists = try context.fetch(request)
        } catch {
            // Handle error
        }
    }

    @MainActor
    private func refreshUserPlaylists() async {
        do {
            let list = try await playlistService.getPlaylists()
            self.userPlaylists = list
        } catch {
            // Ignore for now; callers will surface errors when performing actions
        }
    }

    private func saveContext() {
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Handle error
            }
        }
    }
    
    private func saveGlobalWallpapers() {
        let paths = globalWallpapers.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "globalWallpapers")
    }

    

    private func rotateToNextWallpaper(random: Bool = false) async {
        var wallpapersToRotate: [URL] = []
        var currentWallpaperIndex: Int = -1

      if isUsingGlobalWallpapers {
            wallpapersToRotate = globalWallpapers
            currentWallpaperIndex = globalWallpapers.firstIndex(of: URL(fileURLWithPath: currentWallpaperPath)) ?? -1
        } else {
        guard let activePlaylistId = activePlaylistId,
            let playlist = userPlaylists.first(where: { $0.id == activePlaylistId }),
            !playlist.wallpapers.isEmpty else { return }
        wallpapersToRotate = playlist.wallpapers.map { $0.url }
        currentWallpaperIndex = wallpapersToRotate.firstIndex(of: URL(fileURLWithPath: currentWallpaperPath)) ?? -1
        }

        guard !wallpapersToRotate.isEmpty else { return }

        let nextIndex: Int
        switch playbackMode {
        case .sequential:
            nextIndex = (currentWallpaperIndex + 1) % wallpapersToRotate.count
        case .random:
            nextIndex = Int.random(in: 0..<wallpapersToRotate.count)
        case .shuffle:
            if shuffledIndices.isEmpty || currentShuffleIndex >= shuffledIndices.count {
                shuffledIndices = Array(0..<wallpapersToRotate.count).shuffled()
                currentShuffleIndex = 0
            }
            nextIndex = shuffledIndices[currentShuffleIndex]
            currentShuffleIndex += 1
        }
        await setWallpaper(from: wallpapersToRotate[nextIndex])
    }

    private func setupAppearanceObserver() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
            guard let activePlaylistId = self.activePlaylistId,
                let playlist = self.userPlaylists.first(where: { $0.id == activePlaylistId }) else { return }

                // Check if playlist should change based on appearance
                // If following system appearance, rotate to next
                if true {
                    await self.rotateToNextWallpaper()
                }
            }
        }
    }
}

// MARK: - Factory
extension WallpaperManager {
    nonisolated static func create() -> WallpaperManager {
        // Create dependencies
        let rotationService = MockWallpaperRotationService()
        let persistenceController = PersistenceController.shared
        
        // Create the manager on main actor
        return MainActor.assumeIsolated {
            let wallpaperService = WallpaperService(
                workspace: NSWorkspace.shared,
                fileManager: .default,
                userDefaults: .standard,
                rotationService: rotationService
            )
            
            return WallpaperManager(wallpaperService: wallpaperService as! WallpaperTypes.WallpaperServiceProtocol, persistenceController: persistenceController)
        }
    }
}

// Mock rotation service to satisfy the constructor
private class MockWallpaperRotationService: Wallpaper.WallpaperRotationServiceProtocol {
    var isRotating: Bool = false
    var rotationInterval: TimeInterval = 3600
    var isRotationEnabled: Bool = false
    
    func startRotation(interval: TimeInterval) async {}
    func stopRotation() async {}
    func rotateToNext() async throws {}
    func rotateToPrevious() async throws {}
    func start() async {}
    func stop() {}
    func setRotationInterval(_ interval: TimeInterval) async {}
    func getNextWallpaper() async throws -> WallpaperTypes.WallpaperItem? { nil }
}