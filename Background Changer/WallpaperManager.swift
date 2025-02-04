import AppKit
import Foundation
import SwiftUI

enum WallpaperError: Error {
    case invalidScreen
    case invalidURL
    case setWallpaperFailed(String)
}

public enum DisplayMode: String, CaseIterable {
    case fillScreen = "Fill Screen"
    case fit = "Fit to Screen"
    case stretch = "Stretch"
    case center = "Center"
    
    var nsWorkspaceOptions: [NSWorkspace.DesktopImageOptionKey: Any] {
        switch self {
        case .fillScreen:
            return [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                   .allowClipping: true]
        case .fit:
            return [.imageScaling: NSImageScaling.scaleProportionallyDown.rawValue]
        case .stretch:
            return [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue]
        case .center:
            return [.imageScaling: NSImageScaling.scaleNone.rawValue]
        }
    }
}

enum WallpaperManagerError: LocalizedError {
    case playlistNotFound
    case invalidWallpaperURL
    case playlistLimitExceeded
    case duplicatePlaylistName
    case persistenceError
    
    var errorDescription: String? {
        switch self {
        case .playlistNotFound:
            return "Playlist not found"
        case .invalidWallpaperURL:
            return "Invalid wallpaper URL"
        case .playlistLimitExceeded:
            return "Maximum number of playlists reached"
        case .duplicatePlaylistName:
            return "A playlist with this name already exists"
        case .persistenceError:
            return "Failed to save data"
        }
    }
}

class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    @Published private(set) var loadedPlaylists: [Playlist] = []
    @Published private var wallpapers: [WallpaperItem] = []
    
    // MARK: - Properties
    private var currentIndex = 0
    private var timer: Timer?
    private var displayMode: DisplayMode = .fillScreen
    private var showOnAllSpaces: Bool = true
    private var playlists: [Playlist] = []
    private let playlistsKey = "savedPlaylists"
    
    // UserDefaults keys
    private let wallpapersKey = "savedWallpapers"
    private let displayModeKey = "displayMode"
    private let showOnAllSpacesKey = "showOnAllSpaces"
    private let currentIndexKey = "currentIndex"
    
    // Add to existing properties
    private let maxPlaylists = 20
    
    private var fileMonitor: FileMonitor?
    
    // Add new properties
    private var activePlaylistId: UUID?
    private let activePlaylistKey = "activePlaylist"
    
    // Add to properties section
    @Published private var activePlaylistRotating: Bool = false
    private var playlistRotationInterval: TimeInterval = 60
    
    @Published private(set) var currentWallpaperPath: String = ""
    
    // Add property to track last random indices
    private var usedRandomIndices: Set<Int> = []
    
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
        guard !wallpapers.isEmpty else { return }
        
        stopRotation()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            do {
                try self?.rotateToNext()
            } catch {
                print("Error rotating wallpaper: \(error.localizedDescription)")
                self?.stopRotation() // Stop rotation if we encounter an error
            }
        }
    }
    
    /// Stops wallpaper rotation
    func stopRotation() {
        timer?.invalidate()
        timer = nil
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
    
    /// Gets all wallpapers
    var allWallpapers: [URL] {
        wallpapers.compactMap { $0.fileURL }
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
        updateLoadedPlaylists()
    }
    
    /// Adds wallpapers to a playlist
    func addWallpapersToPlaylist(_ wallpapers: [WallpaperItem], playlistId: UUID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        
        // Validate and copy files to app's documents directory if needed
        let validatedWallpapers = try wallpapers.map { wallpaper -> WallpaperItem in
            guard let sourceURL = wallpaper.fileURL else {
                throw WallpaperManagerError.invalidWallpaperURL
            }
            
            // Create a copy in the app's documents directory
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let destinationURL = documentsURL
                .appendingPathComponent("Wallpapers")
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(sourceURL.pathExtension)
            
            // Create Wallpapers directory if it doesn't exist
            try FileManager.default.createDirectory(
                at: documentsURL.appendingPathComponent("Wallpapers"),
                withIntermediateDirectories: true
            )
            
            // Copy file
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // Create new wallpaper item with saved path
            return WallpaperItem(
                id: UUID(),
                path: destinationURL.absoluteString,
                name: wallpaper.name,
                isSelected: false
            )
        }
        
        playlists[index].wallpapers.append(contentsOf: validatedWallpapers)
        try savePlaylists()
        updateLoadedPlaylists()
    }
    
    /// Renames a playlist
    func renamePlaylist(id: UUID, newName: String) throws {
        if let index = playlists.firstIndex(where: { $0.id == id }) {
            playlists[index].name = newName
            try savePlaylists()
        } else {
            throw WallpaperManagerError.playlistNotFound
        }
    }
    
    /// Deletes a playlist
    func deletePlaylist(id: UUID) throws {
        guard playlists.contains(where: { $0.id == id }) else {
            throw WallpaperManagerError.playlistNotFound
        }
        playlists.removeAll(where: { $0.id == id })
        try savePlaylists()
        updateLoadedPlaylists()
    }
    
    // MARK: - Private Methods
    
    private func rotateToNext() throws {
        if let playlistId = activePlaylistId,
           let playlist = playlists.first(where: { $0.id == playlistId }),
           !playlist.wallpapers.isEmpty {
            currentIndex = (currentIndex + 1) % playlist.wallpapers.count
            if let nextWallpaper = playlist.wallpapers[currentIndex].fileURL {
                try setWallpaper(from: nextWallpaper)
            }
        } else {
            guard !wallpapers.isEmpty else { return }
            currentIndex = (currentIndex + 1) % wallpapers.count
            if let nextWallpaper = wallpapers[currentIndex].fileURL {
                try setWallpaper(from: nextWallpaper)
            }
        }
        saveCurrentIndex()
    }
    
    private func loadSavedData() {
        // Load playlists
        loadPlaylists()
        
        // Load all photos
        if let data = UserDefaults.standard.data(forKey: wallpapersKey),
           let savedWallpapers = try? JSONDecoder().decode([WallpaperItem].self, from: data) {
            // Verify files still exist and update wallpapers
            wallpapers = savedWallpapers.filter { wallpaper in
                if let url = wallpaper.fileURL {
                    return FileManager.default.fileExists(atPath: url.path)
                }
                return false
            }
        }
        
        // Load active playlist
        if let activeId = UserDefaults.standard.string(forKey: activePlaylistKey) {
            activePlaylistId = UUID(uuidString: activeId)
        }
        
        updateLoadedPlaylists()
    }
    
    private func loadPlaylists() {
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
            updateLoadedPlaylists()
        }
    }
    
    private func saveWallpapers() {
        if let encoded = try? JSONEncoder().encode(wallpapers) {
            UserDefaults.standard.set(encoded, forKey: wallpapersKey)
        }
    }
    
    private func saveCurrentIndex() {
        UserDefaults.standard.set(currentIndex, forKey: currentIndexKey)
    }
    
    private func savePlaylists() throws {
        do {
            let encoded = try JSONEncoder().encode(playlists)
            UserDefaults.standard.set(encoded, forKey: playlistsKey)
            
            // Save active playlist
            if let activeId = activePlaylistId {
                UserDefaults.standard.set(activeId.uuidString, forKey: activePlaylistKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activePlaylistKey)
            }
            
            updateLoadedPlaylists()
        } catch {
            throw WallpaperManagerError.persistenceError
        }
    }
    
    private func validateURL(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    private func handleError(_ error: Error) {
        print("Error: \(error.localizedDescription)")
        // You could implement a delegate pattern here for better error handling
    }
    
    func setWallpaperSafely(from url: URL) {
        guard validateURL(url) else {
            handleError(WallpaperError.invalidURL)
            return
        }
        
        do {
            try setWallpaper(from: url)
        } catch {
            handleError(error)
        }
    }
    
    private func handleDeletedWallpaper() {
        // Remove any wallpapers that no longer exist
        wallpapers.removeAll { url in
            !FileManager.default.fileExists(atPath: url.path)
        }
        saveWallpapers()
    }
    
    func setActivePlaylist(_ playlistId: UUID?) {
        activePlaylistId = playlistId
        UserDefaults.standard.set(playlistId?.uuidString, forKey: activePlaylistKey)
        
        // Reset rotation if active
        if timer != nil {
            startRotation(interval: UserDefaults.standard.double(forKey: "rotationInterval"))
        }
    }
    
    // Update loadedPlaylists whenever playlists change
    private func updateLoadedPlaylists() {
        loadedPlaylists = playlists
    }
    
    // Add these new methods
    func startPlaylistRotation(_ playlist: Playlist, interval: TimeInterval) {
        stopRotation() // Stop any existing rotation
        
        activePlaylistId = playlist.id
        playlistRotationInterval = interval
        activePlaylistRotating = true
        
        // Start the timer with the specified interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            do {
                try self?.rotatePlaylist()
            } catch {
                print("Error rotating playlist: \(error.localizedDescription)")
                self?.stopPlaylistRotation()
            }
        }
        
        // Trigger first rotation immediately
        try? rotatePlaylist()
    }
    
    func stopPlaylistRotation() {
        activePlaylistRotating = false
        stopRotation()
    }
    
    func isPlaylistRotating(_ playlistId: UUID) -> Bool {
        return activePlaylistId == playlistId && activePlaylistRotating
    }
    
    func rotatePlaylist() throws {
        guard let playlistId = activePlaylistId,
              let playlist = playlists.first(where: { $0.id == playlistId }),
              !playlist.wallpapers.isEmpty else {
            stopPlaylistRotation()
            throw WallpaperError.invalidURL
        }
        
        let nextIndex = getNextIndex(for: playlist)
        currentIndex = nextIndex
        
        if let nextWallpaper = playlist.wallpapers[currentIndex].fileURL {
            try setWallpaper(from: nextWallpaper)
            currentWallpaperPath = nextWallpaper.absoluteString
        }
    }
    
    private func getNextIndex(for playlist: Playlist) -> Int {
        switch playlist.playbackMode {
        case .sequential:
            return (currentIndex + 1) % playlist.wallpapers.count
        case .random:
            if usedRandomIndices.count == playlist.wallpapers.count {
                usedRandomIndices.removeAll()
            }
            
            var randomIndex: Int
            repeat {
                randomIndex = Int.random(in: 0..<playlist.wallpapers.count)
            } while usedRandomIndices.contains(randomIndex)
            
            usedRandomIndices.insert(randomIndex)
            return randomIndex
        }
    }
    
    func getCurrentRotationInterval(for playlistId: UUID) -> TimeInterval {
        if activePlaylistId == playlistId {
            return playlistRotationInterval
        }
        return 60 // Default interval
    }
    
    func getCurrentSystemWallpaper() -> (URL, NSImage)? {
        guard let screen = NSScreen.main,
              let wallpaperURL = try? NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: wallpaperURL) else {
            return nil
        }
        return (wallpaperURL, image)
    }
    
    func moveWallpaper(from sourcePlaylist: Playlist, at sourceIndex: Int, to targetPlaylist: Playlist, at targetIndex: Int) {
        guard let sourcePlaylistIndex = playlists.firstIndex(where: { $0.id == sourcePlaylist.id }),
              let targetPlaylistIndex = playlists.firstIndex(where: { $0.id == targetPlaylist.id }) else {
            return
        }
        
        let wallpaper = playlists[sourcePlaylistIndex].wallpapers.remove(at: sourceIndex)
        playlists[targetPlaylistIndex].wallpapers.insert(wallpaper, at: targetIndex)
        
        // Perform save operations after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            try? self?.savePlaylists()
            self?.updateLoadedPlaylists()
        }
    }
    
    func updatePlaylistPlaybackMode(_ playlistId: UUID, mode: PlaybackMode) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[index].playbackMode = mode
            usedRandomIndices.removeAll()
            try? savePlaylists()
            updateLoadedPlaylists()
        }
    }
}

// MARK: - Extensions

extension WallpaperManager {
    /// Gets current wallpaper for specific screen
    func getCurrentWallpaper(for screen: NSScreen) -> URL? {
        do {
            return try NSWorkspace.shared.desktopImageURL(for: screen)
        } catch {
            return nil
        }
    }
    
    /// Sets wallpaper for specific screen
    func setWallpaper(from url: URL, for screen: NSScreen) throws {
        try setWallpaper(from: url, for: screen, mode: displayMode)
    }
    
    /// Rotates to specific index
    func rotateToIndex(_ index: Int) {
        guard index < wallpapers.count else { return }
        currentIndex = index
        if let wallpaper = currentWallpaper {
            try? setWallpaper(from: wallpaper)
        }
        saveCurrentIndex()
    }
}
