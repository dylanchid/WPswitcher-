import Testing
@testable import Wallpaper
import XCTest

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

class WallpaperServiceTests: XCTestCase {
    var wallpaperService: WallpaperService!
    var mockCacheService: MockCacheService!
    var mockDisplayService: MockDisplayService!
    var mockRotationService: MockRotationService!
    
    override func setUp() {
        super.setUp()
        mockCacheService = MockCacheService()
        mockDisplayService = MockDisplayService()
        mockRotationService = MockRotationService()
        wallpaperService = WallpaperService(
            cacheService: mockCacheService,
            displayService: mockDisplayService,
            rotationService: mockRotationService
        )
    }
    
    override func tearDown() {
        wallpaperService = nil
        mockCacheService = nil
        mockDisplayService = nil
        mockRotationService = nil
        super.tearDown()
    }
    
    // MARK: - WallpaperService Tests
    func testSetWallpaper() async throws {
        let url = URL(fileURLWithPath: "/test/path.jpg")
        try await wallpaperService.setWallpaper(from: url)
        XCTAssertTrue(mockDisplayService.setWallpaperCalled)
    }
    
    func testAddWallpapers() async throws {
        let urls = [URL(fileURLWithPath: "/test/path1.jpg"), URL(fileURLWithPath: "/test/path2.jpg")]
        let wallpapers = try await wallpaperService.addWallpapers(from: urls)
        XCTAssertEqual(wallpapers.count, 2)
        XCTAssertTrue(mockCacheService.addWallpapersCalled)
    }
    
    func testRemoveWallpaper() async throws {
        let wallpaper = WallpaperItem(
            url: URL(fileURLWithPath: "/test/path.jpg"),
            name: "Test Wallpaper",
            metadata: WallpaperMetadata(
                name: "Test Wallpaper",
                format: "jpg",
                size: CGSize(width: 1920, height: 1080),
                fileSize: 1024,
                lastModified: Date()
            )
        )
        try await wallpaperService.removeWallpaper(wallpaper)
        XCTAssertTrue(mockCacheService.removeWallpaperCalled)
    }
    
    func testStartStopRotation() async {
        await wallpaperService.startRotation(interval: 60)
        XCTAssertTrue(mockRotationService.startRotationCalled)
        
        wallpaperService.stopRotation()
        XCTAssertTrue(mockRotationService.stopRotationCalled)
    }
}

class WallpaperDisplayServiceTests: XCTestCase {
    var displayService: WallpaperDisplayService!
    
    override func setUp() {
        super.setUp()
        displayService = WallpaperDisplayService()
    }
    
    override func tearDown() {
        displayService = nil
        super.tearDown()
    }
    
    // MARK: - WallpaperDisplayService Tests
    func testSetWallpaper() async throws {
        let url = URL(fileURLWithPath: "/test/path.jpg")
        try await displayService.setWallpaper(from: url)
        XCTAssertEqual(displayService.currentWallpaperPath, url.path)
    }
    
    func testUpdateDisplayMode() async throws {
        let url = URL(fileURLWithPath: "/test/path.jpg")
        try await displayService.setWallpaper(from: url)
        
        displayService.displayMode = .fit
        try await displayService.updateDisplayMode(.fit)
        XCTAssertEqual(displayService.displayMode, .fit)
    }
    
    func testUpdateShowOnAllSpaces() async throws {
        let url = URL(fileURLWithPath: "/test/path.jpg")
        try await displayService.setWallpaper(from: url)
        
        displayService.showOnAllSpaces = false
        try await displayService.updateShowOnAllSpaces(false)
        XCTAssertFalse(displayService.showOnAllSpaces)
    }
}

// MARK: - Mock Services
class MockCacheService: WallpaperCacheServiceProtocol {
    var addWallpapersCalled = false
    var removeWallpaperCalled = false
    var maxCacheSize: UInt64 = 1024 * 1024 * 100 // 100MB
    var currentCacheSize: UInt64 = 0
    
    func cacheWallpaper(from url: URL) async throws -> URL {
        return url
    }
    
    func removeFromCache(_ url: URL) async throws {
        removeWallpaperCalled = true
    }
    
    func clearCache() async throws {
        currentCacheSize = 0
    }
    
    func isCached(_ url: URL) -> Bool {
        return true
    }
    
    func getCachedURL(for url: URL) -> URL? {
        return url
    }
    
    func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem] {
        addWallpapersCalled = true
        return urls.map { url in
            WallpaperItem(
                url: url,
                name: url.lastPathComponent,
                metadata: WallpaperMetadata(
                    name: url.lastPathComponent,
                    format: url.pathExtension,
                    size: CGSize(width: 1920, height: 1080),
                    fileSize: 1024,
                    lastModified: Date()
                )
            )
        }
    }
    
    func removeWallpaper(_ item: WallpaperItem) async throws {
        removeWallpaperCalled = true
    }
}

class MockDisplayService: WallpaperDisplayServiceProtocol {
    var setWallpaperCalled = false
    var currentWallpaperPath: String = ""
    var displayMode: DisplayMode = .fill
    var showOnAllSpaces: Bool = true
    
    func setWallpaper(from url: URL, for screen: NSScreen?, mode: DisplayMode?) async throws {
        setWallpaperCalled = true
        currentWallpaperPath = url.path
    }
    
    func getCurrentWallpaper(for screen: NSScreen?) -> URL? {
        return URL(fileURLWithPath: currentWallpaperPath)
    }
    
    func updateDisplayMode(_ mode: DisplayMode) async throws {
        displayMode = mode
    }
    
    func updateShowOnAllSpaces(_ show: Bool) async throws {
        showOnAllSpaces = show
    }
}

class MockRotationService: WallpaperRotationServiceProtocol {
    var startRotationCalled = false
    var stopRotationCalled = false
    
    func start() {
        startRotationCalled = true
    }
    
    func stop() {
        stopRotationCalled = true
    }
    
    func setRotationInterval(_ interval: TimeInterval) {
        // Not implemented for tests
    }
    
    func getRotationInterval() -> TimeInterval {
        return 3600
    }
    
    func setRotationEnabled(_ enabled: Bool) {
        // Not implemented for tests
    }
    
    func isRotationEnabled() -> Bool {
        return true
    }
}
