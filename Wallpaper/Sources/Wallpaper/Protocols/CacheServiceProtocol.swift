import Foundation
import AppKit
import WallpaperTypes

/// Protocol defining the caching functionality for wallpapers
@preconcurrency
public protocol CacheServiceProtocol {
    // MARK: - Metadata Caching
    func getMetadata(for url: URL) -> WallpaperMetadata?
    func setMetadata(_ metadata: WallpaperMetadata, for url: URL)
    func removeMetadata(for url: URL)
    
    // MARK: - Image Caching
    func getImage(for url: URL) -> NSImage?
    func setImage(_ image: NSImage, for url: URL)
    func removeImage(for url: URL)
    
    // MARK: - Cache Management
    func clearCache()
    func removeCache(for url: URL)
    
    // MARK: - File Operations
    func cacheWallpaper(from url: URL) async throws -> URL
    func removeFromCache(_ url: URL) async throws
} 