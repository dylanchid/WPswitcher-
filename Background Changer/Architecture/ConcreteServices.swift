import Foundation
import WallpaperTypes
import Wallpaper
import AppKit
import OSLog

// MARK: - Enhanced Wallpaper Coordinator Implementation
@MainActor
public final class WallpaperCoordinator: WallpaperCoordinatorProtocol {
    private let wallpaperService: WallpaperTypes.WallpaperServiceProtocol
    private let playlistService: Wallpaper.PlaylistServiceProtocol
    private let rotationService: Wallpaper.WallpaperRotationServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    // Enhanced services
    private let imageProcessor: ImageProcessor
    private let smartRotationEngine: SmartRotationEngine
    private let fileMonitor: WallpaperFileMonitor
    private let adaptiveCache: AdaptiveCache
    private let stateStore: StateStore
    
    @Published public private(set) var currentWallpaper: WallpaperItem?
    @Published public private(set) var isRotationActive: Bool = false
    
    private let logger = Logger(subsystem: "WallpaperManager", category: "WallpaperCoordinator")
    
    public init(
        wallpaperService: WallpaperTypes.WallpaperServiceProtocol,
        playlistService: Wallpaper.PlaylistServiceProtocol,
        rotationService: Wallpaper.WallpaperRotationServiceProtocol,
        cacheService: CacheServiceProtocol,
        imageProcessor: ImageProcessor = ImageProcessor.shared,
        smartRotationEngine: SmartRotationEngine = SmartRotationEngine(),
        fileMonitor: WallpaperFileMonitor = WallpaperFileMonitor(),
        adaptiveCache: AdaptiveCache = AdaptiveCache(),
        stateStore: StateStore
    ) {
        self.wallpaperService = wallpaperService
        self.playlistService = playlistService
        self.rotationService = rotationService
        self.cacheService = cacheService
        self.imageProcessor = imageProcessor
        self.smartRotationEngine = smartRotationEngine
        self.fileMonitor = fileMonitor
        self.adaptiveCache = adaptiveCache
        self.stateStore = stateStore
    }
    
    // MARK: - Display Operations
    public func setWallpaper(_ item: WallpaperItem, on screen: NSScreen?) async throws {
        // Validate wallpaper through state store
        guard stateStore.state.wallpapers.contains(where: { $0.id == item.id }) else {
            throw WallpaperError.stateManagement(.invalidWallpaper)
        }
        
        let targetScreen = screen ?? NSScreen.main
        
        // Use enhanced image processing for validation
        do {
            let processedWallpaper = try await imageProcessor.processWallpaper(at: item.url)
            
            // Set wallpaper using the service  
            try await wallpaperService.setWallpaper(from: item.url, for: targetScreen, mode: nil)
            
            // Update state through store
            try await stateStore.setCurrentWallpaper(item)
            
            // Start monitoring file changes
            fileMonitor.monitorWallpaper(item) { [weak self] change, url in
                Task { @MainActor in
                    await self?.handleFileChange(change, for: url)
                }
            }
            
            logger.info("Successfully set wallpaper: \(item.name)")
            
        } catch {
            logger.error("Failed to set wallpaper: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func updateDisplayMode(_ mode: DisplayMode) async throws {
        guard let currentWallpaper = stateStore.state.currentWallpaper else {
            throw WallpaperError.stateManagement(.invalidWallpaper)
        }
        
        // Update display settings through state store
        try await stateStore.dispatch(AppAction.setDisplayMode(mode))
        
        // Reapply wallpaper with new mode
        try await setWallpaper(currentWallpaper, on: nil)
    }
    
    // MARK: - Rotation Operations
    public func startRotation(playlist: Playlist) async throws {
        guard !playlist.wallpapers.isEmpty else {
            throw WallpaperError.playlistOperation(.empty)
        }
        
        // Validate playlist exists in state
        guard stateStore.state.playlists.contains(where: { $0.id == playlist.id }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        
        // Start rotation through state store
        try await stateStore.startRotation(playlistId: playlist.id)
        
        // Configure rotation service
        await rotationService.setRotationInterval(playlist.rotationInterval)
        await rotationService.start()
        
        // Set first wallpaper if none is current
        if stateStore.state.currentWallpaper == nil,
           let firstWallpaper = playlist.wallpapers.first {
            try await setWallpaper(firstWallpaper, on: nil)
        }
        
        logger.info("Started rotation for playlist: \(playlist.name)")
    }
    
    public func stopRotation() async throws {
        try await stateStore.stopRotation()
        rotationService.stop()
        logger.info("Stopped wallpaper rotation")
    }
    
    // MARK: - Data Operations
    public func addWallpapers(_ urls: [URL]) async throws -> [WallpaperItem] {
        var wallpapers: [WallpaperItem] = []
        
        for url in urls {
            guard url.isFileURL else {
                throw WallpaperError.network(.invalidURL(url.absoluteString))
            }
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw WallpaperError.systemOperation(.insufficientPermissions("File not found: \(url.path)"))
            }
            
            do {
                // Process image with enhanced processor
                _ = try await imageProcessor.processWallpaper(at: url)
                
                let wallpaper = WallpaperItem(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent
                )
                
                // Add to state store
                try await stateStore.addWallpaper(wallpaper)
                
                wallpapers.append(wallpaper)
                
            } catch {
                logger.error("Failed to process wallpaper \(url.lastPathComponent): \(error.localizedDescription)")
                throw error
            }
        }
        
        return wallpapers
    }
    
    public func removeWallpaper(_ item: WallpaperItem) async throws {
        // Remove from state store
        try await stateStore.removeWallpaper(id: item.id)
        
        // Stop monitoring
        fileMonitor.stopMonitoring(item.url)
        
        // Clear from caches
        adaptiveCache.removeImage(for: item.url)
        adaptiveCache.removeMetadata(for: item.url)
        
        logger.info("Removed wallpaper: \(item.name)")
    }
    
    public func validateWallpaper(_ item: WallpaperItem) async throws -> Bool {
        do {
            _ = try await imageProcessor.processWallpaper(at: item.url)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Playlist Operations
    public func createPlaylist(name: String) async throws -> Playlist {
        let playlistId = try await stateStore.createPlaylist(name: name)
        
        guard let playlist = stateStore.state.playlists.first(where: { $0.id == playlistId }) else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        
        return playlist
    }
    
    public func deletePlaylist(_ playlist: Playlist) async throws {
        try await stateStore.dispatch(AppAction.deletePlaylist(playlist.id))
        logger.info("Deleted playlist: \(playlist.name)")
    }
    
    public func updatePlaylist(_ playlist: Playlist) async throws {
        try await stateStore.dispatch(AppAction.updatePlaylist(playlist))
        logger.info("Updated playlist: \(playlist.name)")
    }
    
    public func addWallpaperToPlaylist(_ wallpaper: WallpaperItem, playlist: Playlist) async throws {
        try await stateStore.dispatch(AppAction.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlist.id))
    }
    
    public func removeWallpaperFromPlaylist(_ wallpaper: WallpaperItem, playlist: Playlist) async throws {
        try await stateStore.dispatch(AppAction.removeWallpaperFromPlaylist(wallpaperId: wallpaper.id, playlistId: playlist.id))
    }
    
    public func reorderWallpapers(in playlist: Playlist, from source: IndexSet, to destination: Int) async throws {
        try await stateStore.dispatch(AppAction.reorderPlaylistWallpapers(playlistId: playlist.id, from: source, to: destination))
    }
    
    // MARK: - File Change Handling
    private func handleFileChange(_ change: FileChange, for url: URL) async {
        logger.info("File change detected: \(String(describing: change)) for \(url.lastPathComponent)")
        
        guard let wallpaper = stateStore.state.wallpapers.first(where: { $0.url == url }) else {
            return
        }
        
        switch change {
        case .deleted, .accessLost:
            do {
                try await removeWallpaper(wallpaper)
                try await stateStore.dispatch(AppAction.setError(WallpaperError.systemOperation(.insufficientPermissions("File deleted: \(url.lastPathComponent)"))))
            } catch {
                logger.error("Failed to handle file deletion: \(error.localizedDescription)")
            }
            
        case .modified:
            // Invalidate caches and reprocess
            adaptiveCache.removeImage(for: url)
            adaptiveCache.removeMetadata(for: url)
            
            do {
                _ = try await imageProcessor.processWallpaper(at: url)
            } catch {
                logger.error("Failed to reprocess modified wallpaper: \(error.localizedDescription)")
            }
            
        case .recovered:
            logger.info("File recovered: \(url.lastPathComponent)")
            try? await stateStore.dispatch(AppAction.clearError)
            
        default:
            break
        }
    }
    
    // MARK: - Smart Rotation
    public func rotateToNext() async throws {
        guard let activePlaylist = stateStore.activePlaylist else {
            throw WallpaperError.stateManagement(.playlistNotFound)
        }
        
        let context = RotationContext(
            currentWallpaper: stateStore.state.currentWallpaper,
            screenSize: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        )
        
        guard let nextWallpaper = smartRotationEngine.selectNextWallpaper(
            from: activePlaylist,
            mode: stateStore.state.rotationSettings.playbackMode,
            context: context
        ) else {
            throw WallpaperError.playlistOperation(.empty)
        }
        
        try await setWallpaper(nextWallpaper, on: nil)
    }
    
    // MARK: - State Access
    public var allPlaylists: [Playlist] {
        get async throws {
            return stateStore.state.playlists
        }
    }
}

// MARK: - Enhanced Storage Service Implementation
public final class DefaultStorageService: StorageServiceProtocol, @unchecked Sendable {
    private let documentsDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init() throws {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WallpaperManager")
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: documentsDirectory,
            withIntermediateDirectories: true
        )
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    public func save<T: Codable>(_ object: T, key: String) async throws {
        let data = try encoder.encode(object)
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        try data.write(to: url)
    }
    
    public func load<T: Codable>(_ type: T.Type, key: String) async throws -> T? {
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }
    
    public func delete(key: String) async throws {
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    public func exists(key: String) async throws -> Bool {
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public func backup(key: String) async throws -> String {
        let sourceURL = documentsDirectory.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw WallpaperError.systemOperation(.insufficientPermissions("No file to backup for key: \(key)"))
        }
        
        let backupId = "backup_\(key)_\(Date().timeIntervalSince1970)"
        let backupURL = documentsDirectory.appendingPathComponent("\(backupId).json")
        
        try FileManager.default.copyItem(at: sourceURL, to: backupURL)
        return backupId
    }
    
    public func restore(key: String, backupId: String) async throws {
        let backupURL = documentsDirectory.appendingPathComponent("\(backupId).json")
        let targetURL = documentsDirectory.appendingPathComponent("\(key).json")
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw WallpaperError.systemOperation(.insufficientPermissions("Backup not found: \(backupId)"))
        }
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        
        try FileManager.default.copyItem(at: backupURL, to: targetURL)
    }
}
