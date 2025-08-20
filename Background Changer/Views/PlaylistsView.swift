import SwiftUI
import AppKit

struct PlaylistsView: View {
    @EnvironmentObject var rotationVM: RotationViewModel
    @EnvironmentObject var router: PlaylistFlowRouter
    @EnvironmentObject var wallpaperManager: WallpaperManager
    
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
                    ForEach(rotationVM.playlists) { playlist in
                        PlaylistViewModule.View(
                            playlist: playlist,
                            onEdit: { p in router.startRename(p) }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Preview Provider
struct PlaylistsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistsView()
    }
} 