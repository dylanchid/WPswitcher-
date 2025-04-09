import XCTest
import AppKit
@testable import Background_Changer

class WallpaperItemTests: XCTestCase {
    var testWallpaper: WallpaperItem!
    var testURL: URL!
    var testImage: NSImage!
    
    override func setUp() {
        super.setUp()
        
        // Create test image
        testImage = NSImage(size: NSSize(width: 800, height: 600))
        testImage.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: testImage.size).fill()
        testImage.unlockFocus()
        
        // Save test image to temporary directory
        testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-image.jpg")
        if let tiffData = testImage.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let imageData = bitmapImage.representation(using: .jpeg, properties: [:]) {
            try? imageData.write(to: testURL)
        }
        
        testWallpaper = WallpaperItem(
            id: UUID(),
            path: testURL.path,
            name: "Test Image",
            isSelected: false
        )
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testURL)
        testWallpaper = nil
        testURL = nil
        testImage = nil
        super.tearDown()
    }
    
    func testWallpaperItemInitialization() {
        XCTAssertNotNil(testWallpaper)
        XCTAssertEqual(testWallpaper.name, "Test Image")
        XCTAssertFalse(testWallpaper.isSelected)
        XCTAssertNil(testWallpaper.metadata)
        XCTAssertNil(testWallpaper.lastError)
    }
    
    func testFileURL() {
        XCTAssertEqual(testWallpaper.fileURL, testURL)
    }
    
    func testIsValid() {
        XCTAssertTrue(testWallpaper.isValid)
        
        let invalidWallpaper = WallpaperItem(
            id: UUID(),
            path: "/nonexistent/path/image.jpg",
            name: "Invalid Image"
        )
        XCTAssertFalse(invalidWallpaper.isValid)
    }
    
    func testIsValidFormat() {
        XCTAssertTrue(testWallpaper.isValidFormat)
        
        let invalidFormatWallpaper = WallpaperItem(
            id: UUID(),
            path: testURL.deletingPathExtension().appendingPathExtension("txt").path,
            name: "Invalid Format"
        )
        XCTAssertFalse(invalidFormatWallpaper.isValidFormat)
    }
    
    func testLoadMetadata() async throws {
        let metadata = try await testWallpaper.loadMetadata()
        XCTAssertNotNil(metadata)
        XCTAssertGreaterThan(metadata.size.width, 0)
        XCTAssertGreaterThan(metadata.size.height, 0)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertNotNil(metadata.lastModified)
        XCTAssertEqual(metadata.format, "jpg")
    }
    
    func testLoadMetadataInvalidFile() async {
        let invalidWallpaper = WallpaperItem(
            id: UUID(),
            path: "/nonexistent/path/image.jpg",
            name: "Invalid Image"
        )
        
        do {
            _ = try await invalidWallpaper.loadMetadata()
            XCTFail("Expected error when loading invalid file")
        } catch {
            XCTAssertTrue(error is WallpaperError)
        }
    }
    
    func testReloadMetadata() async throws {
        let metadata1 = try await testWallpaper.loadMetadata()
        let metadata2 = try await testWallpaper.reloadMetadata()
        
        XCTAssertNotEqual(metadata1.lastModified, metadata2.lastModified)
    }
    
    func testClearCache() async throws {
        _ = try await testWallpaper.loadMetadata()
        XCTAssertNotNil(testWallpaper.metadata)
        
        testWallpaper.clearCache()
        XCTAssertNil(testWallpaper.metadata)
    }
    
    func testBatchLoading() async throws {
        let wallpapers = [
            testWallpaper,
            WallpaperItem(
                id: UUID(),
                path: testURL.path,
                name: "Test Image 2",
                isSelected: false
            )
        ]
        
        let loadedWallpapers = try await WallpaperItem.loadBatch(wallpapers)
        XCTAssertEqual(loadedWallpapers.count, 2)
        
        for wallpaper in loadedWallpapers {
            XCTAssertNotNil(wallpaper.metadata)
        }
    }
}

class WallpaperMetadataTests: XCTestCase {
    var testMetadata: WallpaperMetadata!
    var testURL: URL!
    
    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: type(of: self))
        testURL = bundle.url(forResource: "test-image", withExtension: "jpg")!
        
        let image = NSImage(contentsOf: testURL)!
        testMetadata = WallpaperMetadata(
            url: testURL,
            name: "Test Image",
            size: image.size,
            fileSize: 1024,
            lastModified: Date(),
            format: "jpg"
        )
    }
    
    override func tearDown() {
        testMetadata = nil
        testURL = nil
        super.tearDown()
    }
    
    func testMetadataInitialization() {
        XCTAssertNotNil(testMetadata)
        XCTAssertEqual(testMetadata.url, testURL)
        XCTAssertEqual(testMetadata.name, "Test Image")
        XCTAssertGreaterThan(testMetadata.size.width, 0)
        XCTAssertGreaterThan(testMetadata.size.height, 0)
        XCTAssertEqual(testMetadata.fileSize, 1024)
        XCTAssertEqual(testMetadata.format, "jpg")
    }
    
    func testAspectRatio() {
        let expectedRatio = testMetadata.size.width / testMetadata.size.height
        XCTAssertEqual(testMetadata.aspectRatio, expectedRatio)
    }
    
    func testFormattedFileSize() {
        let formattedSize = testMetadata.formattedFileSize
        XCTAssertTrue(formattedSize.contains("KB") || formattedSize.contains("bytes"))
    }
    
    func testFormattedLastModified() {
        let formattedDate = testMetadata.formattedLastModified
        XCTAssertFalse(formattedDate.isEmpty)
    }
    
    func testIsValid() {
        XCTAssertTrue(testMetadata.isValid())
        
        let invalidMetadata = WallpaperMetadata(
            url: testURL,
            name: "Invalid",
            size: CGSize(width: 0, height: 0),
            fileSize: 0,
            lastModified: Date(),
            format: ""
        )
        XCTAssertFalse(invalidMetadata.isValid())
    }
    
    func testEquality() {
        let sameMetadata = WallpaperMetadata(
            url: testURL,
            name: "Test Image",
            size: testMetadata.size,
            fileSize: 1024,
            lastModified: testMetadata.lastModified,
            format: "jpg"
        )
        
        XCTAssertEqual(testMetadata, sameMetadata)
        
        let differentMetadata = WallpaperMetadata(
            url: testURL,
            name: "Different",
            size: CGSize(width: 100, height: 100),
            fileSize: 2048,
            lastModified: Date(),
            format: "png"
        )
        
        XCTAssertNotEqual(testMetadata, differentMetadata)
    }
    
    func testHash() {
        let sameMetadata = WallpaperMetadata(
            url: testURL,
            name: "Test Image",
            size: testMetadata.size,
            fileSize: 1024,
            lastModified: testMetadata.lastModified,
            format: "jpg"
        )
        
        XCTAssertEqual(testMetadata.hash, sameMetadata.hash)
    }
    
    func testLoadFromURL() async throws {
        let metadata = try await WallpaperMetadata.load(from: testURL)
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata.url, testURL)
        XCTAssertGreaterThan(metadata.size.width, 0)
        XCTAssertGreaterThan(metadata.size.height, 0)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertNotNil(metadata.lastModified)
        XCTAssertEqual(metadata.format, "jpg")
    }
    
    func testLoadFromInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/image.jpg")
        
        do {
            _ = try await WallpaperMetadata.load(from: invalidURL)
            XCTFail("Expected error when loading from invalid URL")
        } catch {
            XCTAssertTrue(error is WallpaperError)
        }
    }
} 