import Foundation
import WallpaperTypes
import AppKit

// MARK: - App Actions
public enum AppAction: Equatable, Sendable {
    // Wallpaper Actions
    case addWallpaper(WallpaperItem)
    case removeWallpaper(UUID)
    case updateWallpaper(WallpaperItem)
    case setCurrentWallpaper(WallpaperItem?)
    case refreshWallpaperMetadata(UUID)
    
    // Playlist Actions
    case createPlaylist(name: String, id: UUID = UUID())
    case deletePlaylist(UUID)
    case updatePlaylist(Playlist)
    case setActivePlaylist(UUID?)
    case addWallpaperToPlaylist(wallpaperId: UUID, playlistId: UUID)
    case removeWallpaperFromPlaylist(wallpaperId: UUID, playlistId: UUID)
    case reorderPlaylistWallpapers(playlistId: UUID, from: IndexSet, to: Int)
    
    // Rotation Actions
    case startRotation(playlistId: UUID)
    case stopRotation
    case pauseRotation
    case resumeRotation
    case rotateToNext
    case rotateToPrevious
    case rotateToWallpaper(UUID)
    case updateRotationSettings(RotationSettings)
    
    // Display Actions
    case updateDisplaySettings(DisplaySettings)
    case setDisplayMode(DisplayMode)
    case setTargetScreen(NSScreen?)
    
    // User Profile Actions
    case updateUserProfile(UserProfile)
    case updatePreferences([String: Any])
    
    // Error Actions
    case setError(WallpaperError?)
    case clearError
    
    // System Actions
    case applicationDidBecomeActive
    case applicationDidResignActive
    case systemDidWakeFromSleep
    case memoryWarningReceived
    case diskSpaceLow
    
    // Undo/Redo Actions
    case undo
    case redo
    case clearHistory
}

// MARK: - State Reducer
public func appReducer(state: inout AppState, action: AppAction) throws {
    switch action {
    case .addWallpaper(let item):
        guard item.isValid else { 
            throw WallpaperError.stateManagement(.invalidWallpaper) 
        }
        if !state.wallpapers.contains(where: { $0.id == item.id }) {
            state.wallpapers.append(item)
        }
        
    case .removeWallpaper(let id):
        state.wallpapers.removeAll { $0.id == id }
        // If current wallpaper was removed, clear it
        if state.currentWallpaper?.id == id {
            state.currentWallpaper = nil
        }
        // Remove from all playlists
        for playlistIndex in state.playlists.indices {
            state.playlists[playlistIndex].wallpapers.removeAll { $0.id == id }
        }
        
    case .updateWallpaper(let item):
        guard let index = state.wallpapers.firstIndex(where: { $0.id == item.id }) else {
            throw WallpaperError.stateManagement(.invalidWallpaper)
        }
        state.wallpapers[index] = item
        
        // Update in playlists
        for playlistIndex in state.playlists.indices {
            if let wallpaperIndex = state.playlists[playlistIndex].wallpapers.firstIndex(where: { $0.id == item.id }) {
                state.playlists[playlistIndex].wallpapers[wallpaperIndex] = item
            }
        }
        
        // Update current wallpaper if it matches
        if state.currentWallpaper?.id == item.id {
            state.currentWallpaper = item
        }
        
    case .setCurrentWallpaper(let wallpaper):
        state.currentWallpaper = wallpaper
        
    case .refreshWallpaperMetadata(let id):
        // This action triggers metadata refresh - handled by middleware
        break
        
    case .createPlaylist(let name, let id):
        guard !name.isEmpty else {
            throw WallpaperError.playlistOperation(.invalidName(name))
        }
        guard !state.playlists.contains(where: { $0.name == name }) else {
            throw WallpaperError.playlistOperation(.invalidName("Playlist name already exists"))
        }
        
        let playlist = Playlist(id: id, name: name)
        state.playlists.append(playlist)
        
    case .deletePlaylist(let id):
        guard let index = state.playlists.firstIndex(where: { $0.id == id }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        state.playlists.remove(at: index)
        
        // Clear active playlist if it was deleted
        if state.activePlaylistId == id {
            state.activePlaylistId = nil
        }
        
    case .updatePlaylist(let playlist):
        guard let index = state.playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        state.playlists[index] = playlist
        
    case .setActivePlaylist(let id):
        if let id = id {
            guard state.playlists.contains(where: { $0.id == id }) else {
                throw WallpaperError.stateManagement(.playlistNotFound)
            }
        }
        state.activePlaylistId = id
        
    case .addWallpaperToPlaylist(let wallpaperId, let playlistId):
        guard let wallpaper = state.wallpapers.first(where: { $0.id == wallpaperId }) else {
            throw WallpaperError.stateManagement(.invalidWallpaper)
        }
        guard let playlistIndex = state.playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        
        // Check for duplicates
        if state.playlists[playlistIndex].wallpapers.contains(where: { $0.id == wallpaperId }) {
            throw WallpaperError.playlistOperation(.duplicateWallpaper(wallpaperId))
        }
        
        state.playlists[playlistIndex].wallpapers.append(wallpaper)
        
    case .removeWallpaperFromPlaylist(let wallpaperId, let playlistId):
        guard let playlistIndex = state.playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        
        state.playlists[playlistIndex].wallpapers.removeAll { $0.id == wallpaperId }
        
    case .reorderPlaylistWallpapers(let playlistId, let from, let to):
        guard let playlistIndex = state.playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        
        var wallpapers = state.playlists[playlistIndex].wallpapers
        for fromIndex in from.reversed() {
            guard fromIndex < wallpapers.count else { continue }
            let wallpaper = wallpapers.remove(at: fromIndex)
            let insertIndex = fromIndex < to ? to - 1 : to
            wallpapers.insert(wallpaper, at: min(insertIndex, wallpapers.count))
        }
        state.playlists[playlistIndex].wallpapers = wallpapers
        
    case .startRotation(let playlistId):
        guard state.playlists.contains(where: { $0.id == playlistId }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        state.activePlaylistId = playlistId
        state.isRotationActive = true
        
    case .stopRotation:
        state.isRotationActive = false
        
    case .pauseRotation:
        // Handled by rotation service - state tracks overall rotation status
        break
        
    case .resumeRotation:
        // Handled by rotation service
        break
        
    case .rotateToNext, .rotateToPrevious, .rotateToWallpaper:
        // These actions are handled by middleware and result in setCurrentWallpaper
        break
        
    case .updateRotationSettings(let settings):
        state.rotationSettings = settings
        
    case .updateDisplaySettings(let settings):
        state.displaySettings = settings
        
    case .setDisplayMode(let mode):
        state.displaySettings.displayMode = mode
        
    case .setTargetScreen(let screen):
        state.displaySettings.targetScreen = screen
        
    case .updateUserProfile(let profile):
        state.userProfile = profile
        
    case .updatePreferences(let preferences):
        state.userProfile.preferences.merge(preferences) { _, new in new }
        
    case .setError(let error):
        state.lastError = error
        
    case .clearError:
        state.lastError = nil
        
    case .applicationDidBecomeActive:
        // Handled by middleware - may trigger refresh actions
        break
        
    case .applicationDidResignActive:
        // Handled by middleware - may pause certain operations
        break
        
    case .systemDidWakeFromSleep:
        // Handled by middleware - may need to refresh current wallpaper
        break
        
    case .memoryWarningReceived:
        // Handled by middleware - may trigger cache cleanup
        break
        
    case .diskSpaceLow:
        // Handled by middleware - may trigger cleanup
        break
        
    case .undo, .redo, .clearHistory:
        // These are handled by the store's undo/redo system
        break
    }
}

// MARK: - Middleware Protocol
public protocol Middleware {
    func process(action: AppAction, state: AppState) async throws
}

// MARK: - Persistence Middleware
public final class PersistenceMiddleware: Middleware {
    private let storage: StorageServiceProtocol
    private let debounceDelay: TimeInterval = 1.0
    private var saveTask: Task<Void, Never>?
    
    public init(storage: StorageServiceProtocol) {
        self.storage = storage
    }
    
    public func process(action: AppAction, state: AppState) async throws {
        // Only persist for state-changing actions
        guard shouldPersist(action: action) else { return }
        
        // Debounce saves to avoid excessive I/O
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.debounceDelay ?? 1.0 * 1_000_000_000))
            guard !Task.isCancelled else { return }
            try? await self?.storage.save(state, key: "appState")
        }
    }
    
    private func shouldPersist(action: AppAction) -> Bool {
        switch action {
        case .addWallpaper, .removeWallpaper, .updateWallpaper,
             .createPlaylist, .deletePlaylist, .updatePlaylist,
             .addWallpaperToPlaylist, .removeWallpaperFromPlaylist,
             .updateRotationSettings, .updateDisplaySettings,
             .updateUserProfile, .updatePreferences:
            return true
        default:
            return false
        }
    }
}

// MARK: - Logging Middleware
public final class LoggingMiddleware: Middleware {
    private let logger: Logger
    
    public init(logger: Logger = Logger(subsystem: "WallpaperManager", category: "StateManagement")) {
        self.logger = logger
    }
    
    public func process(action: AppAction, state: AppState) async throws {
        logger.info("Action dispatched: \(String(describing: action))")
        
        // Log important state changes
        switch action {
        case .setError(let error):
            if let error = error {
                logger.error("Error set: \(error.localizedDescription)")
            }
        case .startRotation:
            logger.info("Rotation started with \(state.wallpapers.count) wallpapers")
        case .createPlaylist(let name, _):
            logger.info("Playlist created: \(name)")
        default:
            break
        }
    }
}

// MARK: - Validation Middleware
public final class ValidationMiddleware: Middleware {
    public func process(action: AppAction, state: AppState) async throws {
        switch action {
        case .addWallpaper(let item):
            try item.validate()
            
        case .updateWallpaper(let item):
            try item.validate()
            
        case .createPlaylist(let name, _):
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WallpaperError.playlistOperation(.invalidName("Empty name"))
            }
            
        case .updatePlaylist(let playlist):
            try playlist.validate()
            
        default:
            break
        }
    }
}

import OSLog

extension Logger {
    convenience init(subsystem: String, category: String) {
        self.init(OSLog(subsystem: subsystem, category: category))
    }
}
