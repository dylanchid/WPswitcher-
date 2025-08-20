import Foundation
import WallpaperTypes
import Wallpaper

/// Clean dependency injection with protocol-oriented design
public protocol WallpaperManagerDependencies: Sendable {
    var wallpaperCoordinator: WallpaperCoordinatorProtocol { get }
    var storageService: StorageServiceProtocol { get }
    var cacheService: CacheServiceProtocol { get }
    var migrationCoordinator: MigrationCoordinatorProtocol { get }
}

/// Single source of truth for wallpaper operations
@MainActor
public protocol WallpaperCoordinatorProtocol: Sendable {
    // MARK: - Display Operations
    func setWallpaper(_ item: WallpaperItem, on screen: NSScreen?) async throws
    func updateDisplayMode(_ mode: DisplayMode) async throws
    
    // MARK: - Rotation Operations  
    func startRotation(playlist: Playlist) async throws
    func stopRotation() async throws
    
    // MARK: - Data Operations
    func addWallpapers(_ urls: [URL]) async throws -> [WallpaperItem]
    func removeWallpaper(_ item: WallpaperItem) async throws
    func validateWallpaper(_ item: WallpaperItem) async throws -> Bool
    
    // MARK: - Playlist Operations
    func createPlaylist(name: String) async throws -> Playlist
    func deletePlaylist(_ playlist: Playlist) async throws
    func updatePlaylist(_ playlist: Playlist) async throws
    func addWallpaperToPlaylist(_ wallpaper: WallpaperItem, playlist: Playlist) async throws
    func removeWallpaperFromPlaylist(_ wallpaper: WallpaperItem, playlist: Playlist) async throws
    func reorderWallpapers(in playlist: Playlist, from source: IndexSet, to destination: Int) async throws
    
    // MARK: - State Access
    var currentWallpaper: WallpaperItem? { get }
    var allPlaylists: [Playlist] { get async throws }
    var isRotationActive: Bool { get }
}

/// Separate concerns clearly for storage operations
public protocol StorageServiceProtocol: Sendable {
    func save<T: Codable>(_ object: T, key: String) async throws
    func load<T: Codable>(_ type: T.Type, key: String) async throws -> T?
    func delete(key: String) async throws
    func exists(key: String) async throws -> Bool
    func backup(key: String) async throws -> String // Returns backup ID
    func restore(key: String, backupId: String) async throws
}

/// Enhanced cache service protocol
public protocol CacheServiceProtocol: Sendable {
    func getMetadata(for url: URL) async -> WallpaperMetadata?
    func setMetadata(_ metadata: WallpaperMetadata, for url: URL) async
    func getThumbnail(for url: URL) async -> NSImage?
    func setThumbnail(_ image: NSImage, for url: URL) async
    func clearCache() async
    func getCacheSize() async -> Int64
    func evictOldEntries() async
}

/// Migration coordination protocol
public protocol MigrationCoordinatorProtocol: Sendable {
    func performMigration(from: AppVersion, to: AppVersion) async throws
    func validateCurrentVersion() async throws -> Bool
    func rollbackToVersion(_ version: AppVersion) async throws
    var currentVersion: AppVersion { get async throws }
}

/// Concrete implementation of dependencies
public final class DefaultWallpaperManagerDependencies: WallpaperManagerDependencies {
    public let wallpaperCoordinator: WallpaperCoordinatorProtocol
    public let storageService: StorageServiceProtocol
    public let cacheService: CacheServiceProtocol
    public let migrationCoordinator: MigrationCoordinatorProtocol
    
    public init(
        wallpaperCoordinator: WallpaperCoordinatorProtocol,
        storageService: StorageServiceProtocol,
        cacheService: CacheServiceProtocol,
        migrationCoordinator: MigrationCoordinatorProtocol
    ) {
        self.wallpaperCoordinator = wallpaperCoordinator
        self.storageService = storageService
        self.cacheService = cacheService
        self.migrationCoordinator = migrationCoordinator
    }
}
