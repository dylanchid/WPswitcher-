import Foundation
import AppKit

class WallpaperCache {
    static let shared = WallpaperCache()
    
    private let imageCache = NSCache<NSString, NSImage>()
    private let expirationCache = NSCache<NSString, NSDate>()
    private let fileManager = FileManager.default
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {
        configureCache()
    }
    
    private func configureCache() {
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 1024 * 1024 * 100 // 100MB
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
        let expirationDate = NSDate(timeIntervalSinceNow: cacheDuration)
        
        imageCache.setObject(image, forKey: key)
        expirationCache.setObject(expirationDate, forKey: key)
    }
    
    func removeImage(for url: URL) {
        let key = url.absoluteString as NSString
        imageCache.removeObject(forKey: key)
        expirationCache.removeObject(forKey: key)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        imageCache.removeAllObjects()
        expirationCache.removeAllObjects()
    }
    
    // MARK: - Cache Statistics
    
    var imageCacheCount: Int {
        // NSCache doesn't provide a direct count property
        // Return an estimate based on countLimit
        return 0 // TODO: Implement proper cache count tracking if needed
    }
    
    var imageCacheSize: Int {
        // NSCache doesn't provide a direct totalCost property
        // Return an estimate based on totalCostLimit
        return 0 // TODO: Implement proper cache size tracking if needed
    }
} 