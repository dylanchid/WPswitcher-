import AppKit
import Foundation
import SwiftUI

// MARK: - WallpaperManager Class
class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    @Published private(set) var playlists: [Playlist] = []
    @Published private var wallpapers: [WallpaperItem] = []
    
    // MARK: - Properties
    private var currentIndex = 0
    private var timer: Timer?
    @Published var displayMode: DisplayMode = .fillScreen
    @Published var selectedScreen: NSScreen?
    @Published var showOnAllSpaces: Bool = true
    private var playlistsKey = "savedPlaylists"
    
    // UserDefaults keys
    private let wallpapersKey = "savedWallpapers"
    private let displayModeKey = "displayMode"
    private let showOnAllSpacesKey = "showOnAllSpaces"
    private let currentIndexKey = "currentIndex"
    private let maxPlaylists = 20
    
    private var fileMonitor: FileMonitor?
    @Published var activePlaylistId: UUID?
    private let activePlaylistKey = "activePlaylist"
    
    @Published private var activePlaylistRotating: Bool = false
    private var playlistRotationInterval: TimeInterval = 60
    @Published private(set) var currentWallpaperPath: String = ""
    private var usedRandomIndices: Set<Int> = []
    @Published var currentError: ErrorAlert?
    @Published var isRotating: Bool = false
    @Published var rotationInterval: TimeInterval = 60
    
    // MARK: - Initialization
    private init() {
        fileMonitor = FileMonitor { [weak self] in
            self?.handleDeletedWallpaper()
        }
        loadSavedData()
    }
    
    // MARK: - Public Methods
    
    /// Sets wallpaper for specific screen with options
    func setWallpaper(from url: URL, for screen: NSScreen? = NSScreen.main, mode: DisplayMode? = nil) throws {
        guard let screen = screen else {
            throw WallpaperError.invalidScreen
        }
        
        let workspace = NSWorkspace.shared
        let options = (mode ?? displayMode).nsWorkspaceOptions
        
        do {
            try workspace.setDesktopImageURL(url, for: screen, options: options)
            currentWallpaperPath = url.absoluteString
            
            // Update for all screens if needed
            if showOnAllSpaces {
                for additionalScreen in NSScreen.screens where additionalScreen != screen {
                    try workspace.setDesktopImageURL(url, for: additionalScreen, options: options)
                }
            }
        } catch {
            throw WallpaperError.setWallpaperFailed(error.localizedDescription)
        }
    }
    
    /// Updates display mode
    func updateDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
        
        // Reapply current wallpaper with new mode
        if let currentWallpaper = currentWallpaper {
            try? setWallpaper(from: currentWallpaper)
        }
    }
    
    /// Updates show on all spaces setting
    func updateShowOnAllSpaces(_ show: Bool) {
        showOnAllSpaces = show
        UserDefaults.standard.set(show, forKey: showOnAllSpacesKey)
        
        // Reapply current wallpaper with new setting
        if let currentWallpaper = currentWallpaper {
            try? setWallpaper(from: currentWallpaper)
        }
    }
    
    /// Starts wallpaper rotation
    func startRotation(interval: TimeInterval) {
        rotationInterval = interval
        isRotating = true
        activePlaylistRotating = true
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            do {
                try self.rotateToNext()
            } catch {
                self.handleError(error)
            }
        }
    }
    
    /// Stops wallpaper rotation
    func stopRotation() {
        timer?.invalidate()
        timer = nil
        isRotating = false
        activePlaylistRotating = false
    }
    
    /// Adds new wallpapers to the rotation
    func addWallpapers(_ urls: [URL]) {
        let newWallpapers = urls.map { url in
            WallpaperItem(
                id: UUID(),
                path: url.absoluteString,
                name: url.lastPathComponent,
                isSelected: false
            )
        }
        wallpapers.append(contentsOf: newWallpapers)
        saveWallpapers()
    }
    
    /// Removes wallpapers from rotation
    func removeWallpapers(_ urls: [URL]) {
        for url in urls {
            fileMonitor?.stopMonitoring(url)
        }
        
        wallpapers.removeAll { wallpaper in
            guard let fileURL = wallpaper.fileURL else { return false }
            return urls.contains(fileURL)
        }
        saveWallpapers()
    }
    
    /// Clears all wallpapers
    func clearWallpapers() {
        wallpapers.removeAll()
        stopRotation()
        saveWallpapers()
    }
    
    /// Gets all unique wallpapers
    var allWallpapers: [WallpaperItem] {
        let allWallpapers = playlists.flatMap { $0.wallpapers }
        // Create a dictionary keyed by path to keep only unique wallpapers
        let uniqueWallpapers = Dictionary(grouping: allWallpapers) { $0.path }
            .compactMapValues { $0.first }
            .values
        return Array(uniqueWallpapers)
    }
    
    /// Gets current wallpaper
    var currentWallpaper: URL? {
        guard !wallpapers.isEmpty else { return nil }
        return wallpapers[currentIndex].fileURL
    }
    
    /// Creates a new playlist
    func createPlaylist(name: String) throws {
        guard playlists.count < maxPlaylists else {
            throw WallpaperManagerError.playlistLimitExceeded
        }
        
        guard !playlists.contains(where: { $0.name == name }) else {
            throw WallpaperManagerError.duplicatePlaylistName
        }
        
        let newPlaylist = Playlist(name: name)
        playlists.append(newPlaylist)
        try savePlaylists()
    }
    
    /// Deletes a playlist
    func deletePlaylist(id: UUID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        playlists.remove(at: index)
        try savePlaylists()
    }
    
    /// Updates a playlist
    func updatePlaylist(_ playlist: Playlist) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        playlists[index] = playlist
        try savePlaylists()
    }
    
    /// Adds wallpapers to a playlist
    func addWallpapersToPlaylist(_ wallpapers: [WallpaperItem], playlistId: UUID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        var updatedPlaylist = playlists[index]
        updatedPlaylist.wallpapers.append(contentsOf: wallpapers)
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    /// Removes wallpapers from a playlist
    func removeWallpapersFromPlaylist(_ wallpapers: [WallpaperItem], playlist: Playlist) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        var updatedPlaylist = playlist
        let wallpaperIds = Set(wallpapers.map { $0.id })
        updatedPlaylist.wallpapers.removeAll { wallpaperIds.contains($0.id) }
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    /// Gets the current system wallpaper
    func getCurrentSystemWallpaper() -> (URL, NSScreen)? {
        guard let screen = NSScreen.main else { return nil }
        guard let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        return (wallpaperURL, screen)
    }
    
    /// Sets the active playlist
    func setActivePlaylist(_ playlistId: UUID) {
        activePlaylistId = playlistId
        UserDefaults.standard.set(playlistId.uuidString, forKey: activePlaylistKey)
    }
    
    /// Starts playlist rotation
    func startPlaylistRotation(playlistId: UUID, interval: TimeInterval) {
        setActivePlaylist(playlistId)
        startRotation(interval: interval)
    }
    
    /// Renames a playlist
    func renamePlaylist(id: UUID, newName: String) throws {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        var updatedPlaylist = playlists[index]
        updatedPlaylist.name = newName
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    /// Moves a wallpaper from one playlist to another
    func moveWallpaper(from sourcePlaylist: Playlist, at sourceIndex: Int, to destinationPlaylist: Playlist, at destinationIndex: Int) throws {
        guard let sourcePlaylistIndex = playlists.firstIndex(where: { $0.id == sourcePlaylist.id }),
              let destinationPlaylistIndex = playlists.firstIndex(where: { $0.id == destinationPlaylist.id }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        var sourcePlaylist = playlists[sourcePlaylistIndex]
        var destinationPlaylist = playlists[destinationPlaylistIndex]
        
        let wallpaper = sourcePlaylist.wallpapers[sourceIndex]
        sourcePlaylist.wallpapers.remove(at: sourceIndex)
        destinationPlaylist.wallpapers.insert(wallpaper, at: destinationIndex)
        
        playlists[sourcePlaylistIndex] = sourcePlaylist
        playlists[destinationPlaylistIndex] = destinationPlaylist
        
        try savePlaylists()
    }
    
    /// Updates a playlist's playback mode
    func updatePlaylistPlaybackMode(_ playlistId: UUID, _ mode: PlaybackMode) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        var updatedPlaylist = playlists[index]
        updatedPlaylist.playbackMode = mode
        playlists[index] = updatedPlaylist
        try savePlaylists()
    }
    
    // MARK: - Private Methods
    
    private func loadSavedData() {
        // Load playlists
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let decodedPlaylists = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decodedPlaylists
        }
        
        // Load wallpapers
        if let data = UserDefaults.standard.data(forKey: wallpapersKey),
           let decodedWallpapers = try? JSONDecoder().decode([WallpaperItem].self, from: data) {
            wallpapers = decodedWallpapers
        }
        
        // Load display mode
        if let displayModeString = UserDefaults.standard.string(forKey: displayModeKey),
           let mode = DisplayMode(rawValue: displayModeString) {
            displayMode = mode
        }
        
        // Load show on all spaces setting
        showOnAllSpaces = UserDefaults.standard.bool(forKey: showOnAllSpacesKey)
        
        // Load current index
        currentIndex = UserDefaults.standard.integer(forKey: currentIndexKey)
    }
    
    private func saveWallpapers() {
        if let encoded = try? JSONEncoder().encode(wallpapers) {
            UserDefaults.standard.set(encoded, forKey: wallpapersKey)
        }
    }
    
    private func savePlaylists() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(playlists)
        UserDefaults.standard.set(data, forKey: playlistsKey)
    }
    
    private func rotateToNext() throws {
        guard !wallpapers.isEmpty else { return }
        
        // Get the active playlist's playback mode
        let playbackMode: PlaybackMode
        if let activePlaylist = playlists.first(where: { $0.id == activePlaylistId }) {
            playbackMode = activePlaylist.playbackMode
        } else {
            playbackMode = .sequential // Default to sequential if no active playlist
        }
        
        switch playbackMode {
        case .sequential:
            currentIndex = (currentIndex + 1) % wallpapers.count
        case .random:
            var randomIndex: Int
            repeat {
                randomIndex = Int.random(in: 0..<wallpapers.count)
            } while randomIndex == currentIndex && wallpapers.count > 1
            currentIndex = randomIndex
        case .shuffle:
            if usedRandomIndices.count == wallpapers.count {
                usedRandomIndices.removeAll()
            }
            
            var randomIndex: Int
            repeat {
                randomIndex = Int.random(in: 0..<wallpapers.count)
            } while usedRandomIndices.contains(randomIndex)
            
            usedRandomIndices.insert(randomIndex)
            currentIndex = randomIndex
        }
        
        if let url = wallpapers[currentIndex].fileURL {
            try setWallpaper(from: url)
        }
    }
    
    private func handleDeletedWallpaper() {
        wallpapers.removeAll { wallpaper in
            guard let url = wallpaper.fileURL else { return false }
            return !FileManager.default.fileExists(atPath: url.path)
        }
        saveWallpapers()
    }
    
    private func handleError(_ error: Error) {
        currentError = ErrorAlert(title: "Error", message: error.localizedDescription)
    }
} 