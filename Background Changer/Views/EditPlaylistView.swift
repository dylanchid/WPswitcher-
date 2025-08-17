import SwiftUI
import Wallpaper
import WallpaperTypes

struct EditPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rotationVM: RotationViewModel
    let playlist: Wallpaper.Playlist
    
    @State private var playlistName: String
    @State private var duration: Double
    @State private var playbackMode: Wallpaper.PlaybackMode
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var isErrorPresented = false
    
    init(playlist: Wallpaper.Playlist) {
        self.playlist = playlist
        _playlistName = State(initialValue: playlist.name)
        _duration = State(initialValue: playlist.rotationInterval)
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
                    Text("Sequential").tag(Wallpaper.PlaybackMode.sequential)
                    Text("Random").tag(Wallpaper.PlaybackMode.random)
                    Text("Shuffle").tag(Wallpaper.PlaybackMode.shuffle)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") { saveChanges() }
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
        let trimmed = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError = true
            errorMessage = "Please enter a playlist name"
            return
        }

        Task { @MainActor in
            do {
                try await rotationVM.renamePlaylist(id: playlist.id, to: trimmed)
                dismiss()
            } catch {
                let alert = ErrorPresenter.alertContent(for: error)
                errorMessage = [alert.message, alert.suggestion].compactMap { $0 }.joined(separator: "\n\n")
                showError = true
            }
        }
    }
}

// MARK: - Preview Provider
struct EditPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
    let mockPlaylist = Wallpaper.Playlist(id: UUID(), name: "Test Playlist", wallpapers: [], playbackMode: .sequential, rotationInterval: 60)
    EditPlaylistView(playlist: mockPlaylist)
            .frame(width: 400, height: 300)
            .preferredColorScheme(.dark)
    }
} 