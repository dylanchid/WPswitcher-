import Foundation
import AppKit
import Combine
import WallpaperTypes

@MainActor
@preconcurrency
public final class UnifiedWallpaperService: ObservableObject, WallpaperServiceProtocol {
    // MARK: - Published Properties
    @Published public private(set) var currentWallpaperPath: String = ""
    @Published public var displayMode: DisplayMode = .fillScreen
    @Published public var showOnAllSpaces: Bool = true
    
    // MARK: - Private Properties
    private let cacheService: CacheServiceProtocol
    private let fileManager: FileManager
    private var wallpapers: [WallpaperItem] = []
    private var currentIndex: Int = 0
    private var timer: Timer?
    private weak var fileMonitor: FileMonitor?
    
    // MARK: - Initialization
    public init(
        cacheService: CacheServiceProtocol = UnifiedCacheService(),
        fileManager: FileManager = .default,
        fileMonitor: FileMonitor? = nil
    ) {
        self.cacheService = cacheService
        self.fileManager = fileManager
        self.fileMonitor = fileMonitor
        
        setupFileMonitoring()
    }
    
    // MARK: - WallpaperServiceProtocol Implementation
    
    public func setWallpaper(from url: URL, for screen: NSScreen? = NSScreen.main, mode: DisplayMode? = nil) async throws {
        guard let screen = screen else {
            throw WallpaperError.invalidScreen
        }
        
        let workspace = NSWorkspace.shared
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        
        do {
            try workspace.setDesktopImageURL(url, for: screen, options: options)
            currentWallpaperPath = url.absoluteString
            
            if showOnAllSpaces {
                for additionalScreen in NSScreen.screens where additionalScreen != screen {
                    try workspace.setDesktopImageURL(url, for: additionalScreen, options: options)
                }
            }
        } catch {
            throw WallpaperError.setWallpaperFailed("Failed to set wallpaper")
        }
    }
    
    public func setWallpaper(_ wallpaper: WallpaperItem) async throws {
        try await setWallpaper(from: wallpaper.url)
    }
    
    public func getCurrentWallpaper() async throws -> WallpaperItem? {
        guard !currentWallpaperPath.isEmpty else { return nil }
        return wallpapers.first { $0.url.absoluteString == currentWallpaperPath }
    }
    
    public func getWallpaperList() async throws -> [WallpaperItem] {
        return wallpapers
    }
    
    public func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem] {
        var newWallpapers: [WallpaperItem] = []
        
        try await withThrowingTaskGroup(of: WallpaperItem.self) { group in
            for url in urls {
                group.addTask {
                    let cachedURL = try await self.cacheService.cacheWallpaper(from: url)
                    let metadata = try await self.getMetadata(path: cachedURL.path)
                    return WallpaperItem(
                        url: url,
                        name: url.lastPathComponent,
                        metadata: metadata
                    )
                }
            }
            
            for try await wallpaper in group {
                newWallpapers.append(wallpaper)
            }
        }
        
        wallpapers.append(contentsOf: newWallpapers)
        return newWallpapers
    }
    
    public func removeWallpaper(_ item: WallpaperItem) async throws {
        try await cacheService.removeFromCache(item.url)
        wallpapers.removeAll { $0.id == item.id }
    }
    
    public func validateWallpaper(path: String) async throws {
        guard fileManager.fileExists(atPath: path) else {
            throw WallpaperError.fileNotFound("Wallpaper file not found at path: \(path)")
        }
        
        guard let image = NSImage(contentsOfFile: path) else {
            throw WallpaperError.invalidImage("Invalid image format at path: \(path)")
        }
        
        guard image.isValid else {
            throw WallpaperError.invalidImage("Invalid image data at path: \(path)")
        }
    }
    
    public func getMetadata(path: String) async throws -> WallpaperMetadata {
        guard let image = NSImage(contentsOfFile: path) else {
            throw WallpaperError.invalidImage("Could not load image")
        }
        
        let size = image.size
        let fileSize = try fileManager.attributesOfItem(atPath: path)[.size] as? Int64 ?? 0
        let format = (path as NSString).pathExtension.lowercased()
        
        return WallpaperMetadata(
            dimensions: size,
            fileSize: fileSize,
            format: format
        )
    }
    
    public func preloadMetadata(for wallpapers: [WallpaperItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for wallpaper in wallpapers {
                group.addTask {
                    _ = try? await self.getMetadata(path: wallpaper.url.path)
                }
            }
        }
    }
    
    public func preloadImages(for wallpapers: [WallpaperItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for wallpaper in wallpapers {
                group.addTask {
                    _ = try? await self.validateWallpaper(path: wallpaper.url.path)
                }
            }
        }
    }
    
    // MARK: - Rotation
    public func startRotation(interval: TimeInterval) async { /* No-op */ }
    public func stopRotation() async { /* No-op */ }
    public func rotateToNext() async throws { /* No-op */ }
    public func rotateToPrevious() async throws { /* No-op */ }

    // MARK: - Private Methods
    
    private func setupFileMonitoring() {
        // File monitoring setup
    }
    
    deinit {
        Task { @MainActor in
            fileMonitor?.stopMonitoring()
        }
    }
} 