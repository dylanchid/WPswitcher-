import Foundation
import AppKit

/// Protocol defining the contract for wallpaper management operations
protocol WallpaperServiceProtocol {
    /// Current wallpaper state
    var currentWallpaperPath: String { get }
    var displayMode: DisplayMode { get set }
    var showOnAllSpaces: Bool { get set }
    
    /// Wallpaper Operations
    func setWallpaper(from url: URL, for screen: NSScreen?, mode: DisplayMode?) async throws
    func rotateToNext() async throws
    func rotateToPrevious() async throws
    
    /// Playlist Management
    func startRotation(interval: TimeInterval) async
    func stopRotation()
    
    /// Wallpaper Management
    func addWallpapers(_ urls: [URL]) async throws -> [WallpaperItem]
    func removeWallpapers(_ ids: Set<UUID>) async throws
    func preloadMetadata(for wallpapers: [WallpaperItem]) async
    func preloadImages(for wallpapers: [WallpaperItem]) async
}

/// Enum representing display modes for wallpapers
enum DisplayMode: String, Codable, CaseIterable {
    case fillScreen = "Fill Screen"
    case fit = "Fit"
    case stretch = "Stretch"
    case center = "Center"
    case tile = "Tile"
    
    var nsWorkspaceOptions: [NSWorkspace.DesktopImageOptionKey: Any] {
        switch self {
        case .fillScreen:
            return [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                   .allowClipping: true]
        case .fit:
            return [.imageScaling: NSImageScaling.scaleProportionallyDown.rawValue,
                   .allowClipping: false]
        case .stretch:
            return [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                   .allowClipping: true]
        case .center:
            return [.imageScaling: NSImageScaling.scaleNone.rawValue,
                   .allowClipping: false]
        case .tile:
            return [.imageScaling: NSImageScaling.scaleNone.rawValue,
                   .allowClipping: false,
                   .fillColor: NSColor.black]
        }
    }
} 