import SwiftUI
import AppKit
import Wallpaper

struct PlaylistsView: View {
    @EnvironmentObject var rotationVM: RotationViewModel
    @EnvironmentObject var router: PlaylistFlowRouter
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Playlists").font(.title2).bold()
                Spacer()
                Button {
                    router.startCreate()
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    if rotationVM.playlists.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Playlists")
                                .font(.headline)
                            Text("Create a playlist to organize your wallpapers")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Create Playlist") {
                                router.startCreate()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(rotationVM.playlists) { playlist in
                            PlaylistViewModule.View(
                                playlist: playlist,
                                onEdit: { p in router.startRename(p) }
                            )
                        }
                    }
                }
                .padding()
            }
        }
        // Sheet for Create Playlist
        .sheet(isPresented: Binding(
            get: { router.activeFlow?.id == "create" },
            set: { if !$0 { router.dismiss() } }
        )) {
            CreatePlaylistView()
                .environmentObject(rotationVM)
                .environmentObject(themeManager)
        }
        // Sheet for Edit/Rename Playlist
        .sheet(item: Binding(
            get: {
                if case .rename(let playlist) = router.activeFlow {
                    return playlist
                }
                return nil
            },
            set: { _ in router.dismiss() }
        )) { playlist in
            EditPlaylistView(playlist: playlist)
                .environmentObject(rotationVM)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Preview Provider
struct PlaylistsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistsView()
    }
} 