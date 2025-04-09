import Foundation
import AppKit

@MainActor
class MigrationManager: ObservableObject {
    static let shared = MigrationManager()
    
    @Published private(set) var currentVersion: AppVersion
    @Published private(set) var migrationStatus: MigrationStatus = .idle
    @Published private(set) var migrationProgress: Double = 0.0
    @Published private(set) var lastMigrationError: WallpaperError?
    
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private init() {
        self.userDefaults = UserDefaults.standard
        self.fileManager = FileManager.default
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.currentVersion = AppVersion.current
    }
    
    // MARK: - Version Management
    
    func checkForMigration() async throws {
        let lastVersion = userDefaults.string(forKey: "appVersion")
        guard let lastVersion = lastVersion else {
            // First run, no migration needed
            userDefaults.set(AppVersion.current.rawValue, forKey: "appVersion")
            return
        }
        
        guard let version = AppVersion(rawValue: lastVersion),
              version < AppVersion.current else {
            return
        }
        
        try await migrate(from: version, to: AppVersion.current)
    }
    
    // MARK: - Migration Operations
    
    private func migrate(from oldVersion: AppVersion, to newVersion: AppVersion) async throws {
        migrationStatus = .inProgress
        migrationProgress = 0.0
        lastMigrationError = nil
        
        defer {
            migrationStatus = .completed
            migrationProgress = 1.0
            userDefaults.set(newVersion.rawValue, forKey: "appVersion")
        }
        
        // Perform migrations in sequence
        for version in oldVersion.nextVersions(upTo: newVersion) {
            try await performMigration(to: version)
        }
    }
    
    private func performMigration(to version: AppVersion) async throws {
        switch version {
        case .v1_0_0:
            // Initial version, no migration needed
            break
            
        case .v1_1_0:
            try await migrateToV1_1_0()
            
        case .v1_2_0:
            try await migrateToV1_2_0()
            
        case .v1_3_0:
            try await migrateToV1_3_0()
        }
    }
    
    // MARK: - Version-Specific Migrations
    
    private func migrateToV1_1_0() async throws {
        // Add metadata to existing wallpapers
        let wallpapers = WallpaperManager.shared.allWallpapers
        for index in wallpapers.indices {
            do {
                _ = try await wallpapers[index].loadMetadata()
            } catch {
                lastMigrationError = error as? WallpaperError
            }
            migrationProgress = Double(index + 1) / Double(wallpapers.count)
        }
    }
    
    private func migrateToV1_2_0() async throws {
        // Add playlist settings
        for index in WallpaperManager.shared.playlists.indices {
            var playlist = WallpaperManager.shared.playlists[index]
            playlist.settings = PlaylistSettings()
            WallpaperManager.shared.playlists[index] = playlist
            migrationProgress = Double(index + 1) / Double(WallpaperManager.shared.playlists.count)
        }
    }
    
    private func migrateToV1_3_0() async throws {
        // Add user profile and preferences
        if WallpaperManager.shared.userProfile.preferences.customShortcuts.isEmpty {
            WallpaperManager.shared.userProfile.preferences.customShortcuts = [
                KeyboardShortcut(action: .nextWallpaper, keyCode: 124, modifiers: [.command, .shift]),
                KeyboardShortcut(action: .previousWallpaper, keyCode: 123, modifiers: [.command, .shift])
            ]
        }
        migrationProgress = 1.0
    }
    
    // MARK: - Helper Methods
    
    func validateMigration() async throws -> Bool {
        // Check if all data is in the correct format
        do {
            _ = try encoder.encode(WallpaperManager.shared.playlists)
            _ = try encoder.encode(WallpaperManager.shared.userSettings)
            _ = try encoder.encode(WallpaperManager.shared.userProfile)
            return true
        } catch {
            lastMigrationError = .migrationFailed(error.localizedDescription)
            return false
        }
    }
    
    func rollbackMigration() async throws {
        // Restore from backup if available
        if let backup = BackupManager.shared.backups.first {
            try await BackupManager.shared.restoreBackup(backup.id)
        }
        migrationStatus = .failed
    }
}

// MARK: - Supporting Types
enum AppVersion: String, Comparable {
    case v1_0_0 = "1.0.0"
    case v1_1_0 = "1.1.0"
    case v1_2_0 = "1.2.0"
    case v1_3_0 = "1.3.0"
    
    static var current: AppVersion {
        .v1_3_0
    }
    
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let lhsComponents = lhs.rawValue.split(separator: ".").compactMap { Int($0) }
        let rhsComponents = rhs.rawValue.split(separator: ".").compactMap { Int($0) }
        
        for (lhs, rhs) in zip(lhsComponents, rhsComponents) {
            if lhs < rhs { return true }
            if lhs > rhs { return false }
        }
        
        return lhsComponents.count < rhsComponents.count
    }
    
    func nextVersions(upTo target: AppVersion) -> [AppVersion] {
        var versions: [AppVersion] = []
        var current = self
        
        while current < target {
            switch current {
            case .v1_0_0:
                current = .v1_1_0
            case .v1_1_0:
                current = .v1_2_0
            case .v1_2_0:
                current = .v1_3_0
            case .v1_3_0:
                break
            }
            versions.append(current)
        }
        
        return versions
    }
} 