// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AppKit
import WallpaperTypes
import OSLog

@MainActor
public class WallpaperManager {
    // MARK: - Properties
    private var wallpaperService: WallpaperServiceProtocol
    private var rotationService: WallpaperRotationServiceProtocol
    private let logger = Logger(subsystem: "com.wallpaper", category: "manager")
    
    // MARK: - Initialization
    public init(wallpaperService: WallpaperServiceProtocol) {
        self.wallpaperService = wallpaperService
        self.rotationService = WallpaperRotationService(wallpaperService: wallpaperService)
    }
    
    // MARK: - Public Methods
    
    /// Sets wallpaper for specific screen with options
    public func setWallpaper(from url: URL, for screen: NSScreen? = nil, mode: DisplayMode? = nil) async throws {
        logger.info("Setting wallpaper from URL: \(url.path)")
        
        // Validate wallpaper
        do {
            try await wallpaperService.validateWallpaper(path: url.path)
        } catch {
            throw WallpaperError.invalidImage(error.localizedDescription)
        }
        
        // Get metadata with explicit type annotation
        let metadata: WallpaperMetadata = try await wallpaperService.getMetadata(path: url.path)
        logger.debug("Wallpaper metadata: \(String(describing: metadata))")
        
        // Set wallpaper
        try await wallpaperService.setWallpaper(from: url, for: screen, mode: mode)
    }
    
    /// Starts wallpaper rotation with specified interval
    public func startRotation(interval: TimeInterval) async {
        logger.info("Starting wallpaper rotation with interval: \(interval) seconds")
        await rotationService.setRotationInterval(interval)
        await rotationService.start()
    }
    
    /// Stops wallpaper rotation
    public func stopRotation() async {
        logger.info("Stopping wallpaper rotation")
        rotationService.stop()
    }
    
    /// Rotate to next wallpaper
    public func rotateToNext() async throws {
        try await rotationService.rotateToNext()
    }
    
    /// Rotate to previous wallpaper
    public func rotateToPrevious() async throws {
        try await rotationService.rotateToPrevious()
    }
    
    // MARK: - Additional Methods

    /// Adds multiple wallpapers
    public func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem] {
        logger.info("Adding \(urls.count) wallpapers")
        return try await wallpaperService.addWallpapers(from: urls)
    }
    
    /// Removes a wallpaper
    public func removeWallpaper(_ item: WallpaperItem) async throws {
        logger.info("Removing wallpaper: \(item.name)")
        try await wallpaperService.removeWallpaper(item)
    }
    
    /// Gets metadata for a wallpaper
    public func getMetadata(for url: URL) async throws -> WallpaperMetadata {
        logger.debug("Getting metadata for wallpaper at: \(url.path)")
        return try await wallpaperService.getMetadata(path: url.path)
    }
    
    /// Validates a wallpaper
    public func validateWallpaper(_ url: URL) async throws -> Bool {
        logger.debug("Validating wallpaper at: \(url.path)")
        do {
            try await wallpaperService.validateWallpaper(path: url.path)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Properties
    public var currentWallpaperPath: String {
        wallpaperService.currentWallpaperPath
    }
    
    public var displayMode: DisplayMode {
        get { wallpaperService.displayMode }
        set { wallpaperService.displayMode = newValue }
    }
    
    public var showOnAllSpaces: Bool {
        get { wallpaperService.showOnAllSpaces }
        set { wallpaperService.showOnAllSpaces = newValue }
    }
    
    public var isRotationEnabled: Bool {
        get { rotationService.isRotationEnabled }
        set { rotationService.isRotationEnabled = newValue }
    }
    
    public var rotationInterval: TimeInterval {
        rotationService.rotationInterval
    }
    
    // MARK: - Undo/Redo Support
    public func undo() async throws {
        // Implementation for undo functionality
    }
    
    public func redo() async throws {
        // Implementation for redo functionality
    }
}

// MARK: - WallpaperManager Factory Extension
extension WallpaperManager {
    /// Factory method to create a properly configured WallpaperManager
    public static func create() -> WallpaperManager {
        let wallpaperService = SystemWallpaperService()
        return WallpaperManager(wallpaperService: wallpaperService)
    }
}

// MARK: - Additional WallpaperManager Methods for AppDelegate Compatibility
extension WallpaperManager {
    // Properties that the AppDelegate expects
    public var isRotating: Bool {
        rotationService.isRotationEnabled
    }
    
    public var customInterval: TimeInterval {
        rotationService.rotationInterval
    }
    
    public var userPlaylists: [WallpaperTypes.Playlist] {
        // This should come from a playlist service - placeholder for now
        []
    }
    
    // Methods that the AppDelegate expects
    public func nextWallpaper() throws {
        Task {
            try await rotateToNext()
        }
    }
    
    public func previousWallpaper() throws {
        Task {
            try await rotateToPrevious()
        }
    }
    
    public func randomWallpaper() throws {
        Task {
            try await rotateToNext() // For now, just rotate to next
        }
    }
    
    public func setWallpaper(from url: URL) async {
        do {
            try await setWallpaper(from: url, for: nil, mode: nil)
        } catch {
            logger.error("Failed to set wallpaper: \(error.localizedDescription)")
        }
    }
    
    public func startPlaylistRotation(playlistId: UUID, interval: TimeInterval) {
        Task {
            await startRotation(interval: interval)
        }
    }
    
    public func updateDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
    }
    
    public func undo() throws {
        Task {
            try await undo()
        }
    }
    
    public func redo() throws {
        Task {
            try await redo()
        }
    }
    
    public func rotateToNext() throws {
        Task {
            try await rotateToNext()
        }
    }
}
