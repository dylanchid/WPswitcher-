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
    case slideshowNotFound
    case invalidWallpaperURL
    case slideshowLimitExceeded
    case duplicateSlideshowName
    case persistenceError
    
    var errorDescription: String? {
        switch self {
        case .slideshowNotFound:
            return "Slideshow not found"
        case .invalidWallpaperURL:
            return "Invalid wallpaper URL"
        case .slideshowLimitExceeded:
            return "Maximum number of slideshows reached"
        case .duplicateSlideshowName:
            return "A slideshow with this name already exists"
        case .persistenceError:
            return "Failed to save data"
        }
    }
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    @Published private(set) var slideshows: [Slideshow] = []
    @Published private var wallpapers: [WallpaperItem] = []
    
    // MARK: - Properties
    private var currentIndex = 0
    private var timer: Timer?
    @Published var displayMode: DisplayMode = .fillScreen
    @Published var selectedScreen: NSScreen?
    @Published var showOnAllSpaces: Bool = true
    private var slideshowsKey = "savedSlideshows"
    
    // UserDefaults keys
    private let wallpapersKey = "savedWallpapers"
    private let displayModeKey = "displayMode"
    private let showOnAllSpacesKey = "showOnAllSpaces"
    private let currentIndexKey = "currentIndex"
    
    // Add to existing properties
    private let maxSlideshows = 20
    
    private var fileMonitor: FileMonitor?
    
    // Add new properties
    private var activeSlideshowId: UUID?
    private let activeSlideshowKey = "activeSlideshow"
    
    // Add to properties section
    @Published private var activeSlideshowRotating: Bool = false
    private var slideshowRotationInterval: TimeInterval = 60
    
    @Published private(set) var currentWallpaperPath: String = ""
    
    // Add property to track last random indices
    private var usedRandomIndices: Set<Int> = []
    
    @Published var currentError: ErrorAlert?
    
    // Add new properties
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
        activeSlideshowRotating = true
        
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
        activeSlideshowRotating = false
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
        let allWallpapers = slideshows.flatMap { $0.wallpapers }
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
    
    /// Creates a new slideshow
    func createSlideshow(name: String) throws {
        guard slideshows.count < maxSlideshows else {
            throw WallpaperManagerError.slideshowLimitExceeded
        }
        
        guard !slideshows.contains(where: { $0.name == name }) else {
            throw WallpaperManagerError.duplicateSlideshowName
        }
        
        let newSlideshow = Slideshow(name: name)
        slideshows.append(newSlideshow)
        try saveSlideshows()
    }
    
    /// Adds wallpapers to a slideshow
    func addWallpapersToSlideshow(_ wallpapers: [WallpaperItem], slideshowId: UUID) throws {
        guard let index = slideshows.firstIndex(where: { $0.id == slideshowId }) else {
            throw WallpaperManagerError.slideshowNotFound
        }
        
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
        
        slideshows[index].wallpapers.append(contentsOf: validatedWallpapers)
        try saveSlideshows()
    }
    
    /// Renames a slideshow
    func renameSlideshow(id: UUID, newName: String) throws {
        if let index = slideshows.firstIndex(where: { $0.id == id }) {
            slideshows[index].name = newName
            try saveSlideshows()
        } else {
            throw WallpaperManagerError.slideshowNotFound
        }
    }
    
    /// Deletes a slideshow
    func deleteSlideshow(id: UUID) throws {
        guard slideshows.contains(where: { $0.id == id }) else {
            throw WallpaperManagerError.slideshowNotFound
        }
        slideshows.removeAll(where: { $0.id == id })
        try saveSlideshows()
    }
    
    // MARK: - Private Methods
    
    private func rotateToNext() throws {
        if let slideshowId = activeSlideshowId,
           let slideshow = slideshows.first(where: { $0.id == slideshowId }),
           !slideshow.wallpapers.isEmpty {
            
            let nextIndex: Int
            
            // Calculate next index based on playback mode
            if slideshow.playbackMode == .sequential {
                nextIndex = (currentIndex + 1) % slideshow.wallpapers.count
            } else { // random mode
                if usedRandomIndices.count == slideshow.wallpapers.count {
                    usedRandomIndices.removeAll()
                }
                
                var randomIndex: Int
                repeat {
                    randomIndex = Int.random(in: 0..<slideshow.wallpapers.count)
                } while usedRandomIndices.contains(randomIndex)
                
                usedRandomIndices.insert(randomIndex)
                nextIndex = randomIndex
            }
            
            currentIndex = nextIndex
            if let nextWallpaper = slideshow.wallpapers[currentIndex].fileURL {
                try setWallpaper(from: nextWallpaper)
                currentWallpaperPath = nextWallpaper.absoluteString
            }
        }
        saveCurrentIndex()
    }
    
    private func loadSavedData() {
        // Load slideshows
        loadSlideshows()
        
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
        
        // Load active slideshow
        if let activeId = UserDefaults.standard.string(forKey: activeSlideshowKey) {
            activeSlideshowId = UUID(uuidString: activeId)
        }
    }
    
    private func loadSlideshows() {
        if let data = UserDefaults.standard.data(forKey: slideshowsKey),
           let decoded = try? JSONDecoder().decode([Slideshow].self, from: data) {
            slideshows = decoded
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
    
    private func saveSlideshows() throws {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(slideshows) {
            UserDefaults.standard.set(encoded, forKey: slideshowsKey)
        } else {
            throw WallpaperManagerError.persistenceError
        }
    }
    
    private func validateURL(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.currentError = ErrorAlert(
                title: "Error",
                message: error.localizedDescription
            )
        }
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
    
    func setActiveSlideshow(_ slideshowId: UUID?) {
        activeSlideshowId = slideshowId
        UserDefaults.standard.set(slideshowId?.uuidString, forKey: activeSlideshowKey)
        
        // Reset rotation if active
        if timer != nil {
            startRotation(interval: UserDefaults.standard.double(forKey: "rotationInterval"))
        }
    }
    
    // Update loadedSlideshows whenever slideshows change
    private func updateLoadedSlideshows() {
        // This method is no longer needed
    }
    
    // Add these new methods
    func startSlideshowRotation(_ slideshow: Slideshow, interval: TimeInterval) {
        stopRotation() // Stop any existing rotation
        
        activeSlideshowId = slideshow.id
        slideshowRotationInterval = interval
        activeSlideshowRotating = true
        
        // Start the timer with the specified interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            do {
                try self?.rotateSlideshow()
            } catch {
                print("Error rotating slideshow: \(error.localizedDescription)")
                self?.stopSlideshowRotation()
            }
        }
        
        // Trigger first rotation immediately
        try? rotateSlideshow()
    }
    
    func stopSlideshowRotation() {
        activeSlideshowRotating = false
        stopRotation()
    }
    
    func isSlideshowRotating(_ slideshowId: UUID) -> Bool {
        return activeSlideshowId == slideshowId && activeSlideshowRotating
    }
    
    func rotateSlideshow() throws {
        guard let slideshowId = activeSlideshowId,
              let slideshow = slideshows.first(where: { $0.id == slideshowId }),
              !slideshow.wallpapers.isEmpty else {
            stopSlideshowRotation()
            throw WallpaperError.invalidURL
        }
        
        let nextIndex = getNextIndex(for: slideshow)
        currentIndex = nextIndex
        
        if let nextWallpaper = slideshow.wallpapers[currentIndex].fileURL {
            try setWallpaper(from: nextWallpaper)
            currentWallpaperPath = nextWallpaper.absoluteString
        }
    }
    
    private func getNextIndex(for slideshow: Slideshow) -> Int {
        switch slideshow.playbackMode {
        case .sequential:
            return (currentIndex + 1) % slideshow.wallpapers.count
        case .random:
            if usedRandomIndices.count == slideshow.wallpapers.count {
                usedRandomIndices.removeAll()
            }
            
            var randomIndex: Int
            repeat {
                randomIndex = Int.random(in: 0..<slideshow.wallpapers.count)
            } while usedRandomIndices.contains(randomIndex)
            
            usedRandomIndices.insert(randomIndex)
            return randomIndex
        }
    }
    
    func getCurrentRotationInterval(for slideshowId: UUID) -> TimeInterval {
        if activeSlideshowId == slideshowId {
            return slideshowRotationInterval
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
    
    func moveWallpaper(from sourceSlideshow: Slideshow, at sourceIndex: Int, to targetSlideshow: Slideshow, at targetIndex: Int) {
        guard let sourceSlideshowIndex = slideshows.firstIndex(where: { $0.id == sourceSlideshow.id }),
              let targetSlideshowIndex = slideshows.firstIndex(where: { $0.id == targetSlideshow.id }) else {
            return
        }
        
        let wallpaper = slideshows[sourceSlideshowIndex].wallpapers.remove(at: sourceIndex)
        slideshows[targetSlideshowIndex].wallpapers.insert(wallpaper, at: targetIndex)
        
        // Perform save operations after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            try? self?.saveSlideshows()
        }
    }
    
    func updateSlideshowPlaybackMode(_ slideshowId: UUID, mode: PlaybackMode) {
        if let index = slideshows.firstIndex(where: { $0.id == slideshowId }) {
            slideshows[index].playbackMode = mode
            usedRandomIndices.removeAll()
            try? saveSlideshows()
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
