import XCTest
import AppKit
@testable import Background_Changer

class PerformanceTests: XCTestCase {
    var testImages: [NSImage]!
    var testURLs: [URL]!
    var wallpaperManager: WallpaperManager!
    
    override func setUp() {
        super.setUp()
        wallpaperManager = WallpaperManager.shared
        wallpaperManager.clearWallpapers()
        
        // Create test images
        testImages = (0..<10).map { i in
            let image = NSImage(size: NSSize(width: 1000, height: 1000))
            image.lockFocus()
            NSColor(red: CGFloat(i) / 10.0, green: 0, blue: 0, alpha: 1.0).setFill()
            NSRect(origin: .zero, size: image.size).fill()
            image.unlockFocus()
            return image
        }
        
        // Create test URLs
        let tempDir = FileManager.default.temporaryDirectory
        testURLs = testImages.enumerated().map { i, image in
            let url = tempDir.appendingPathComponent("test_image_\(i).png")
            try? image.pngData()?.write(to: url)
            return url
        }
    }
    
    override func tearDown() {
        // Clean up test files
        for url in testURLs {
            try? FileManager.default.removeItem(at: url)
        }
        wallpaperManager.clearWallpapers()
        super.tearDown()
    }
    
    // MARK: - Wallpaper Loading Performance Tests
    
    func testWallpaperLoadingPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Load wallpapers")
            
            Task {
                do {
                    try await wallpaperManager.addWallpapers(testURLs)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to load wallpapers: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testMetadataLoadingPerformance() {
        // First load the wallpapers
        let expectation = XCTestExpectation(description: "Load wallpapers")
        Task {
            do {
                try await wallpaperManager.addWallpapers(testURLs)
                expectation.fulfill()
            } catch {
                XCTFail("Failed to load wallpapers: \(error)")
            }
        }
        wait(for: [expectation], timeout: 10.0)
        
        // Then measure metadata loading
        measure {
            let expectation = XCTestExpectation(description: "Load metadata")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for wallpaper in wallpaperManager.allWallpapers {
                        group.addTask {
                            try? await wallpaper.loadMetadata()
                        }
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testImageLoadingPerformance() {
        // First load the wallpapers
        let expectation = XCTestExpectation(description: "Load wallpapers")
        Task {
            do {
                try await wallpaperManager.addWallpapers(testURLs)
                expectation.fulfill()
            } catch {
                XCTFail("Failed to load wallpapers: \(error)")
            }
        }
        wait(for: [expectation], timeout: 10.0)
        
        // Then measure image loading
        measure {
            let expectation = XCTestExpectation(description: "Load images")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for wallpaper in wallpaperManager.allWallpapers {
                        group.addTask {
                            try? await wallpaper.loadImage()
                        }
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Cache Performance Tests
    
    func testCacheHitPerformance() {
        // First load and cache the wallpapers
        let expectation = XCTestExpectation(description: "Load and cache wallpapers")
        Task {
            do {
                try await wallpaperManager.addWallpapers(testURLs)
                for wallpaper in wallpaperManager.allWallpapers {
                    _ = try? await wallpaper.loadMetadata()
                    _ = try? await wallpaper.loadImage()
                }
                expectation.fulfill()
            } catch {
                XCTFail("Failed to load wallpapers: \(error)")
            }
        }
        wait(for: [expectation], timeout: 10.0)
        
        // Then measure cache hit performance
        measure {
            for wallpaper in wallpaperManager.allWallpapers {
                _ = wallpaper.metadata
                _ = try? wallpaper.loadImage()
            }
        }
    }
    
    func testCacheMissPerformance() {
        // Clear cache
        WallpaperCache.shared.clearCache()
        
        measure {
            for url in testURLs {
                _ = WallpaperCache.shared.getMetadata(for: url)
                _ = WallpaperCache.shared.getImage(for: url)
            }
        }
    }
} 