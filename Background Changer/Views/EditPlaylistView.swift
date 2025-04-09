import SwiftUI

struct EditPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    let wallpaperManager: WallpaperManager
    let playlist: Playlist
    
    @State private var playlistName: String
    @State private var duration: Double
    @State private var playbackMode: PlaybackMode
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false
    
    init(wallpaperManager: WallpaperManager, playlist: Playlist) {
        self.wallpaperManager = wallpaperManager
        self.playlist = playlist
        _playlistName = State(initialValue: playlist.name)
        _duration = State(initialValue: 60)
        _playbackMode = State(initialValue: playlist.playbackMode)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Playlist")
                .font(.headline)
            
            TextField("Playlist Name", text: $playlistName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 250)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.subheadline)
                
                HStack {
                    Slider(value: $duration, in: 10...3600, step: 10)
                        .frame(width: 200)
                    Text("\(Int(duration))s")
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Playback Mode")
                    .font(.subheadline)
                
                Picker("", selection: $playbackMode) {
                    Text("Sequential").tag(PlaybackMode.sequential)
                    Text("Random").tag(PlaybackMode.random)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        }
        .padding(20)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func saveChanges() {
        guard !playlistName.isEmpty else {
            showError = true
            errorMessage = "Please enter a playlist name"
            return
        }
        
        do {
            try wallpaperManager.renamePlaylist(id: playlist.id, newName: playlistName)
            dismiss()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview Provider
struct EditPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPlaylist = Playlist(id: UUID(), name: "Test Playlist", wallpapers: [], playbackMode: .sequential)
        EditPlaylistView(wallpaperManager: WallpaperManager.shared, playlist: mockPlaylist)
            .frame(width: 400, height: 300)
            .preferredColorScheme(.dark)
    }
} 