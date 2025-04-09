import SwiftUI
import AppKit
import Wallpaper

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
                        path: url.absoluteString,
                        name: url.lastPathComponent,
                        isSelected: false
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
        do {
            try wallpaperManager.deletePlaylist(id: playlist.id)
        } catch {
            showError("Failed to delete playlist: \(error.localizedDescription)")
        }
    }
    
    func moveWallpaper(from sourcePlaylist: Playlist, at sourceIndex: Int, to targetIndex: Int) {
        do {
            try wallpaperManager.moveWallpaper(
                from: sourcePlaylist,
                at: sourceIndex,
                to: playlist,
                at: targetIndex
            )
        } catch {
            showError("Failed to move wallpaper: \(error.localizedDescription)")
        }
    }
    
    func setWallpaper(from url: URL) {
        do {
            try wallpaperManager.setWallpaper(from: url)
            wallpaperManager.setActivePlaylist(playlist.id)
        } catch {
            showError("Failed to set wallpaper: \(error.localizedDescription)")
        }
    }
    
    func updatePlaybackMode(_ mode: PlaybackMode) {
        do {
            try wallpaperManager.updatePlaylistPlaybackMode(playlist.id, mode)
        } catch {
            showError("Failed to update playback mode: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        isErrorPresented = true
    }
} 