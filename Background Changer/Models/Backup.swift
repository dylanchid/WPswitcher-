import Foundation

struct Backup: Codable {
    let id: UUID
    let timestamp: Date
    let playlists: [Playlist]
    let wallpapers: [WallpaperItem]
    let userSettings: UserSettings
    let userProfile: UserProfile
} 