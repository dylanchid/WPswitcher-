import SwiftUI
import UniformTypeIdentifiers

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
    @State private var playlistPreviews: [UUID: PlaylistPreview] = [:]
    
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
            // Sidebar
            List(selection: $selectedNavigation) {
                Section {
                    NavigationLink(tag: .home, selection: $selectedNavigation) {
                        HomeView(wallpaperManager: wallpaperManager)
                    } label: {
                        Label("Home", systemImage: "house")
                    }
                    
                    NavigationLink(tag: .playlists, selection: $selectedNavigation) {
                        PlaylistsView(wallpaperManager: wallpaperManager)
                    } label: {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    
                    NavigationLink(tag: .allPhotos, selection: $selectedNavigation) {
                        AllPhotosView(wallpaperManager: wallpaperManager)
                    } label: {
                        Label("All Photos", systemImage: "photo.on.rectangle")
                    }
                    
                    NavigationLink(tag: .settings, selection: $selectedNavigation) {
                        SettingsView(wallpaperManager: wallpaperManager)
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150, maxWidth: 200)
            
            // Default content view
            HomeView(wallpaperManager: wallpaperManager)
        }
        .frame(width: 730, height: 400)
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
    @State private var draggedItemId: UUID?
    @State private var dropTargetIndex: Int?
    @State private var selectedInterval: IntervalOption?
    
    private struct IntervalOption: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let seconds: TimeInterval
        
        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        // Implement Equatable (required by Hashable)
        static func == (lhs: IntervalOption, rhs: IntervalOption) -> Bool {
            return lhs.id == rhs.id
        }
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
    
    private func contextMenu(for wallpaper: WallpaperItem) -> some View {
        Menu {
            Button(action: {
                if let url = wallpaper.fileURL {
                    try? wallpaperManager.setWallpaper(from: url)
                }
            }) {
                Label("Set as Wallpaper", systemImage: "photo")
            }
            
            Button(action: {
                if let url = wallpaper.fileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }) {
                Label("Show in Finder", systemImage: "folder")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                if let url = wallpaper.fileURL {
                    wallpaperManager.removeWallpapers([url])
                }
            }) {
                Label("Remove from Playlist", systemImage: "trash")
            }
        } label: {
            EmptyView()
        }
    }
    
    private func wallpaperItemView(wallpaper: WallpaperItem, index: Int) -> some View {
        Group {
            if let url = wallpaper.fileURL,
               let image = NSImage(contentsOf: url) {
                ZStack {
                    // Show insertion indicator
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
                            try? wallpaperManager.setWallpaper(from: url)
                        }
                        .contextMenu {
                            contextMenu(for: wallpaper)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.5), 
                                       lineWidth: wallpaperManager.currentWallpaperPath == url.absoluteString ? 2 : 0)
                        )
                        .opacity(draggedItemId == wallpaper.id ? 0.5 : 1.0)
                        .draggable(wallpaper.id.uuidString) {
                            DispatchQueue.main.async {
                                draggedItemId = wallpaper.id
                            }
                            return Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30)
                                .cornerRadius(4)
                        }
                }
                .animation(.easeInOut(duration: 0.2), value: dropTargetIndex)
            }
        }
    }
    
    var playlistGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
            ForEach(Array(playlist.wallpapers.enumerated()), id: \.element.id) { index, wallpaper in
                wallpaperItemView(wallpaper: wallpaper, index: index)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: dropTargetIndex)
        .onDrop(of: [.text], delegate: PlaylistDropDelegate(
            playlist: playlist,
            wallpaperManager: wallpaperManager,
            draggedItemId: $draggedItemId,
            dropTargetIndex: $dropTargetIndex
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                playlistHeader
                Spacer()
                
                // Playback Mode Menu
                Menu {
                    ForEach(PlaybackMode.allCases, id: \.self) { mode in
                        Button(action: {
                            wallpaperManager.updatePlaylistPlaybackMode(playlist.id, mode: mode)
                        }) {
                            HStack {
                                Image(systemName: mode == .sequential ? "arrow.right" : "shuffle")
                                Text(mode.rawValue)
                                if playlist.playbackMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: playlist.playbackMode == .sequential ? "arrow.right" : "shuffle")
                        .foregroundColor(.blue)
                }
                
                // Interval Picker
                Picker("", selection: $selectedInterval) {
                    ForEach(intervalOptions) { option in
                        Text(option.name).tag(Optional(option))
                    }
                }
                .frame(width: 120)
                
                // Existing buttons
                optionsMenu
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding(.horizontal)
            
            if isExpanded {
                playlistGridView
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
                  let idString = String(data: data, encoding: .utf8),
                  let sourceId = UUID(uuidString: idString) else {
                return
            }
            
            DispatchQueue.main.async {
                for sourcePlaylist in wallpaperManager.playlists {
                    if let sourceIndex = sourcePlaylist.wallpapers.firstIndex(where: { $0.id.uuidString == idString }) {
                        wallpaperManager.moveWallpaper(from: sourcePlaylist, at: sourceIndex, to: playlist, at: targetIndex)
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

// Separate view for Playlists
struct PlaylistsView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(wallpaperManager.playlists) { playlist in
                    PlaylistView(
                        wallpaperManager: wallpaperManager, 
                        playlist: playlist,
                        onEdit: { playlist in
                            // Handle edit action
                            startEditingPlaylist(playlist)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private func startEditingPlaylist(_ playlist: Playlist) {
        // Implementation of playlist editing
        print("Editing playlist: \(playlist.name)")
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
                if let (currentURL, currentImage) = wallpaperManager.getCurrentSystemWallpaper() {
                    HStack(alignment: .top, spacing: 20) {
                        // Left side - Wallpaper preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Wallpaper")
                                .font(.headline)
                            
                            Image(nsImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .frame(maxWidth: 400)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            
                            // Wallpaper Info
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentURL.lastPathComponent)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        NSWorkspace.shared.activateFileViewerSelecting([currentURL])
                                    }) {
                                        Label("Show in Finder", systemImage: "folder")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.link)
                                }
                                
                                Spacer()
                                
                                if let dimensions = NSImage(contentsOf: currentURL)?.dimensions {
                                    Text("\(dimensions.width) × \(dimensions.height)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
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
                        }
                        .frame(width: 250)
                    }
                    .padding()
                }
                
                // Empty space for future content
                Spacer()
                    .frame(height: 200)
            }
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
