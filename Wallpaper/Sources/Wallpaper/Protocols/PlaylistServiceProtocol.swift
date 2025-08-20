import Foundation
import WallpaperTypes

/// Protocol defining functionality for managing wallpaper playlists
@preconcurrency
public protocol PlaylistServiceProtocol: Sendable {
    // MARK: - Playlist Management
    func createPlaylist(name: String) async throws -> Playlist
    func deletePlaylist(_ playlist: Playlist) async throws
    func renamePlaylist(_ playlist: Playlist, to newName: String) async throws
    
    // MARK: - Wallpaper Management
    func addWallpaper(_ wallpaper: WallpaperItem, to playlist: Playlist) async throws
    func removeWallpaper(_ wallpaper: WallpaperItem, from playlist: Playlist) async throws
    func moveWallpaper(_ wallpaper: WallpaperItem, from source: Playlist, to destination: Playlist) async throws
    
    // MARK: - Playlist Operations
    func getPlaylists() async throws -> [Playlist]
    func getWallpapers(for playlist: Playlist) async throws -> [WallpaperItem]
    func reorderWallpapers(in playlist: Playlist, newOrder: [WallpaperItem]) async throws
    
    // MARK: - Properties
    var currentPlaylist: Playlist? { get set }
}