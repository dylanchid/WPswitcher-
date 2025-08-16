import XCTest
@testable import Wallpaper

class WallpaperRotationServiceTests: XCTestCase {
    var rotationService: WallpaperRotationService!
    var mockWallpaperService: MockWallpaperService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockWallpaperService = MockWallpaperService()
        rotationService = WallpaperRotationService(wallpaperService: mockWallpaperService)
    }
    
    override func tearDown() async throws {
        rotationService.stop()
        rotationService = nil
        mockWallpaperService = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    func testInitialState() {
        XCTAssertFalse(rotationService.isRotationEnabled)
        XCTAssertEqual(rotationService.rotationInterval, 3600)
    }
    
    func testSetRotationInterval() async throws {
        try await rotationService.setRotationInterval(1800)
        XCTAssertEqual(rotationService.rotationInterval, 1800)
        
        // Test invalid interval
        try await rotationService.setRotationInterval(-1)
        XCTAssertEqual(rotationService.rotationInterval, 1800, "Should not accept negative intervals")
        
        try await rotationService.setRotationInterval(0)
        XCTAssertEqual(rotationService.rotationInterval, 1800, "Should not accept zero interval")
    }
    
    func testEnableDisableRotation() async throws {
        try await rotationService.setRotationEnabled(true)
        XCTAssertTrue(rotationService.isRotationEnabled)
        
        try await rotationService.setRotationEnabled(false)
        XCTAssertFalse(rotationService.isRotationEnabled)
    }
    
    // MARK: - Timer Tests
    func testTimerFiring() async throws {
        let expectation = XCTestExpectation(description: "Timer fired")
        expectation.expectedFulfillmentCount = 2
        
        mockWallpaperService.onSetWallpaper = { _ in
            expectation.fulfill()
        }
        
        try await rotationService.setRotationInterval(0.1) // Short interval for testing
        try await rotationService.setRotationEnabled(true)
        await rotationService.start()
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThanOrEqual(mockWallpaperService.setWallpaperCallCount, 2)
    }
    
    func testTimerStopsWhenDisabled() async throws {
        let expectation = XCTestExpectation(description: "Timer fired once")
        expectation.expectedFulfillmentCount = 1
        
        mockWallpaperService.onSetWallpaper = { _ in
            expectation.fulfill()
        }
        
        try await rotationService.setRotationInterval(0.1)
        try await rotationService.setRotationEnabled(true)
        await rotationService.start()
        
        // Wait for first rotation
        await fulfillment(of: [expectation], timeout: 0.5)
        
        // Disable rotation
        try await rotationService.setRotationEnabled(false)
        
        // Wait to ensure no more rotations occur
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        XCTAssertEqual(mockWallpaperService.setWallpaperCallCount, 1)
    }
    
    // MARK: - Error Handling Tests
    func testErrorHandling() async throws {
        let expectation = XCTestExpectation(description: "Error handled")
        
        mockWallpaperService.shouldThrowError = true
        mockWallpaperService.onSetWallpaper = { _ in
            expectation.fulfill()
        }
        
        try await rotationService.setRotationInterval(0.1)
        try await rotationService.setRotationEnabled(true)
        await rotationService.start()
        
        await fulfillment(of: [expectation], timeout: 0.5)
        
        XCTAssertTrue(mockWallpaperService.setWallpaperCalled)
    }
    
    func testEmptyWallpaperList() async throws {
        let expectation = XCTestExpectation(description: "Empty list handled")
        
        mockWallpaperService.wallpapers = []
        mockWallpaperService.onSetWallpaper = { _ in
            expectation.fulfill()
        }
        
        try await rotationService.setRotationInterval(0.1)
        try await rotationService.setRotationEnabled(true)
        await rotationService.start()
        
        await fulfillment(of: [expectation], timeout: 0.5)
        
        XCTAssertFalse(mockWallpaperService.setWallpaperCalled)
    }
    
    // MARK: - Settings Persistence Tests
    func testSettingsPersistence() async throws {
        try await rotationService.setRotationInterval(1800)
        try await rotationService.setRotationEnabled(true)
        
        // Create new instance to test persistence
        let newRotationService = WallpaperRotationService(wallpaperService: mockWallpaperService)
        
        XCTAssertEqual(newRotationService.rotationInterval, 1800)
        XCTAssertTrue(newRotationService.isRotationEnabled)
    }
    
    func testSettingsReset() async throws {
        try await rotationService.setRotationInterval(1800)
        try await rotationService.setRotationEnabled(true)
        
        // Reset settings
        UserDefaults.standard.removeObject(forKey: "wallpaperRotationSettings")
        
        // Create new instance
        let newRotationService = WallpaperRotationService(wallpaperService: mockWallpaperService)
        
        XCTAssertEqual(newRotationService.rotationInterval, 3600)
        XCTAssertFalse(newRotationService.isRotationEnabled)
    }
}

// MARK: - Mock Wallpaper Service
class MockWallpaperService: WallpaperServiceProtocol {
    var setWallpaperCallCount = 0
    var setWallpaperCalled = false
    var currentWallpaperPath: String = ""
    var displayMode: DisplayMode = .fill
    var showOnAllSpaces: Bool = false
    var shouldThrowError = false
    var wallpapers: [WallpaperItem] = [
        WallpaperItem(
            url: URL(fileURLWithPath: "/test/path1.jpg"),
            name: "Test Wallpaper 1",
            metadata: WallpaperMetadata(
                name: "Test Wallpaper 1",
                format: "jpg",
                size: CGSize(width: 1920, height: 1080),
                fileSize: 1024,
                lastModified: Date()
            )
        ),
        WallpaperItem(
            url: URL(fileURLWithPath: "/test/path2.jpg"),
            name: "Test Wallpaper 2",
            metadata: WallpaperMetadata(
                name: "Test Wallpaper 2",
                format: "jpg",
                size: CGSize(width: 1920, height: 1080),
                fileSize: 1024,
                lastModified: Date()
            )
        )
    ]
    
    var onSetWallpaper: ((URL) -> Void)?
    
    func setWallpaper(from url: URL, for screen: NSScreen?, mode: DisplayMode?) async throws {
        setWallpaperCalled = true
        setWallpaperCallCount += 1
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        
        onSetWallpaper?(url)
    }
    
    func startRotation(interval: TimeInterval) async {
        // Not implemented for tests
    }
    
    func stopRotation() {
        // Not implemented for tests
    }
    
    func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem] {
        return wallpapers
    }
    
    func removeWallpaper(_ item: WallpaperItem) async throws {
        // Not implemented for tests
    }
    
    func rotateToNext() async throws {
        // Not implemented for tests
    }
} 