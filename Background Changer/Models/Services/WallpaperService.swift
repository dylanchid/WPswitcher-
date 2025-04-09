import Foundation
import AppKit

@MainActor
class WallpaperService: ObservableObject, WallpaperServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var currentWallpaperPath: String = ""
    @Published var displayMode: DisplayMode = .fillScreen
    @Published var showOnAllSpaces: Bool = true
    
    // MARK: - Private Properties
    private var wallpapers: [WallpaperItem] = []
    private var currentIndex: Int = 0
    private var timer: Timer?
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private weak var fileMonitor: FileMonitor?
    
    // MARK: - Constants
    private let wallpapersKey = "savedWallpapers"
    private let displayModeKey = "displayMode"
    private let showOnAllSpacesKey = "showOnAllSpaces"
    private let currentIndexKey = "currentIndex"
    
    // MARK: - Initialization
    init(fileManager: FileManager = .default,
         userDefaults: UserDefaults = .standard,
         fileMonitor: FileMonitor? = nil) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.fileMonitor = fileMonitor
        
        loadSavedData()
        setupFileMonitoring()
    }
    
    // MARK: - WallpaperServiceProtocol Implementation
    
    func setWallpaper(from url: URL, for screen: NSScreen? = NSScreen.main, mode: DisplayMode? = nil) async throws {
        guard let screen = screen else {
            throw WallpaperError.invalidScreen
        }
        
        let workspace = NSWorkspace.shared
        let options = (mode ?? displayMode).nsWorkspaceOptions
        
        do {
            try workspace.setDesktopImageURL(url, for: screen, options: options)
            currentWallpaperPath = url.absoluteString
            
            if showOnAllSpaces {
                for additionalScreen in NSScreen.screens where additionalScreen != screen {
                    try workspace.setDesktopImageURL(url, for: additionalScreen, options: options)
                }
            }
        } catch {
            throw WallpaperError.setWallpaperFailed(error.localizedDescription)
        }
    }
    
    func rotateToNext() async throws {
        guard !wallpapers.isEmpty else {
            throw WallpaperError.invalidPlaylistOperation("No wallpapers available")
        }
        
        currentIndex = (currentIndex + 1) % wallpapers.count
        if let url = wallpapers[currentIndex].fileURL {
            try await setWallpaper(from: url)
        }
    }
    
    func rotateToPrevious() async throws {
        guard !wallpapers.isEmpty else {
            throw WallpaperError.invalidPlaylistOperation("No wallpapers available")
        }
        
        currentIndex = (currentIndex - 1 + wallpapers.count) % wallpapers.count
        if let url = wallpapers[currentIndex].fileURL {
            try await setWallpaper(from: url)
        }
    }
    
    func startRotation(interval: TimeInterval) async {
        stopRotation()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try await self.rotateToNext()
                } catch {
                    print("Failed to rotate wallpaper: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopRotation() {
        timer?.invalidate()
        timer = nil
    }
    
    func addWallpapers(_ urls: [URL]) async throws -> [WallpaperItem] {
        var newWallpapers: [WallpaperItem] = []
        
        try await withThrowingTaskGroup(of: WallpaperItem.self) { group in
            for url in urls {
                group.addTask {
                    let wallpaper = WallpaperItem(
                        id: UUID(),
                        path: url.absoluteString,
                        name: url.lastPathComponent,
                        isSelected: false
                    )
                    
                    // Load metadata asynchronously
                    let metadata = try await wallpaper.loadMetadata()
                    var updatedWallpaper = wallpaper
                    updatedWallpaper.metadata = metadata
                    return updatedWallpaper
                }
            }
            
            for try await wallpaper in group {
                newWallpapers.append(wallpaper)
            }
        }
        
        wallpapers.append(contentsOf: newWallpapers)
        saveWallpapers()
        return newWallpapers
    }
    
    func removeWallpapers(_ ids: Set<UUID>) async throws {
        wallpapers.removeAll { ids.contains($0.id) }
        saveWallpapers()
    }
    
    func preloadMetadata(for wallpapers: [WallpaperItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for wallpaper in wallpapers {
                group.addTask {
                    try? await wallpaper.loadMetadata()
                }
            }
        }
    }
    
    func preloadImages(for wallpapers: [WallpaperItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for wallpaper in wallpapers {
                group.addTask {
                    try? await wallpaper.loadImage()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSavedData() {
        if let savedDisplayMode = userDefaults.string(forKey: displayModeKey),
           let mode = DisplayMode(rawValue: savedDisplayMode) {
            displayMode = mode
        }
        
        showOnAllSpaces = userDefaults.bool(forKey: showOnAllSpacesKey)
        currentIndex = userDefaults.integer(forKey: currentIndexKey)
        
        if let data = userDefaults.data(forKey: wallpapersKey),
           let decoded = try? JSONDecoder().decode([WallpaperItem].self, from: data) {
            wallpapers = decoded
        }
    }
    
    private func saveWallpapers() {
        if let encoded = try? JSONEncoder().encode(wallpapers) {
            userDefaults.set(encoded, forKey: wallpapersKey)
        }
    }
    
    private func setupFileMonitoring() {
        fileMonitor?.startMonitoring()
    }
    
    deinit {
        stopRotation()
        fileMonitor?.stopMonitoring()
    }
} 