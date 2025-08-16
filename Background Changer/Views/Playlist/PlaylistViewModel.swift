import SwiftUI
import AppKit
import Wallpaper
import WallpaperTypes

@MainActor
class PlaylistViewModel: ObservableObject {
    @Published var isExpanded: Bool = true
    @Published var showingDeleteAlert = false
    @Published var draggedItemId: UUID?
    @Published var dropTargetIndex: Int?
    @Published var showingImagePicker = false
    @Published var errorMessage: String?
    @Published var isErrorPresented = false
    
    let wallpaperManager: WallpaperManager
    let playlist: Playlist
    let onEdit: (Playlist) -> Void
    
    // Version history properties
    var canUndo: Bool {
        wallpaperManager.currentVersionIndex >= 0
    }
    
    var canRedo: Bool {
        wallpaperManager.currentVersionIndex < wallpaperManager.versionHistory.count - 1
    }
    
    var versionHistory: [PlaylistVersion] {
        wallpaperManager.versionHistory
    }
    
    init(wallpaperManager: WallpaperManager, playlist: Playlist, onEdit: @escaping (Playlist) -> Void) {
        self.wallpaperManager = wallpaperManager
        self.playlist = playlist
        self.onEdit = onEdit
    }
    
    func handleImagePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    let wallpaper = WallpaperItem(
                        id: UUID(),
                        url: url,
                        name: url.lastPathComponent
                    )
                    do {
                        try wallpaperManager.addWallpapersToPlaylist([wallpaper], playlistId: playlist.id)
                    } catch {
                        showError("Failed to add wallpaper: \(error.localizedDescription)")
                    }
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            showError("Error selecting images: \(error.localizedDescription)")
        }
    }
    
    func deletePlaylist() {
        wallpaperManager.deletePlaylist(id: playlist.id)
    }
    
    func moveWallpaper(from sourceIndex: Int, to destinationIndex: Int) {
        do {
            try wallpaperManager.reorderWallpapers(in: playlist.id, from: sourceIndex, to: destinationIndex)
        } catch {
            showError("Failed to move wallpaper: \(error.localizedDescription)")
        }
    }
    
    func setWallpaper(from url: URL) {
        Task {
            await wallpaperManager.setWallpaper(from: url)
            wallpaperManager.setActivePlaylist(playlist.id)
        }
    }
    
    func updatePlaybackMode(_ mode: PlaybackMode) {
        // Convert local PlaybackMode to Wallpaper.PlaybackMode
        let wallpaperMode: Wallpaper.PlaybackMode
        switch mode {
        case .sequential:
            wallpaperMode = .sequential
        case .random:
            wallpaperMode = .random
        case .shuffle:
            wallpaperMode = .shuffle
        }
        wallpaperManager.updatePlaylistPlaybackMode(playlistId: playlist.id, mode: wallpaperMode)
    }
    
    func showError(_ message: String) {
        errorMessage = message
        isErrorPresented = true
    }
} 