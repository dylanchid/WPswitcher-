import XCTest
import AppKit
@testable import Background_Changer
import Wallpaper

class WallpaperItemTests: XCTestCase {
    var testWallpaper: WallpaperItem!
    var testURL: URL!
    var testImage: NSImage!
    var wallpaperService: WallpaperServiceProtocol!
    
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
        
        wallpaperService = UnifiedWallpaperService()
        
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
        wallpaperService = nil
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
        let metadata = try await wallpaperService.loadMetadata(for: testURL)
        XCTAssertNotNil(metadata)
        XCTAssertGreaterThan(metadata.dimensions.width, 0)
        XCTAssertGreaterThan(metadata.dimensions.height, 0)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertEqual(metadata.format, "jpg")
        XCTAssertEqual(metadata.colorSpace, "RGB")
        XCTAssertGreaterThan(metadata.dpi, 0)
    }
    
    func testLoadMetadataInvalidFile() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/image.jpg")
        
        do {
            _ = try await wallpaperService.loadMetadata(for: invalidURL)
            XCTFail("Expected error when loading invalid file")
        } catch {
            XCTAssertTrue(error is WallpaperError)
        }
    }
    
    func testReloadMetadata() async throws {
        let metadata1 = try await wallpaperService.loadMetadata(for: testURL)
        let metadata2 = try await wallpaperService.loadMetadata(for: testURL)
        
        XCTAssertEqual(metadata1.dimensions, metadata2.dimensions)
        XCTAssertEqual(metadata1.fileSize, metadata2.fileSize)
        XCTAssertEqual(metadata1.format, metadata2.format)
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
            dimensions: image.size,
            fileSize: 1024,
            format: "jpg",
            colorSpace: "RGB",
            dpi: 72.0
        )
    }
    
    override func tearDown() {
        testMetadata = nil
        testURL = nil
        super.tearDown()
    }
    
    func testMetadataInitialization() {
        XCTAssertNotNil(testMetadata)
        XCTAssertGreaterThan(testMetadata.dimensions.width, 0)
        XCTAssertGreaterThan(testMetadata.dimensions.height, 0)
        XCTAssertEqual(testMetadata.fileSize, 1024)
        XCTAssertEqual(testMetadata.format, "jpg")
        XCTAssertEqual(testMetadata.colorSpace, "RGB")
        XCTAssertEqual(testMetadata.dpi, 72.0)
    }
    
    func testAspectRatio() {
        let expectedRatio = testMetadata.dimensions.width / testMetadata.dimensions.height
        XCTAssertEqual(testMetadata.aspectRatio, expectedRatio)
    }
    
    func testFormattedFileSize() {
        let formattedSize = testMetadata.formattedFileSize
        XCTAssertTrue(formattedSize.contains("KB") || formattedSize.contains("bytes"))
    }
    
    func testIsValid() {
        XCTAssertTrue(testMetadata.isValid)
        
        let invalidMetadata = WallpaperMetadata(
            dimensions: CGSize(width: 0, height: 0),
            fileSize: 0,
            format: "",
            colorSpace: "",
            dpi: 0
        )
        XCTAssertFalse(invalidMetadata.isValid)
    }
} 