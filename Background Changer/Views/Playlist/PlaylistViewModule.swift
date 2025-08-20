import SwiftUI
import AppKit
import Wallpaper

public enum PlaylistViewModule {
    public struct View: SwiftUI.View {
        private let playlist: Wallpaper.Playlist
        private let onEdit: (Wallpaper.Playlist) -> Void

        public init(playlist: Wallpaper.Playlist, onEdit: @escaping (Wallpaper.Playlist) -> Void) {
                self.playlist = playlist
                self.onEdit = onEdit
            }

            public var body: some SwiftUI.View {
                PlaylistView(playlist: playlist, onEdit: onEdit)
            }
    }
} 