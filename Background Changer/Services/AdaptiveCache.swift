import Foundation
import AppKit
import OSLog

// MARK: - Adaptive Cache with Memory Pressure Handling
public final class AdaptiveCache {
    private let imageCache = NSCache<NSURL, NSImage>()
    private let metadataCache = NSCache<NSURL, CachedMetadata>()
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let previewCache = NSCache<NSURL, NSImage>()
    
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let logger = Logger(subsystem: "WallpaperManager", category: "AdaptiveCache")
    
    // Cache statistics
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    
    // Configuration
    private let defaultImageCacheSize = 50 * 1024 * 1024 // 50MB
    private let defaultThumbnailCacheSize = 20 * 1024 * 1024 // 20MB
    private let defaultPreviewCacheSize = 100 * 1024 * 1024 // 100MB
    private let defaultMetadataCacheSize = 5 * 1024 * 1024 // 5MB
    
    // Access tracking for LRU
    private var accessTimes: [String: Date] = [:]
    private let accessQueue = DispatchQueue(label: "cache.access", qos: .utility)
    
    public init() {
        setupCaches()
        setupMemoryPressureHandling()
        setupPeriodicCleanup()
    }
    
    deinit {
        memoryPressureSource?.cancel()
    }
    
    // MARK: - Cache Setup
    private func setupCaches() {
        // Image cache (full-size images)
        imageCache.name = "ImageCache"
        imageCache.countLimit = 100
        imageCache.totalCostLimit = defaultImageCacheSize
        imageCache.delegate = self
        
        // Thumbnail cache
        thumbnailCache.name = "ThumbnailCache"
        thumbnailCache.countLimit = 500
        thumbnailCache.totalCostLimit = defaultThumbnailCacheSize
        thumbnailCache.delegate = self
        
        // Preview cache
        previewCache.name = "PreviewCache"
        previewCache.countLimit = 200
        previewCache.totalCostLimit = defaultPreviewCacheSize
        previewCache.delegate = self
        
        // Metadata cache
        metadataCache.name = "MetadataCache"
        metadataCache.countLimit = 1000
        metadataCache.totalCostLimit = defaultMetadataCacheSize
        metadataCache.delegate = self
    }
    
    private func setupMemoryPressureHandling() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.memoryPressureSource?.data
            switch event {
            case .some(.warning):
                self.handleMemoryWarning()
            case .some(.critical):
                self.handleCriticalMemoryPressure()
            default:
                break
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func setupPeriodicCleanup() {
        // Clean up old access times every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupOldAccessTimes()
        }
    }
    
    // MARK: - Memory Pressure Handling
    private func handleMemoryWarning() {
        logger.warning("Memory pressure warning - reducing cache sizes")
        reduceCacheSize(by: 0.5)
        cleanupLeastRecentlyUsed()
    }
    
    private func handleCriticalMemoryPressure() {
        logger.error("Critical memory pressure - clearing all caches")
        clearAllCaches()
    }
    
    public func reduceCacheSize(by factor: Double) {
        let reductionFactor = min(0.9, max(0.1, factor))
        
        // Reduce image cache
        let newImageLimit = Int(Double(imageCache.totalCostLimit) * (1 - reductionFactor))
        imageCache.totalCostLimit = max(10 * 1024 * 1024, newImageLimit) // Min 10MB
        imageCache.countLimit = max(10, Int(Double(imageCache.countLimit) * (1 - reductionFactor)))
        
        // Reduce thumbnail cache
        let newThumbnailLimit = Int(Double(thumbnailCache.totalCostLimit) * (1 - reductionFactor))
        thumbnailCache.totalCostLimit = max(5 * 1024 * 1024, newThumbnailLimit) // Min 5MB
        thumbnailCache.countLimit = max(50, Int(Double(thumbnailCache.countLimit) * (1 - reductionFactor)))
        
        // Reduce preview cache
        let newPreviewLimit = Int(Double(previewCache.totalCostLimit) * (1 - reductionFactor))
        previewCache.totalCostLimit = max(20 * 1024 * 1024, newPreviewLimit) // Min 20MB
        previewCache.countLimit = max(20, Int(Double(previewCache.countLimit) * (1 - reductionFactor)))
        
        logger.info("Cache sizes reduced by \(Int(reductionFactor * 100))%")
    }
    
    private func cleanupLeastRecentlyUsed() {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
            let oldKeys = self.accessTimes.compactMap { key, date in
                date < cutoffDate ? key : nil
            }
            
            for key in oldKeys {
                let nsKey = NSString(string: key)
                self.imageCache.removeObject(forKey: nsKey)
                self.thumbnailCache.removeObject(forKey: nsKey)
                self.previewCache.removeObject(forKey: nsKey)
                self.metadataCache.removeObject(forKey: nsKey)
                self.accessTimes.removeValue(forKey: key)
            }
            
            if !oldKeys.isEmpty {
                self.logger.info("Cleaned up \(oldKeys.count) least recently used items")
            }
        }
    }
    
    private func cleanupOldAccessTimes() {
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cutoffDate = Date().addingTimeInterval(-7200) // 2 hours ago
            let oldKeys = self.accessTimes.compactMap { key, date in
                date < cutoffDate ? key : nil
            }
            
            for key in oldKeys {
                self.accessTimes.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Image Caching
    public func setImage(_ image: NSImage, for url: URL, type: ImageType = .full) {
        let key = cacheKey(for: url, type: type)
        let nsKey = NSString(string: key)
        let cost = estimateImageCost(image)
        
        recordAccess(key: key)
        
        switch type {
        case .full:
            imageCache.setObject(image, forKey: nsKey, cost: cost)
        case .thumbnail:
            thumbnailCache.setObject(image, forKey: nsKey, cost: cost)
        case .preview:
            previewCache.setObject(image, forKey: nsKey, cost: cost)
        }
        
        logger.debug("Cached \(type.rawValue) image: \(url.lastPathComponent)")
    }
    
    public func getImage(for url: URL, type: ImageType = .full) -> NSImage? {
        let key = cacheKey(for: url, type: type)
        let nsKey = NSString(string: key)
        
        let image: NSImage?
        switch type {
        case .full:
            image = imageCache.object(forKey: nsKey)
        case .thumbnail:
            image = thumbnailCache.object(forKey: nsKey)
        case .preview:
            image = previewCache.object(forKey: nsKey)
        }
        
        if image != nil {
            recordAccess(key: key)
            hitCount += 1
            logger.debug("Cache hit for \(type.rawValue): \(url.lastPathComponent)")
        } else {
            missCount += 1
            logger.debug("Cache miss for \(type.rawValue): \(url.lastPathComponent)")
        }
        
        return image
    }
    
    public func removeImage(for url: URL, type: ImageType? = nil) {
        if let type = type {
            let key = cacheKey(for: url, type: type)
            let nsKey = NSString(string: key)
            
            switch type {
            case .full:
                imageCache.removeObject(forKey: nsKey)
            case .thumbnail:
                thumbnailCache.removeObject(forKey: nsKey)
            case .preview:
                previewCache.removeObject(forKey: nsKey)
            }
            
            accessQueue.async { [weak self] in
                self?.accessTimes.removeValue(forKey: key)
            }
        } else {
            // Remove all types
            for imageType in ImageType.allCases {
                removeImage(for: url, type: imageType)
            }
        }
    }
    
    // MARK: - Metadata Caching
    public func setMetadata(_ metadata: CachedMetadata, for url: URL) {
        let key = cacheKey(for: url, type: .metadata)
        let nsKey = NSString(string: key)
        let cost = MemoryLayout<CachedMetadata>.size
        
        metadataCache.setObject(metadata, forKey: nsKey, cost: cost)
        recordAccess(key: key)
        
        logger.debug("Cached metadata: \(url.lastPathComponent)")
    }
    
    public func getMetadata(for url: URL) -> CachedMetadata? {
        let key = cacheKey(for: url, type: .metadata)
        let nsKey = NSString(string: key)
        
        let metadata = metadataCache.object(forKey: nsKey)
        
        if metadata != nil {
            recordAccess(key: key)
            hitCount += 1
        } else {
            missCount += 1
        }
        
        return metadata
    }
    
    public func removeMetadata(for url: URL) {
        let key = cacheKey(for: url, type: .metadata)
        let nsKey = NSString(string: key)
        
        metadataCache.removeObject(forKey: nsKey)
        
        accessQueue.async { [weak self] in
            self?.accessTimes.removeValue(forKey: key)
        }
    }
    
    // MARK: - Cache Management
    public func clearAllCaches() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        previewCache.removeAllObjects()
        metadataCache.removeAllObjects()
        
        accessQueue.async { [weak self] in
            self?.accessTimes.removeAll()
        }
        
        logger.info("All caches cleared")
    }
    
    public func clearExpiredEntries(olderThan timeInterval: TimeInterval = 3600) {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        
        accessQueue.async { [weak self] in
            guard let self = self else { return }
            
            let expiredKeys = self.accessTimes.compactMap { key, date in
                date < cutoffDate ? key : nil
            }
            
            for key in expiredKeys {
                let nsKey = NSString(string: key)
                self.imageCache.removeObject(forKey: nsKey)
                self.thumbnailCache.removeObject(forKey: nsKey)
                self.previewCache.removeObject(forKey: nsKey)
                self.metadataCache.removeObject(forKey: nsKey)
                self.accessTimes.removeValue(forKey: key)
            }
            
            if !expiredKeys.isEmpty {
                self.logger.info("Cleared \(expiredKeys.count) expired cache entries")
            }
        }
    }
    
    // MARK: - Cache Statistics
    public func getCacheStatistics() -> CacheStatistics {
        let totalRequests = hitCount + missCount
        let hitRatio = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        
        return CacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            hitRatio: hitRatio,
            imageCacheSize: imageCache.totalCostLimit,
            thumbnailCacheSize: thumbnailCache.totalCostLimit,
            previewCacheSize: previewCache.totalCostLimit,
            metadataCacheSize: metadataCache.totalCostLimit,
            totalEntries: accessTimes.count
        )
    }
    
    public func resetStatistics() {
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }
    
    // MARK: - Preloading
    public func preloadImages(for urls: [URL], priority: OperationQueuePriority = .normal) {
        let preloadQueue = OperationQueue()
        preloadQueue.maxConcurrentOperationCount = 3
        preloadQueue.qualityOfService = .utility
        
        for url in urls {
            let operation = BlockOperation { [weak self] in
                guard let self = self else { return }
                
                // Check if already cached
                if self.getImage(for: url, type: .thumbnail) == nil {
                    if let image = NSImage(contentsOf: url) {
                        // Generate and cache thumbnail
                        let thumbnail = self.createThumbnail(from: image, size: CGSize(width: 200, height: 150))
                        self.setImage(thumbnail, for: url, type: .thumbnail)
                    }
                }
            }
            
            operation.queuePriority = priority
            preloadQueue.addOperation(operation)
        }
    }
    
    // MARK: - Utility Methods
    private func cacheKey(for url: URL, type: ImageType) -> String {
        return "\(type.rawValue)_\(url.absoluteString)"
    }
    
    private func cacheKey(for url: URL, type: MetadataType) -> String {
        return "\(type.rawValue)_\(url.absoluteString)"
    }
    
    private func recordAccess(key: String) {
        accessQueue.async { [weak self] in
            self?.accessTimes[key] = Date()
        }
    }
    
    private func estimateImageCost(_ image: NSImage) -> Int {
        let size = image.size
        let bytesPerPixel = 4 // RGBA
        return Int(size.width * size.height) * bytesPerPixel
    }
    
    private func createThumbnail(from image: NSImage, size: CGSize) -> NSImage {
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        let sourceRect = NSRect(origin: .zero, size: image.size)
        let destRect = NSRect(origin: .zero, size: size)
        
        image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }
}

// MARK: - NSCacheDelegate
extension AdaptiveCache: NSCacheDelegate {
    public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: AnyObject) {
        evictionCount += 1
        
        // Log eviction for debugging
        if let cacheName = cache.name {
            logger.debug("Cache eviction in \(cacheName)")
        }
    }
}

// MARK: - Supporting Types
public enum ImageType: String, CaseIterable {
    case full = "full"
    case thumbnail = "thumbnail"
    case preview = "preview"
}

public enum MetadataType: String {
    case metadata = "metadata"
}

public class CachedMetadata: NSObject {
    public let url: URL
    public let dimensions: CGSize
    public let fileSize: Int64
    public let modificationDate: Date
    public let colorSpace: String
    public let hasAlpha: Bool
    public let dominantColors: [NSColor]
    public let cacheDate: Date
    
    public init(
        url: URL,
        dimensions: CGSize,
        fileSize: Int64,
        modificationDate: Date,
        colorSpace: String,
        hasAlpha: Bool,
        dominantColors: [NSColor]
    ) {
        self.url = url
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.colorSpace = colorSpace
        self.hasAlpha = hasAlpha
        self.dominantColors = dominantColors
        self.cacheDate = Date()
        super.init()
    }
    
    public var isStale: Bool {
        // Check if cached metadata is older than file modification
        return cacheDate < modificationDate
    }
}

public struct CacheStatistics {
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let hitRatio: Double
    public let imageCacheSize: Int
    public let thumbnailCacheSize: Int
    public let previewCacheSize: Int
    public let metadataCacheSize: Int
    public let totalEntries: Int
    
    public var totalCacheSize: Int {
        return imageCacheSize + thumbnailCacheSize + previewCacheSize + metadataCacheSize
    }
    
    public var formattedHitRatio: String {
        return String(format: "%.1f%%", hitRatio * 100)
    }
    
    public var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(totalCacheSize), countStyle: .memory)
    }
}

// MARK: - Cache Factory
public final class CacheFactory {
    public static func createAdaptiveCache(
        imageCacheSize: Int = 50 * 1024 * 1024,
        thumbnailCacheSize: Int = 20 * 1024 * 1024,
        previewCacheSize: Int = 100 * 1024 * 1024
    ) -> AdaptiveCache {
        let cache = AdaptiveCache()
        
        // Configure custom sizes if needed
        if imageCacheSize != 50 * 1024 * 1024 {
            cache.imageCache.totalCostLimit = imageCacheSize
        }
        if thumbnailCacheSize != 20 * 1024 * 1024 {
            cache.thumbnailCache.totalCostLimit = thumbnailCacheSize
        }
        if previewCacheSize != 100 * 1024 * 1024 {
            cache.previewCache.totalCostLimit = previewCacheSize
        }
        
        return cache
    }
    
    public static func createMemoryConstrainedCache() -> AdaptiveCache {
        // Smaller cache for memory-constrained environments
        return createAdaptiveCache(
            imageCacheSize: 20 * 1024 * 1024,    // 20MB
            thumbnailCacheSize: 10 * 1024 * 1024, // 10MB
            previewCacheSize: 30 * 1024 * 1024    // 30MB
        )
    }
}
