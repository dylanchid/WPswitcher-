import SwiftUI
import AppKit

struct PlaylistsView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    @State private var showingCreatePlaylist = false
    @State private var editingPlaylist: Playlist?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(wallpaperManager.playlists) { playlist in
                    PlaylistViewModule.View(
                        wallpaperManager: wallpaperManager,
                        playlist: playlist,
                        onEdit: { playlist in
                            editingPlaylist = playlist
                        }
                    )
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView(wallpaperManager: wallpaperManager)
        }
        .sheet(item: $editingPlaylist) { playlist in
            EditPlaylistView(wallpaperManager: wallpaperManager, playlist: playlist)
        }
    }
}

// MARK: - Preview Provider
struct PlaylistsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistsView(wallpaperManager: WallpaperManager.shared)
    }
} 