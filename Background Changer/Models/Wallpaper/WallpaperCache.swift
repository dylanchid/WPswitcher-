import Foundation
import AppKit
import SwiftUI

class WallpaperCache {
    static let shared = WallpaperCache()
    
    private let metadataCache = NSCache<NSString, WallpaperMetadata>()
    private let imageCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Initialize cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        cacheDirectory = appSupport.appendingPathComponent("BackgroundChanger/Cache")
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure cache limits
        metadataCache.countLimit = 1000 // Cache up to 1000 metadata entries
        imageCache.countLimit = 100 // Cache up to 100 images
        imageCache.totalCostLimit = 1024 * 1024 * 100 // 100MB limit for images
    }
    
    // MARK: - Metadata Caching
    
    func getMetadata(for url: URL) -> WallpaperMetadata? {
        let key = url.absoluteString as NSString
        return metadataCache.object(forKey: key)
    }
    
    func setMetadata(_ metadata: WallpaperMetadata, for url: URL) {
        let key = url.absoluteString as NSString
        metadataCache.setObject(metadata, forKey: key)
    }
    
    // MARK: - Image Caching
    
    func getImage(for url: URL) -> NSImage? {
        let key = url.absoluteString as NSString
        return imageCache.object(forKey: key)
    }
    
    func setImage(_ image: NSImage, for url: URL) {
        let key = url.absoluteString as NSString
        if let metadata = getMetadata(for: url) {
            imageCache.setObject(image, forKey: key, cost: metadata.estimatedCost())
        } else {
            imageCache.setObject(image, forKey: key)
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        metadataCache.removeAllObjects()
        imageCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func clearExpiredCache() {
        // Remove metadata for files that no longer exist
        let keysToRemove = metadataCache.allKeys.filter { key in
            guard let metadata = metadataCache.object(forKey: key) else { return true }
            return !fileManager.fileExists(atPath: metadata.url.path)
        }
        
        for key in keysToRemove {
            metadataCache.removeObject(forKey: key)
            imageCache.removeObject(forKey: key)
        }
    }
    
    // MARK: - Cache Statistics
    
    var metadataCacheCount: Int {
        return metadataCache.countLimit
    }
    
    var imageCacheCount: Int {
        return imageCache.countLimit
    }
    
    var totalCacheSize: Int64 {
        var totalSize: Int64 = 0
        let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
} 