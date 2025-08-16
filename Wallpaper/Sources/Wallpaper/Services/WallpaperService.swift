import Foundation
import AppKit
import UniformTypeIdentifiers
import WallpaperTypes

@MainActor
@preconcurrency
public final class WallpaperService: WallpaperServiceProtocol {
    // MARK: - Properties
    private let workspace: NSWorkspace
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let rotationService: WallpaperRotationServiceProtocol
    
    private var currentWallpaperIndex: Int {
        get { userDefaults.integer(forKey: "currentWallpaperIndex") }
        set { userDefaults.set(newValue, forKey: "currentWallpaperIndex") }
    }
    
    public nonisolated var currentWallpaperPath: String {
        workspace.desktopImageURL(for: NSScreen.main!)?.absoluteString ?? ""
    }
    
    public var displayMode: DisplayMode {
        get { .fillScreen } // Default mode
        set { } // No-op for now
    }
    
    public var showOnAllSpaces: Bool {
        get { true } // Default value
        set { } // No-op for now
    }
    
    // MARK: - Initialization
    public init(
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        rotationService: WallpaperRotationServiceProtocol
    ) {
        self.workspace = workspace
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.rotationService = rotationService
    }
    
    // MARK: - Wallpaper Management
    public func setWallpaper(from url: URL, for screen: NSScreen? = nil, mode: DisplayMode? = nil) async throws {
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen = targetScreen else {
            throw WallpaperError.invalidScreen
        }
        
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        
        do {
            try workspace.setDesktopImageURL(url, for: targetScreen, options: options)
        } catch {
            throw WallpaperError.setWallpaperFailed("Failed to set wallpaper")
        }
    }
    
    public func addWallpapers(from urls: [URL]) async throws -> [WallpaperItem] {
        var items: [WallpaperItem] = []
        
        for url in urls {
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
        // In a real app, this would remove the wallpaper from storage
    }
    
    // MARK: - Rotation
    public func startRotation(interval: TimeInterval) async {
        await rotationService.startRotation(interval: interval)
    }
    
    public func stopRotation() async {
        await rotationService.stopRotation()
    }
    
    public func rotateToNext() async throws {
        try await rotationService.rotateToNext()
    }
    
    public func rotateToPrevious() async throws {
        try await rotationService.rotateToPrevious()
    }
    
    // MARK: - Validation
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
    
    // MARK: - Preloading
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
    
    // MARK: - Additional Methods
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
    
    // MARK: - Private Methods
    private func getWallpaperDirectory() throws -> URL {
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let wallpaperDirectory = documentsDirectory.appendingPathComponent("Wallpapers")
        try fileManager.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        
        return wallpaperDirectory
    }
} 