import Foundation
import Wallpaper

struct UserProfile: Codable {
    let id: UUID
    var name: String
    var email: String?
    var avatarURL: URL?
    var preferences: UserPreferences
    var lastLogin: Date
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        avatarURL: URL? = nil,
        preferences: UserPreferences = UserPreferences(),
        lastLogin: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.preferences = preferences
        self.lastLogin = lastLogin
        self.createdAt = createdAt
    }
    
    mutating func updatePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
    }
    
    mutating func updateLastLogin() {
        lastLogin = Date()
    }
}

struct UserPreferences: Codable {
    var favoritePlaylists: [UUID]
    var recentlyUsedWallpapers: [UUID]
    var customShortcuts: [Shortcut]
    var displayPreferences: DisplayPreferences
    
    init(
        favoritePlaylists: [UUID] = [],
        recentlyUsedWallpapers: [UUID] = [],
        customShortcuts: [Shortcut] = [],
        displayPreferences: DisplayPreferences = DisplayPreferences()
    ) {
        self.favoritePlaylists = favoritePlaylists
        self.recentlyUsedWallpapers = recentlyUsedWallpapers
        self.customShortcuts = customShortcuts
        self.displayPreferences = displayPreferences
    }
}

struct Shortcut: Codable, Identifiable {
    let id: UUID
    var name: String
    var keyCombination: String
    var action: ShortcutAction
    
    init(
        id: UUID = UUID(),
        name: String,
        keyCombination: String,
        action: ShortcutAction
    ) {
        self.id = id
        self.name = name
        self.keyCombination = keyCombination
        self.action = action
    }
}

enum ShortcutAction: String, Codable {
    case nextWallpaper = "Next Wallpaper"
    case previousWallpaper = "Previous Wallpaper"
    case pauseRotation = "Pause Rotation"
    case resumeRotation = "Resume Rotation"
    case showApp = "Show App"
    case hideApp = "Hide App"
}

struct DisplayPreferences: Codable {
    var showWallpaperInfo: Bool
    var showPlaylistStats: Bool
    var thumbnailSize: ThumbnailSize
    var gridColumns: Int
    
    init(
        showWallpaperInfo: Bool = true,
        showPlaylistStats: Bool = true,
        thumbnailSize: ThumbnailSize = .medium,
        gridColumns: Int = 4
    ) {
        self.showWallpaperInfo = showWallpaperInfo
        self.showPlaylistStats = showPlaylistStats
        self.thumbnailSize = thumbnailSize
        self.gridColumns = gridColumns
    }
}

enum ThumbnailSize: String, Codable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var size: CGFloat {
        switch self {
        case .small: return 60
        case .medium: return 100
        case .large: return 150
        }
    }
} 