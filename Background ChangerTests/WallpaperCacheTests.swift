import XCTest
import AppKit
@testable import Background_Changer

class WallpaperCacheTests: XCTestCase {
    var cache: WallpaperCache!
    var testImage: NSImage!
    var testURL: URL!
    var testMetadata: WallpaperMetadata!
    
    override func setUp() {
        super.setUp()
        cache = WallpaperCache.shared
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
            width: 100,
            height: 100,
            fileSize: 1024,
            lastModified: Date()
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
        XCTAssertEqual(retrievedMetadata?.width, testMetadata.width)
        XCTAssertEqual(retrievedMetadata?.height, testMetadata.height)
    }
    
    func testMetadataCacheExpiration() {
        // Test cache limit
        for i in 0..<1001 {
            let url = URL(string: "test://\(i)")!
            let metadata = WallpaperMetadata(
                width: i,
                height: i,
                fileSize: Int64(i),
                lastModified: Date()
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
} 