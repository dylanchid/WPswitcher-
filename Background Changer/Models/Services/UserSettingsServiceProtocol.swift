import Foundation
import AppKit

/// Protocol defining the contract for user settings management
protocol UserSettingsServiceProtocol {
    /// User Settings
    var userSettings: UserSettings { get }
    var userProfile: UserProfile { get }
    
    /// Settings Operations
    func updateSettings(_ settings: UserSettings) async throws
    func updateProfile(_ profile: UserProfile) async throws
    func resetSettings() async throws
    func exportSettings() async throws -> Data
    func importSettings(_ data: Data) async throws
}

/// Struct representing user settings
struct UserSettings: Codable {
    var startAtLogin: Bool
    var showInDock: Bool
    var showInMenuBar: Bool
    var notificationsEnabled: Bool
    var autoUpdateEnabled: Bool
    var checkForUpdatesInterval: TimeInterval
    var maxCacheSize: Int64
    var maxRecentWallpapers: Int
    var defaultDisplayMode: DisplayMode
    var defaultRotationInterval: TimeInterval
    
    init(startAtLogin: Bool = false,
         showInDock: Bool = true,
         showInMenuBar: Bool = true,
         notificationsEnabled: Bool = true,
         autoUpdateEnabled: Bool = true,
         checkForUpdatesInterval: TimeInterval = 86400, // 24 hours
         maxCacheSize: Int64 = 1_073_741_824, // 1GB
         maxRecentWallpapers: Int = 50,
         defaultDisplayMode: DisplayMode = .fillScreen,
         defaultRotationInterval: TimeInterval = 3600) {
        self.startAtLogin = startAtLogin
        self.showInDock = showInDock
        self.showInMenuBar = showInMenuBar
        self.notificationsEnabled = notificationsEnabled
        self.autoUpdateEnabled = autoUpdateEnabled
        self.checkForUpdatesInterval = checkForUpdatesInterval
        self.maxCacheSize = maxCacheSize
        self.maxRecentWallpapers = maxRecentWallpapers
        self.defaultDisplayMode = defaultDisplayMode
        self.defaultRotationInterval = defaultRotationInterval
    }
}

/// Struct representing user profile and preferences
struct UserProfile: Codable {
    var id: UUID
    var preferences: UserPreferences
    var statistics: UserStatistics
    
    init(id: UUID = UUID(),
         preferences: UserPreferences = UserPreferences(),
         statistics: UserStatistics = UserStatistics()) {
        self.id = id
        self.preferences = preferences
        self.statistics = statistics
    }
}

/// Struct representing user preferences
struct UserPreferences: Codable {
    var favoriteWallpapers: Set<UUID>
    var recentlyUsedWallpapers: [UUID]
    var customShortcuts: [KeyboardShortcut]
    var defaultFolders: [URL]
    var excludedFolders: [URL]
    var tags: Set<String>
    
    init(favoriteWallpapers: Set<UUID> = [],
         recentlyUsedWallpapers: [UUID] = [],
         customShortcuts: [KeyboardShortcut] = [],
         defaultFolders: [URL] = [],
         excludedFolders: [URL] = [],
         tags: Set<String> = []) {
        self.favoriteWallpapers = favoriteWallpapers
        self.recentlyUsedWallpapers = recentlyUsedWallpapers
        self.customShortcuts = customShortcuts
        self.defaultFolders = defaultFolders
        self.excludedFolders = excludedFolders
        self.tags = tags
    }
}

/// Struct representing user statistics
struct UserStatistics: Codable {
    var totalWallpapersUsed: Int
    var totalPlaytime: TimeInterval
    var lastUsedDate: Date?
    var mostUsedWallpapers: [UUID: Int]
    var mostUsedTags: [String: Int]
    
    init(totalWallpapersUsed: Int = 0,
         totalPlaytime: TimeInterval = 0,
         lastUsedDate: Date? = nil,
         mostUsedWallpapers: [UUID: Int] = [:],
         mostUsedTags: [String: Int] = [:]) {
        self.totalWallpapersUsed = totalWallpapersUsed
        self.totalPlaytime = totalPlaytime
        self.lastUsedDate = lastUsedDate
        self.mostUsedWallpapers = mostUsedWallpapers
        self.mostUsedTags = mostUsedTags
    }
}

/// Struct representing a keyboard shortcut
struct KeyboardShortcut: Codable, Identifiable {
    var id: UUID
    var action: ShortcutAction
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    
    init(id: UUID = UUID(),
         action: ShortcutAction,
         keyCode: UInt16,
         modifiers: NSEvent.ModifierFlags) {
        self.id = id
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// Enum representing shortcut actions
enum ShortcutAction: String, Codable, CaseIterable {
    case nextWallpaper = "Next Wallpaper"
    case previousWallpaper = "Previous Wallpaper"
    case toggleRotation = "Toggle Rotation"
    case showPreferences = "Show Preferences"
    case addWallpaper = "Add Wallpaper"
    
    var description: String {
        return rawValue
    }
} 