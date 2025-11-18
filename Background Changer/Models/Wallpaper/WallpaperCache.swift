import Foundation
import AppKit

class WallpaperCache {
    static let shared = WallpaperCache()

    private let imageCache = NSCache<NSString, NSImage>()
    private let expirationCache = NSCache<NSString, NSDate>()
    private let fileManager = FileManager.default
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    // Track actual cache statistics
    private var cachedKeys: Set<String> = []
    private var totalCacheSize: Int = 0
    private let statsLock = NSLock()

    private init() {
        configureCache()
    }

    private func configureCache() {
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 1024 * 1024 * 100 // 100MB

        // Set delegate to track evictions
        imageCache.delegate = CacheDelegate(cache: self)
    }
    
    // MARK: - Image Caching
    
    func getImage(for url: URL) -> NSImage? {
        let key = url.absoluteString as NSString
        
        if let expirationDate = expirationCache.object(forKey: key), expirationDate.timeIntervalSinceNow < 0 {
            // Expired
            removeImage(for: url)
            return nil
        }
        
        return imageCache.object(forKey: key)
    }
    
    func setImage(_ image: NSImage, for url: URL) {
        let key = url.absoluteString as NSString
        let keyString = url.absoluteString
        let expirationDate = NSDate(timeIntervalSinceNow: cacheDuration)

        // Calculate image size (approximate)
        let imageSize = estimateImageSize(image)

        // Update tracking
        statsLock.lock()
        if !cachedKeys.contains(keyString) {
            cachedKeys.insert(keyString)
            totalCacheSize += imageSize
        }
        statsLock.unlock()

        imageCache.setObject(image, forKey: key, cost: imageSize)
        expirationCache.setObject(expirationDate, forKey: key)
    }

    func removeImage(for url: URL) {
        let key = url.absoluteString as NSString
        let keyString = url.absoluteString

        // Get size before removal for tracking
        if let image = imageCache.object(forKey: key) {
            let imageSize = estimateImageSize(image)
            statsLock.lock()
            cachedKeys.remove(keyString)
            totalCacheSize = max(0, totalCacheSize - imageSize)
            statsLock.unlock()
        }

        imageCache.removeObject(forKey: key)
        expirationCache.removeObject(forKey: key)
    }

    // MARK: - Cache Management

    func clearCache() {
        imageCache.removeAllObjects()
        expirationCache.removeAllObjects()

        statsLock.lock()
        cachedKeys.removeAll()
        totalCacheSize = 0
        statsLock.unlock()
    }

    // MARK: - Cache Statistics

    var imageCacheCount: Int {
        statsLock.lock()
        let count = cachedKeys.count
        statsLock.unlock()
        return count
    }

    var imageCacheSize: Int {
        statsLock.lock()
        let size = totalCacheSize
        statsLock.unlock()
        return size
    }

    /// Returns cache size in human readable format
    var formattedCacheSize: String {
        let bytes = imageCacheSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    // MARK: - Private Helpers

    private func estimateImageSize(_ image: NSImage) -> Int {
        // Estimate size based on image dimensions and assumed 4 bytes per pixel (RGBA)
        let size = image.size
        return Int(size.width * size.height * 4)
    }

    /// Called when an object is evicted from cache
    fileprivate func objectEvicted(forKey key: String, cost: Int) {
        statsLock.lock()
        cachedKeys.remove(key)
        totalCacheSize = max(0, totalCacheSize - cost)
        statsLock.unlock()
    }
}

// MARK: - Cache Delegate
private class CacheDelegate: NSObject, NSCacheDelegate {
    weak var cache: WallpaperCache?

    init(cache: WallpaperCache) {
        self.cache = cache
    }

    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Note: NSCache doesn't provide the key in willEvictObject
        // For more accurate tracking, we'd need a wrapper object
        // This is a limitation of NSCache
    }
} 