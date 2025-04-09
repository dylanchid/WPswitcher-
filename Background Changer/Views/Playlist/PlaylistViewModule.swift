import SwiftUI
import AppKit

public enum PlaylistViewModule {
    public struct View: SwiftUI.View {
        private let wallpaperManager: WallpaperManager
        private let playlist: Playlist
        private let onEdit: (Playlist) -> Void
        
        public init(wallpaperManager: WallpaperManager, playlist: Playlist, onEdit: @escaping (Playlist) -> Void) {
            self.wallpaperManager = wallpaperManager
            self.playlist = playlist
            self.onEdit = onEdit
        }
        
        public var body: some SwiftUI.View {
            PlaylistView(wallpaperManager: wallpaperManager, playlist: playlist, onEdit: onEdit)
        }
    }
} 