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
    
    // MARK: - Dependencies (Clean Architecture)
    private let dependencies: WallpaperManagerDependencies
    private let stateStore: AppStateStore
    
    // MARK: - Published Properties (Derived from State)
    @Published private(set) var currentWallpaperPath: String = ""
    @Published private(set) var globalWallpapers: [URL] = []
    @Published private(set) var playlists: [PlaylistEntity] = []
    @Published private(set) var userPlaylists: [WallpaperTypes.Playlist] = []
    @Published var isRotating: Bool = false
    @Published var rotationInterval: RotationInterval = .thirtyMinutes
    @Published var customInterval: TimeInterval = 0
    @Published var currentError: AppError?
    @Published var userProfile: UserProfile = UserProfile()
    @Published var currentVersionIndex: Int = -1
    @Published var versionHistory: [PlaylistVersion] = []
    @Published var wallpapers: [WallpaperTypes.WallpaperItem] = []
    
    // Convenience properties derived from state
    public var displayMode: WallpaperTypes.DisplayMode {
        get { stateStore.state.displaySettings.displayMode }
        set { stateStore.dispatch(.updateDisplayMode(newValue)) }
    }
    
    public var showOnAllSpaces: Bool {
        get { stateStore.state.displaySettings.showOnAllSpaces }
        set { 
            var settings = stateStore.state.displaySettings
            settings.showOnAllSpaces = newValue
            stateStore.dispatch(.updateDisplaySettings(settings))
        }
    }
    
    public var playbackMode: WallpaperTypes.PlaybackMode {
        get { stateStore.state.rotationSettings.playbackMode }
        set {
            var settings = stateStore.state.rotationSettings
            settings.playbackMode = newValue
            stateStore.dispatch(.updateRotationSettings(settings))
        }
    }
    
    var allWallpapers: [WallpaperTypes.WallpaperItem] { wallpapers }

    // MARK: - Private Properties
    private var timer: Timer?
    private var activePlaylistId: UUID?
    private var appearanceObserver: NSObjectProtocol?
    private var shuffledIndices: [Int] = []
    private var currentShuffleIndex: Int = 0

    // MARK: - Wallpaper History
    private var wallpaperHistory: [WallpaperTypes.WallpaperItem] = []
    private var historyIndex: Int = -1
    private let maxHistorySize = 50
    
    private var isUsingGlobalWallpapers: Bool {
        activePlaylistId == nil
    }
    
    private var currentWallpaper: URL? {
        currentWallpaperPath.isEmpty ? nil : URL(fileURLWithPath: currentWallpaperPath)
    }

    // MARK: - Initialization
    init(dependencies: WallpaperManagerDependencies, stateStore: AppStateStore) {
        self.dependencies = dependencies
        self.stateStore = stateStore
        
        // Subscribe to state changes
        setupStateObservation()
        setupAppearanceObserver()
        
        // Load initial state
        Task {
            await loadInitialState()
        }
    }
    
    private func setupStateObservation() {
        // Observe state changes and update published properties
        stateStore.$state
            .map { $0.wallpapers }
            .assign(to: &$wallpapers)
        
        stateStore.$state
            .map { $0.playlists }
            .assign(to: &$userPlaylists)
        
        stateStore.$state
            .map { $0.isRotationActive }
            .assign(to: &$isRotating)
        
        stateStore.$state
            .map { $0.lastError }
            .assign(to: &$currentError)
        
        stateStore.$state
            .map { $0.currentWallpaper?.url.path ?? "" }
            .assign(to: &$currentWallpaperPath)
    }
    
    private func loadInitialState() async {
        do {
            try await stateStore.loadState()
            await refreshFromState()
        } catch {
            currentError = AppError.systemError(error)
        }
    }
    
    @MainActor
    private func refreshFromState() async {
        // Sync legacy properties with new state
        wallpapers = stateStore.state.wallpapers
        userPlaylists = stateStore.state.playlists
        isRotating = stateStore.state.isRotationActive
        currentError = stateStore.state.lastError
        
        if let currentWallpaper = stateStore.state.currentWallpaper {
            currentWallpaperPath = currentWallpaper.url.path
        }
    }

    deinit {
        if let observer = appearanceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods (Facade over Clean Architecture)

    /// Sets wallpaper for specific screen with options
    public func setWallpaper(from url: URL, for screen: NSScreen? = nil) async {
        do {
            let wallpaperItem = WallpaperItem(url: url, name: url.deletingPathExtension().lastPathComponent)
            try await dependencies.wallpaperCoordinator.setWallpaper(wallpaperItem, on: screen)
            stateStore.setCurrentWallpaper(wallpaperItem)
            currentError = nil
        } catch {
            currentError = AppError.systemError(error)
        }
    }

    /// Updates display mode
    public func updateDisplayMode(_ mode: WallpaperTypes.DisplayMode) {
        Task {
            do {
                try await dependencies.wallpaperCoordinator.updateDisplayMode(mode)
                stateStore.dispatch(.updateDisplayMode(mode))
            } catch {
                currentError = AppError.systemError(error)
            }
        }
    }

    /// Updates whether to show wallpaper on all spaces
    public func updateShowOnAllSpaces(_ show: Bool) {
        var settings = stateStore.state.displaySettings
        settings.showOnAllSpaces = show
        stateStore.dispatch(.updateDisplaySettings(settings))
    }

    /// Starts wallpaper rotation
    public func startRotation(interval: RotationInterval = .thirtyMinutes, customInterval: TimeInterval? = nil) {
        Task {
            do {
                stopRotation()
                
                self.rotationInterval = interval
                self.customInterval = customInterval ?? self.customInterval
                
                let actualInterval = interval == .custom ? self.customInterval : TimeInterval(interval.rawValue)
                
                // Update rotation settings in state
                var settings = stateStore.state.rotationSettings
                settings.rotationInterval = actualInterval
                stateStore.dispatch(.updateRotationSettings(settings))
                
                // Start rotation with active playlist or global wallpapers
                if let activePlaylistId = stateStore.state.activePlaylistId,
                   let playlist = stateStore.state.playlists.first(where: { $0.id == activePlaylistId }) {
                    try await dependencies.wallpaperCoordinator.startRotation(playlist: playlist)
                } else {
                    // Create temporary playlist from global wallpapers
                    let globalPlaylist = Playlist(
                        name: "Global Wallpapers",
                        wallpapers: stateStore.state.wallpapers,
                        rotationInterval: actualInterval
                    )
                    if !globalPlaylist.isEmpty {
                        try await dependencies.wallpaperCoordinator.startRotation(playlist: globalPlaylist)
                    }
                }
                
                stateStore.dispatch(.startRotation)
                
                // Setup timer for UI updates
                timer = Timer.scheduledTimer(withTimeInterval: actualInterval, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    Task {
                        await self.rotateToNextWallpaper()
                    }
                }
            } catch {
                currentError = AppError.systemError(error)
            }
        }
    }

    /// Stops wallpaper rotation
    public func stopRotation() {
        Task {
            do {
                try await dependencies.wallpaperCoordinator.stopRotation()
                stateStore.dispatch(.stopRotation)
                timer?.invalidate()
                timer = nil
            } catch {
                currentError = AppError.systemError(error)
            }
        }
    }

    /// Starts playlist rotation for the specified playlist
    public func startPlaylistRotation(playlistId: UUID, interval: TimeInterval) {
        stateStore.setActivePlaylist(playlistId)
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
        guard historyIndex > 0 else {
            throw WallpaperTypes.WallpaperError.rotationError("No previous wallpaper in history")
        }

        historyIndex -= 1
        let previousWallpaper = wallpaperHistory[historyIndex]

        Task {
            await setWallpaperWithoutHistory(from: previousWallpaper.url)
        }
    }

    /// Undo last wallpaper change
    public func undo() throws {
        try rotateToPrevious()
    }

    /// Redo last undone wallpaper change
    public func redo() throws {
        guard historyIndex < wallpaperHistory.count - 1 else {
            throw WallpaperTypes.WallpaperError.rotationError("No wallpaper to redo")
        }

        historyIndex += 1
        let nextWallpaper = wallpaperHistory[historyIndex]

        Task {
            await setWallpaperWithoutHistory(from: nextWallpaper.url)
        }
    }

    /// Check if undo is available
    public var canUndo: Bool {
        historyIndex > 0
    }

    /// Check if redo is available
    public var canRedo: Bool {
        historyIndex < wallpaperHistory.count - 1
    }

    /// Get the wallpaper history
    public var history: [WallpaperTypes.WallpaperItem] {
        wallpaperHistory
    }

    /// Clear wallpaper history
    public func clearHistory() {
        wallpaperHistory.removeAll()
        historyIndex = -1
    }

    // MARK: - Private History Methods

    /// Add wallpaper to history
    private func addToHistory(_ wallpaper: WallpaperTypes.WallpaperItem) {
        // If we're not at the end of history, remove future entries
        if historyIndex < wallpaperHistory.count - 1 {
            wallpaperHistory.removeSubrange((historyIndex + 1)...)
        }

        // Add to history
        wallpaperHistory.append(wallpaper)
        historyIndex = wallpaperHistory.count - 1

        // Limit history size
        if wallpaperHistory.count > maxHistorySize {
            wallpaperHistory.removeFirst()
            historyIndex = wallpaperHistory.count - 1
        }
    }

    /// Set wallpaper without adding to history (used for undo/redo)
    private func setWallpaperWithoutHistory(from url: URL) async {
        do {
            let wallpaperItem = WallpaperItem(url: url, name: url.deletingPathExtension().lastPathComponent)
            try await dependencies.wallpaperCoordinator.setWallpaper(wallpaperItem, on: nil)
            stateStore.setCurrentWallpaper(wallpaperItem)
            currentError = nil
        } catch {
            currentError = AppError.systemError(error)
        }
    }

    // MARK: - Shims for legacy view calls
    public func loadWallpapers() async throws {
        // Load wallpapers from state
        await refreshFromState()
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
        Task {
            do {
                let newWallpapers = try await dependencies.wallpaperCoordinator.addWallpapers(urls)
                for wallpaper in newWallpapers {
                    stateStore.addWallpaper(wallpaper)
                }
            } catch {
                currentError = AppError.systemError(error)
            }
        }
    }

    /// Adds wallpapers to global list (legacy support)
    public func addGlobalWallpapers(_ urls: [URL]) async {
        do {
            let newWallpapers = try await dependencies.wallpaperCoordinator.addWallpapers(urls)
            for wallpaper in newWallpapers {
                stateStore.addWallpaper(wallpaper)
            }
            
            // Update global wallpapers list for legacy compatibility
            globalWallpapers.append(contentsOf: urls)
        } catch {
            currentError = AppError.systemError(error)
        }
    }

    /// Removes wallpapers from global list
    public func removeGlobalWallpapers(_ urls: [URL]) {
        for url in urls {
            if let wallpaper = stateStore.state.wallpapers.first(where: { $0.url == url }) {
                stateStore.removeWallpaper(wallpaper.id)
            }
        }
        globalWallpapers.removeAll { urls.contains($0) }
    }

    /// Clears all global wallpapers
    public func clearGlobalWallpapers() {
        globalWallpapers.removeAll()
        stateStore.dispatch(.replaceAllWallpapers([]))
        if isUsingGlobalWallpapers {
            stopRotation()
        }
    }

    /// Creates a new playlist (Unified service)
    public func createPlaylist(name: String) async throws {
        do {
            let playlist = try await dependencies.wallpaperCoordinator.createPlaylist(name: name)
            stateStore.addPlaylist(playlist)
        } catch {
            currentError = AppError.systemError(error)
            throw error
        }
    }

    /// Deletes a playlist (Unified service)
    public func deletePlaylist(id: UUID) async {
        guard let playlist = stateStore.state.playlists.first(where: { $0.id == id }) else { return }
        do {
            try await dependencies.wallpaperCoordinator.deletePlaylist(playlist)
            stateStore.dispatch(.removePlaylist(id))
        } catch {
            currentError = AppError.playlistError(error.localizedDescription)
        }
    }

    /// Renames a playlist (Unified service)
    public func renamePlaylist(id: UUID, newName: String) async throws {
        guard var playlist = stateStore.state.playlists.first(where: { $0.id == id }) else {
            throw WallpaperTypes.WallpaperError.playlistNotFound
        }
        
        try playlist.setName(newName)
        try await dependencies.wallpaperCoordinator.updatePlaylist(playlist)
        stateStore.dispatch(.updatePlaylist(playlist))
    }

    /// Adds wallpapers to a playlist (Unified service)
    public func addWallpaperToPlaylist(playlistId: UUID, urls: [URL]) async {
        guard let playlist = stateStore.state.playlists.first(where: { $0.id == playlistId }) else { return }
        do {
            for url in urls {
                let item = WallpaperItem(id: UUID(), url: url, name: url.lastPathComponent)
                try await dependencies.wallpaperCoordinator.addWallpaperToPlaylist(item, playlist: playlist)
                stateStore.dispatch(.addWallpaperToPlaylist(wallpaperId: item.id, playlistId: playlistId))
            }
        } catch {
            currentError = AppError.playlistError(error.localizedDescription)
        }
    }

    /// Removes wallpapers from a playlist (Unified service)
    public func removeWallpapers(_ urls: [URL], from playlistId: UUID) async {
        guard let playlist = stateStore.state.playlists.first(where: { $0.id == playlistId }) else { return }
        do {
            for url in urls {
                if let wallpaper = playlist.wallpapers.first(where: { $0.url == url }) {
                    try await dependencies.wallpaperCoordinator.removeWallpaperFromPlaylist(wallpaper, playlist: playlist)
                    stateStore.dispatch(.removeWallpaperFromPlaylist(wallpaperId: wallpaper.id, playlistId: playlistId))
                }
            }
        } catch {
            currentError = AppError.playlistError(error.localizedDescription)
        }
    }

    /// Reorders wallpapers in a playlist
    public func reorderWallpapers(in playlistId: UUID, from sourceIndex: Int, to destinationIndex: Int) async {
        guard let playlist = self.stateStore.state.playlists.first(where: { $0.id == playlistId }) else { return }
        do {
            let sourceIndexSet = IndexSet(integer: sourceIndex)
            try await self.dependencies.wallpaperCoordinator.reorderWallpapers(in: playlist, from: sourceIndexSet, to: destinationIndex)
            
            // Update state
            var updatedPlaylist = playlist
            try updatedPlaylist.moveWallpaper(from: sourceIndexSet, to: destinationIndex)
            self.stateStore.dispatch(.updatePlaylist(updatedPlaylist))
        } catch {
            self.currentError = AppError.playlistError(error.localizedDescription)
        }
    }

    /// Sets the active playlist for rotation
    public func setActivePlaylist(_ playlistId: UUID) {
        self.stateStore.setActivePlaylist(playlistId)
    }

    /// Updates the playback mode for a specific playlist
    public func updatePlaylistPlaybackMode(playlistId: UUID, mode: WallpaperTypes.PlaybackMode) {
        var settings = self.stateStore.state.rotationSettings
        settings.playbackMode = mode
        self.stateStore.dispatch(.updateRotationSettings(settings))
    }

    public func restoreFromBackup(id: UUID) throws {
        // Find the backup in version history
        guard let backupIndex = versionHistory.firstIndex(where: { $0.id == id }) else {
            throw WallpaperTypes.WallpaperError.systemError(NSError(domain: "WallpaperManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backup not found"]))
        }

        let backup = versionHistory[backupIndex]

        // Restore playlists from backup
        Task {
            // Restore wallpapers state
            stateStore.dispatch(.replaceAllWallpapers(backup.wallpapers))

            // Restore playlists state
            stateStore.dispatch(.replaceAllPlaylists(backup.playlists))

            // Set the current version index
            currentVersionIndex = backupIndex
        }
    }

    public func deleteBackup(id: UUID) throws {
        // Find and remove the backup from version history
        guard let backupIndex = versionHistory.firstIndex(where: { $0.id == id }) else {
            throw WallpaperTypes.WallpaperError.systemError(NSError(domain: "WallpaperManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backup not found"]))
        }

        // Don't allow deletion of the current version
        if backupIndex == currentVersionIndex {
            throw WallpaperTypes.WallpaperError.systemError(NSError(domain: "WallpaperManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot delete the current active backup"]))
        }

        versionHistory.remove(at: backupIndex)

        // Adjust current version index if needed
        if backupIndex < currentVersionIndex {
            currentVersionIndex -= 1
        }
    }

    /// Create a new backup of current state
    public func createBackup(name: String? = nil) -> UUID {
        let backup = PlaylistVersion(
            id: UUID(),
            name: name ?? "Backup \(Date().formatted(date: .abbreviated, time: .shortened))",
            date: Date(),
            wallpapers: stateStore.state.wallpapers,
            playlists: stateStore.state.playlists
        )

        versionHistory.append(backup)
        currentVersionIndex = versionHistory.count - 1

        return backup.id
    }

    /// List all available backups
    public var backups: [PlaylistVersion] {
        versionHistory
    }

    /// Get the current backup
    public var currentBackup: PlaylistVersion? {
        guard currentVersionIndex >= 0 && currentVersionIndex < versionHistory.count else {
            return nil
        }
        return versionHistory[currentVersionIndex]
    }

    // MARK: - Private Methods (Legacy Support)
    private func loadPlaylists() {
        // Legacy method - now handled by state store
        Task {
            await self.refreshFromState()
        }
    }

    @MainActor
    private func refreshUserPlaylists() async {
        // Legacy method - now handled by state store
        await self.refreshFromState()
    }

    private func saveContext() {
        // Legacy method - now handled by storage service through state store
    }
    
    private func saveGlobalWallpapers() {
        // Legacy method - now handled by state persistence
    }

    private func rotateToNextWallpaper(random: Bool = false) async {
        var wallpapersToRotate: [WallpaperItem] = []
        var currentWallpaperIndex: Int = -1

        if let activePlaylistId = self.stateStore.state.activePlaylistId,
           let playlist = self.stateStore.state.playlists.first(where: { $0.id == activePlaylistId }) {
            wallpapersToRotate = playlist.wallpapers
            currentWallpaperIndex = wallpapersToRotate.firstIndex(where: { $0.url.path == self.currentWallpaperPath }) ?? -1
        } else {
            // Use global wallpapers
            wallpapersToRotate = self.stateStore.state.wallpapers
            currentWallpaperIndex = wallpapersToRotate.firstIndex(where: { $0.url.path == self.currentWallpaperPath }) ?? -1
        }

        guard !wallpapersToRotate.isEmpty else { return }

        let nextIndex: Int
        let mode = self.stateStore.state.rotationSettings.playbackMode
        
        switch mode {
        case .sequential:
            nextIndex = (currentWallpaperIndex + 1) % wallpapersToRotate.count
        case .random:
            nextIndex = Int.random(in: 0..<wallpapersToRotate.count)
        case .shuffle:
            if self.shuffledIndices.isEmpty || self.currentShuffleIndex >= self.shuffledIndices.count {
                self.shuffledIndices = Array(0..<wallpapersToRotate.count).shuffled()
                self.currentShuffleIndex = 0
            }
            nextIndex = self.shuffledIndices[self.currentShuffleIndex]
            self.currentShuffleIndex += 1
        }
        
        let nextWallpaper = wallpapersToRotate[nextIndex]
        await self.setWallpaper(from: nextWallpaper.url)
    }

    private func setupAppearanceObserver() {
        self.appearanceObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let activePlaylistId = self.stateStore.state.activePlaylistId,
                    let _ = self.stateStore.state.playlists.first(where: { $0.id == activePlaylistId }) else { return }

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
        let persistenceController = PersistenceController.shared
        
        // Create the manager on main actor
        return MainActor.assumeIsolated {
            // Create services
            let storageService = DefaultStorageService()
            let cacheService = DefaultCacheService()
            
            // Create rotation service with real implementation
            let rotationService = DefaultWallpaperRotationService()
            let wallpaperService = WallpaperService(
                workspace: NSWorkspace.shared,
                fileManager: .default,
                userDefaults: .standard,
                rotationService: rotationService
            )
            let playlistService = PlaylistService()

            // Create state store first so we can wire up dependencies
            let stateStore = AppStateStore(storageService: storageService)

            // Wire up wallpaper lookup for PlaylistService
            playlistService.wallpaperLookup = { [weak stateStore] id in
                return stateStore?.state.wallpapers.first { $0.id == id }
            }

            // Create coordinator
            // Note: WallpaperService conforms to WallpaperTypes.WallpaperServiceProtocol
            guard let wallpaperServiceProtocol = wallpaperService as? WallpaperTypes.WallpaperServiceProtocol else {
                fatalError("WallpaperService must conform to WallpaperTypes.WallpaperServiceProtocol")
            }

            let coordinator = WallpaperCoordinator(
                wallpaperService: wallpaperServiceProtocol,
                playlistService: playlistService,
                rotationService: rotationService,
                cacheService: cacheService
            )

            // Create migration coordinator
            let migrationCoordinator = MigrationCoordinator(
                migrations: [],
                storageService: storageService
            )

            // Create dependencies container
            let dependencies = DefaultWallpaperManagerDependencies(
                wallpaperCoordinator: coordinator,
                storageService: storageService,
                cacheService: cacheService,
                migrationCoordinator: migrationCoordinator
            )

            return WallpaperManager(dependencies: dependencies, stateStore: stateStore)
        }
    }
}

// MARK: - Default Rotation Service Implementation
@MainActor
private class DefaultWallpaperRotationService: Wallpaper.WallpaperRotationServiceProtocol {
    // MARK: - Properties
    private(set) var isRotating: Bool = false
    private(set) var rotationInterval: TimeInterval = 3600
    var isRotationEnabled: Bool = false

    // Private state
    private var timer: Timer?
    private var playlist: WallpaperTypes.Playlist?
    private var currentIndex: Int = 0
    private var shuffledIndices: [Int] = []
    private var playbackMode: WallpaperTypes.PlaybackMode = .sequential
    private weak var wallpaperManager: WallpaperManager?

    // Callback for when rotation needs to trigger a wallpaper change
    var onRotationTick: (() async -> Void)?

    // MARK: - Initialization
    init() {}

    // MARK: - Configuration
    func configure(playlist: WallpaperTypes.Playlist, mode: WallpaperTypes.PlaybackMode) {
        self.playlist = playlist
        self.playbackMode = mode
        self.currentIndex = 0

        if mode == .shuffle && !playlist.wallpapers.isEmpty {
            shuffledIndices = Array(0..<playlist.wallpapers.count).shuffled()
        }
    }

    // MARK: - Rotation Control
    func startRotation(interval: TimeInterval) async {
        guard !isRotating else { return }

        self.rotationInterval = interval
        isRotating = true
        isRotationEnabled = true

        // Create timer on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.onRotationTick?()
            }
        }

        // Add to common run loop mode for better reliability
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopRotation() async {
        timer?.invalidate()
        timer = nil
        isRotating = false
        isRotationEnabled = false
    }

    func rotateToNext() async throws {
        guard let playlist = playlist, !playlist.wallpapers.isEmpty else {
            throw WallpaperTypes.WallpaperError.playlistNotFound
        }

        switch playbackMode {
        case .sequential:
            currentIndex = (currentIndex + 1) % playlist.wallpapers.count
        case .random:
            currentIndex = Int.random(in: 0..<playlist.wallpapers.count)
        case .shuffle:
            if shuffledIndices.isEmpty {
                shuffledIndices = Array(0..<playlist.wallpapers.count).shuffled()
            }
            if let currentShuffleIndex = shuffledIndices.firstIndex(of: currentIndex) {
                let nextShuffleIndex = (currentShuffleIndex + 1) % shuffledIndices.count
                currentIndex = shuffledIndices[nextShuffleIndex]

                // Reshuffle when we complete a cycle
                if nextShuffleIndex == 0 {
                    shuffledIndices = Array(0..<playlist.wallpapers.count).shuffled()
                }
            } else {
                currentIndex = shuffledIndices.first ?? 0
            }
        }
    }

    func rotateToPrevious() async throws {
        guard let playlist = playlist, !playlist.wallpapers.isEmpty else {
            throw WallpaperTypes.WallpaperError.playlistNotFound
        }

        switch playbackMode {
        case .sequential:
            currentIndex = (currentIndex - 1 + playlist.wallpapers.count) % playlist.wallpapers.count
        case .random:
            // For random mode, just pick another random one
            currentIndex = Int.random(in: 0..<playlist.wallpapers.count)
        case .shuffle:
            if shuffledIndices.isEmpty {
                shuffledIndices = Array(0..<playlist.wallpapers.count).shuffled()
            }
            if let currentShuffleIndex = shuffledIndices.firstIndex(of: currentIndex) {
                let prevShuffleIndex = (currentShuffleIndex - 1 + shuffledIndices.count) % shuffledIndices.count
                currentIndex = shuffledIndices[prevShuffleIndex]
            } else {
                currentIndex = shuffledIndices.last ?? 0
            }
        }
    }

    func start() async {
        await startRotation(interval: rotationInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRotating = false
    }

    func setRotationInterval(_ interval: TimeInterval) async {
        self.rotationInterval = interval

        // If currently rotating, restart with new interval
        if isRotating {
            await stopRotation()
            await startRotation(interval: interval)
        }
    }

    func getNextWallpaper() async throws -> WallpaperTypes.WallpaperItem? {
        guard let playlist = playlist, !playlist.wallpapers.isEmpty else {
            return nil
        }

        // Calculate next index without changing state
        let nextIndex: Int
        switch playbackMode {
        case .sequential:
            nextIndex = (currentIndex + 1) % playlist.wallpapers.count
        case .random:
            nextIndex = Int.random(in: 0..<playlist.wallpapers.count)
        case .shuffle:
            if shuffledIndices.isEmpty {
                return playlist.wallpapers.first
            }
            if let currentShuffleIndex = shuffledIndices.firstIndex(of: currentIndex) {
                let nextShuffleIndex = (currentShuffleIndex + 1) % shuffledIndices.count
                nextIndex = shuffledIndices[nextShuffleIndex]
            } else {
                nextIndex = shuffledIndices.first ?? 0
            }
        }

        return playlist.wallpapers[nextIndex]
    }

    func getCurrentWallpaper() -> WallpaperTypes.WallpaperItem? {
        guard let playlist = playlist, currentIndex < playlist.wallpapers.count else {
            return nil
        }
        return playlist.wallpapers[currentIndex]
    }
}