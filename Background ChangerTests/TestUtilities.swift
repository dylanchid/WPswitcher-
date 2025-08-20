import XCTest
import AppKit
import WallpaperTypes
@testable import Background_Changer

// MARK: - Comprehensive Test Utilities
open class WallpaperTestCase: XCTestCase {
    var testImages: TestImageGenerator!
    var mockFileSystem: MockFileSystem!
    var testCoordinator: TestCoordinator!
    var stateStore: StateStore!
    var testCache: AdaptiveCache!
    
    override open func setUp() async throws {
        try await super.setUp()
        
        testImages = TestImageGenerator()
        mockFileSystem = MockFileSystem()
        testCoordinator = TestCoordinator()
        stateStore = StateStoreFactory.createForTesting()
        testCache = CacheFactory.createMemoryConstrainedCache()
        
        // Generate test data
        try await setupTestEnvironment()
    }
    
    override open func tearDown() async throws {
        try await cleanupTestEnvironment()
        try await super.tearDown()
    }
    
    // MARK: - Test Environment Setup
    private func setupTestEnvironment() async throws {
        // Create test directory structure
        try await mockFileSystem.createTestDirectories()
        
        // Generate test images
        try await generateTestImages()
        
        // Setup test playlists
        try await setupTestPlaylists()
    }
    
    private func cleanupTestEnvironment() async throws {
        try await mockFileSystem.cleanup()
        testCache.clearAllCaches()
        stateStore.clearHistory()
    }
    
    private func generateTestImages() async throws {
        // Generate various test images
        let testImageConfigs = [
            TestImageConfig(size: CGSize(width: 1920, height: 1080), format: .jpeg, name: "test_wallpaper_1"),
            TestImageConfig(size: CGSize(width: 2560, height: 1440), format: .png, name: "test_wallpaper_2"),
            TestImageConfig(size: CGSize(width: 3840, height: 2160), format: .heic, name: "test_wallpaper_3"),
            TestImageConfig(size: CGSize(width: 1024, height: 768), format: .jpeg, name: "test_wallpaper_small"),
            TestImageConfig(size: CGSize(width: 800, height: 600), format: .png, name: "test_wallpaper_tiny")
        ]
        
        for config in testImageConfigs {
            let image = try testImages.generate(config: config)
            try await mockFileSystem.save(image, name: config.name, format: config.format)
        }
    }
    
    private func setupTestPlaylists() async throws {
        let wallpapers = try await createTestWallpapers(count: 5)
        
        // Create test playlists
        let playlistId1 = try await stateStore.createPlaylist(name: "Test Playlist 1")
        let playlistId2 = try await stateStore.createPlaylist(name: "Test Playlist 2")
        
        // Add wallpapers to playlists
        for wallpaper in wallpapers.prefix(3) {
            try await stateStore.dispatch(.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlistId1))
        }
        
        for wallpaper in wallpapers.suffix(2) {
            try await stateStore.dispatch(.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlistId2))
        }
    }
    
    // MARK: - Test Helper Methods
    
    /// Helper to create consistent test images
    public func createTestWallpaper(
        size: CGSize = CGSize(width: 1920, height: 1080),
        format: ImageFormat = .jpeg,
        colorSpace: ColorSpace = .sRGB,
        name: String? = nil
    ) async throws -> WallpaperItem {
        let config = TestImageConfig(
            size: size,
            format: format,
            colorSpace: colorSpace,
            name: name ?? "test_wallpaper_\(UUID().uuidString)"
        )
        
        let image = try testImages.generate(config: config)
        let url = try await mockFileSystem.save(image, name: config.name, format: format)
        
        return WallpaperItem(url: url, name: config.name)
    }
    
    public func createTestWallpapers(count: Int) async throws -> [WallpaperItem] {
        var wallpapers: [WallpaperItem] = []
        
        for i in 0..<count {
            let wallpaper = try await createTestWallpaper(
                name: "test_wallpaper_\(i)",
                size: CGSize(width: 1920 + i * 100, height: 1080 + i * 50)
            )
            wallpapers.append(wallpaper)
        }
        
        return wallpapers
    }
    
    public func createTestPlaylist(
        name: String,
        wallpaperCount: Int = 3
    ) async throws -> (Playlist, [WallpaperItem]) {
        let wallpapers = try await createTestWallpapers(count: wallpaperCount)
        
        let playlistId = try await stateStore.createPlaylist(name: name)
        
        for wallpaper in wallpapers {
            try await stateStore.addWallpaper(wallpaper)
            try await stateStore.dispatch(.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlistId))
        }
        
        guard let playlist = stateStore.state.playlists.first(where: { $0.id == playlistId }) else {
            throw TestError.playlistNotFound
        }
        
        return (playlist, wallpapers)
    }
    
    // MARK: - Performance Testing Helper
    public func measureWallpaperOperation<T>(
        _ name: String,
        operation: () async throws -> T
    ) async throws -> T {
        let metrics: [XCTMetric] = [
            XCTMemoryMetric(),
            XCTCPUMetric(),
            XCTStorageMetric()
        ]
        
        var result: T!
        var operationError: Error?
        
        measure(metrics: metrics) {
            let expectation = expectation(description: name)
            
            Task {
                do {
                    result = try await operation()
                } catch {
                    operationError = error
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30)
        }
        
        if let error = operationError {
            throw error
        }
        
        return result
    }
    
    public func measureMemoryUsage<T>(
        during operation: () async throws -> T
    ) async throws -> (result: T, peakMemory: Int64) {
        let startMemory = getMemoryUsage()
        let result = try await operation()
        let endMemory = getMemoryUsage()
        
        return (result, max(startMemory, endMemory))
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Async Test Helpers
    public func waitFor<T>(
        _ condition: @escaping () async throws -> T?,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if let result = try await condition() {
                return result
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        XCTFail("Condition not met within timeout", file: file, line: line)
        throw TestError.timeout
    }
    
    public func expectError<T>(
        _ expectedError: WallpaperError,
        from operation: () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected error \(expectedError) but operation succeeded", file: file, line: line)
        } catch let error as WallpaperError {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected \(expectedError) but got \(error)", file: file, line: line)
        }
    }
    
    // MARK: - State Validation Helpers
    public func assertStateConsistency(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let state = stateStore.state
        
        // Validate active playlist exists
        if let activePlaylistId = state.activePlaylistId {
            XCTAssertTrue(
                state.playlists.contains { $0.id == activePlaylistId },
                "Active playlist not found in playlists collection",
                file: file,
                line: line
            )
        }
        
        // Validate current wallpaper exists in collection
        if let currentWallpaper = state.currentWallpaper {
            XCTAssertTrue(
                state.wallpapers.contains { $0.id == currentWallpaper.id },
                "Current wallpaper not found in wallpapers collection",
                file: file,
                line: line
            )
        }
        
        // Validate playlist wallpapers exist in main collection
        for playlist in state.playlists {
            for wallpaper in playlist.wallpapers {
                XCTAssertTrue(
                    state.wallpapers.contains { $0.id == wallpaper.id },
                    "Playlist wallpaper \(wallpaper.id) not found in main collection",
                    file: file,
                    line: line
                )
            }
        }
        
        // Validate no duplicate IDs
        let wallpaperIds = state.wallpapers.map { $0.id }
        XCTAssertEqual(
            wallpaperIds.count,
            Set(wallpaperIds).count,
            "Duplicate wallpaper IDs found",
            file: file,
            line: line
        )
        
        let playlistIds = state.playlists.map { $0.id }
        XCTAssertEqual(
            playlistIds.count,
            Set(playlistIds).count,
            "Duplicate playlist IDs found",
            file: file,
            line: line
        )
    }
}

// MARK: - Test Image Generator
public final class TestImageGenerator {
    public func generate(config: TestImageConfig) throws -> NSImage {
        let image = NSImage(size: config.size)
        
        image.lockFocus()
        
        // Draw background with specified colors
        config.backgroundColor.setFill()
        NSRect(origin: .zero, size: config.size).fill()
        
        // Add some visual elements for testing
        if config.includeGradient {
            drawGradient(in: NSRect(origin: .zero, size: config.size), colors: config.gradientColors)
        }
        
        if config.includeText {
            drawText(config.name, in: NSRect(origin: .zero, size: config.size))
        }
        
        if config.includePattern {
            drawTestPattern(in: NSRect(origin: .zero, size: config.size))
        }
        
        image.unlockFocus()
        
        return image
    }
    
    private func drawGradient(in rect: NSRect, colors: [NSColor]) {
        guard colors.count >= 2 else { return }
        
        let gradient = NSGradient(colors: colors)
        gradient?.draw(in: rect, angle: 45)
    }
    
    private func drawText(_ text: String, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(rect.width, rect.height) / 20),
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -2
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(
            x: rect.width * 0.1,
            y: rect.height * 0.1,
            width: rect.width * 0.8,
            height: rect.height * 0.2
        )
        
        attributedString.draw(in: textRect)
    }
    
    private func drawTestPattern(in rect: NSRect) {
        NSColor.white.withAlphaComponent(0.3).setStroke()
        
        let path = NSBezierPath()
        path.lineWidth = 2
        
        // Draw grid pattern
        let gridSize: CGFloat = 50
        
        for x in stride(from: 0, through: rect.width, by: gridSize) {
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, through: rect.height, by: gridSize) {
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: rect.width, y: y))
        }
        
        path.stroke()
    }
}

// MARK: - Mock File System
public final class MockFileSystem {
    private let tempDirectory: URL
    private var createdFiles: Set<URL> = []
    
    public init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperManagerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    public func createTestDirectories() async throws {
        let directories = [
            "wallpapers",
            "playlists", 
            "cache",
            "backups"
        ]
        
        for directory in directories {
            let url = tempDirectory.appendingPathComponent(directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    public func save(_ image: NSImage, name: String, format: ImageFormat) async throws -> URL {
        let filename = "\(name).\(format.fileExtension)"
        let url = tempDirectory.appendingPathComponent("wallpapers").appendingPathComponent(filename)
        
        guard let data = image.representation(for: format) else {
            throw TestError.imageConversionFailed
        }
        
        try data.write(to: url)
        createdFiles.insert(url)
        
        return url
    }
    
    public func cleanup() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        createdFiles.removeAll()
    }
    
    public var testDirectoryURL: URL {
        return tempDirectory
    }
}

// MARK: - Test Coordinator
public final class TestCoordinator {
    private var operations: [String: TestOperation] = [:]
    
    public func startOperation(_ name: String) {
        operations[name] = TestOperation(name: name, startTime: Date())
    }
    
    public func endOperation(_ name: String) {
        operations[name]?.endTime = Date()
    }
    
    public func getOperationDuration(_ name: String) -> TimeInterval? {
        guard let operation = operations[name],
              let endTime = operation.endTime else {
            return nil
        }
        return endTime.timeIntervalSince(operation.startTime)
    }
    
    public func getAllOperations() -> [TestOperation] {
        return Array(operations.values)
    }
    
    public func reset() {
        operations.removeAll()
    }
}

// MARK: - Supporting Types
public struct TestImageConfig {
    let size: CGSize
    let format: ImageFormat
    let colorSpace: ColorSpace
    let name: String
    let backgroundColor: NSColor
    let includeGradient: Bool
    let gradientColors: [NSColor]
    let includeText: Bool
    let includePattern: Bool
    
    public init(
        size: CGSize,
        format: ImageFormat = .jpeg,
        colorSpace: ColorSpace = .sRGB,
        name: String,
        backgroundColor: NSColor = .blue,
        includeGradient: Bool = true,
        gradientColors: [NSColor] = [.blue, .purple],
        includeText: Bool = true,
        includePattern: Bool = false
    ) {
        self.size = size
        self.format = format
        self.colorSpace = colorSpace
        self.name = name
        self.backgroundColor = backgroundColor
        self.includeGradient = includeGradient
        self.gradientColors = gradientColors
        self.includeText = includeText
        self.includePattern = includePattern
    }
}

public enum ImageFormat {
    case jpeg
    case png
    case heic
    case tiff
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
}

public enum ColorSpace {
    case sRGB
    case displayP3
    case adobeRGB
}

public struct TestOperation {
    let name: String
    let startTime: Date
    var endTime: Date?
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

public enum TestError: Error {
    case timeout
    case playlistNotFound
    case imageConversionFailed
    case setupFailed
    case cleanupFailed
}

// MARK: - NSImage Extensions for Testing
extension NSImage {
    func representation(for format: ImageFormat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        switch format {
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .tiff:
            return bitmapRep.representation(using: .tiff, properties: [:])
        case .heic:
            // HEIC support would require additional implementation
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }
    }
}
