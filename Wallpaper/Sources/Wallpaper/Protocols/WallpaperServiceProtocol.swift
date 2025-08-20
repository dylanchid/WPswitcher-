import Foundation
import AppKit
import WallpaperTypes

/// Protocol defining the core wallpaper service functionality
@preconcurrency
@MainActor
public protocol WallpaperServiceProtocol: Sendable {
    // MARK: - Wallpaper Management
    func setWallpaper(from url: URL, for screen: NSScreen?, mode: DisplayMode?) async throws
    func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem]
    func removeWallpaper(_ item: WallpaperItem) async throws
    
    // MARK: - Validation
    func validateWallpaper(path: String) async throws
    func getMetadata(path: String) async throws -> WallpaperMetadata
    
    // MARK: - Preloading
    func preloadMetadata(for wallpapers: [WallpaperItem]) async
    func preloadImages(for wallpapers: [WallpaperItem]) async
    
    // MARK: - Properties
    var currentWallpaperPath: String { get }
    var displayMode: DisplayMode { get set }
    var showOnAllSpaces: Bool { get set }
    
    // MARK: - Additional Methods
    func setWallpaper(_ wallpaper: WallpaperItem) async throws
    func getCurrentWallpaper() async throws -> WallpaperItem?
    func getWallpaperList() async throws -> [WallpaperItem]
} 