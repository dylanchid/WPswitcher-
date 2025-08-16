import Foundation

/// Represents a version of a playlist at a specific point in time
struct PlaylistVersion: Identifiable, Codable {
    let id: UUID
    let playlistId: UUID
    let timestamp: Date
    let playlist: Playlist
    let action: PlaylistAction
    
    enum CodingKeys: String, CodingKey {
        case id, playlistId, timestamp, playlist, action
    }
    
    init(id: UUID = UUID(), playlistId: UUID, playlist: Playlist, action: PlaylistAction) {
        self.id = id
        self.playlistId = playlistId
        self.timestamp = Date()
        self.playlist = playlist
        self.action = action
    }
}

/// Represents the type of action that created a playlist version
enum PlaylistAction: String, Codable {
    case create = "Create"
    case update = "Update"
    case delete = "Delete"
    case addWallpapers = "Add Wallpapers"
    case removeWallpapers = "Remove Wallpapers"
    case reorder = "Reorder"
    case rename = "Rename"
    case changePlaybackMode = "Change Playback Mode"
    
    var description: String {
        switch self {
        case .create:
            return "Created playlist"
        case .update:
            return "Updated playlist"
        case .delete:
            return "Deleted playlist"
        case .addWallpapers:
            return "Added wallpapers"
        case .removeWallpapers:
            return "Removed wallpapers"
        case .reorder:
            return "Reordered wallpapers"
        case .rename:
            return "Renamed playlist"
        case .changePlaybackMode:
            return "Changed playback mode"
        }
    }
} 