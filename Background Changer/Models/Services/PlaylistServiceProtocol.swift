import Foundation

/// Protocol defining the contract for playlist management
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
struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var wallpapers: [WallpaperItem]
    var playbackMode: PlaybackMode
    var isExpanded: Bool
    var settings: PlaylistSettings
    
    init(id: UUID = UUID(), 
         name: String, 
         wallpapers: [WallpaperItem] = [], 
         playbackMode: PlaybackMode = .sequential,
         isExpanded: Bool = true,
         settings: PlaylistSettings = PlaylistSettings()) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.playbackMode = playbackMode
        self.isExpanded = isExpanded
        self.settings = settings
    }
}

/// Struct representing playlist settings
struct PlaylistSettings: Codable {
    var rotationInterval: TimeInterval
    var activeHours: ClosedRange<Int>?
    var activeDays: Set<Weekday>
    
    init(rotationInterval: TimeInterval = 3600,
         activeHours: ClosedRange<Int>? = nil,
         activeDays: Set<Weekday> = Set(Weekday.allCases)) {
        self.rotationInterval = rotationInterval
        self.activeHours = activeHours
        self.activeDays = activeDays
    }
}

/// Enum representing days of the week
enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
} 