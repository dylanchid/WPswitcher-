//
//  Background_ChangerUITests.swift
//  Background ChangerUITests
//
//  Created by Dylan Chidambaram on 1/31/25.
//

import XCTest

final class Background_ChangerUITests: XCTestCase {
    let app = XCUIApplication()
    var testImageURL: URL!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        
        // Create a test image in the temporary directory
        testImageURL = try createTestImage()
    }

    override func tearDownWithError() throws {
        // Clean up test image
        try? FileManager.default.removeItem(at: testImageURL)
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - Basic UI Tests
    
    @MainActor
    func testMenuBarIconExists() throws {
        let menuBarItem = app.menuBars.firstMatch
        XCTAssertTrue(menuBarItem.exists, "Menu bar item should exist")
    }
    
    @MainActor
    func testInitialUIState() throws {
        let menuBar = app.menuBars.firstMatch
        menuBar.click()
        
        // Check for main UI elements
        XCTAssertTrue(app.buttons["Select Image"].exists)
        XCTAssertTrue(app.buttons["Add Photo"].exists)
        XCTAssertTrue(app.staticTexts["Wallpaper Settings"].exists)
    }
    
    // MARK: - Wallpaper Selection Tests
    
    @MainActor
    func testAddWallpaperFlow() throws {
        let menuBar = app.menuBars.firstMatch
        menuBar.click()
        
        let addPhotoButton = app.buttons["Add Photo"]
        XCTAssertTrue(addPhotoButton.exists)
        addPhotoButton.click()
        
        // Note: We can't fully test the file picker dialog as it's a system component
        // but we can verify it appears
        let filePickerSheet = app.sheets.firstMatch
        XCTAssertTrue(filePickerSheet.exists)
    }
    
    @MainActor
    func testDisplayModeSelection() throws {
        let menuBar = app.menuBars.firstMatch
        menuBar.click()
        
        let displayModePicker = app.popUpButtons["Display Mode"]
        XCTAssertTrue(displayModePicker.exists)
        displayModePicker.click()
        
        // Test each display mode option exists
        let modes = ["Fill Screen", "Fit to Screen", "Stretch", "Center"]
        for mode in modes {
            XCTAssertTrue(app.menuItems[mode].exists)
        }
    }
    
    // MARK: - Rotation Settings Tests
    
    @MainActor
    func testRotationControls() throws {
        let menuBar = app.menuBars.firstMatch
        menuBar.click()
        
        let rotationToggle = app.checkBoxes["Auto-rotate wallpapers"]
        XCTAssertTrue(rotationToggle.exists)
        
        // Test enabling rotation
        rotationToggle.click()
        
        // Verify slider appears when rotation is enabled
        let intervalSlider = app.sliders.firstMatch
        XCTAssertTrue(intervalSlider.exists)
    }
    
    @MainActor
    func testMultiScreenToggle() throws {
        let menuBar = app.menuBars.firstMatch
        menuBar.click()
        
        let multiScreenToggle = app.checkBoxes["Show on all Spaces"]
        XCTAssertTrue(multiScreenToggle.exists)
        multiScreenToggle.click()
        
        // Verify toggle state changes
        XCTAssertTrue(multiScreenToggle.isSelected)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    @MainActor
    func testWallpaperSwitchingPerformance() throws {
        let menuBar = app.menuBars.firstMatch
        menuBar.click()
        
        measure {
            // Test wallpaper switching performance
            let setWallpaperButton = app.buttons["Set Wallpaper"]
            if setWallpaperButton.exists {
                setWallpaperButton.click()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let imageURL = tempDirectory.appendingPathComponent("test_image.jpg")
        
        // Create a simple test image using CoreGraphics
        let size = CGSize(width: 100, height: 100)
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(origin: .zero, size: size))
        
        if let image = context?.makeImage(),
           let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, kUTTypeJPEG, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
        
        return imageURL
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    var isSelected: Bool {
        (value as? String) == "1"
    }
}
