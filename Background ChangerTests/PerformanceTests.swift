import XCTest
import AppKit
@testable import Background_Changer
import Wallpaper

class PerformanceTests: XCTestCase {
    var testImages: [NSImage]!
    var testURLs: [URL]!
    var wallpaperManager: WallpaperManager!
    var wallpaperService: WallpaperServiceProtocol!
    var cacheService: CacheServiceProtocol!
    
    override func setUp() {
        super.setUp()
        wallpaperService = UnifiedWallpaperService()
        cacheService = UnifiedCacheService()
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
        cacheService.clearCache()
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
                            _ = try? await wallpaperService.loadMetadata(for: wallpaper.fileURL)
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
                            _ = try? await wallpaperService.loadImage(from: wallpaper.fileURL)
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
                    _ = try? await wallpaperService.loadMetadata(for: wallpaper.fileURL)
                    _ = try? await wallpaperService.loadImage(from: wallpaper.fileURL)
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
                _ = cacheService.getMetadata(for: wallpaper.fileURL)
                _ = cacheService.getImage(for: wallpaper.fileURL)
            }
        }
    }
    
    func testCacheMissPerformance() {
        // Clear cache
        cacheService.clearCache()
        
        measure {
            for url in testURLs {
                _ = cacheService.getMetadata(for: url)
                _ = cacheService.getImage(for: url)
            }
        }
    }
} 