import SwiftUI

struct WallpaperItem: Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    var isSelected: Bool
    
    init(id: UUID = UUID(), path: String, name: String, isSelected: Bool = false) {
        self.id = id
        self.path = path
        self.name = name
        self.isSelected = isSelected
    }
    
    enum CodingKeys: String, CodingKey {
        case id, path, name
        // Don't persist selection state
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        name = try container.decode(String.self, forKey: .name)
        isSelected = false
    }
    
    var fileURL: URL? {
        if path.hasPrefix("file://") {
            return URL(string: path)
        } else {
            return URL(fileURLWithPath: path)
        }
    }
}

struct MenuBarView: View {
    @State public var selectedImagePath: String = ""
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
    @State private var playlistPreviews: [UUID: PlaylistPreview] = [:]
    
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    init() {
        _wallpaperManager = StateObject(wrappedValue: WallpaperManager.shared)
        // Set initial wallpaper
        if let (wallpaperURL, _) = WallpaperManager.shared.getCurrentSystemWallpaper() {
            _selectedImagePath = State(initialValue: wallpaperURL.absoluteString)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Header Section
                Section {
                    if !selectedImagePath.isEmpty {
                        wallpaperPreviewHeader
                    }
                }
                
                // Display Options Section
                Section {
                    displayOptionsView
                }
                
                // Playlists Section
                Section(header: HStack {
                    Text("Playlists")
                    Spacer()
                    addPlaylistButton
                }) {
                    ForEach(wallpaperManager.loadedPlaylists) { playlist in
                        PlaylistView(wallpaperManager: wallpaperManager, playlist: playlist, onEdit: { startEditingPlaylist($0) })
                    }
                }
                
                // Your Photos section becomes "All Photos"
                Section(header: Text("All Photos")) {
                    wallpaperCollectionGrid
                }
                
                // Rotation Settings Section
                Section(header: Text("Rotation Settings")) {
                    rotationSettingsView
                }
            }
            .listStyle(InsetListStyle())
            .frame(width: 480, height: 640)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onReceive(wallpaperManager.$currentWallpaperPath) { newPath in
            if !newPath.isEmpty {
                selectedImagePath = newPath
            }
        }
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
            Picker("Display", selection: $selectedDisplay) {
                Text("All Displays").tag("All Displays")
                // Add additional displays as needed
            }
            .pickerStyle(PopUpButtonPickerStyle())
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
        Button(action: selectImage) {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change every: \(Int(rotationInterval)) seconds")
                        .font(.caption)
                    Slider(value: $rotationInterval, in: 10...3600, step: 10)
                }
            }
        }
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    for url in panel.urls {
                        let name = url.lastPathComponent
                        let wallpaper = WallpaperItem(
                            id: UUID(),
                            path: url.absoluteString,
                            name: name,
                            isSelected: false
                        )
                        wallpapers.append(wallpaper)
                        wallpaperManager.addWallpapers([url])
                    }
                    
                    if selectedImagePath.isEmpty && !wallpapers.isEmpty {
                        selectedImagePath = wallpapers[0].path
                    }
                }
            }
        }
    }
}

// MARK: - Subviews
struct PlaylistView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    let playlist: Playlist
    let onEdit: (Playlist) -> Void
    @State private var isExpanded: Bool = false
    @State private var showingDeleteAlert = false
    
    private struct IntervalOption: Identifiable {
        let id = UUID()
        let name: String
        let seconds: TimeInterval
    }
    
    private let intervalOptions = [
        IntervalOption(name: "60 seconds", seconds: 60),
        IntervalOption(name: "3 minutes", seconds: 180),
        IntervalOption(name: "5 minutes", seconds: 300),
        IntervalOption(name: "10 minutes", seconds: 600),
        IntervalOption(name: "30 minutes", seconds: 1800),
        IntervalOption(name: "60 minutes", seconds: 3600),
        IntervalOption(name: "3 hours", seconds: 10800)
    ]
    
    // Break up the view into smaller components
    private var playlistHeader: some View {
        Text(playlist.name)
            .font(.headline)
    }
    
    private var playPauseButton: some View {
        Button(action: {
            if wallpaperManager.isPlaylistRotating(playlist.id) {
                wallpaperManager.stopPlaylistRotation()
            } else {
                // Start with current interval or default to 60 seconds
                let interval = wallpaperManager.getCurrentRotationInterval(for: playlist.id)
                wallpaperManager.startPlaylistRotation(playlist, interval: interval)
                try? wallpaperManager.rotatePlaylist() // Immediately show first wallpaper
            }
        }) {
            Image(systemName: wallpaperManager.isPlaylistRotating(playlist.id) ? "pause.circle.fill" : "play.circle.fill")
                .foregroundColor(wallpaperManager.isPlaylistRotating(playlist.id) ? .red : .green)
                .imageScale(.large)
        }
    }
    
    private var intervalMenu: some View {
        Menu {
            ForEach(intervalOptions) { option in
                Button {
                    if wallpaperManager.isPlaylistRotating(playlist.id) {
                        wallpaperManager.startPlaylistRotation(playlist, interval: option.seconds)
                    }
                } label: {
                    HStack {
                        Text(option.name)
                        if wallpaperManager.getCurrentRotationInterval(for: playlist.id) == option.seconds {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "clock")
                Text(getCurrentIntervalText())
                    .foregroundColor(.gray)
            }
        }
        .disabled(!wallpaperManager.isPlaylistRotating(playlist.id))
    }
    
    private func getCurrentIntervalText() -> String {
        let interval = wallpaperManager.getCurrentRotationInterval(for: playlist.id)
        return intervalOptions.first { $0.seconds == interval }?.name ?? "60 seconds"
    }
    
    private var optionsMenu: some View {
        Menu {
            Button(action: { onEdit(playlist) }) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: { addPhotosToPlaylist(playlist) }) {
                Label("Add Photos", systemImage: "plus.square")
            }
            
            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.gray)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                playlistHeader
                Spacer()
                playPauseButton
                intervalMenu
                optionsMenu
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    ForEach(playlist.wallpapers) { wallpaper in
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue.opacity(0.5), lineWidth: wallpaperManager.currentWallpaperPath == url.absoluteString ? 2 : 0)
                                )
                        }
                    }
                    
                    Button(action: { addPhotosToPlaylist(playlist) }) {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                            Text("Add")
                                .font(.caption)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
        .alert("Delete Playlist", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePlaylist(playlist)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this playlist?")
        }
    }
    
    private func addPhotosToPlaylist(_ playlist: Playlist) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    let newWallpapers = panel.urls.map { url in
                        WallpaperItem(
                            id: UUID(),
                            path: url.absoluteString,
                            name: url.lastPathComponent,
                            isSelected: false
                        )
                    }
                    
                    do {
                        try WallpaperManager.shared.addWallpapersToPlaylist(newWallpapers, playlistId: playlist.id)
                    } catch {
                        print("Error adding wallpapers: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func deletePlaylist(_ playlist: Playlist) {
        do {
            try WallpaperManager.shared.deletePlaylist(id: playlist.id)
        } catch {
            // Handle error through environment object or callback
            print("Error deleting playlist: \(error.localizedDescription)")
        }
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
