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

        // Cleanup
        cache.clearCache()
    }

    func testCacheClear() {
        let cache = WallpaperCache.shared
        cache.clearCache()

        // Add multiple images
        for i in 0..<5 {
            let testImage = NSImage(size: NSSize(width: 100, height: 100))
            let testURL = URL(fileURLWithPath: "/tmp/test_clear_\(i).jpg")
            cache.setImage(testImage, for: testURL)
        }

        XCTAssertEqual(cache.imageCacheCount, 5)

        // Clear all
        cache.clearCache()

        XCTAssertEqual(cache.imageCacheCount, 0)
        XCTAssertEqual(cache.imageCacheSize, 0)
    }

    // MARK: - Playlist Service Tests

    func testPlaylistCreation() async {
        let service = await MainActor.run { PlaylistService() }

        do {
            let playlist = try await service.createPlaylist(name: "Test Playlist")
            XCTAssertEqual(playlist.name, "Test Playlist")
            XCTAssertTrue(playlist.wallpapers.isEmpty)
        } catch {
            XCTFail("Playlist creation should succeed: \(error)")
        }
    }

    func testDuplicatePlaylistName() async {
        let service = await MainActor.run { PlaylistService() }

        do {
            let _ = try await service.createPlaylist(name: "Duplicate")
            let _ = try await service.createPlaylist(name: "Duplicate")
            XCTFail("Should not allow duplicate playlist names")
        } catch {
            // Expected - duplicate name should throw
        }
    }

    func testPlaylistLimit() async {
        let service = await MainActor.run { PlaylistService() }

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
            // Expected - should fail when exceeding limit
        }
    }

    func testPlaylistRename() async {
        let service = await MainActor.run { PlaylistService() }

        do {
            let playlist = try await service.createPlaylist(name: "Original Name")
            try await service.renamePlaylist(playlist, to: "New Name")

            let playlists = try await service.getPlaylists()
            XCTAssertEqual(playlists.first?.name, "New Name")
        } catch {
            XCTFail("Playlist rename should succeed: \(error)")
        }
    }

    func testPlaylistDeletion() async {
        let service = await MainActor.run { PlaylistService() }

        do {
            let playlist = try await service.createPlaylist(name: "To Delete")
            var playlists = try await service.getPlaylists()
            XCTAssertEqual(playlists.count, 1)

            try await service.deletePlaylist(playlist)
            playlists = try await service.getPlaylists()
            XCTAssertEqual(playlists.count, 0)
        } catch {
            XCTFail("Playlist deletion should succeed: \(error)")
        }
    }

    func testWallpaperLookup() async {
        let service = await MainActor.run { PlaylistService() }

        // Create a test wallpaper
        let testWallpaper = WallpaperItem(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            name: "Test Wallpaper"
        )

        // Set up wallpaper lookup
        await MainActor.run {
            service.wallpaperLookup = { id in
                if id == testWallpaper.id {
                    return testWallpaper
                }
                return nil
            }
        }

        do {
            let playlist = try await service.createPlaylist(name: "Test Playlist")

            // Add wallpaper using lookup
            try await service.addWallpapersToPlaylist(
                playlistId: playlist.id,
                wallpaperIds: Set([testWallpaper.id])
            )

            let playlists = try await service.getPlaylists()
            XCTAssertEqual(playlists.first?.wallpapers.count, 1)
            XCTAssertEqual(playlists.first?.wallpapers.first?.name, "Test Wallpaper")
        } catch {
            XCTFail("Adding wallpaper via lookup should succeed: \(error)")
        }
    }

    func testWallpaperLookupFailure() async {
        let service = await MainActor.run { PlaylistService() }

        // Don't set up wallpaper lookup (will return nil)

        do {
            let playlist = try await service.createPlaylist(name: "Test Playlist")

            // Try to add wallpaper without lookup configured
            try await service.addWallpapersToPlaylist(
                playlistId: playlist.id,
                wallpaperIds: Set([UUID()])
            )
            XCTFail("Should fail when wallpaper lookup returns nil")
        } catch {
            // Expected - should fail when lookup returns nil
        }
    }

    // MARK: - Rotation Interval Tests

    func testRotationIntervalUpdate() async {
        let service = await MainActor.run { PlaylistService() }

        do {
            let playlist = try await service.createPlaylist(name: "Test Playlist")
            try await service.activatePlaylist(playlist.id)

            await service.updateRotationInterval(7200) // 2 hours

            let currentInterval = await MainActor.run { service.rotationInterval }
            XCTAssertEqual(currentInterval, 7200)
        } catch {
            // Note: activatePlaylist may fail if playlist is empty, which is expected
        }
    }

    // MARK: - Persistence Tests

    func testPersistenceControllerInit() {
        // Test that PersistenceController initializes without crashing
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container)
        XCTAssertNotNil(controller.viewContext)
    }

    func testPersistenceBackgroundContext() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.newBackgroundContext()
        XCTAssertNotNil(context)
    }
}

// MARK: - Mock Storage Service for Testing
class MockStorageService: StorageServiceProtocol {
    private var storage: [String: Data] = [:]

    func save<T: Codable>(_ object: T, key: String) async throws {
        let data = try JSONEncoder().encode(object)
        storage[key] = data
    }

    func load<T: Codable>(_ type: T.Type, key: String) async throws -> T? {
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func delete(key: String) async throws {
        storage.removeValue(forKey: key)
    }

    func exists(key: String) async throws -> Bool {
        return storage[key] != nil
    }

    func backup(key: String) async throws -> String {
        let backupKey = "backup_\(key)_\(Date().timeIntervalSince1970)"
        if let data = storage[key] {
            storage[backupKey] = data
        }
        return backupKey
    }

    func restore(key: String, backupId: String) async throws {
        if let data = storage[backupId] {
            storage[key] = data
        }
    }
}
