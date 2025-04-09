import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Wallpaper

struct PlaylistView: View {
    @StateObject private var viewModel: PlaylistViewModel
    
    init(wallpaperManager: WallpaperManager, playlist: Playlist, onEdit: @escaping (Playlist) -> Void) {
        _viewModel = StateObject(wrappedValue: PlaylistViewModel(
            wallpaperManager: wallpaperManager,
            playlist: playlist,
            onEdit: onEdit
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            if viewModel.isExpanded {
                wallpaperGridView
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .fileImporter(
            isPresented: $viewModel.showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleImagePickerResult(result)
        }
        .alert("Delete Playlist", isPresented: $viewModel.showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                viewModel.deletePlaylist()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this playlist? This action cannot be undone.")
        }
        .alert("Error", isPresented: $viewModel.isErrorPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: viewModel.isExpanded ? "chevron.down" : "chevron.right")
            Text(viewModel.playlist.name)
                .font(.headline)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { viewModel.showingImagePicker = true }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if viewModel.wallpaperManager.isRotating {
                        viewModel.wallpaperManager.stopRotation()
                    } else {
                        viewModel.wallpaperManager.startPlaylistRotation(
                            playlistId: viewModel.playlist.id,
                            interval: 60
                        )
                    }
                }) {
                    Image(systemName: viewModel.wallpaperManager.isRotating ? "pause.circle" : "play.circle")
                }
                .buttonStyle(.plain)
                
                Menu {
                    Picker("Playback Mode", selection: Binding(
                        get: { viewModel.playlist.playbackMode },
                        set: { viewModel.updatePlaybackMode($0) }
                    )) {
                        Text("Sequential").tag(PlaybackMode.sequential)
                        Text("Random").tag(PlaybackMode.random)
                    }
                } label: {
                    Image(systemName: "gear")
                }
                
                Button(action: { viewModel.onEdit(viewModel.playlist) }) {
                    Image(systemName: "pencil")
                }
                
                Button(action: { viewModel.showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                }
            }
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                viewModel.isExpanded.toggle()
            }
        }
    }
    
    private var wallpaperGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            ForEach(Array(viewModel.playlist.wallpapers.enumerated()), id: \.element.id) { index, wallpaper in
                if let url = wallpaper.fileURL,
                   let image = NSImage(contentsOf: url) {
                    PlaylistThumbnailView(
                        image: image,
                        wallpaper: wallpaper,
                        index: index,
                        isDragged: viewModel.draggedItemId == wallpaper.id,
                        isDropTarget: viewModel.dropTargetIndex == index,
                        onTap: { viewModel.setWallpaper(from: url) },
                        onDragStart: { viewModel.draggedItemId = wallpaper.id },
                        onDragEnd: { viewModel.draggedItemId = nil }
                    )
                }
            }
        }
        .padding(.top, 8)
        .dropDestination(for: String.self) { items, location in
            guard let droppedId = items.first,
                  let sourceIndex = viewModel.playlist.wallpapers.firstIndex(where: { $0.id.uuidString == droppedId }) else {
                return false
            }
            
            let targetIndex = viewModel.dropTargetIndex ?? viewModel.playlist.wallpapers.count
            viewModel.moveWallpaper(
                from: viewModel.playlist,
                at: sourceIndex,
                to: targetIndex
            )
            
            viewModel.dropTargetIndex = nil
            viewModel.draggedItemId = nil
            return true
        } isTargeted: { isTargeted in
            viewModel.dropTargetIndex = isTargeted ? viewModel.playlist.wallpapers.count : nil
        }
    }
} 