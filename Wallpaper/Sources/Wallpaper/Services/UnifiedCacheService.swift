import Foundation
import AppKit
import WallpaperTypes

public final class UnifiedCacheService: CacheServiceProtocol {
    // MARK: - Properties
    private let metadataCache = NSCache<NSString, WallpaperMetadataWrapper>()
    private let imageCache = NSCache<NSString, NSImage>()
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let metadataFile: URL
    private var metadata: [String: WallpaperMetadata]
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Initialization
    public init() {
        self.fileManager = .default
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
        
        // Initialize cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("BackgroundChanger/Cache")
        self.metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
        self.metadata = [:]
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure caches
        configureCaches()
        
        // Load metadata
        self.metadata = loadMetadata()
    }
    
    // MARK: - CacheServiceProtocol Implementation
    
    public func getMetadata(for url: URL) -> WallpaperMetadata? {
        let key = url.absoluteString as NSString
        if let cached = metadataCache.object(forKey: key)?.metadata {
            return cached
        }
        return metadata[url.absoluteString]
    }
    
    public func setMetadata(_ metadata: WallpaperMetadata, for url: URL) {
        let key = url.absoluteString as NSString
        metadataCache.setObject(WallpaperMetadataWrapper(metadata), forKey: key)
        self.metadata[url.absoluteString] = metadata
        saveMetadata()
    }
    
    public func removeMetadata(for url: URL) {
        let key = url.absoluteString as NSString
        metadataCache.removeObject(forKey: key)
        metadata.removeValue(forKey: url.absoluteString)
        saveMetadata()
    }
    
    public func getImage(for url: URL) -> NSImage? {
        let key = url.absoluteString as NSString
        return imageCache.object(forKey: key)
    }
    
    public func setImage(_ image: NSImage, for url: URL) {
        let key = url.absoluteString as NSString
        imageCache.setObject(image, forKey: key)
    }
    
    public func removeImage(for url: URL) {
        let key = url.absoluteString as NSString
        imageCache.removeObject(forKey: key)
    }
    
    public func clearCache() {
        metadataCache.removeAllObjects()
        imageCache.removeAllObjects()
        metadata.removeAll()
        saveMetadata()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    public func removeCache(for url: URL) {
        removeMetadata(for: url)
        removeImage(for: url)
    }
    
    public func cacheWallpaper(from url: URL) async throws -> URL {
        let fileName = url.lastPathComponent
        let cachedURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }
        
        try fileManager.copyItem(at: url, to: cachedURL)
        return cachedURL
    }
    
    public func removeFromCache(_ url: URL) async throws {
        try fileManager.removeItem(at: url)
        removeCache(for: url)
    }
    
    // MARK: - Private Methods
    
    private func configureCaches() {
        metadataCache.countLimit = 1000
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 1024 * 1024 * 100 // 100MB
    }
    
    private func loadMetadata() -> [String: WallpaperMetadata] {
        guard fileManager.fileExists(atPath: metadataFile.path) else {
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: metadataFile)
            return try jsonDecoder.decode([String: WallpaperMetadata].self, from: data)
        } catch {
            print("Error loading metadata: \(error)")
            return [:]
        }
    }
    
    private func saveMetadata() {
        do {
            let data = try jsonEncoder.encode(metadata)
            try data.write(to: metadataFile)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
}

// MARK: - Helper Types
private class WallpaperMetadataWrapper: NSObject {
    let metadata: WallpaperMetadata
    
    init(_ metadata: WallpaperMetadata) {
        self.metadata = metadata
    }
} 