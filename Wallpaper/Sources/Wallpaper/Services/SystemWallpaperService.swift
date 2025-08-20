import Foundation
import AppKit
import WallpaperTypes

/// System implementation of WallpaperServiceProtocol
/// This is the concrete implementation that manages wallpapers using macOS APIs
@MainActor
public final class SystemWallpaperService: WallpaperServiceProtocol {
    // MARK: - Properties
    private let workspace: NSWorkspace
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    
    public nonisolated var currentWallpaperPath: String {
        workspace.desktopImageURL(for: NSScreen.main!)?.path ?? ""
    }
    
    public var displayMode: DisplayMode = .fillScreen
    public var showOnAllSpaces: Bool = true
    
    // MARK: - Initialization
    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
        self.userDefaults = userDefaults
    }
    
    // MARK: - WallpaperServiceProtocol Implementation
    
    public func setWallpaper(from url: URL, for screen: NSScreen? = nil, mode: DisplayMode? = nil) async throws {
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen = targetScreen else {
            throw WallpaperError.invalidScreen
        }
        
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        
        do {
            try workspace.setDesktopImageURL(url, for: targetScreen, options: options)
        } catch {
            throw WallpaperError.setWallpaperFailed("Failed to set wallpaper: \(error.localizedDescription)")
        }
    }
    
    public func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem] {
        var items: [WallpaperItem] = []
        
        for url in urls {
            try await validateWallpaper(path: url.path)
            let metadata = try await getMetadata(path: url.path)
            let item = WallpaperItem(
                url: url,
                name: url.lastPathComponent,
                metadata: metadata
            )
            items.append(item)
        }
        
        return items
    }
    
    public func removeWallpaper(_ item: WallpaperItem) async throws {
        // This is a placeholder implementation
        // In a real app, this would remove the wallpaper from storage/playlist
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
    
    public func setWallpaper(_ wallpaper: WallpaperItem) async throws {
        try await setWallpaper(from: wallpaper.url)
    }
    
    public func getCurrentWallpaper() async throws -> WallpaperItem? {
        guard let url = workspace.desktopImageURL(for: NSScreen.main!) else {
            return nil
        }
        
        let metadata = try await getMetadata(path: url.path)
        return WallpaperItem(
            url: url,
            name: url.lastPathComponent,
            metadata: metadata
        )
    }
    
    public func getWallpaperList() async throws -> [WallpaperItem] {
        // This is a placeholder implementation
        // In a real app, this would return the list of wallpapers from a database or file system
        return []
    }
}
