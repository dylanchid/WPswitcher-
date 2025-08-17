import Foundation
import WallpaperTypes

@MainActor
@preconcurrency
public final class UnifiedPlaylistService: PlaylistServiceProtocol {
    // MARK: - Properties
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let playlistsDirectory: URL
    private var playlists: [Playlist] = []
    
    // MARK: - Initialization
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
        
        // Initialize playlists directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.playlistsDirectory = appSupport.appendingPathComponent("BackgroundChanger/Playlists")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: playlistsDirectory.path) {
            try? fileManager.createDirectory(at: playlistsDirectory, withIntermediateDirectories: true)
        }
        
        // Load playlists
        self.playlists = loadPlaylists()
    }
    
    // MARK: - PlaylistServiceProtocol Implementation
    
    public func createPlaylist(name: String) async throws -> Playlist {
        let playlist = Playlist(name: name, wallpapers: [])
        playlists.append(playlist)
        try savePlaylists()
        return playlist
    }
    
    public func deletePlaylist(_ playlist: Playlist) async throws {
        playlists.removeAll { $0.id == playlist.id }
        try savePlaylists()
    }
    
    public func renamePlaylist(_ playlist: Playlist, to newName: String) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistNotFound
        }
        
    var updatedPlaylist = playlist
    updatedPlaylist.name = newName
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    public func addWallpaper(_ wallpaper: WallpaperItem, to playlist: Playlist) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistNotFound
        }
        
    var updatedPlaylist = playlist
    updatedPlaylist.wallpapers.append(wallpaper)
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    public func removeWallpaper(_ wallpaper: WallpaperItem, from playlist: Playlist) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistNotFound
        }
        
    var updatedPlaylist = playlist
    updatedPlaylist.wallpapers.removeAll { $0.id == wallpaper.id }
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    public func moveWallpaper(_ wallpaper: WallpaperItem, from source: Playlist, to destination: Playlist) async throws {
        try await removeWallpaper(wallpaper, from: source)
        try await addWallpaper(wallpaper, to: destination)
    }
    
    public func getPlaylists() async throws -> [Playlist] {
        return playlists
    }
    
    public func getWallpapers(for playlist: Playlist) async throws -> [WallpaperItem] {
        guard let playlist = playlists.first(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistNotFound
        }
    return playlist.wallpapers
    }
    
    public func reorderWallpapers(in playlist: Playlist, newOrder: [WallpaperItem]) async throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperError.playlistNotFound
        }
        
    var updatedPlaylist = playlist
    updatedPlaylist.wallpapers = newOrder
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    // MARK: - Properties
    public var currentPlaylist: Playlist? {
        get { playlists.first { $0.id == UserDefaults.standard.string(forKey: "currentPlaylistId").flatMap(UUID.init) } }
        set {
            if let id = newValue?.id {
                UserDefaults.standard.set(id.uuidString, forKey: "currentPlaylistId")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentPlaylistId")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPlaylists() -> [Playlist] {
        guard let contents = try? fileManager.contentsOfDirectory(at: playlistsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return contents.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? jsonDecoder.decode(Playlist.self, from: data)
        }
    }
    
    private func savePlaylists() throws {
        for playlist in playlists {
            let url = playlistsDirectory.appendingPathComponent("\(playlist.id).json")
            let data = try jsonEncoder.encode(playlist)
            try data.write(to: url)
        }
    }
} 