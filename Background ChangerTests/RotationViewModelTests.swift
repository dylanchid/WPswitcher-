import XCTest
@testable import Background_Changer

@MainActor
final class RotationViewModelTests: XCTestCase {
    func testStartStopRotation() async throws {
        let wallpaper = MockWallpaperService()
        let playlist = MockPlaylistService()
    let settings = MockUserSettingsService()
    let vm = RotationViewModel(wallpaperService: wallpaper, playlistService: playlist, userSettingsService: settings)

        XCTAssertFalse(vm.isRotating)
        vm.startRotation(interval: 120)
        XCTAssertTrue(vm.isRotating)
        XCTAssertEqual(wallpaper.startCalls, 1)

        vm.stopRotation()
        XCTAssertFalse(vm.isRotating)
        XCTAssertEqual(wallpaper.stopCalls, 1)
    }

    func testActivateEmptyPlaylistSurfacesError() async {
        let wallpaper = MockWallpaperService()
        let playlist = MockPlaylistService()
        playlist.playlists = [Playlist(id: UUID(), name: "Empty", wallpapers: [])]
    let settings = MockUserSettingsService()
    let vm = RotationViewModel(wallpaperService: wallpaper, playlistService: playlist, userSettingsService: settings)
        await vm.activatePlaylist(playlist.playlists[0].id)
        XCTAssertNotNil(vm.lastError)
    }

    func testCreateDuplicatePlaylistSurfacesError() async {
        let wallpaper = MockWallpaperService()
        let playlist = MockPlaylistService()
        playlist.playlists = [Playlist(name: "Dup")]
    let settings = MockUserSettingsService()
    let vm = RotationViewModel(wallpaperService: wallpaper, playlistService: playlist, userSettingsService: settings)
        await vm.createPlaylist(named: "Dup")
        XCTAssertNotNil(vm.lastError)
    }

    func testStartRotationWithNegativeIntervalStillCallsService() async {
        let wallpaper = MockWallpaperService()
        let playlist = MockPlaylistService()
    let settings = MockUserSettingsService()
    let vm = RotationViewModel(wallpaperService: wallpaper, playlistService: playlist, userSettingsService: settings)
        vm.startRotation(interval: -1)
        XCTAssertTrue(vm.isRotating)
        XCTAssertEqual(wallpaper.startCalls, 1)
    }
}

@MainActor
private final class MockWallpaperService: AppWallpaperServiceProtocol {
    var startCalls = 0
    var stopCalls = 0
    var nextCalls = 0
    var prevCalls = 0

    func setWallpaper(from url: URL) async {}
    func startRotation(interval: TimeInterval) { startCalls += 1 }
    func stopRotation() { stopCalls += 1 }
    func rotateToNext() throws { nextCalls += 1 }
    func rotateToPrevious() throws { prevCalls += 1 }
}

@MainActor
private final class MockPlaylistService: PlaylistServiceProtocol {
    var playlists: [Playlist] = []
    var activePlaylistId: UUID? = nil
    var isRotating: Bool = false
    var rotationInterval: TimeInterval = 3600

    func createPlaylist(name: String) async throws -> Playlist {
        if playlists.contains(where: { $0.name == name }) {
            throw WallpaperTypes.WallpaperError.playlistError("Duplicate")
        }
        let p = Playlist(name: name)
        playlists.append(p)
        return p
    }
    func deletePlaylist(_ id: UUID) async throws {}
    func updatePlaylist(_ playlist: Playlist) async throws {}
    func addWallpapersToPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {}
    func removeWallpapersFromPlaylist(playlistId: UUID, wallpaperIds: Set<UUID>) async throws {}
    func activatePlaylist(_ id: UUID) async throws {
        guard let p = playlists.first(where: { $0.id == id }) else { throw WallpaperTypes.WallpaperError.playlistNotFound }
        guard !p.wallpapers.isEmpty else { throw WallpaperTypes.WallpaperError.playlistError("Playlist is empty") }
        activePlaylistId = id
    }
    func deactivateCurrentPlaylist() async { activePlaylistId = nil }
    func updateRotationInterval(_ interval: TimeInterval) async { rotationInterval = interval }
    func updatePlaybackMode(_ mode: PlaybackMode, for playlistId: UUID) async throws {}
}

@MainActor
private final class MockUserSettingsService: UserSettingsServiceProtocol {
    var userSettings: UserSettings = UserSettings()
    func updateSettings(_ settings: UserSettings) async throws { userSettings = settings }
    func resetSettings() async throws { userSettings = UserSettings() }
    func exportSettings() async throws -> Data { Data() }
    func importSettings(_ data: Data) async throws {}
}
