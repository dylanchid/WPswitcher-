import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentError: WallpaperError?
    @Published var isLoading: Bool = false
    @Published var activeView: AppView = .home
    @Published var selectedPlaylist: UUID?
    @Published var selectedWallpaper: UUID?
    @Published var isSettingsOpen: Bool = false
    @Published var isBackupOpen: Bool = false
    @Published var isMigrationOpen: Bool = false
    
    // User preferences
    @Published var preferences: UserPreferences = UserPreferences()
    
    // Playlist state
    @Published var playlists: [Playlist] = []
    @Published var expandedPlaylists: Set<UUID> = []
    
    // Wallpaper state
    @Published var currentWallpaper: WallpaperItem?
    @Published var recentlyUsedWallpapers: [WallpaperItem] = []
    
    // Backup state
    @Published var backupHistory: [Backup] = []
    @Published var lastBackupDate: Date?
    
    // Migration state
    @Published var migrationStatus: MigrationStatus = .idle
    @Published var migrationProgress: Double = 0.0
    
    // MARK: - Error Handling
    func handleError(_ error: WallpaperError) {
        currentError = error
    }
    
    func clearError() {
        currentError = nil
    }
    
    // MARK: - Loading State
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    // MARK: - View Management
    func navigate(to view: AppView) {
        activeView = view
    }
    
    // MARK: - Playlist Management
    func selectPlaylist(_ id: UUID?) {
        selectedPlaylist = id
    }
    
    func togglePlaylistExpansion(_ id: UUID) {
        if expandedPlaylists.contains(id) {
            expandedPlaylists.remove(id)
        } else {
            expandedPlaylists.insert(id)
        }
    }
    
    // MARK: - Wallpaper Management
    func selectWallpaper(_ id: UUID?) {
        selectedWallpaper = id
    }
    
    func addToRecentlyUsed(_ wallpaper: WallpaperItem) {
        recentlyUsedWallpapers.removeAll { $0.id == wallpaper.id }
        recentlyUsedWallpapers.insert(wallpaper, at: 0)
        if recentlyUsedWallpapers.count > 10 {
            recentlyUsedWallpapers.removeLast()
        }
    }
    
    // MARK: - Settings Management
    func toggleSettings() {
        isSettingsOpen.toggle()
    }
    
    // MARK: - Backup Management
    func addBackup(_ backup: Backup) {
        backupHistory.insert(backup, at: 0)
        lastBackupDate = backup.timestamp
    }
    
    // MARK: - Migration Management
    func startMigration() {
        migrationStatus = .inProgress
        migrationProgress = 0.0
    }
    
    func updateMigrationProgress(_ progress: Double) {
        migrationProgress = progress
    }
    
    func completeMigration() {
        migrationStatus = .completed
        migrationProgress = 1.0
    }
    
    func resetMigration() {
        migrationStatus = .idle
        migrationProgress = 0.0
    }
}

// MARK: - Supporting Types
enum AppView: String, CaseIterable {
    case home = "Home"
    case playlists = "Playlists"
    case allPhotos = "All Photos"
    case settings = "Settings"
    case backup = "Backup"
    case migration = "Migration"
}

enum MigrationStatus {
    case idle
    case inProgress
    case completed
    case failed
}

struct UserPreferences: Codable {
    var thumbnailSize: ThumbnailSize = .medium
    var showMetadata: Bool = true
    var autoLoadMetadata: Bool = true
    var backupInterval: TimeInterval = 86400 // 24 hours
    var maxBackups: Int = 10
    var theme: AppTheme = .system
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
} 