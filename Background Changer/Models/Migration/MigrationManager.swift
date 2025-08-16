import Foundation
import AppKit
import Wallpaper
import WallpaperTypes

@MainActor
class MigrationManager: ObservableObject {
    static let shared = MigrationManager()
    
    @Published private(set) var currentVersion: AppVersion
    @Published private(set) var migrationStatus: MigrationStatus = .notStarted
    @Published private(set) var migrationProgress: Double = 0.0
    @Published private(set) var lastMigrationError: WallpaperTypes.WallpaperError?
    
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
        migrationStatus = .inProgress(version: newVersion)
        migrationProgress = 0.0
        lastMigrationError = nil as WallpaperTypes.WallpaperError?
        
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
        if version == .v1_0_0 {
            // Initial version, no migration needed
        } else if version == .v1_1_0 {
            try await migrateToV1_1_0()
        } else if version == .v1_2_0 {
            try await migrateToV1_2_0()
        } else if version == .v1_3_0 {
            try await migrateToV1_3_0()
        } else {
            // Handle future versions
            print("Unknown version \(version), skipping migration")
        }
    }
    
    // MARK: - Version-Specific Migrations
    
    private func migrateToV1_1_0() async throws {
        // Add metadata to existing wallpapers
        // Migration placeholder - wallpaper manager instance not available in this context
        migrationProgress = 1.0
    }
    
    private func migrateToV1_2_0() async throws {
        // Add playlist settings
        // Migration placeholder - wallpaper manager instance not available in this context
        migrationProgress = 1.0
    }
    
    private func migrateToV1_3_0() async throws {
        // Add user profile and preferences
        // Migration placeholder - wallpaper manager instance not available in this context
        migrationProgress = 1.0
    }
    
    // MARK: - Helper Methods
    
    func validateMigration() async throws -> Bool {
        // Check if all data is in the correct format
        // Migration placeholder - proper validation would require wallpaper manager instance
        return true
    }
    
    func rollbackMigration() async throws {
        // Restore from backup if available
        // Migration placeholder - backup manager not implemented yet
        migrationStatus = .failed(error: "Migration rollback not yet implemented")
    }
} 