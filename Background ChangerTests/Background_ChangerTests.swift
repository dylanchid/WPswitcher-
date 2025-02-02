//
//  Background_ChangerTests.swift
//  Background ChangerTests
//
//  Created by Dylan Chidambaram on 1/31/25.
//

import XCTest
import AppKit
@testable import Background_Changer

class Background_ChangerTests: XCTestCase {
    
    var wallpaperManager: WallpaperManager!
    var testBundle: Bundle!
    var testImageURLs: [URL]!
    
    override func setUp() {
        super.setUp()
        wallpaperManager = WallpaperManager.shared
        testBundle = Bundle(for: type(of: self))
        
        // Create temporary test images
        testImageURLs = createTestImages()
    }
    
    override func tearDown() {
        wallpaperManager.clearWallpapers()
        // Clean up temporary test images
        cleanupTestImages()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddWallpaper() {
        guard let testURL = testImageURLs.first else {
            XCTFail("No test image available")
            return
        }
        
        wallpaperManager.addWallpapers([testURL])
        XCTAssertEqual(wallpaperManager.allWallpapers.count, 1)
        XCTAssertEqual(wallpaperManager.allWallpapers.first, testURL)
    }
    
    func testRemoveWallpaper() {
        guard let testURL = testImageURLs.first else {
            XCTFail("No test image available")
            return
        }
        
        wallpaperManager.addWallpapers([testURL])
        wallpaperManager.removeWallpapers([testURL])
        XCTAssertEqual(wallpaperManager.allWallpapers.count, 0)
    }
    
    func testClearWallpapers() {
        wallpaperManager.addWallpapers(testImageURLs)
        wallpaperManager.clearWallpapers()
        XCTAssertEqual(wallpaperManager.allWallpapers.count, 0)
    }
    
    // MARK: - Display Mode Tests
    
    func testDisplayModeUpdate() {
        let newMode = DisplayMode.fit
        wallpaperManager.updateDisplayMode(newMode)
        
        // Test if display mode is persisted
        let savedMode = UserDefaults.standard.string(forKey: "displayMode")
        XCTAssertEqual(savedMode, newMode.rawValue)
    }
    
    func testShowOnAllSpacesUpdate() {
        let newValue = true
        wallpaperManager.updateShowOnAllSpaces(newValue)
        
        // Test if setting is persisted
        let savedValue = UserDefaults.standard.bool(forKey: "showOnAllSpaces")
        XCTAssertEqual(savedValue, newValue)
    }
    
    // MARK: - Wallpaper Rotation Tests
    
    func testWallpaperRotation() {
        wallpaperManager.addWallpapers(testImageURLs)
        let initialWallpaper = wallpaperManager.currentWallpaper
        
        // Start rotation with a short interval
        wallpaperManager.startRotation(interval: 0.1)
        
        // Wait for rotation to occur
        let expectation = XCTestExpectation(description: "Wallpaper rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let newWallpaper = self.wallpaperManager.currentWallpaper
            XCTAssertNotEqual(initialWallpaper, newWallpaper)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRotationStop() {
        wallpaperManager.addWallpapers(testImageURLs)
        wallpaperManager.startRotation(interval: 0.1)
        wallpaperManager.stopRotation()
        
        let initialWallpaper = wallpaperManager.currentWallpaper
        
        // Wait to ensure no rotation occurs
        let expectation = XCTestExpectation(description: "No wallpaper rotation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let newWallpaper = self.wallpaperManager.currentWallpaper
            XCTAssertEqual(initialWallpaper, newWallpaper)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidWallpaperURL() {
        let invalidURL = URL(string: "file:///nonexistent/path/image.jpg")!
        XCTAssertThrowsError(try wallpaperManager.setWallpaper(from: invalidURL)) { error in
            XCTAssertTrue(error is WallpaperError)
        }
    }
    
    // MARK: - State Persistence Tests
    
    func testStatePersistence() {
        wallpaperManager.addWallpapers(testImageURLs)
        let mode = DisplayMode.stretch
        wallpaperManager.updateDisplayMode(mode)
        wallpaperManager.updateShowOnAllSpaces(true)
        
        // Create new instance to test persistence
        let newManager = WallpaperManager.shared
        XCTAssertEqual(newManager.allWallpapers.count, testImageURLs.count)
        
        if let currentWallpaper = UserDefaults.standard.string(forKey: "displayMode") {
            XCTAssertEqual(currentWallpaper, mode.rawValue)
        }
        
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "showOnAllSpaces"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestImages() -> [URL] {
        let tempDirectory = FileManager.default.temporaryDirectory
        var urls: [URL] = []
        
        for i in 1...3 {
            let imageURL = tempDirectory.appendingPathComponent("test_image_\(i).jpg")
            
            // Create a simple test image
            let image = NSImage(size: NSSize(width: 100, height: 100))
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [:]) {
                try? jpegData.write(to: imageURL)
                urls.append(imageURL)
            }
        }
        
        return urls
    }
    
    private func cleanupTestImages() {
        for url in testImageURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - MenuBarView Tests

class MenuBarViewTests: XCTestCase {
    var menuBarView: MenuBarView!
    
    override func setUp() {
        super.setUp()
        menuBarView = MenuBarView()
    }
    
    func testInitialState() {
        XCTAssertEqual(menuBarView.selectedImagePath, "")
        XCTAssertEqual(menuBarView.rotationInterval, 60)
        XCTAssertFalse(menuBarView.isRotating)
        XCTAssertEqual(menuBarView.displayMode, .fillScreen)
    }
    
    func testDisplayModeSelection() {
        let newMode = DisplayMode.stretch
        menuBarView.displayMode = newMode
        XCTAssertEqual(menuBarView.displayMode, newMode)
    }
    
    func testWallpaperSelection() {
        let testPath = "file:///test/path/image.jpg"
        menuBarView.selectedImagePath = testPath
        XCTAssertEqual(menuBarView.selectedImagePath, testPath)
    }
}
