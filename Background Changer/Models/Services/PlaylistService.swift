import Foundation
import Combine

@MainActor
class PlaylistService: ObservableObject, PlaylistServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var activePlaylistId: UUID?
    @Published private(set) var isRotating: Bool = false
    @Published private(set) var rotationInterval: TimeInterval = 3600 // Default 1 hour
    
    var playlistsPublisher: Published<[Playlist]>.Publisher { $playlists }
    
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
            throw WallpaperError.playlistLimitExceeded
        }
        
        guard !playlists.contains(where: { $0.name == name }) else {
            throw WallpaperError.invalidPlaylistOperation("Playlist with name '\(name)' already exists")
        }
        
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }
    
    func deletePlaylist(_ id: UUID) async throws {
        guard playlists.contains(where: { $0.id == id }) else {
            throw WallpaperError.playlistNotFound(id)
        }
        
        playlists.removeAll { $0.id == id }
        if activePlaylistId == id {
            activePlaylistId = nil
        }
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: Playlist) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistNotFound(playlist.id)
        }
        
        playlists[index] = playlist
        savePlaylists()
    }
    
    func addWallpapersToPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.playlistNotFound(playlistId)
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
            throw WallpaperError.playlistNotFound(playlistId)
        }
        
        var playlist = playlists[index]
        playlist.wallpapers.removeAll { wallpaperIds.contains($0.id) }
        playlists[index] = playlist
        savePlaylists()
    }
    
    func activatePlaylist(_ id: UUID) async throws {
        guard let playlist = playlists.first(where: { $0.id == id }) else {
            throw WallpaperError.playlistNotFound(id)
        }
        
        guard !playlist.wallpapers.isEmpty else {
            throw WallpaperError.emptyPlaylist(id)
        }
        
        activePlaylistId = id
        userDefaults.set(id.uuidString, forKey: activePlaylistKey)
    }
    
    func deactivateCurrentPlaylist() async {
        activePlaylistId = nil
        userDefaults.removeObject(forKey: activePlaylistKey)
    }
    
    func updateRotationInterval(_ interval: TimeInterval) async {
        rotationInterval = interval
        if isRotating {
            // Restart rotation with new interval
            stopRotation()
            await startRotation(interval: interval)
        }
    }
    
    func updatePlaybackMode(_ mode: PlaybackMode, for playlistId: UUID) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.playlistNotFound(playlistId)
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
        }
    }
    
    private func savePlaylists() {
        if let encoded = try? JSONEncoder().encode(playlists) {
            userDefaults.set(encoded, forKey: playlistsKey)
        }
    }
} 