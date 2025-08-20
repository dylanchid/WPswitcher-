import Foundation
import AppKit

/// Protocol defining the core functionality for managing wallpapers
@preconcurrency
@MainActor
public protocol WallpaperServiceProtocol {
    /// Sets a wallpaper from a URL for a specific screen with optional display mode
    func setWallpaper(from url: URL, for screen: NSScreen?, mode: DisplayMode?) async throws
    
    /// Starts wallpaper rotation with the specified interval
    func startRotation(interval: TimeInterval) async
    
    /// Stops wallpaper rotation
    func stopRotation()
    
    /// Adds multiple wallpapers from URLs
    func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem]
    
    /// Removes a wallpaper
    func removeWallpaper(_ item: WallpaperItem) async throws
    
    /// Validates a wallpaper file
    func validateWallpaper(path: String) async throws
    
    /// Gets metadata for a wallpaper file
    func getMetadata(path: String) async throws -> WallpaperMetadata
    
    /// Current wallpaper path
    var currentWallpaperPath: String { get }
    
    /// Current display mode
    var displayMode: DisplayMode { get set }
    
    /// Whether to show the wallpaper on all spaces
    var showOnAllSpaces: Bool { get set }
}

/// Protocol defining functionality for wallpaper rotation
@preconcurrency
@MainActor
public protocol WallpaperRotationServiceProtocol {
    /// Starts the rotation service
    func start() async
    
    /// Stops the rotation service
    func stop()
    
    /// Sets the rotation interval
    func setRotationInterval(_ interval: TimeInterval) async
    
    /// Gets the next wallpaper in the rotation
    func getNextWallpaper() async throws -> WallpaperItem?
    
    /// Whether rotation is currently enabled
    var isRotationEnabled: Bool { get set }
    
    /// Current rotation interval
    var rotationInterval: TimeInterval { get }
}

/// Protocol defining functionality for managing wallpaper playlists
public protocol WallpaperPlaylistProtocol {
    /// Adds a wallpaper to the playlist
    func addWallpaper(_ item: WallpaperItem) async throws
    
    /// Removes a wallpaper from the playlist
    func removeWallpaper(_ item: WallpaperItem) async throws
    
    /// Reorders wallpapers in the playlist
    func reorderWallpapers(_ items: [WallpaperItem]) async throws
    
    /// Gets the next wallpaper in the playlist
    func getNextWallpaper() async throws -> WallpaperItem?
    
    /// Unique identifier for the playlist
    var id: UUID { get }
    
    /// Name of the playlist
    var name: String { get }
    
    /// List of wallpapers in the playlist
    var wallpapers: [WallpaperItem] { get }
    
    /// Rotation interval for the playlist
    var rotationInterval: TimeInterval { get set }
}
