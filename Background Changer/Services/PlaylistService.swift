import Foundation
import Combine
import WallpaperTypes

/// Protocol defining the contract for playlist management
@MainActor
protocol PlaylistServiceProtocol {
    /// Playlist state
    var playlists: [Playlist] { get }
    var activePlaylistId: UUID? { get }
    var isRotating: Bool { get }
    var rotationInterval: TimeInterval { get }
    
    /// Playlist Operations
    func createPlaylist(name: String) async throws -> Playlist
    func deletePlaylist(_ id: UUID) async throws
    func updatePlaylist(_ playlist: Playlist) async throws
    func addWallpapersToPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws
    func removeWallpapersFromPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws
    
    /// Playlist Activation
    func activatePlaylist(_ id: UUID) async throws
    func deactivateCurrentPlaylist() async
    
    /// Playlist Settings
    func updateRotationInterval(_ interval: TimeInterval) async
    func updatePlaybackMode(_ mode: PlaybackMode, for playlistId: UUID) async throws
}

/// Enum representing playback modes for playlists
enum PlaybackMode: String, Codable, CaseIterable {
    case sequential = "Sequential"
    case random = "Random"
    case shuffle = "Shuffle"
    
    var description: String {
        switch self {
        case .sequential:
            return "Play wallpapers in order"
        case .random:
            return "Play wallpapers randomly"
        case .shuffle:
            return "Shuffle wallpapers once"
        }
    }
}

/// Struct representing a playlist
public struct Playlist: Identifiable, Codable {
    public let id: UUID
    var name: String
    var wallpapers: [WallpaperItem]
    var playbackMode: PlaybackMode
    var rotationInterval: TimeInterval
    
    init(id: UUID = UUID(), 
         name: String, 
         wallpapers: [WallpaperItem] = [], 
         playbackMode: PlaybackMode = .sequential,
         rotationInterval: TimeInterval = 3600) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.playbackMode = playbackMode
        self.rotationInterval = rotationInterval
    }
}

@MainActor
class PlaylistService: ObservableObject, PlaylistServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var activePlaylistId: UUID?
    @Published private(set) var isRotating: Bool = false
    @Published private(set) var rotationInterval: TimeInterval = 3600 // Default 1 hour
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private let maxPlaylists = 20
    private let playlistsKey = "savedPlaylists"
    private let activePlaylistKey = "activePlaylist"
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSavedData()
    }
    
    // MARK: - PlaylistServiceProtocol Implementation
    
    func createPlaylist(name: String) async throws -> Playlist {
        guard playlists.count < maxPlaylists else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist limit exceeded")
        }
        
        guard !playlists.contains(where: { $0.name == name }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist with name '\(name)' already exists")
        }
        
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }
    
    func deletePlaylist(_ id: UUID) async throws {
        guard playlists.contains(where: { $0.id == id }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist not found")
        }
        
        playlists.removeAll { $0.id == id }
        if activePlaylistId == id {
            activePlaylistId = nil
        }
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: Playlist) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist not found")
        }
        
        playlists[index] = playlist
        savePlaylists()
    }
    
    func addWallpapersToPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist not found")
        }
        
        var playlist = playlists[index]
        let existingIds = Set(playlist.wallpapers.map { $0.id })
        let newIds = wallpaperIds.subtracting(existingIds)
        
        // Add only new wallpapers
        for id in newIds {
            if let wallpaper = WallpaperManager.shared.wallpapers.first(where: { $0.id == id }) {
                playlist.wallpapers.append(wallpaper)
            }
        }
        
        playlists[index] = playlist
        savePlaylists()
    }
    
    func removeWallpapersFromPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist not found")
        }
        
        var playlist = playlists[index]
        playlist.wallpapers.removeAll { wallpaperIds.contains($0.id) }
        playlists[index] = playlist
        savePlaylists()
    }
    
    func activatePlaylist(_ id: UUID) async throws {
        guard let playlist = playlists.first(where: { $0.id == id }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist not found")
        }
        
        guard !playlist.wallpapers.isEmpty else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist is empty")
        }
        
        activePlaylistId = id
        rotationInterval = playlist.rotationInterval
        userDefaults.set(id.uuidString, forKey: activePlaylistKey)
    }
    
    func deactivateCurrentPlaylist() async {
        activePlaylistId = nil
        userDefaults.removeObject(forKey: activePlaylistKey)
    }
    
    func updateRotationInterval(_ interval: TimeInterval) async {
        rotationInterval = interval
        if let activeId = activePlaylistId,
           let index = playlists.firstIndex(where: { $0.id == activeId }) {
            var playlist = playlists[index]
            playlist.rotationInterval = interval
            playlists[index] = playlist
            savePlaylists()
        }
    }
    
    func updatePlaybackMode(_ mode: PlaybackMode, for playlistId: UUID) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperTypes.WallpaperError.playlistError("Playlist not found")
        }
        
        var playlist = playlists[index]
        playlist.playbackMode = mode
        playlists[index] = playlist
        savePlaylists()
    }
    
    // MARK: - Private Methods
    
    private func loadSavedData() {
        if let data = userDefaults.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
        }
        
        if let activeId = userDefaults.string(forKey: activePlaylistKey),
           let id = UUID(uuidString: activeId) {
            activePlaylistId = id
            if let playlist = playlists.first(where: { $0.id == id }) {
                rotationInterval = playlist.rotationInterval
            }
        }
    }
    
    private func savePlaylists() {
        if let encoded = try? JSONEncoder().encode(playlists) {
            userDefaults.set(encoded, forKey: playlistsKey)
        }
    }
} 