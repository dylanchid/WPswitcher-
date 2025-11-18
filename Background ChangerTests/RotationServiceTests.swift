//
//  RotationServiceTests.swift
//  Background ChangerTests
//
//  Tests for the wallpaper rotation service and related functionality
//

import XCTest
@testable import Background_Changer
import WallpaperTypes

final class RotationServiceTests: XCTestCase {

    // MARK: - Wallpaper History Tests

    func testWallpaperHistoryAddition() async {
        // Test that wallpapers are properly added to history
        let manager = await createTestWallpaperManager()

        // Create test wallpapers
        let wallpaper1 = WallpaperItem(
            url: URL(fileURLWithPath: "/tmp/test1.jpg"),
            name: "Test 1"
        )
        let wallpaper2 = WallpaperItem(
            url: URL(fileURLWithPath: "/tmp/test2.jpg"),
            name: "Test 2"
        )

        // Add to history
        await MainActor.run {
            manager.addToHistory(wallpaper1)
            manager.addToHistory(wallpaper2)

            // Verify history
            XCTAssertEqual(manager.history.count, 2)
            XCTAssertEqual(manager.history[0].name, "Test 1")
            XCTAssertEqual(manager.history[1].name, "Test 2")
        }
    }

    func testUndoRedo() async {
        // Test undo/redo functionality
        let manager = await createTestWallpaperManager()

        await MainActor.run {
            // Add wallpapers
            let wallpaper1 = WallpaperItem(url: URL(fileURLWithPath: "/tmp/test1.jpg"), name: "Test 1")
            let wallpaper2 = WallpaperItem(url: URL(fileURLWithPath: "/tmp/test2.jpg"), name: "Test 2")

            manager.addToHistory(wallpaper1)
            manager.addToHistory(wallpaper2)

            // Check initial state
            XCTAssertTrue(manager.canUndo)
            XCTAssertFalse(manager.canRedo)

            // Undo
            do {
                try manager.undo()
                XCTAssertTrue(manager.canRedo)
            } catch {
                XCTFail("Undo should not throw: \(error)")
            }
        }
    }

    func testHistoryLimit() async {
        // Test that history is limited to maxHistorySize
        let manager = await createTestWallpaperManager()

        await MainActor.run {
            // Add more than maxHistorySize wallpapers
            for i in 0..<60 {
                let wallpaper = WallpaperItem(
                    url: URL(fileURLWithPath: "/tmp/test\(i).jpg"),
                    name: "Test \(i)"
                )
                manager.addToHistory(wallpaper)
            }

            // Verify history is limited
            XCTAssertLessEqual(manager.history.count, 50)
        }
    }

    func testClearHistory() async {
        let manager = await createTestWallpaperManager()

        await MainActor.run {
            // Add some wallpapers
            let wallpaper = WallpaperItem(url: URL(fileURLWithPath: "/tmp/test.jpg"), name: "Test")
            manager.addToHistory(wallpaper)

            XCTAssertEqual(manager.history.count, 1)

            // Clear history
            manager.clearHistory()

            XCTAssertEqual(manager.history.count, 0)
            XCTAssertFalse(manager.canUndo)
            XCTAssertFalse(manager.canRedo)
        }
    }

    // MARK: - Backup System Tests

    func testCreateBackup() async {
        let manager = await createTestWallpaperManager()

        await MainActor.run {
            let backupId = manager.createBackup(name: "Test Backup")

            XCTAssertNotNil(backupId)
            XCTAssertEqual(manager.backups.count, 1)
            XCTAssertEqual(manager.backups.first?.name, "Test Backup")
        }
    }

    func testDeleteBackup() async {
        let manager = await createTestWallpaperManager()

        await MainActor.run {
            // Create multiple backups
            let _ = manager.createBackup(name: "Backup 1")
            let backupId2 = manager.createBackup(name: "Backup 2")

            XCTAssertEqual(manager.backups.count, 2)

            // Delete first backup (not current)
            do {
                try manager.deleteBackup(id: manager.backups[0].id)
                XCTAssertEqual(manager.backups.count, 1)
                XCTAssertEqual(manager.backups.first?.name, "Backup 2")
            } catch {
                XCTFail("Should be able to delete non-current backup: \(error)")
            }

            // Try to delete current backup (should fail)
            do {
                try manager.deleteBackup(id: backupId2)
                XCTFail("Should not be able to delete current backup")
            } catch {
                // Expected
            }
        }
    }

    // MARK: - Cache Monitoring Tests

    func testCacheStatistics() {
        let cache = WallpaperCache.shared

        // Clear cache first
        cache.clearCache()

        XCTAssertEqual(cache.imageCacheCount, 0)
        XCTAssertEqual(cache.imageCacheSize, 0)

        // Create a test image
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let testURL = URL(fileURLWithPath: "/tmp/test_cache.jpg")

        // Add to cache
        cache.setImage(testImage, for: testURL)

        XCTAssertEqual(cache.imageCacheCount, 1)
        XCTAssertGreaterThan(cache.imageCacheSize, 0)

        // Remove from cache
        cache.removeImage(for: testURL)

        XCTAssertEqual(cache.imageCacheCount, 0)
        XCTAssertEqual(cache.imageCacheSize, 0)
    }

    func testCacheExpiration() {
        let cache = WallpaperCache.shared
        cache.clearCache()

        let testImage = NSImage(size: NSSize(width: 50, height: 50))
        let testURL = URL(fileURLWithPath: "/tmp/test_expire.jpg")

        cache.setImage(testImage, for: testURL)

        // Image should be retrievable
        XCTAssertNotNil(cache.getImage(for: testURL))
    }

    func testFormattedCacheSize() {
        let cache = WallpaperCache.shared
        cache.clearCache()

        // Add a known-size image
        let testImage = NSImage(size: NSSize(width: 512, height: 512))
        let testURL = URL(fileURLWithPath: "/tmp/test_format.jpg")

        cache.setImage(testImage, for: testURL)

        let formatted = cache.formattedCacheSize
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("MB") || formatted.contains("B"))
    }

    // MARK: - Playlist Validation Tests

    func testPlaylistCreation() async {
        let service = PlaylistService()

        do {
            let playlist = try await service.createPlaylist(name: "Test Playlist")
            XCTAssertEqual(playlist.name, "Test Playlist")
            XCTAssertTrue(playlist.wallpapers.isEmpty)
        } catch {
            XCTFail("Playlist creation should succeed: \(error)")
        }
    }

    func testDuplicatePlaylistName() async {
        let service = PlaylistService()

        do {
            let _ = try await service.createPlaylist(name: "Duplicate")
            let _ = try await service.createPlaylist(name: "Duplicate")
            XCTFail("Should not allow duplicate playlist names")
        } catch {
            // Expected
        }
    }

    func testPlaylistLimit() async {
        let service = PlaylistService()

        // Create max number of playlists
        for i in 0..<20 {
            do {
                let _ = try await service.createPlaylist(name: "Playlist \(i)")
            } catch {
                XCTFail("Should be able to create playlist \(i): \(error)")
            }
        }

        // Try to create one more
        do {
            let _ = try await service.createPlaylist(name: "One Too Many")
            XCTFail("Should not exceed playlist limit")
        } catch {
            // Expected
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func createTestWallpaperManager() -> WallpaperManager {
        // Create a minimal test setup
        // Note: This requires proper dependency injection setup in tests
        // For now, we'll use a simplified approach

        // This would typically be done with mocks/stubs
        fatalError("Test setup requires proper mock implementation")
    }
}

// MARK: - Test Extension for WallpaperManager
extension WallpaperManager {
    // Expose internal method for testing
    func addToHistory(_ wallpaper: WallpaperTypes.WallpaperItem) {
        // If we're not at the end of history, remove future entries
        if historyIndex < wallpaperHistory.count - 1 {
            wallpaperHistory.removeSubrange((historyIndex + 1)...)
        }

        wallpaperHistory.append(wallpaper)
        historyIndex = wallpaperHistory.count - 1

        if wallpaperHistory.count > maxHistorySize {
            wallpaperHistory.removeFirst()
            historyIndex = wallpaperHistory.count - 1
        }
    }

    // Expose properties for testing
    var wallpaperHistory: [WallpaperTypes.WallpaperItem] {
        get { history }
        set { /* Set through addToHistory */ }
    }

    var historyIndex: Int {
        get { _historyIndex }
        set { _historyIndex = newValue }
    }

    private var _historyIndex: Int {
        get { -1 } // Would access private property
        set { }
    }
}
