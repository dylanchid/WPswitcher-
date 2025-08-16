import SwiftUI
import Wallpaper
import WallpaperTypes

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallpaperManager: WallpaperManager
    
    @State private var playlistName: String = ""
    @State private var duration: Double = 60
    @State private var playbackMode: Wallpaper.PlaybackMode = .sequential
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Playlist")
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
                    Text("Shuffle").tag(PlaybackMode.shuffle)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Create") {
                    createPlaylist()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        }
        .padding(20)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createPlaylist() {
        guard !playlistName.isEmpty else {
            showError = true
            errorMessage = "Please enter a playlist name"
            return
        }
        
        do {
            try wallpaperManager.createPlaylist(name: playlistName)
            dismiss()
        } catch let error as WallpaperTypes.WallpaperError {
            showError = true
            switch error {
            case .invalidPlaylistOperation(let message):
                errorMessage = message
            case .playlistLimitExceeded:
                errorMessage = "You have reached the maximum number of playlists."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview Provider
struct CreatePlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePlaylistView(wallpaperManager: WallpaperManager.shared)
            .frame(width: 400, height: 300)
            .preferredColorScheme(.dark)
    }
} 