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

struct Slideshow: Identifiable, Codable {
    let id: UUID
    var name: String
    var wallpapers: [WallpaperItem]
    var playbackMode: PlaybackMode
    
    init(id: UUID = UUID(), name: String, wallpapers: [WallpaperItem] = [], playbackMode: PlaybackMode = .sequential) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.playbackMode = playbackMode
    }
}

struct SlideshowPreview: View {
    let image: NSImage
    let name: String
    let wallpaperCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            Text(name)
                .font(.caption)
                .lineLimit(1)
            
            Text("\(wallpaperCount) photos")
                .font(.caption2)
                .foregroundColor(.secondary)
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
    @State private var slideshows: [Slideshow] = []
    @State private var editingSlideshowId: UUID?
    @State private var editingSlideshowName: String = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var slideshowPreviews: [UUID: SlideshowPreview] = [:]
    
    enum NavigationItem: String, Hashable {
        case home = "Home"
        case slideshows = "Slideshows"
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
                    
                    NavigationLink(tag: .slideshows, selection: $selectedNavigation) {
                        SlideshowsView(wallpaperManager: wallpaperManager)
                    } label: {
                        Label("Slideshows", systemImage: "play.square.stack")
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
            
            // Update preview references
            if let slideshow = wallpaperManager.slideshows.first,
               let firstWallpaper = slideshow.wallpapers.first,
               let fileURL = firstWallpaper.fileURL,
               let image = NSImage(contentsOf: fileURL) {
                SlideshowPreview(
                    image: image,
                    name: slideshow.name,
                    wallpaperCount: slideshow.wallpapers.count
                )
            }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .frame(width: 800, height: 500)  // Set fixed frame size
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change every: \(Int(rotationInterval)) seconds")
                        .font(.caption)
                    Slider(value: $rotationInterval, in: 10...3600, step: 10)
                }
            }
        }
    }
    
    private func addWallpapers() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    for url in panel.urls {
                        if url.startAccessingSecurityScopedResource() {
                            let wallpaper = WallpaperItem(
                                id: UUID(),
                                path: url.absoluteString,
                                name: url.lastPathComponent,
                                isSelected: false
                            )
                            // Add to the first slideshow if none exists
                            if let firstSlideshow = wallpaperManager.slideshows.first {
                                try? wallpaperManager.addWallpapersToSlideshow(
                                    [wallpaper],
                                    slideshowId: firstSlideshow.id
                                )
                            }
                            url.stopAccessingSecurityScopedResource()
                        }
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
struct SlideshowView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    let slideshow: Slideshow
    let onEdit: (Slideshow) -> Void
    
    @State private var isExpanded: Bool = true
    @State private var showingDeleteAlert = false
    @State private var draggedItemId: UUID?
    @State private var dropTargetIndex: Int?
    @State private var showingImagePicker = false
    @State private var rotationInterval: Double = 60
    
    private var wallpaperGridItem: some View {
        ForEach(Array(slideshow.wallpapers.enumerated()), id: \.element.id) { index, wallpaper in
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
                }
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.dragLink.push()  // Show drag cursor on hover
                    } else {
                        NSCursor.pop()  // Restore default cursor
                    }
                }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { _ in
                            NSCursor.closedHand.push()  // Show grabbing cursor while dragging
                        }
                        .onEnded { _ in
                            NSCursor.pop()  // Restore default cursor when drag ends
                        }
                )
                .contextMenu {
                    contextMenu(for: wallpaper)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.opacity(0.5), 
                               lineWidth: wallpaper.fileURL?.absoluteString == wallpaperManager.currentWallpaperPath ? 2 : 0)
                )
                .opacity(draggedItemId == wallpaper.id ? 0.5 : 1.0)
                .draggable(wallpaper.id.uuidString) {
                    draggedItemId = wallpaper.id
                    NSCursor.closedHand.push()  // Show grabbing cursor when drag starts
                    return Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                Text(slideshow.name)
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
                            wallpaperManager.startSlideshowRotation(slideshow, interval: 60)
                        }
                    }) {
                        Image(systemName: wallpaperManager.isRotating ? "pause.circle" : "play.circle")
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
                        Picker("Playback Mode", selection: Binding(
                            get: { slideshow.playbackMode },
                            set: { newValue in
                                wallpaperManager.updateSlideshowPlaybackMode(slideshow.id, mode: newValue)
                            }
                        )) {
                            Text("Sequential").tag(PlaybackMode.sequential)
                            Text("Random").tag(PlaybackMode.random)
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                    
                    Button(action: { onEdit(slideshow) }) {
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    wallpaperGridItem
                }
                .onDrop(of: [.text], delegate: SlideshowDropDelegate(
                    slideshow: slideshow,
                    wallpaperManager: wallpaperManager,
                    draggedItemId: $draggedItemId,
                    dropTargetIndex: $dropTargetIndex
                ))
            }
        }
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
                        try? wallpaperManager.addWallpapersToSlideshow(
                            [wallpaper],
                            slideshowId: slideshow.id
                        )
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                print("Error selecting images: \(error.localizedDescription)")
            }
        }
        .alert("Delete Slideshow", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? wallpaperManager.deleteSlideshow(id: slideshow.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this slideshow? This action cannot be undone.")
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
                Label("Remove from Slideshow", systemImage: "trash")
            }
        }
    }
}

struct SlideshowDropDelegate: DropDelegate {
    let slideshow: Slideshow
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
        
        dropTargetIndex = min(targetIndex, slideshow.wallpapers.count)
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        dropTargetIndex = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let targetIndex = dropTargetIndex ?? slideshow.wallpapers.count
        dropTargetIndex = nil
        draggedItemId = nil
        
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
            guard let data = data as? Data,
                  let idString = String(data: data, encoding: .utf8) else {
                return
            }
            
            DispatchQueue.main.async {
                for sourceSlideshow in wallpaperManager.slideshows {
                    if let sourceIndex = sourceSlideshow.wallpapers.firstIndex(where: { $0.id.uuidString == idString }) {
                        wallpaperManager.moveWallpaper(from: sourceSlideshow, at: sourceIndex, to: slideshow, at: targetIndex)
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
    private func startEditingSlideshow(_ slideshow: Slideshow) {
        editingSlideshowId = slideshow.id
        editingSlideshowName = slideshow.name
    }
    
    private var addSlideshowButton: some View {
        Button(action: createNewSlideshow) {
            Label("New Slideshow", systemImage: "plus")
        }
    }
    
    private func createNewSlideshow() {
        let alert = NSAlert()
        alert.messageText = "Create New Slideshow"
        alert.informativeText = "Enter a name for your new slideshow:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = ""
        input.placeholderString = "Slideshow Name"
        alert.accessoryView = input
        
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    let slideshowName = input.stringValue.isEmpty ? "New Slideshow" : input.stringValue
                    do {
                        try wallpaperManager.createSlideshow(name: slideshowName)
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
}

// Add this new view for slideshow creation
struct CreateSlideshowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallpaperManager: WallpaperManager
    
    @State private var slideshowName: String = ""
    @State private var duration: Double = 60
    @State private var playbackMode: PlaybackMode = .sequential
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Slideshow")
                .font(.headline)
            
            TextField("Slideshow Name", text: $slideshowName)
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
                    createSlideshow()
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
    
    private func createSlideshow() {
        guard !slideshowName.isEmpty else {
            showError = true
            errorMessage = "Please enter a slideshow name"
            return
        }
        
        do {
            try wallpaperManager.createSlideshow(name: slideshowName)
            dismiss()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

// Update SlideshowsView to include the create button
struct SlideshowsView: View {
    @ObservedObject var wallpaperManager: WallpaperManager
    @State private var showingCreateSheet = false
    @State private var editingSlideshow: Slideshow? = nil
    
    var body: some View {
        VStack {
            HStack {
                Text("Slideshows")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingCreateSheet = true }) {
                    Label("New Slideshow", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(wallpaperManager.slideshows) { slideshow in
                        SlideshowView(
                            wallpaperManager: wallpaperManager,
                            slideshow: slideshow,
                            onEdit: { slideshow in
                                editingSlideshow = slideshow
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateSlideshowView(wallpaperManager: wallpaperManager)
        }
        .sheet(item: $editingSlideshow) { slideshow in
            EditSlideshowView(wallpaperManager: wallpaperManager, slideshow: slideshow)
        }
    }
}

// Add EditSlideshowView
struct EditSlideshowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var wallpaperManager: WallpaperManager
    let slideshow: Slideshow
    
    @State private var slideshowName: String
    @State private var duration: Double
    @State private var playbackMode: PlaybackMode
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(wallpaperManager: WallpaperManager, slideshow: Slideshow) {
        self.wallpaperManager = wallpaperManager
        self.slideshow = slideshow
        _slideshowName = State(initialValue: slideshow.name)
        _duration = State(initialValue: 60)
        _playbackMode = State(initialValue: slideshow.playbackMode)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Slideshow")
                .font(.headline)
            
            TextField("Slideshow Name", text: $slideshowName)
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
        guard !slideshowName.isEmpty else {
            showError = true
            errorMessage = "Please enter a slideshow name"
            return
        }
        
        do {
            try wallpaperManager.renameSlideshow(id: slideshow.id, newName: slideshowName)
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
                                .frame(maxWidth: .infinity)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
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
