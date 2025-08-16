import XCTest
@testable import Background_Changer

final class WallpaperTests: XCTestCase {
    var testImageURL: URL!
    var testMetadata: WallpaperMetadata!
    var cache: WallpaperCache!
    
    override func setUp() {
        super.setUp()
        cache = WallpaperCache.shared
        cache.clearCache()
        
        // Create a test image
        let testImage = NSImage(size: NSSize(width: 1920, height: 1080))
        let tempDir = FileManager.default.temporaryDirectory
        testImageURL = tempDir.appendingPathComponent("test_image.png")
        
        if let imageData = testImage.pngData() {
            try? imageData.write(to: testImageURL)
        }
        
        testMetadata = WallpaperMetadata(
            size: NSSize(width: 1920, height: 1080),
            fileSize: 1024 * 1024,
            format: "png",
            colorSpace: "RGB",
            dpi: 72.0,
            lastModified: Date(),
            creationDate: Date(),
            url: testImageURL,
            name: "test_image.png"
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testImageURL)
        cache.clearCache()
        super.tearDown()
    }
    
    // MARK: - WallpaperMetadata Tests
    
    func testWallpaperMetadataInitialization() {
        XCTAssertEqual(testMetadata.size.width, 1920)
        XCTAssertEqual(testMetadata.size.height, 1080)
        XCTAssertEqual(testMetadata.fileSize, 1024 * 1024)
        XCTAssertEqual(testMetadata.format, "png")
        XCTAssertEqual(testMetadata.colorSpace, "RGB")
        XCTAssertEqual(testMetadata.dpi, 72.0)
        XCTAssertEqual(testMetadata.name, "test_image.png")
    }
    
    func testWallpaperMetadataComputedProperties() {
        XCTAssertEqual(testMetadata.aspectRatio, 16/9, accuracy: 0.01)
        XCTAssertEqual(testMetadata.formattedFileSize, "1 MB")
        XCTAssertEqual(testMetadata.formattedDimensions, "1920x1080")
        XCTAssertEqual(testMetadata.estimatedCost, 1024)
    }
    
    // MARK: - WallpaperCache Tests
    
    func testMetadataCaching() {
        cache.setMetadata(testMetadata, for: testImageURL)
        let cachedMetadata = cache.getMetadata(for: testImageURL)
        
        XCTAssertNotNil(cachedMetadata)
        XCTAssertEqual(cachedMetadata?.size.width, testMetadata.size.width)
        XCTAssertEqual(cachedMetadata?.size.height, testMetadata.size.height)
    }
    
    func testImageCaching() {
        let testImage = NSImage(size: NSSize(width: 1920, height: 1080))
        cache.setImage(testImage, for: testImageURL)
        let cachedImage = cache.getImage(for: testImageURL)
        
        XCTAssertNotNil(cachedImage)
        XCTAssertEqual(cachedImage?.size.width, testImage.size.width)
        XCTAssertEqual(cachedImage?.size.height, testImage.size.height)
    }
    
    func testCacheClearing() {
        cache.setMetadata(testMetadata, for: testImageURL)
        cache.setImage(NSImage(size: NSSize(width: 1920, height: 1080)), for: testImageURL)
        
        cache.clearCache()
        
        XCTAssertNil(cache.getMetadata(for: testImageURL))
        XCTAssertNil(cache.getImage(for: testImageURL))
    }
    
    // MARK: - WallpaperItem Tests
    
    func testWallpaperItemInitialization() {
        let item = WallpaperItem(
            path: testImageURL.path,
            name: "test_image.png",
            metadata: testMetadata
        )
        
        XCTAssertEqual(item.path, testImageURL.path)
        XCTAssertEqual(item.name, "test_image.png")
        XCTAssertEqual(item.metadata?.size.width, testMetadata.size.width)
    }
    
    func testWallpaperItemValidation() {
        let item = WallpaperItem(
            path: testImageURL.path,
            name: "test_image.png"
        )
        
        XCTAssertTrue(item.isValidFormat)
        XCTAssertTrue(item.isValid)
    }
    
    func testWallpaperItemMetadataLoading() async throws {
        let item = WallpaperItem(
            path: testImageURL.path,
            name: "test_image.png"
        )
        
        let metadata = try await item.loadMetadata()
        XCTAssertEqual(metadata.size.width, 1920)
        XCTAssertEqual(metadata.size.height, 1080)
    }
    
    func testWallpaperItemBatchLoading() async throws {
        let items = [
            WallpaperItem(path: testImageURL.path, name: "test1.png"),
            WallpaperItem(path: testImageURL.path, name: "test2.png")
        ]
        
        let loadedItems = try await WallpaperItem.loadBatch(items)
        XCTAssertEqual(loadedItems.count, 2)
        XCTAssertNotNil(loadedItems[0].metadata)
        XCTAssertNotNil(loadedItems[1].metadata)
    }
} 