import Foundation
import WallpaperTypes
import AppKit

// MARK: - App State
public struct AppState: Equatable, Codable, Sendable {
    public var wallpapers: [WallpaperItem]
    public var playlists: [Playlist]
    public var activePlaylistId: UUID?
    public var displaySettings: DisplaySettings
    public var rotationSettings: RotationSettings
    public var userProfile: UserProfile
    public var currentWallpaper: WallpaperItem?
    public var isRotationActive: Bool
    public var lastError: WallpaperError?
    
    public init(
        wallpapers: [WallpaperItem] = [],
        playlists: [Playlist] = [],
        activePlaylistId: UUID? = nil,
        displaySettings: DisplaySettings = DisplaySettings(),
        rotationSettings: RotationSettings = RotationSettings(),
        userProfile: UserProfile = UserProfile(),
        currentWallpaper: WallpaperItem? = nil,
        isRotationActive: Bool = false,
        lastError: WallpaperError? = nil
    ) {
        self.wallpapers = wallpapers
        self.playlists = playlists
        self.activePlaylistId = activePlaylistId
        self.displaySettings = displaySettings
        self.rotationSettings = rotationSettings
        self.userProfile = userProfile
        self.currentWallpaper = currentWallpaper
        self.isRotationActive = isRotationActive
        self.lastError = lastError
    }
    
    // Computed properties
    public var activePlaylist: Playlist? {
        guard let id = activePlaylistId else { return nil }
        return playlists.first { $0.id == id }
    }
    
    public var totalWallpapers: Int {
        wallpapers.count
    }
    
    public var totalPlaylists: Int {
        playlists.count
    }
}

// MARK: - Display Settings
public struct DisplaySettings: Equatable, Codable, Sendable {
    public var displayMode: DisplayMode
    public var showOnAllSpaces: Bool
    public var maintainAspectRatio: Bool
    public var preferredScreen: String? // Screen identifier
    
    public init(
        displayMode: DisplayMode = .fillScreen,
        showOnAllSpaces: Bool = true,
        maintainAspectRatio: Bool = true,
        preferredScreen: String? = nil
    ) {
        self.displayMode = displayMode
        self.showOnAllSpaces = showOnAllSpaces
        self.maintainAspectRatio = maintainAspectRatio
        self.preferredScreen = preferredScreen
    }
}

// MARK: - Rotation Settings
public struct RotationSettings: Equatable, Codable, Sendable {
    public var rotationInterval: TimeInterval
    public var playbackMode: PlaybackMode
    public var randomizeOnStart: Bool
    public var pauseOnBattery: Bool
    
    public init(
        rotationInterval: TimeInterval = 3600,
        playbackMode: PlaybackMode = .sequential,
        randomizeOnStart: Bool = false,
        pauseOnBattery: Bool = false
    ) {
        self.rotationInterval = rotationInterval
        self.playbackMode = playbackMode
        self.randomizeOnStart = randomizeOnStart
        self.pauseOnBattery = pauseOnBattery
    }
}

// MARK: - Action-based Updates
public enum AppAction: Sendable {
    // Wallpaper actions
    case addWallpaper(WallpaperItem)
    case removeWallpaper(UUID)
    case updateWallpaper(WallpaperItem)
    case setCurrentWallpaper(WallpaperItem?)
    
    // Playlist actions
    case addPlaylist(Playlist)
    case removePlaylist(UUID)
    case updatePlaylist(Playlist)
    case setActivePlaylist(UUID?)
    case addWallpaperToPlaylist(wallpaperId: UUID, playlistId: UUID)
    case removeWallpaperFromPlaylist(wallpaperId: UUID, playlistId: UUID)
    
    // Settings actions
    case updateDisplayMode(DisplayMode)
    case updateDisplaySettings(DisplaySettings)
    case updateRotationSettings(RotationSettings)
    case updateUserProfile(UserProfile)
    
    // Rotation actions
    case startRotation
    case stopRotation
    case setRotationActive(Bool)
    
    // Error handling
    case setError(WallpaperError?)
    case clearError
    
    // Bulk actions
    case replaceAllWallpapers([WallpaperItem])
    case replaceAllPlaylists([Playlist])
    case resetState
}

// MARK: - State Errors
public enum StateError: LocalizedError {
    case invalidWallpaper
    case wallpaperNotFound
    case playlistNotFound
    case playlistFull
    case invalidAction
    case validationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidWallpaper:
            return "Invalid wallpaper"
        case .wallpaperNotFound:
            return "Wallpaper not found"
        case .playlistNotFound:
            return "Playlist not found"
        case .playlistFull:
            return "Playlist is full"
        case .invalidAction:
            return "Invalid action"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}

// MARK: - Reducer with Validation
public func appReducer(state: inout AppState, action: AppAction) throws {
    switch action {
    case .addWallpaper(let item):
        // Validate wallpaper before adding
        try item.validate()
        
        // Check for duplicates
        guard !state.wallpapers.contains(where: { $0.id == item.id }) else {
            throw StateError.invalidWallpaper
        }
        
        state.wallpapers.append(item)
        
    case .removeWallpaper(let id):
        guard let index = state.wallpapers.firstIndex(where: { $0.id == id }) else {
            throw StateError.wallpaperNotFound
        }
        
        let removedWallpaper = state.wallpapers.remove(at: index)
        
        // Remove from all playlists
        for playlistIndex in state.playlists.indices {
            state.playlists[playlistIndex].wallpapers.removeAll { $0.id == id }
        }
        
        // Clear current wallpaper if it was removed
        if state.currentWallpaper?.id == id {
            state.currentWallpaper = nil
        }
        
    case .updateWallpaper(let item):
        try item.validate()
        
        guard let index = state.wallpapers.firstIndex(where: { $0.id == item.id }) else {
            throw StateError.wallpaperNotFound
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
        if let wallpaper = wallpaper {
            try wallpaper.validate()
        }
        state.currentWallpaper = wallpaper
        
    case .addPlaylist(let playlist):
        try playlist.validate()
        
        // Check for duplicates
        guard !state.playlists.contains(where: { $0.id == playlist.id }) else {
            throw StateError.invalidAction
        }
        
        state.playlists.append(playlist)
        
    case .removePlaylist(let id):
        guard let index = state.playlists.firstIndex(where: { $0.id == id }) else {
            throw StateError.playlistNotFound
        }
        
        state.playlists.remove(at: index)
        
        // Clear active playlist if it was removed
        if state.activePlaylistId == id {
            state.activePlaylistId = nil
        }
        
    case .updatePlaylist(let playlist):
        try playlist.validate()
        
        guard let index = state.playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw StateError.playlistNotFound
        }
        
        state.playlists[index] = playlist
        
    case .setActivePlaylist(let id):
        if let id = id {
            guard state.playlists.contains(where: { $0.id == id }) else {
                throw StateError.playlistNotFound
            }
        }
        state.activePlaylistId = id
        
    case .addWallpaperToPlaylist(let wallpaperId, let playlistId):
        guard let wallpaper = state.wallpapers.first(where: { $0.id == wallpaperId }) else {
            throw StateError.wallpaperNotFound
        }
        
        guard let playlistIndex = state.playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw StateError.playlistNotFound
        }
        
        try state.playlists[playlistIndex].addWallpaper(wallpaper)
        
    case .removeWallpaperFromPlaylist(let wallpaperId, let playlistId):
        guard let playlistIndex = state.playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw StateError.playlistNotFound
        }
        
        guard state.playlists[playlistIndex].removeWallpaper(id: wallpaperId) else {
            throw StateError.wallpaperNotFound
        }
        
    case .updateDisplayMode(let mode):
        state.displaySettings.displayMode = mode
        
    case .updateDisplaySettings(let settings):
        state.displaySettings = settings
        
    case .updateRotationSettings(let settings):
        state.rotationSettings = settings
        
    case .updateUserProfile(let profile):
        state.userProfile = profile
        
    case .startRotation:
        state.isRotationActive = true
        
    case .stopRotation:
        state.isRotationActive = false
        
    case .setRotationActive(let active):
        state.isRotationActive = active
        
    case .setError(let error):
        state.lastError = error
        
    case .clearError:
        state.lastError = nil
        
    case .replaceAllWallpapers(let wallpapers):
        // Validate all wallpapers
        for wallpaper in wallpapers {
            try wallpaper.validate()
        }
        state.wallpapers = wallpapers
        
        // Clear current wallpaper if it's not in the new list
        if let currentWallpaper = state.currentWallpaper,
           !wallpapers.contains(where: { $0.id == currentWallpaper.id }) {
            state.currentWallpaper = nil
        }
        
    case .replaceAllPlaylists(let playlists):
        // Validate all playlists
        for playlist in playlists {
            try playlist.validate()
        }
        state.playlists = playlists
        
        // Clear active playlist if it's not in the new list
        if let activeId = state.activePlaylistId,
           !playlists.contains(where: { $0.id == activeId }) {
            state.activePlaylistId = nil
        }
        
    case .resetState:
        state = AppState()
    }
}

// MARK: - State Store
@MainActor
public final class AppStateStore: ObservableObject {
    @Published public private(set) var state: AppState
    private let storageService: StorageServiceProtocol
    
    public init(initialState: AppState = AppState(), storageService: StorageServiceProtocol) {
        self.state = initialState
        self.storageService = storageService
    }
    
    public func dispatch(_ action: AppAction) {
        do {
            try appReducer(state: &state, action: action)
            
            // Persist state changes
            Task {
                try await persistState()
            }
        } catch {
            // Handle error by setting it in state
            state.lastError = WallpaperError.systemError(error)
        }
    }
    
    public func loadState() async throws {
        if let savedState = try await storageService.load(AppState.self, key: "app_state") {
            state = savedState
        }
    }
    
    private func persistState() async throws {
        try await storageService.save(state, key: "app_state")
    }
    
    // Convenience methods
    public func addWallpaper(_ wallpaper: WallpaperItem) {
        dispatch(.addWallpaper(wallpaper))
    }
    
    public func removeWallpaper(_ id: UUID) {
        dispatch(.removeWallpaper(id))
    }
    
    public func setCurrentWallpaper(_ wallpaper: WallpaperItem?) {
        dispatch(.setCurrentWallpaper(wallpaper))
    }
    
    public func addPlaylist(_ playlist: Playlist) {
        dispatch(.addPlaylist(playlist))
    }
    
    public func setActivePlaylist(_ id: UUID?) {
        dispatch(.setActivePlaylist(id))
    }
    
    public func startRotation() {
        dispatch(.startRotation)
    }
    
    public func stopRotation() {
        dispatch(.stopRotation)
    }
    
    public func clearError() {
        dispatch(.clearError)
    }
}
