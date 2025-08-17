import SwiftUI
import AppKit
import Wallpaper
import WallpaperTypes

@MainActor
class PlaylistViewModel: ObservableObject {
    @Published var isExpanded: Bool = true
    @Published var draggedItemId: UUID?
    @Published var dropTargetIndex: Int?
    @Published var showingImagePicker = false
    @Published var errorMessage: String?
    @Published var isErrorPresented = false
    private var lastError: Error?

    var presentedErrorMessage: String {
        if let lastError = lastError {
            let alert = ErrorPresenter.alertContent(for: lastError)
            return [alert.message, alert.suggestion].compactMap { $0 }.joined(separator: "\n\n")
        }
        return errorMessage ?? "An unknown error occurred"
    }
    
    let wallpaperManager: WallpaperManager
    let playlist: Playlist
    let onEdit: (Wallpaper.Playlist) -> Void
    var onDelete: ((Wallpaper.Playlist) -> Void)?
    
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
    
    init(playlist: Wallpaper.Playlist, onEdit: @escaping (Wallpaper.Playlist) -> Void) {
        self.wallpaperManager = .shared
        self.playlist = playlist
        self.onEdit = onEdit
    }
    
    func handleImagePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await wallpaperManager.addWallpaperToPlaylist(playlistId: playlist.id, urls: urls)
            }
        case .failure(let error):
            present(error)
        }
    }
    
    // Delete is handled by the coordinator; trigger from the View via router
    
    func moveWallpaper(from sourceIndex: Int, to destinationIndex: Int) {
        Task { @MainActor in
            await wallpaperManager.reorderWallpapers(in: playlist.id, from: sourceIndex, to: destinationIndex)
        }
    }
    
    func setWallpaper(from url: URL) {
        Task {
            await wallpaperManager.setWallpaper(from: url)
            wallpaperManager.setActivePlaylist(playlist.id)
        }
    }
    
    func updatePlaybackMode(_ mode: Wallpaper.PlaybackMode) {
        wallpaperManager.updatePlaylistPlaybackMode(playlistId: playlist.id, mode: mode)
    }
    
    func presentError(_ error: Error) {
        present(error)
    }

    private func present(_ error: Error) {
        lastError = error
        isErrorPresented = true
    }
}