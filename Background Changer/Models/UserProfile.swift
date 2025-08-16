import Foundation
import WallpaperTypes

struct UserProfile: Codable {
    var preferences: UserPreferences
    var playlists: [Playlist]
    
    init() {
        self.preferences = UserPreferences()
        self.playlists = []
    }
}

struct UserPreferences: Codable {
    var startAtLogin: Bool
    var showInDock: Bool
    var showInMenuBar: Bool
    var displayMode: WallpaperTypes.DisplayMode
    var randomOrder: Bool
    var changeOnWake: Bool
    var showPlaylistNames: Bool
    var showWallpaperCount: Bool
    
    init() {
        self.startAtLogin = false
        self.showInDock = true
        self.showInMenuBar = true
        self.displayMode = .fillScreen
        self.randomOrder = false
        self.changeOnWake = true
        self.showPlaylistNames = true
        self.showWallpaperCount = true
    }
}
