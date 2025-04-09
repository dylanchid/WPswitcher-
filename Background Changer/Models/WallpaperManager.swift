import AppKit
import Foundation
import SwiftUI
import Wallpaper

// MARK: - WallpaperManager Class
@MainActor
class WallpaperManager: ObservableObject {
    // MARK: - Dependencies
    private let wallpaperService: WallpaperServiceProtocol
    private let playlistService: PlaylistServiceProtocol
    private let userSettingsService: UserSettingsServiceProtocol
    
    // MARK: - Published Properties
    @Published private(set) var currentWallpaperPath: String = ""
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var wallpapers: [WallpaperItem] = []
    @Published var userSettings: UserSettings
    @Published var userProfile: UserProfile
    @Published var displayMode: DisplayMode
    @Published var showOnAllSpaces: Bool
    @Published var isRotating: Bool = false
    @Published var rotationInterval: TimeInterval
    @Published var currentError: WallpaperError?
    
    // MARK: - Properties
    private var currentIndex = 0
    private var timer: Timer?
    @Published var selectedScreen: NSScreen?
    private var playlistsKey = "savedPlaylists"
    
    // UserDefaults keys
    private let wallpapersKey = "savedWallpapers"
    private let displayModeKey = "displayMode"
    private let showOnAllSpacesKey = "showOnAllSpaces"
    private let currentIndexKey = "currentIndex"
    private let maxPlaylists = 20
    private let userSettingsKey = "userSettings"
    private let userProfileKey = "userProfile"
    
    private var fileMonitor: FileMonitor?
    @Published var activePlaylistId: UUID?
    private let activePlaylistKey = "activePlaylist"
    
    @Published private var activePlaylistRotating: Bool = false
    private var playlistRotationInterval: TimeInterval = 60
    private var usedRandomIndices: Set<Int> = []
    
    // MARK: - Initialization
    init(wallpaperService: WallpaperServiceProtocol,
         playlistService: PlaylistServiceProtocol,
         userSettingsService: UserSettingsServiceProtocol) {
        self.wallpaperService = wallpaperService
        self.playlistService = playlistService
        self.userSettingsService = userSettingsService
        
        // Initialize with default values
        self.userSettings = userSettingsService.userSettings
        self.userProfile = userSettingsService.userProfile
        self.displayMode = wallpaperService.displayMode
        self.showOnAllSpaces = wallpaperService.showOnAllSpaces
        self.rotationInterval = userSettings.defaultRotationInterval
        
        // Setup bindings
        setupBindings()
        
        fileMonitor = FileMonitor { [weak self] in
            self?.handleDeletedWallpaper()
        }
        loadSavedData()
    }
    
    // MARK: - Public Methods
    
    /// Sets wallpaper for specific screen with options
    func setWallpaper(from url: URL, for screen: NSScreen? = NSScreen.main) async {
        do {
            try await wallpaperService.setWallpaper(from: url, for: screen, mode: displayMode)
            updateRecentlyUsedWallpapers(url)
        } catch {
            handleError(error)
        }
    }
    
    /// Updates display mode
    func updateDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
        
        // Reapply current wallpaper with new mode
        if let currentWallpaper = currentWallpaper {
            Task {
                do {
                    try await setWallpaper(from: currentWallpaper)
                } catch {
                    handleError(error)
                }
            }
        }
    }
    
    /// Updates show on all spaces setting
    func updateShowOnAllSpaces(_ show: Bool) {
        showOnAllSpaces = show
        UserDefaults.standard.set(show, forKey: showOnAllSpacesKey)
        
        // Reapply current wallpaper with new setting
        if let currentWallpaper = currentWallpaper {
            Task {
                do {
                    try await setWallpaper(from: currentWallpaper)
                } catch {
                    handleError(error)
                }
            }
        }
    }
    
    /// Starts wallpaper rotation
    func startRotation(interval: TimeInterval? = nil) {
        let rotationInterval = interval ?? self.rotationInterval
        Task {
            await wallpaperService.startRotation(interval: rotationInterval)
            isRotating = true
            activePlaylistRotating = true
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    do {
                        try self.rotateToNext()
                    } catch {
                        self.handleError(error)
                    }
                }
            }
        }
    }
    
    /// Stops wallpaper rotation
    func stopRotation() {
        wallpaperService.stopRotation()
        timer?.invalidate()
        timer = nil
        isRotating = false
        activePlaylistRotating = false
    }
    
    /// Adds new wallpapers
    func addWallpapers(_ urls: [URL]) async {
        do {
            let newWallpapers = try await wallpaperService.addWallpapers(urls)
            wallpapers.append(contentsOf: newWallpapers)
        } catch {
            handleError(error)
        }
    }
    
    /// Preloads metadata for all wallpapers in background
    func preloadMetadata() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for wallpaper in wallpapers {
                    group.addTask {
                        try? await wallpaper.loadMetadata()
                    }
                }
            }
        }
    }
    
    /// Preloads images for visible wallpapers
    func preloadImages(for visibleWallpapers: [WallpaperItem]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for wallpaper in visibleWallpapers {
                    group.addTask {
                        try? await wallpaper.loadImage()
                    }
                }
            }
        }
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
    func createPlaylist(name: String) async {
        do {
            let playlist = try await playlistService.createPlaylist(name: name)
            playlists.append(playlist)
        } catch {
            handleError(error)
        }
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
    
    /// Updates user settings
    func updateSettings(_ settings: UserSettings) async {
        do {
            try await userSettingsService.updateSettings(settings)
            userSettings = settings
        } catch {
            handleError(error)
        }
    }
    
    /// Updates user profile
    func updateUserProfile(_ profile: UserProfile) {
        userProfile = profile
        saveUserProfile()
    }
    
    // MARK: - Backup Methods
    /// Creates a backup of the current state
    func createBackup() throws {
        let backup = Backup(
            id: UUID(),
            timestamp: Date(),
            playlists: playlists,
            wallpapers: wallpapers,
            userSettings: userSettings,
            userProfile: userProfile
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(backup)
        
        let backupURL = getBackupURL()
        try data.write(to: backupURL)
        
        // Update backup history
        userSettings.backup.backupHistory.append(backup.id)
        if userSettings.backup.backupHistory.count > userSettings.backup.maxBackups {
            let oldestBackupId = userSettings.backup.backupHistory.removeFirst()
            try deleteBackup(id: oldestBackupId)
        }
        
        saveUserSettings()
    }
    
    /// Restores from a backup
    func restoreFromBackup(id: UUID) throws {
        let backupURL = getBackupURL(for: id)
        let data = try Data(contentsOf: backupURL)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(Backup.self, from: data)
        
        // Restore state
        playlists = backup.playlists
        wallpapers = backup.wallpapers
        userSettings = backup.userSettings
        userProfile = backup.userProfile
        
        // Save restored state
        try savePlaylists()
        saveWallpapers()
        saveUserSettings()
        saveUserProfile()
    }
    
    /// Deletes a backup
    func deleteBackup(id: UUID) throws {
        let backupURL = getBackupURL(for: id)
        try FileManager.default.removeItem(at: backupURL)
        userSettings.backup.backupHistory.removeAll { $0 == id }
        saveUserSettings()
    }
    
    /// Gets all available backups
    func getAvailableBackups() -> [Backup] {
        var backups: [Backup] = []
        for backupId in userSettings.backup.backupHistory {
            if let backup = try? loadBackup(id: backupId) {
                backups.append(backup)
            }
        }
        return backups
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
    
    private func loadUserSettings() -> UserSettings {
        if let data = UserDefaults.standard.data(forKey: userSettingsKey),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            return settings
        }
        return UserSettings()
    }
    
    private func saveUserSettings() {
        if let encoded = try? JSONEncoder().encode(userSettings) {
            UserDefaults.standard.set(encoded, forKey: userSettingsKey)
        }
    }
    
    private func loadUserProfile() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: userProfileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return UserProfile(name: NSUserName())
    }
    
    private func saveUserProfile() {
        if let encoded = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(encoded, forKey: userProfileKey)
        }
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
        let errorAlert: ErrorAlert
        if let wallpaperError = error as? WallpaperError {
            errorAlert = ErrorAlert(
                title: "Wallpaper Error",
                message: wallpaperError.localizedDescription,
                severity: .error
            )
        } else if let managerError = error as? WallpaperManagerError {
            errorAlert = ErrorAlert(
                title: "Manager Error",
                message: managerError.localizedDescription,
                severity: .error
            )
        } else {
            errorAlert = ErrorAlert(
                title: "Error",
                message: error.localizedDescription,
                severity: .error
            )
        }
        currentError = errorAlert
    }
    
    // MARK: - Private Backup Methods
    
    private func loadBackup(id: UUID) throws -> Backup {
        let backupURL = getBackupURL(for: id)
        let data = try Data(contentsOf: backupURL)
        let decoder = JSONDecoder()
        return try decoder.decode(Backup.self, from: data)
    }
    
    private func getBackupURL(for id: UUID? = nil) -> URL {
        let backupDirectory = getBackupDirectory()
        if let id = id {
            return backupDirectory.appendingPathComponent("\(id).json")
        }
        return backupDirectory.appendingPathComponent("\(UUID()).json")
    }
    
    private func getBackupDirectory() -> URL {
        let fileManager = FileManager.default
        let backupPath = userSettings.backup.backupLocation.isEmpty ?
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BackgroundChanger/Backups") :
            URL(fileURLWithPath: userSettings.backup.backupLocation)
        
        if !fileManager.fileExists(atPath: backupPath.path) {
            try? fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)
        }
        
        return backupPath
    }
    
    private func setupBindings() {
        // Observe playlist changes
        Task {
            for await playlists in playlistService.playlistsPublisher.values {
                self.playlists = playlists
            }
        }
        
        // Observe wallpaper changes
        Task {
            for await wallpapers in wallpaperService.$wallpapers.values {
                self.wallpapers = wallpapers
            }
        }
    }
    
    private func updateRecentlyUsedWallpapers(_ url: URL) {
        Task {
            var profile = userProfile
            if let wallpaper = wallpapers.first(where: { $0.fileURL == url }) {
                profile.preferences.recentlyUsedWallpapers.insert(wallpaper.id, at: 0)
                if profile.preferences.recentlyUsedWallpapers.count > userSettings.maxRecentWallpapers {
                    profile.preferences.recentlyUsedWallpapers.removeLast()
                }
                try? await userSettingsService.updateProfile(profile)
            }
        }
    }
}

// MARK: - Keyboard Shortcut Handling
extension WallpaperManager {
    func handleKeyboardShortcut(_ shortcut: Shortcut) {
        switch shortcut.action {
        case .nextWallpaper:
            try? rotateToNext()
        case .previousWallpaper:
            try? rotateToPrevious()
        case .pauseRotation:
            if isRotating {
                stopRotation()
            } else {
                startRotation(interval: rotationInterval)
            }
        case .openSettings:
            NotificationCenter.default.post(name: .openSettings, object: nil)
        case .openMainWindow:
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
    }
    
    private func rotateToPrevious() throws {
        guard !wallpapers.isEmpty else { return }
        currentIndex = (currentIndex - 1 + wallpapers.count) % wallpapers.count
        if let url = wallpapers[currentIndex].fileURL {
            try setWallpaper(from: url)
        }
    }
}

// MARK: - Factory
extension WallpaperManager {
    static func create() -> WallpaperManager {
        let wallpaperService = WallpaperService(
            fileManager: .default,
            userDefaults: .standard,
            fileMonitor: FileMonitor()
        )
        
        let playlistService = PlaylistService(
            userDefaults: .standard
        )
        
        let userSettingsService = UserSettingsService(
            userDefaults: .standard
        )
        
        return WallpaperManager(
            wallpaperService: wallpaperService,
            playlistService: playlistService,
            userSettingsService: userSettingsService
        )
    }
} 