//
//  CreateEditPlaylistView.swift
//  Background Changer
//
//  Views for creating and editing playlists
//

import SwiftUI
import Wallpaper
import WallpaperTypes

// MARK: - Create Playlist View
struct CreatePlaylistView: View {
    @EnvironmentObject var rotationVM: RotationViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var playlistName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Create New Playlist")
                .font(.title2)
                .fontWeight(.bold)
                .themedText()

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist Name")
                    .font(.subheadline)
                    .foregroundColor(themeManager.theme.secondaryTextColorValue)

                TextField("Enter playlist name", text: $playlistName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createPlaylist()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(minWidth: 350)
        .themedBackground()
    }

    private func createPlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a playlist name"
            return
        }

        // Check for duplicate names
        if rotationVM.playlists.contains(where: { $0.name == trimmedName }) {
            errorMessage = "A playlist with this name already exists"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await rotationVM.createPlaylist(name: trimmedName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

// MARK: - Edit Playlist View
struct EditPlaylistView: View {
    @EnvironmentObject var rotationVM: RotationViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let playlist: Wallpaper.Playlist

    @State private var playlistName: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Edit Playlist")
                .font(.title2)
                .fontWeight(.bold)
                .themedText()

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist Name")
                    .font(.subheadline)
                    .foregroundColor(themeManager.theme.secondaryTextColorValue)

                TextField("Enter playlist name", text: $playlistName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }

            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text("Wallpapers: \(playlist.wallpapers.count)")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.secondaryTextColorValue)

                if playlist.rotationInterval > 0 {
                    Text("Rotation: \(formatInterval(playlist.rotationInterval))")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.secondaryTextColorValue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    savePlaylist()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(minWidth: 350)
        .themedBackground()
        .onAppear {
            playlistName = playlist.name
        }
    }

    private func savePlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a playlist name"
            return
        }

        // Check for duplicate names (excluding current playlist)
        if rotationVM.playlists.contains(where: { $0.name == trimmedName && $0.id != playlist.id }) {
            errorMessage = "A playlist with this name already exists"
            return
        }

        // If name hasn't changed, just dismiss
        if trimmedName == playlist.name {
            dismiss()
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await rotationVM.renamePlaylist(id: playlist.id, newName: trimmedName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval)) seconds"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) minutes"
        } else {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
    }
}

// MARK: - Preview Providers
struct CreatePlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePlaylistView()
    }
}

struct EditPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePlaylist = WallpaperTypes.Playlist(name: "Sample Playlist")
        EditPlaylistView(playlist: samplePlaylist)
    }
}
