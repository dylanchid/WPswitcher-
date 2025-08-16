import Foundation
import WallpaperTypes

/// Protocol defining functionality for managing wallpaper playlists
@preconcurrency
public protocol PlaylistServiceProtocol: Sendable {
    // MARK: - Playlist Management
    func createPlaylist(name: String) async throws -> Playlist
    func deletePlaylist(_ playlist: Playlist) async throws
    func renamePlaylist(_ playlist: Playlist, to newName: String) async throws
    
    // MARK: - Wallpaper Management
    func addWallpaper(_ wallpaper: WallpaperItem, to playlist: Playlist) async throws
    func removeWallpaper(_ wallpaper: WallpaperItem, from playlist: Playlist) async throws
    func moveWallpaper(_ wallpaper: WallpaperItem, from source: Playlist, to destination: Playlist) async throws
    
    // MARK: - Playlist Operations
    func getPlaylists() async throws -> [Playlist]
    func getWallpapers(for playlist: Playlist) async throws -> [WallpaperItem]
    func reorderWallpapers(in playlist: Playlist, newOrder: [WallpaperItem]) async throws
    
    // MARK: - Properties
    var currentPlaylist: Playlist? { get set }
}

/// Represents different playback modes for playlists
public enum PlaybackMode: String, Codable, CaseIterable, Sendable {
    /// Play wallpapers in order
    case sequential = "Sequential"
    
    /// Play wallpapers randomly
    case random = "Random"
    
    /// Shuffle wallpapers once and play in that order
    case shuffle = "Shuffle"
    
    /// Description of the playback mode
    public var description: String {
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

/// Represents a playlist of wallpapers
public struct Playlist: Identifiable, Codable, Sendable {
    /// Unique identifier
    public let id: UUID
    
    /// Display name
    public var name: String
    
    /// Wallpapers in the playlist
    public var wallpapers: [WallpaperItem]
    
    /// Whether the playlist is expanded in the UI
    public var isExpanded: Bool
    
    /// Current playback mode
    public var playbackMode: PlaybackMode
    
    /// Rotation interval in seconds
    public var rotationInterval: TimeInterval
    
    private enum CodingKeys: String, CodingKey {
        case id, name, wallpapers, playbackMode, rotationInterval
        // Don't persist isExpanded state
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        wallpapers: [WallpaperItem],
        isExpanded: Bool = false,
        playbackMode: PlaybackMode = .sequential,
        rotationInterval: TimeInterval = 3600
    ) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.isExpanded = isExpanded
        self.playbackMode = playbackMode
        self.rotationInterval = rotationInterval
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        wallpapers = try container.decode([WallpaperItem].self, forKey: .wallpapers)
        playbackMode = try container.decode(PlaybackMode.self, forKey: .playbackMode)
        rotationInterval = try container.decode(TimeInterval.self, forKey: .rotationInterval)
        isExpanded = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wallpapers, forKey: .wallpapers)
        try container.encode(playbackMode, forKey: .playbackMode)
        try container.encode(rotationInterval, forKey: .rotationInterval)
        // Don't encode isExpanded state
    }
} 