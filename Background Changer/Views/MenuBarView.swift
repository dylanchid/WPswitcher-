import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}

struct MenuBarView: View {
    @StateObject var wallpaperManager: WallpaperManager = WallpaperManager.shared
    @State private var selectedNavigation: NavigationItem? = .home
    @State private var selectedImagePath: String = ""
    @State public var rotationInterval: Double = 60
    @State public var isRotating: Bool = false
    @State public var showOnAllSpaces: Bool = true
    @State public var selectedDisplay: String = "All Displays"
    @State public var wallpapers: [WallpaperItem] = []
    @State public var displayMode: DisplayMode = .fillScreen
    @State private var playlists: [Playlist] = []
    @State private var editingPlaylistId: UUID?
    @State private var editingPlaylistName: String = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var playlistPreviews: [UUID: PlaylistPreviewData] = [:]
    
    enum NavigationItem: String, Hashable {
        case home = "Home"
        case playlists = "Playlists"
        case allPhotos = "All Photos"
        case settings = "Settings"
    }
    
    init() {
        _wallpaperManager = StateObject(wrappedValue: WallpaperManager.shared)
        // Set initial wallpaper
        if let (wallpaperURL, _) = WallpaperManager.shared.getCurrentSystemWallpaper() {
            _selectedImagePath = State(initialValue: wallpaperURL.absoluteString)
        }
    }
    
    var body: some View {
        NavigationView {
            // Sidebar with translucent background
            ZStack {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                List(selection: $selectedNavigation) {
                    Section {
                        NavigationLink(tag: .home, selection: $selectedNavigation) {
                            HomeView(wallpaperManager: wallpaperManager)
                        } label: {
                            Label("Home", systemImage: "house")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        
                        NavigationLink(tag: .playlists, selection: $selectedNavigation) {
                            PlaylistsView(wallpaperManager: wallpaperManager)
                        } label: {
                            Label("Playlists", systemImage: "play.square.stack")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        
                        NavigationLink(tag: .allPhotos, selection: $selectedNavigation) {
                            AllPhotosView(wallpaperManager: wallpaperManager)
                        } label: {
                            Label("All Photos", systemImage: "photo.on.rectangle")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        
                        NavigationLink(tag: .settings, selection: $selectedNavigation) {
                            SettingsView(wallpaperManager: wallpaperManager)
                        } label: {
                            Label("Settings", systemImage: "gear")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 150, maxWidth: 200)
            }
            
            // Default content view
            HomeView(wallpaperManager: wallpaperManager)
            
            // Bottom Tab Bar
            VStack {
                Spacer()
                HStack {
                    Button { selectedNavigation = .home } label: {
                        Label("Home", systemImage: "house")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button { selectedNavigation = .playlists } label: {
                        Label("Playlists", systemImage: "play.square.stack")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button { selectedNavigation = .settings } label: {
                        Label("Settings", systemImage: "gear")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            
            // Update preview references
            if let playlist = wallpaperManager.playlists.first,
               let firstWallpaper = playlist.wallpapers.first,
               let fileURL = firstWallpaper.fileURL,
               let image = NSImage(contentsOf: fileURL) {
                PlaylistPreview(
                    playlist: playlist,
                    previewData: PlaylistPreviewData(
                        id: playlist.id,
                        previewImages: [image],
                        isActive: playlist.id == wallpaperManager.activePlaylistId
                    )
                )
            }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .frame(width: 650, height: 400)  // Set fixed frame size
    }
    
    private var wallpaperPreviewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let url = URL(string: selectedImagePath),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 120)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading) {
                    Text(selectedImagePath.split(separator: "/").last ?? "")
                        .font(.headline)
                    
                    Picker("Display Mode", selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(PopUpButtonPickerStyle())
                    
                    Toggle("Show on all Spaces", isOn: $showOnAllSpaces)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var displayOptionsView: some View {
        VStack(alignment: .leading) {
            Picker("Display Mode", selection: $wallpaperManager.displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Toggle("Show on all Spaces", isOn: $wallpaperManager.showOnAllSpaces)
        }
    }
    
    private var displaySelectionView: some View {
        Picker("Display", selection: $wallpaperManager.selectedScreen) {
            Text("All Displays").tag(Optional<NSScreen>.none)
            ForEach(NSScreen.screens, id: \.self) { screen in
                Text("Display \(NSScreen.screens.firstIndex(of: screen)! + 1)")
                    .tag(Optional(screen))
            }
        }
    }
    
    private var wallpaperCollectionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 100), spacing: 12)
        ], spacing: 12) {
            ForEach(wallpapers) { wallpaper in
                wallpaperThumbnail(wallpaper)
            }
            
            addPhotoButton
        }
        .padding(.vertical)
    }
    
    private func wallpaperThumbnail(_ wallpaper: WallpaperItem) -> some View {
        Button(action: {
            selectedImagePath = wallpaper.path
            if let url = wallpaper.fileURL {
                try? wallpaperManager.setWallpaper(from: url)
            }
        }) {
            if let url = wallpaper.fileURL,
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 60)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(wallpaper.isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var addPhotoButton: some View {
        Button(action: addWallpapers) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                Text("Add Photo")
                    .font(.caption)
            }
            .frame(width: 100, height: 60)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rotationSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Auto-rotate wallpapers", isOn: $isRotating)
                .onChange(of: isRotating) { newValue in
                    if newValue {
                        wallpaperManager.startRotation(interval: rotationInterval)
                    } else {
                        wallpaperManager.stopRotation()
                    }
                }
            
            if isRotating {
                HStack {
                    Text("Rotation Interval:")
                    Slider(value: $rotationInterval, in: 10...3600, step: 10)
                    Text("\(Int(rotationInterval))s")
                }
            }
        }
    }
    
    private func addWallpapers() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.image]
        
        if openPanel.runModal() == .OK {
            let urls = openPanel.urls
            wallpaperManager.addWallpapers(urls)
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
    }
}

// MARK: - Subviews
struct PlaylistView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    let playlist: Playlist
    let onEdit: (Playlist) -> Void
    
    @State private var isExpanded: Bool = true
    @State private var showingDeleteAlert = false
    @State private var draggedItemId: UUID?
    @State private var dropTargetIndex: Int?
    @State private var showingImagePicker = false
    @State private var rotationInterval: Double = 60
    
    private var wallpaperGridItem: some View {
        ForEach(Array(playlist.wallpapers.enumerated()), id: \.element.id) { index, wallpaper in
            if let url = wallpaper.fileURL,
               let image = NSImage(contentsOf: url) {
                wallpaperThumbnail(image: image, wallpaper: wallpaper, index: index)
            }
        }
    }
    
    private func wallpaperThumbnail(image: NSImage, wallpaper: WallpaperItem, index: Int) -> some View {
        ZStack {
            if dropTargetIndex == index {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2)
                    .frame(height: 60)
                    .position(x: 0, y: 30)
            }
            
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(6)
                .onTapGesture {
                    guard let url = wallpaper.fileURL else { return }
                    try? wallpaperManager.setWallpaper(from: url)
                    wallpaperManager.setActivePlaylist(playlist.id)
                }
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.dragLink.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { _ in
                            NSCursor.closedHand.push()
                        }
                        .onEnded { _ in
                            NSCursor.pop()
                        }
                )
                .draggable(wallpaper.id.uuidString) {
                    draggedItemId = wallpaper.id
                    NSCursor.closedHand.push()
                    return Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                }
            .opacity(draggedItemId == wallpaper.id ? 0.5 : 1.0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                Text(playlist.name)
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if wallpaperManager.isRotating {
                            wallpaperManager.stopRotation()
                        } else {
                            wallpaperManager.startPlaylistRotation(playlistId: playlist.id, interval: 60)
                        }
                    }) {
                        Image(systemName: wallpaperManager.isRotating ? "pause.circle" : "play.circle")
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
                        Picker("Playback Mode", selection: Binding(
                            get: { playlist.playbackMode },
                            set: { newValue in
                                try? wallpaperManager.updatePlaylistPlaybackMode(playlist.id, newValue)
                            }
                        )) {
                            Text("Sequential").tag(PlaybackMode.sequential)
                            Text("Random").tag(PlaybackMode.random)
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                    
                    Button(action: { onEdit(playlist) }) {
                        Image(systemName: "pencil")
                    }
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                    }
                }
            }
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(playlist.wallpapers) { wallpaper in
                        if let url = wallpaper.fileURL,
                           let image = NSImage(contentsOf: url) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .opacity(draggedItemId == wallpaper.id ? 0.5 : 1.0)
                                .draggable(wallpaper.id.uuidString) {
                                    draggedItemId = wallpaper.id
                                    return Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(4)
                                }
                        }
                    }
                }
                .padding(.top, 8)
                .dropDestination(for: String.self) { items, location in
                    guard let droppedId = items.first,
                          let sourceIndex = playlist.wallpapers.firstIndex(where: { $0.id.uuidString == droppedId }) else {
                        return false
                    }
                    
                    let targetIndex = dropTargetIndex ?? playlist.wallpapers.count
                    try? wallpaperManager.moveWallpaper(
                        from: playlist,
                        at: sourceIndex,
                        to: playlist,
                        at: targetIndex
                    )
                    
                    dropTargetIndex = nil
                    draggedItemId = nil
                    return true
                } isTargeted: { isTargeted in
                    dropTargetIndex = isTargeted ? playlist.wallpapers.count : nil
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        let wallpaper = WallpaperItem(
                            id: UUID(),
                            path: url.absoluteString,
                            name: url.lastPathComponent,
                            isSelected: false
                        )
                        try? wallpaperManager.addWallpapersToPlaylist(
                            [wallpaper],
                            playlistId: playlist.id
                        )
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                print("Error selecting images: \(error.localizedDescription)")
            }
        }
        .alert("Delete Playlist", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? wallpaperManager.deletePlaylist(id: playlist.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this playlist? This action cannot be undone.")
        }
    }
    
    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) seconds"
        } else if seconds < 3600 {
            return "\(seconds / 60) minutes"
        } else {
            return "\(seconds / 3600) hours"
        }
    }
    
    private func contextMenu(for wallpaper: WallpaperItem) -> some View {
        Group {
            Button(action: {
                guard let url = wallpaper.fileURL else { return }
                try? wallpaperManager.setWallpaper(from: url)
            }) {
                Label("Set as Wallpaper", systemImage: "photo")
            }
            
            Button(action: {
                guard let url = wallpaper.fileURL else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }) {
                Label("Show in Finder", systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                guard let url = wallpaper.fileURL else { return }
                wallpaperManager.removeWallpapers([url])
            }) {
                Label("Remove from Playlist", systemImage: "trash")
            }
        }
    }
}

struct PlaylistDropDelegate: DropDelegate {
    let playlist: Playlist
    let wallpaperManager: WallpaperManager
    @Binding var draggedItemId: UUID?
    @Binding var dropTargetIndex: Int?
    
    func validateDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Calculate target index based on drop location
        let gridItemWidth: CGFloat = 68 // 60 + 8 spacing
        let row = Int(info.location.y / gridItemWidth)
        let col = Int(info.location.x / gridItemWidth)
        let itemsPerRow = Int(info.location.x / gridItemWidth)
        let targetIndex = (row * itemsPerRow) + col
        
        dropTargetIndex = min(targetIndex, playlist.wallpapers.count)
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        dropTargetIndex = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let targetIndex = dropTargetIndex ?? playlist.wallpapers.count
        dropTargetIndex = nil
        draggedItemId = nil
        
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
            guard let data = data as? Data,
                  let idString = String(data: data, encoding: .utf8) else {
                return
            }
            
            DispatchQueue.main.async {
                for sourcePlaylist in wallpaperManager.playlists {
                    if let sourceIndex = sourcePlaylist.wallpapers.firstIndex(where: { $0.id.uuidString == idString }) {
                        try? wallpaperManager.moveWallpaper(
                            from: sourcePlaylist,
                            at: sourceIndex,
                            to: playlist,
                            at: targetIndex
                        )
                        break
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Extensions
extension MenuBarView {
    private func startEditingPlaylist(_ playlist: Playlist) {
        editingPlaylistId = playlist.id
        editingPlaylistName = playlist.name
    }
    
    private var addPlaylistButton: some View {
        Button(action: createNewPlaylist) {
            Label("New Playlist", systemImage: "plus")
        }
    }
    
    private func createNewPlaylist() {
        let alert = NSAlert()
        alert.messageText = "Create New Playlist"
        alert.informativeText = "Enter a name for your new playlist:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = ""
        input.placeholderString = "Playlist Name"
        alert.accessoryView = input
        
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    let playlistName = input.stringValue.isEmpty ? "New Playlist" : input.stringValue
                    do {
                        try wallpaperManager.createPlaylist(name: playlistName)
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
}

// Add this new view for playlist creation
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallpaperManager: WallpaperManager
    
    @State private var playlistName: String = ""
    @State private var duration: Double = 60
    @State private var playbackMode: PlaybackMode = .sequential
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
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

// Update PlaylistsView to include the create button
struct PlaylistsView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    @State private var showingCreateSheet = false
    @State private var editingPlaylist: Playlist? = nil
    
    var body: some View {
        VStack {
            HStack {
                Text("Playlists")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingCreateSheet = true }) {
                    Label("New Playlist", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(wallpaperManager.playlists) { playlist in
                        PlaylistView(
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
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePlaylistView(wallpaperManager: wallpaperManager)
        }
        .sheet(item: $editingPlaylist) { playlist in
            EditPlaylistView(wallpaperManager: wallpaperManager, playlist: playlist)
        }
    }
}

// Add EditPlaylistView
struct EditPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallpaperManager: WallpaperManager
    let playlist: Playlist
    
    @State private var playlistName: String
    @State private var duration: Double
    @State private var playbackMode: PlaybackMode
    @State private var showError = false
    @State private var errorMessage = ""
    
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
            Text(errorMessage)
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

// Separate view for All Photos
struct AllPhotosView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(wallpaperManager.allWallpapers) { wallpaper in
                    WallpaperThumbnailView(wallpaper: wallpaper)
                }
            }
            .padding()
        }
    }
}

// Separate view for Settings
struct SettingsView: View {
    @StateObject var wallpaperManager: WallpaperManager = WallpaperManager.shared
    @State private var rotationInterval: Double = 60
    @State private var isRotating: Bool = false
    
    var body: some View {
        Form {
            Toggle("Auto-rotate wallpapers", isOn: $isRotating)
                .onChange(of: isRotating) { newValue in
                    if newValue {
                        wallpaperManager.startRotation(interval: rotationInterval)
                    } else {
                        wallpaperManager.stopRotation()
                    }
                }
            
            if isRotating {
                VStack(alignment: .leading) {
                    Text("Change every: \(Int(rotationInterval)) seconds")
                    Slider(value: $rotationInterval, in: 10...3600, step: 10)
                }
            }
        }
        .padding()
    }
}

struct WallpaperThumbnailView: View {
    let wallpaper: WallpaperItem
    @StateObject var wallpaperManager: WallpaperManager = WallpaperManager.shared
    
    var body: some View {
        if let url = wallpaper.fileURL,
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(6)
                .onTapGesture {
                    try? wallpaperManager.setWallpaper(from: url)
                }
                .contextMenu {
                    Button(action: {
                        try? wallpaperManager.setWallpaper(from: url)
                    }) {
                        Label("Set as Wallpaper", systemImage: "photo")
                    }
                    
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.opacity(0.5),
                               lineWidth: wallpaperManager.currentWallpaperPath == url.absoluteString ? 2 : 0)
                )
        }
    }
}

// Add HomeView
struct HomeView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Current Wallpaper Preview with Settings
                if let (currentURL, currentScreen) = wallpaperManager.getCurrentSystemWallpaper() {
                    HStack(alignment: .top, spacing: 20) {
                        // Left side - Wallpaper preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Wallpaper")
                                .font(.headline)
                            
                            if let image = NSImage(contentsOf: currentURL) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right side - Display settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Display Settings")
                                .font(.headline)
                            
                            Picker("Display Mode", selection: $wallpaperManager.displayMode) {
                                ForEach(DisplayMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(PopUpButtonPickerStyle())
                            .frame(maxWidth: 200)
                            
                            Toggle("Show on all Spaces", isOn: $wallpaperManager.showOnAllSpaces)
                                .padding(.vertical, 4)
                            
                            Picker("Display", selection: $wallpaperManager.selectedScreen) {
                                Text("All Displays").tag(Optional<NSScreen>.none)
                                ForEach(NSScreen.screens, id: \.self) { screen in
                                    Text("Display \(NSScreen.screens.firstIndex(of: screen)! + 1)")
                                        .tag(Optional(screen))
                                }
                            }
                            .pickerStyle(PopUpButtonPickerStyle())
                            .frame(maxWidth: 200)
                        }
                        .frame(width: 200)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        }
    }
}

// Add extension for NSImage dimensions
extension NSImage {
    var dimensions: (width: Int, height: Int)? {
        guard let firstRepresentation = representations.first else { return nil }
        return (Int(firstRepresentation.pixelsWide), Int(firstRepresentation.pixelsHigh))
    }
}

