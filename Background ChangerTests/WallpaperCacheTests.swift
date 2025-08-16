import XCTest
import AppKit
@testable import Background_Changer
import Wallpaper

class WallpaperCacheTests: XCTestCase {
    var cache: CacheServiceProtocol!
    var testImage: NSImage!
    var testURL: URL!
    var testMetadata: WallpaperMetadata!
    
    override func setUp() {
        super.setUp()
        cache = UnifiedCacheService()
        cache.clearCache()
        
        // Create test image
        testImage = NSImage(size: NSSize(width: 100, height: 100))
        testImage.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: testImage.size).fill()
        testImage.unlockFocus()
        
        // Create test URL
        let tempDir = FileManager.default.temporaryDirectory
        testURL = tempDir.appendingPathComponent("test_image.png")
        try? testImage.pngData()?.write(to: testURL)
        
        // Create test metadata
        testMetadata = WallpaperMetadata(
            dimensions: CGSize(width: 100, height: 100),
            fileSize: 1024,
            format: "png",
            colorSpace: "RGB",
            dpi: 72.0
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testURL)
        cache.clearCache()
        super.tearDown()
    }
    
    // MARK: - Metadata Cache Tests
    
    func testMetadataCache() {
        // Test setting metadata
        cache.setMetadata(testMetadata, for: testURL)
        
        // Test getting metadata
        let retrievedMetadata = cache.getMetadata(for: testURL)
        XCTAssertNotNil(retrievedMetadata)
        XCTAssertEqual(retrievedMetadata?.dimensions.width, testMetadata.dimensions.width)
        XCTAssertEqual(retrievedMetadata?.dimensions.height, testMetadata.dimensions.height)
    }
    
    func testMetadataCacheExpiration() {
        // Test cache limit
        for i in 0..<1001 {
            let url = URL(string: "test://\(i)")!
            let metadata = WallpaperMetadata(
                dimensions: CGSize(width: CGFloat(i), height: CGFloat(i)),
                fileSize: Int64(i),
                format: "png",
                colorSpace: "RGB",
                dpi: 72.0
            )
            cache.setMetadata(metadata, for: url)
        }
        
        // First item should be evicted
        let firstURL = URL(string: "test://0")!
        XCTAssertNil(cache.getMetadata(for: firstURL))
    }
    
    // MARK: - Image Cache Tests
    
    func testImageCache() {
        // Test setting image
        cache.setImage(testImage, for: testURL)
        
        // Test getting image
        let retrievedImage = cache.getImage(for: testURL)
        XCTAssertNotNil(retrievedImage)
        XCTAssertEqual(retrievedImage?.size, testImage.size)
    }
    
    func testImageCacheExpiration() {
        // Test cache limit
        for i in 0..<101 {
            let url = URL(string: "test://\(i)")!
            let image = NSImage(size: NSSize(width: i, height: i))
            cache.setImage(image, for: url)
        }
        
        // First item should be evicted
        let firstURL = URL(string: "test://0")!
        XCTAssertNil(cache.getImage(for: firstURL))
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCache() {
        // Add items to cache
        cache.setMetadata(testMetadata, for: testURL)
        cache.setImage(testImage, for: testURL)
        
        // Clear cache
        cache.clearCache()
        
        // Verify cache is empty
        XCTAssertNil(cache.getMetadata(for: testURL))
        XCTAssertNil(cache.getImage(for: testURL))
    }
    
    // MARK: - File Operations Tests
    
    func testCacheWallpaper() async throws {
        let cachedURL = try await cache.cacheWallpaper(from: testURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cachedURL.path))
        XCTAssertNotEqual(cachedURL, testURL)
    }
    
    func testRemoveFromCache() async throws {
        let cachedURL = try await cache.cacheWallpaper(from: testURL)
        try await cache.removeFromCache(cachedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedURL.path))
    }
} 