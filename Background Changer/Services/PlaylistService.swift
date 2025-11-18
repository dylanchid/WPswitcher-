import Foundation
import Combine
import Wallpaper
import WallpaperTypes

@MainActor
final class PlaylistService: PlaylistServiceProtocol {
    nonisolated public var currentPlaylist: Wallpaper.Playlist? {
        get {
            // Use MainActor.assumeIsolated to safely access the main actor property
            MainActor.assumeIsolated { _currentPlaylist }
        }
        set {
            Task { @MainActor in
                _currentPlaylist = newValue
            }
        }
    }

    private var _currentPlaylist: Wallpaper.Playlist?

    // MARK: - Published Properties
    @Published private(set) var playlists: [Wallpaper.Playlist] = []
    @Published private(set) var activePlaylistId: UUID?
    @Published private(set) var isRotating: Bool = false
    @Published private(set) var rotationInterval: TimeInterval = 3600 // Default 1 hour

    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private let maxPlaylists = 20
    private let playlistsKey = "savedPlaylists"
    private let activePlaylistKey = "activePlaylist"

    // Wallpaper lookup closure - set by owner to resolve IDs to wallpaper items
    var wallpaperLookup: ((UUID) -> WallpaperTypes.WallpaperItem?)?
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSavedData()
    }
    
    // MARK: - PlaylistServiceProtocol Implementation
    
    public func createPlaylist(name: String) async throws -> Wallpaper.Playlist {
        guard playlists.count < maxPlaylists else {
            throw WallpaperError.playlistError("Playlist limit exceeded")
        }
        
        guard !playlists.contains(where: { $0.name == name }) else {
            throw WallpaperError.playlistError("Playlist with name '\(name)' already exists")
        }
        
        let playlist = Wallpaper.Playlist(name: name, wallpapers: [])
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }
    
    public func deletePlaylist(_ playlist: Wallpaper.Playlist) async throws {
        guard playlists.contains(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        
        playlists.removeAll { $0.id == playlist.id }
        if activePlaylistId == playlist.id {
            activePlaylistId = nil
        }
        savePlaylists()
    }
    
    public func renamePlaylist(_ playlist: Wallpaper.Playlist, to newName: String) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        playlists[index].name = newName
        savePlaylists()
    }
    
    public func addWallpaper(_ wallpaper: WallpaperTypes.WallpaperItem, to playlist: Wallpaper.Playlist) async throws {
        try await addWallpapersToPlaylist(playlistId: playlist.id, wallpaperIds: [wallpaper.id])
    }
    
    public func removeWallpaper(_ wallpaper: WallpaperTypes.WallpaperItem, from playlist: Wallpaper.Playlist) async throws {
        try await removeWallpapersFromPlaylist(playlistId: playlist.id, wallpaperIds: [wallpaper.id])
    }
    
    public func moveWallpaper(_ wallpaper: WallpaperTypes.WallpaperItem, from source: Wallpaper.Playlist, to destination: Wallpaper.Playlist) async throws {
        try await removeWallpaper(wallpaper, from: source)
        try await addWallpaper(wallpaper, to: destination)
    }
    
    public func getPlaylists() async throws -> [Wallpaper.Playlist] {
        return playlists
    }
    
    public func getWallpapers(for playlist: Wallpaper.Playlist) async throws -> [WallpaperTypes.WallpaperItem] {
        return playlist.wallpapers
    }
    
    func getCurrentWallpaper(for playlist: Wallpaper.Playlist) throws -> URL? {
        guard !playlist.wallpapers.isEmpty else {
            throw WallpaperError.playlistError("Playlist is empty")
        }

        // For now, just return the first wallpaper since there's no currentIndex
        return playlist.wallpapers.first?.url
    }
    
    public func reorderWallpapers(in playlist: Wallpaper.Playlist, newOrder: [WallpaperTypes.WallpaperItem]) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        playlists[index].wallpapers = newOrder
        try await updatePlaylist(playlists[index])
    }
    
    func updatePlaylist(_ playlist: Wallpaper.Playlist) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        
        playlists[index] = playlist
        savePlaylists()
    }
    
    func addWallpapersToPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }

        var playlist = playlists[index]
        let existingIds = Set(playlist.wallpapers.map { $0.id })
        let newIds = wallpaperIds.subtracting(existingIds)

        // Resolve wallpaper IDs to actual items using the lookup closure
        var newWallpapers: [WallpaperTypes.WallpaperItem] = []
        var notFoundIds: [UUID] = []

        for id in newIds {
            if let lookup = wallpaperLookup, let wallpaper = lookup(id) {
                newWallpapers.append(wallpaper)
            } else {
                notFoundIds.append(id)
            }
        }

        // Report any wallpapers that couldn't be found
        if !notFoundIds.isEmpty {
            throw WallpaperError.playlistError("Could not find \(notFoundIds.count) wallpaper(s)")
        }

        playlist.wallpapers.append(contentsOf: newWallpapers)

        playlists[index] = playlist
        savePlaylists()
    }
    
    func removeWallpapersFromPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        
        var playlist = playlists[index]
        playlist.wallpapers.removeAll { wallpaperIds.contains($0.id) }
        playlists[index] = playlist
        savePlaylists()
    }
    
    func activatePlaylist(_ id: UUID) async throws {
        guard let playlist = playlists.first(where: { $0.id == id }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        
        guard !playlist.wallpapers.isEmpty else {
            throw WallpaperError.playlistError("Playlist is empty")
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
            playlists[index].rotationInterval = interval
            savePlaylists()
        }
    }
    
    func updatePlaybackMode(_ mode: Wallpaper.PlaybackMode, for playlistId: UUID) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperError.playlistError("Playlist not found")
        }
        
        playlists[index].playbackMode = mode
        savePlaylists()
    }
    
    // MARK: - Private Methods
    
    private func loadSavedData() {
        if let data = userDefaults.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Wallpaper.Playlist].self, from: data) {
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