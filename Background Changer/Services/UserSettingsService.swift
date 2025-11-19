import Foundation
import AppKit
import WallpaperTypes

/// Protocol defining the contract for user settings management
@MainActor
protocol UserSettingsServiceProtocol {
    /// User Settings
    var userSettings: UserSettings { get }
    
    /// Settings Operations
    func updateSettings(_ settings: UserSettings) async throws
    func resetSettings() async throws
    func exportSettings() async throws -> Data
    func importSettings(_ data: Data) async throws
}

/// Struct representing backup settings
struct BackupSettings: Codable {
    var autoBackup: Bool
    var backupInterval: TimeInterval
    var backupLocation: String
    var maxBackups: Int

    init(autoBackup: Bool = false,
         backupInterval: TimeInterval = 604800, // Weekly
         backupLocation: String = "",
         maxBackups: Int = 5) {
        self.autoBackup = autoBackup
        self.backupInterval = backupInterval
        self.backupLocation = backupLocation
        self.maxBackups = maxBackups
    }
}

/// Struct representing user settings
struct UserSettings: Codable {
    // App Behavior
    var startAtLogin: Bool
    var showInDock: Bool
    var showInMenuBar: Bool
    var notificationsEnabled: Bool

    // Wallpaper Settings
    var defaultDisplayMode: DisplayMode
    var defaultRotationInterval: TimeInterval
    var randomOrder: Bool
    var changeOnWake: Bool
    var maxCacheSize: Int64
    var maxRecentWallpapers: Int

    // User Preferences
    var favoriteWallpapers: Set<UUID>
    var recentlyUsedWallpapers: [UUID]
    var customShortcuts: [KeyboardShortcut]
    var defaultFolders: [URL]
    var excludedFolders: [URL]

    // Backup Settings
    var backup: BackupSettings

    init(startAtLogin: Bool = false,
         showInDock: Bool = true,
         showInMenuBar: Bool = true,
         notificationsEnabled: Bool = true,
         defaultDisplayMode: DisplayMode = .fillScreen,
         defaultRotationInterval: TimeInterval = 3600,
         randomOrder: Bool = false,
         changeOnWake: Bool = true,
         maxCacheSize: Int64 = 1_073_741_824, // 1GB
         maxRecentWallpapers: Int = 50,
         favoriteWallpapers: Set<UUID> = [],
         recentlyUsedWallpapers: [UUID] = [],
         customShortcuts: [KeyboardShortcut] = [],
         defaultFolders: [URL] = [],
         excludedFolders: [URL] = [],
         backup: BackupSettings = BackupSettings()) {
        self.startAtLogin = startAtLogin
        self.showInDock = showInDock
        self.showInMenuBar = showInMenuBar
        self.notificationsEnabled = notificationsEnabled
        self.defaultDisplayMode = defaultDisplayMode
        self.defaultRotationInterval = defaultRotationInterval
        self.randomOrder = randomOrder
        self.changeOnWake = changeOnWake
        self.maxCacheSize = maxCacheSize
        self.maxRecentWallpapers = maxRecentWallpapers
        self.favoriteWallpapers = favoriteWallpapers
        self.recentlyUsedWallpapers = recentlyUsedWallpapers
        self.customShortcuts = customShortcuts
        self.defaultFolders = defaultFolders
        self.excludedFolders = excludedFolders
        self.backup = backup
    }
}

@MainActor
class UserSettingsService: ObservableObject, UserSettingsServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var userSettings: UserSettings
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // MARK: - Constants
    private let userSettingsKey = "userSettings"
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Load or create default settings
        if let data = userDefaults.data(forKey: userSettingsKey),
           let settings = try? decoder.decode(UserSettings.self, from: data) {
            self.userSettings = settings
        } else {
            self.userSettings = UserSettings()
        }
    }
    
    // MARK: - UserSettingsServiceProtocol Implementation
    
    func updateSettings(_ settings: UserSettings) async throws {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: userSettingsKey)
            userSettings = settings
        } catch {
            throw WallpaperError.systemError(error)
        }
    }
    
    func resetSettings() async throws {
        let defaultSettings = UserSettings()
        try await updateSettings(defaultSettings)
    }
    
    func exportSettings() async throws -> Data {
        do {
            return try encoder.encode(userSettings)
        } catch {
            throw WallpaperError.systemError(error)
        }
    }
    
    func importSettings(_ data: Data) async throws {
        do {
            let settings = try decoder.decode(UserSettings.self, from: data)
            try await updateSettings(settings)
        } catch {
            throw WallpaperError.systemError(error)
        }
    }
} 