import XCTest
import AppKit
@testable import Background_Changer

// MARK: - State Management Tests
final class StateManagementTests: WallpaperTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
    }
    
    // MARK: - Basic State Operations
    func testAddWallpaper() async throws {
        let wallpaper = try await createTestWallpaper(name: "test_add_wallpaper")
        
        try await stateStore.addWallpaper(wallpaper)
        
        XCTAssertTrue(stateStore.state.wallpapers.contains { $0.id == wallpaper.id })
        assertStateConsistency()
    }
    
    func testRemoveWallpaper() async throws {
        let wallpaper = try await createTestWallpaper(name: "test_remove_wallpaper")
        try await stateStore.addWallpaper(wallpaper)
        
        try await stateStore.removeWallpaper(id: wallpaper.id)
        
        XCTAssertFalse(stateStore.state.wallpapers.contains { $0.id == wallpaper.id })
        assertStateConsistency()
    }
    
    func testCreatePlaylist() async throws {
        let playlistName = "Test Playlist"
        
        let playlistId = try await stateStore.createPlaylist(name: playlistName)
        
        XCTAssertTrue(stateStore.state.playlists.contains { $0.id == playlistId && $0.name == playlistName })
        assertStateConsistency()
    }
    
    func testAddWallpaperToPlaylist() async throws {
        let (playlist, wallpapers) = try await createTestPlaylist(name: "Test Playlist", wallpaperCount: 3)
        
        XCTAssertEqual(playlist.wallpapers.count, 3)
        
        for wallpaper in wallpapers {
            XCTAssertTrue(playlist.wallpapers.contains { $0.id == wallpaper.id })
        }
        
        assertStateConsistency()
    }
    
    // MARK: - Undo/Redo Tests
    func testUndoRedo() async throws {
        // Initial state
        XCTAssertTrue(stateStore.state.wallpapers.isEmpty)
        XCTAssertFalse(stateStore.canUndo)
        XCTAssertFalse(stateStore.canRedo)
        
        // Add wallpaper
        let wallpaper = try await createTestWallpaper(name: "test_undo_redo")
        try await stateStore.addWallpaper(wallpaper)
        
        XCTAssertTrue(stateStore.canUndo)
        XCTAssertFalse(stateStore.canRedo)
        XCTAssertEqual(stateStore.state.wallpapers.count, 1)
        
        // Undo
        try stateStore.undo()
        
        XCTAssertFalse(stateStore.canUndo)
        XCTAssertTrue(stateStore.canRedo)
        XCTAssertTrue(stateStore.state.wallpapers.isEmpty)
        
        // Redo
        try stateStore.redo()
        
        XCTAssertTrue(stateStore.canUndo)
        XCTAssertFalse(stateStore.canRedo)
        XCTAssertEqual(stateStore.state.wallpapers.count, 1)
        
        assertStateConsistency()
    }
    
    // MARK: - Error Handling Tests
    func testInvalidWallpaperError() async {
        await expectError(
            WallpaperError.stateManagement(.playlistNotFound),
            from: {
                try await stateStore.dispatch(AppAction.setActivePlaylist(UUID()))
            }
        )
    }
    
    func testDuplicateWallpaperInPlaylist() async throws {
        let (playlist, wallpapers) = try await createTestPlaylist(name: "Test Playlist", wallpaperCount: 1)
        let wallpaper = wallpapers[0]
        
        await expectError(
            WallpaperError.playlistOperation(.duplicateWallpaper(wallpaper.id)),
            from: {
                try await stateStore.dispatch(AppAction.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlist.id))
            }
        )
    }
    
    // MARK: - Performance Tests
    func testLargeStatePerformance() async throws {
        try await measureWallpaperOperation("Add 100 wallpapers") {
            let wallpapers = try await createTestWallpapers(count: 100)
            
            for wallpaper in wallpapers {
                try await stateStore.addWallpaper(wallpaper)
            }
            
            return wallpapers.count
        }
        
        XCTAssertEqual(stateStore.state.wallpapers.count, 100)
        assertStateConsistency()
    }
    
    func testPlaylistOperationsPerformance() async throws {
        // Create wallpapers first
        let wallpapers = try await createTestWallpapers(count: 50)
        for wallpaper in wallpapers {
            try await stateStore.addWallpaper(wallpaper)
        }
        
        let playlistCount = try await measureWallpaperOperation("Create 10 playlists with 5 wallpapers each") {
            var createdPlaylists = 0
            
            for i in 0..<10 {
                let playlistId = try await stateStore.createPlaylist(name: "Performance Test Playlist \(i)")
                
                // Add 5 wallpapers to each playlist
                for j in 0..<5 {
                    let wallpaper = wallpapers[i * 5 + j]
                    try await stateStore.dispatch(AppAction.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlistId))
                }
                
                createdPlaylists += 1
            }
            
            return createdPlaylists
        }
        
        XCTAssertEqual(playlistCount, 10)
        XCTAssertEqual(stateStore.state.playlists.count, 10)
        assertStateConsistency()
    }
    
    // MARK: - Memory Usage Tests
    func testMemoryUsageWithLargeState() async throws {
        let (result, peakMemory) = try await measureMemoryUsage {
            let wallpapers = try await createTestWallpapers(count: 200)
            
            for wallpaper in wallpapers {
                try await stateStore.addWallpaper(wallpaper)
            }
            
            // Create several playlists
            for i in 0..<20 {
                let playlistId = try await stateStore.createPlaylist(name: "Memory Test Playlist \(i)")
                
                // Add 10 wallpapers to each playlist
                for j in 0..<10 {
                    let wallpaper = wallpapers[j]
                    try await stateStore.dispatch(AppAction.addWallpaperToPlaylist(wallpaperId: wallpaper.id, playlistId: playlistId))
                }
            }
            
            return stateStore.state.wallpapers.count
        }
        
        XCTAssertEqual(result, 200)
        print("Peak memory usage: \(ByteCountFormatter.string(fromByteCount: peakMemory, countStyle: .memory))")
        
        // Memory should be reasonable (less than 100MB for test data)
        XCTAssertLessThan(peakMemory, 100 * 1024 * 1024, "Memory usage too high")
        
        assertStateConsistency()
    }
    
    // MARK: - Concurrent Access Tests
    func testConcurrentStateModifications() async throws {
        let expectation = expectation(description: "Concurrent modifications")
        expectation.expectedFulfillmentCount = 10
        
        // Launch multiple concurrent operations
        for i in 0..<10 {
            Task {
                do {
                    let wallpaper = try await createTestWallpaper(name: "concurrent_wallpaper_\(i)")
                    try await stateStore.addWallpaper(wallpaper)
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent operation failed: \(error)")
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10)
        
        XCTAssertEqual(stateStore.state.wallpapers.count, 10)
        assertStateConsistency()
    }
    
    // MARK: - State Validation Tests
    func testStateConsistencyAfterComplexOperations() async throws {
        // Create initial state
        let wallpapers = try await createTestWallpapers(count: 20)
        for wallpaper in wallpapers {
            try await stateStore.addWallpaper(wallpaper)
        }
        
        // Create playlists
        let playlist1Id = try await stateStore.createPlaylist(name: "Playlist 1")
        let playlist2Id = try await stateStore.createPlaylist(name: "Playlist 2")
        
        // Add wallpapers to playlists
        for i in 0..<10 {
            try await stateStore.dispatch(AppAction.addWallpaperToPlaylist(wallpaperId: wallpapers[i].id, playlistId: playlist1Id))
        }
        
        for i in 10..<20 {
            try await stateStore.dispatch(AppAction.addWallpaperToPlaylist(wallpaperId: wallpapers[i].id, playlistId: playlist2Id))
        }
        
        // Set active playlist
        try await stateStore.setActivePlaylist(id: playlist1Id)
        
        // Set current wallpaper
        try await stateStore.setCurrentWallpaper(wallpapers[0])
        
        // Perform various operations
        try await stateStore.dispatch(AppAction.removeWallpaperFromPlaylist(wallpaperId: wallpapers[0].id, playlistId: playlist1Id))
        try await stateStore.removeWallpaper(id: wallpapers[19].id)
        
        // Validate final state
        assertStateConsistency()
        
        XCTAssertEqual(stateStore.state.wallpapers.count, 19) // One removed
        XCTAssertEqual(stateStore.state.activePlaylistId, playlist1Id)
        XCTAssertEqual(stateStore.state.currentWallpaper?.id, wallpapers[0].id)
        
        // Playlist 1 should have 8 wallpapers (started with 10, removed 1, but removed wallpaper should still be in main collection)
        let playlist1 = stateStore.state.playlists.first { $0.id == playlist1Id }!
        XCTAssertEqual(playlist1.wallpapers.count, 9)
        
        // Playlist 2 should have 9 wallpapers (started with 10, but 1 was removed from main collection)
        let playlist2 = stateStore.state.playlists.first { $0.id == playlist2Id }!
        XCTAssertEqual(playlist2.wallpapers.count, 9)
    }
}

// MARK: - Image Processing Tests
final class ImageProcessingTests: WallpaperTestCase {
    
    func testImageProcessing() async throws {
        let wallpaper = try await createTestWallpaper(
            size: CGSize(width: 1920, height: 1080),
            name: "test_image_processing"
        )
        
        let processedWallpaper = try await ImageProcessor.shared.processWallpaper(at: wallpaper.url)
        
        XCTAssertEqual(processedWallpaper.originalURL, wallpaper.url)
        XCTAssertNotNil(processedWallpaper.thumbnail)
        XCTAssertNotNil(processedWallpaper.preview)
        XCTAssertEqual(processedWallpaper.metadata.dimensions, CGSize(width: 1920, height: 1080))
    }
    
    func testImageCaching() async throws {
        let wallpaper = try await createTestWallpaper(name: "test_caching")
        
        // First call should process and cache
        let start1 = Date()
        _ = try await ImageProcessor.shared.generateThumbnail(wallpaper.url)
        let duration1 = Date().timeIntervalSince(start1)
        
        // Second call should be faster (cached)
        let start2 = Date()
        _ = try await ImageProcessor.shared.generateThumbnail(wallpaper.url)
        let duration2 = Date().timeIntervalSince(start2)
        
        XCTAssertLessThan(duration2, duration1 * 0.5, "Cache should make second call significantly faster")
    }
    
    func testMemoryPressureHandling() async throws {
        let cache = AdaptiveCache()
        let wallpapers = try await createTestWallpapers(count: 10)
        
        // Fill cache
        for wallpaper in wallpapers {
            let image = NSImage(contentsOf: wallpaper.url)!
            cache.setImage(image, for: wallpaper.url, type: .thumbnail)
        }
        
        let initialStats = cache.getCacheStatistics()
        XCTAssertGreaterThan(initialStats.totalEntries, 0)
        
        // Simulate memory pressure
        cache.reduceCacheSize(by: 0.8)
        
        let reducedStats = cache.getCacheStatistics()
        XCTAssertLessThan(reducedStats.totalCacheSize, initialStats.totalCacheSize)
    }
}

// MARK: - Smart Rotation Tests
final class SmartRotationTests: WallpaperTestCase {
    
    func testSmartRotationSelection() async throws {
        let (playlist, wallpapers) = try await createTestPlaylist(name: "Smart Rotation Test", wallpaperCount: 5)
        
        let smartEngine = SmartRotationEngine()
        let context = RotationContext()
        
        let selectedWallpaper = smartEngine.selectNextWallpaper(
            from: playlist,
            mode: .smart,
            context: context
        )
        
        XCTAssertNotNil(selectedWallpaper)
        XCTAssertTrue(wallpapers.contains { $0.id == selectedWallpaper?.id })
    }
    
    func testRotationHistory() async throws {
        let (playlist, _) = try await createTestPlaylist(name: "History Test", wallpaperCount: 10)
        
        let smartEngine = SmartRotationEngine()
        let context = RotationContext()
        
        var selectedWallpapers: [UUID] = []
        
        // Select multiple wallpapers
        for _ in 0..<5 {
            if let selected = smartEngine.selectNextWallpaper(from: playlist, mode: .smart, context: context) {
                selectedWallpapers.append(selected.id)
            }
        }
        
        XCTAssertEqual(selectedWallpapers.count, 5)
        
        // Should prefer variety (no immediate repeats in small sets)
        let uniqueSelections = Set(selectedWallpapers)
        XCTAssertGreaterThan(uniqueSelections.count, 2, "Should show some variety in selection")
    }
}

// MARK: - File Monitoring Tests
final class FileMonitoringTests: WallpaperTestCase {
    
    func testFileChangeDetection() async throws {
        let wallpaper = try await createTestWallpaper(name: "test_file_monitoring")
        let monitor = WallpaperFileMonitor()
        
        let changeExpectation = expectation(description: "File change detected")
        var detectedChange: FileChange?
        
        monitor.monitorWallpaper(wallpaper) { change, url in
            detectedChange = change
            changeExpectation.fulfill()
        }
        
        // Wait a moment for monitoring to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Modify the file
        let modifiedData = "modified".data(using: .utf8)!
        try modifiedData.write(to: wallpaper.url.appendingPathExtension("txt"))
        
        await fulfillment(of: [changeExpectation], timeout: 5)
        
        XCTAssertNotNil(detectedChange)
        monitor.stopMonitoring(wallpaper.url)
    }
    
    func testMonitoringStatus() async throws {
        let monitor = WallpaperFileMonitor()
        let wallpapers = try await createTestWallpapers(count: 3)
        
        // Initially no monitors
        var status = monitor.getMonitoringStatus()
        XCTAssertEqual(status.activeMonitors, 0)
        XCTAssertTrue(status.isEnabled)
        
        // Start monitoring
        for wallpaper in wallpapers {
            monitor.monitorWallpaper(wallpaper) { _, _ in }
        }
        
        // Should have active monitors
        status = monitor.getMonitoringStatus()
        XCTAssertEqual(status.activeMonitors, 3)
        
        // Stop all monitoring
        monitor.stopAllMonitoring()
        status = monitor.getMonitoringStatus()
        XCTAssertEqual(status.activeMonitors, 0)
    }
}
