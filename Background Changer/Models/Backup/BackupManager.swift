import Foundation
import AppKit

@MainActor
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    @Published private(set) var backups: [Backup] = []
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var isBackingUp: Bool = false
    @Published private(set) var isRestoring: Bool = false
    @Published private(set) var currentProgress: Double = 0.0
    
    private let backupDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private init() {
        self.fileManager = FileManager.default
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Set up backup directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.backupDirectory = appSupport.appendingPathComponent("Backups")
        
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create backup directory: \(error)")
        }
        
        loadBackups()
    }
    
    // MARK: - Backup Operations
    
    func createBackup() async throws {
        guard !isBackingUp else { return }
        isBackingUp = true
        currentProgress = 0.0
        
        defer {
            isBackingUp = false
            currentProgress = 0.0
        }
        
        let backup = Backup(
            id: UUID(),
            timestamp: Date(),
            playlists: WallpaperManager.shared.playlists,
            wallpapers: WallpaperManager.shared.allWallpapers,
            userSettings: WallpaperManager.shared.userSettings,
            userProfile: WallpaperManager.shared.userProfile
        )
        
        let backupURL = backupDirectory.appendingPathComponent("\(backup.id).backup")
        let data = try encoder.encode(backup)
        try data.write(to: backupURL)
        
        backups.insert(backup, at: 0)
        lastBackupDate = backup.timestamp
        
        // Clean up old backups if needed
        if backups.count > WallpaperManager.shared.userSettings.backup.maxBackups {
            let oldBackups = backups.suffix(from: WallpaperManager.shared.userSettings.backup.maxBackups)
            for oldBackup in oldBackups {
                try? deleteBackup(oldBackup.id)
            }
        }
    }
    
    func restoreBackup(_ id: UUID) async throws {
        guard !isRestoring else { return }
        isRestoring = true
        currentProgress = 0.0
        
        defer {
            isRestoring = false
            currentProgress = 0.0
        }
        
        guard let backup = backups.first(where: { $0.id == id }) else {
            throw WallpaperError.backupFailed("Backup not found")
        }
        
        let backupURL = backupDirectory.appendingPathComponent("\(backup.id).backup")
        let data = try Data(contentsOf: backupURL)
        let restoredBackup = try decoder.decode(Backup.self, from: data)
        
        // Restore data
        WallpaperManager.shared.playlists = restoredBackup.playlists
        WallpaperManager.shared.userSettings = restoredBackup.userSettings
        WallpaperManager.shared.userProfile = restoredBackup.userProfile
        
        // Save restored data
        try WallpaperManager.shared.savePlaylists()
        try WallpaperManager.shared.saveUserSettings()
        try WallpaperManager.shared.saveUserProfile()
    }
    
    func deleteBackup(_ id: UUID) throws {
        let backupURL = backupDirectory.appendingPathComponent("\(id).backup")
        try fileManager.removeItem(at: backupURL)
        backups.removeAll { $0.id == id }
    }
    
    // MARK: - Helper Methods
    
    private func loadBackups() {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            backups = try backupFiles
                .filter { $0.pathExtension == "backup" }
                .compactMap { url in
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(Backup.self, from: data)
                }
                .sorted { $0.timestamp > $1.timestamp }
            
            lastBackupDate = backups.first?.timestamp
        } catch {
            print("Failed to load backups: \(error)")
        }
    }
    
    func validateBackup(_ id: UUID) async throws -> Bool {
        guard let backup = backups.first(where: { $0.id == id }) else {
            return false
        }
        
        let backupURL = backupDirectory.appendingPathComponent("\(backup.id).backup")
        let data = try Data(contentsOf: backupURL)
        _ = try decoder.decode(Backup.self, from: data)
        return true
    }
    
    func getBackupSize(_ id: UUID) -> Int64? {
        guard let backup = backups.first(where: { $0.id == id }) else {
            return nil
        }
        
        let backupURL = backupDirectory.appendingPathComponent("\(backup.id).backup")
        return try? fileManager.attributesOfItem(atPath: backupURL.path)[.size] as? Int64
    }
    
    func getBackupInfo(_ id: UUID) -> BackupInfo? {
        guard let backup = backups.first(where: { $0.id == id }) else {
            return nil
        }
        
        return BackupInfo(
            id: backup.id,
            timestamp: backup.timestamp,
            playlistCount: backup.playlists.count,
            wallpaperCount: backup.wallpapers.count,
            size: getBackupSize(id)
        )
    }
}

// MARK: - Supporting Types
struct Backup: Codable {
    let id: UUID
    let timestamp: Date
    let playlists: [Playlist]
    let wallpapers: [WallpaperItem]
    let userSettings: UserSettings
    let userProfile: UserProfile
}

struct BackupInfo {
    let id: UUID
    let timestamp: Date
    let playlistCount: Int
    let wallpaperCount: Int
    let size: Int64?
} 