import Foundation
import AppKit
import SwiftUI
import Error

// MARK: - Playlist Model
struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var wallpapers: [WallpaperItem]
    var isExpanded: Bool
    var playbackMode: PlaybackMode
    
    enum CodingKeys: String, CodingKey {
        case id, name, wallpapers, playbackMode
        // Don't persist isExpanded state
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        wallpapers = try container.decode([WallpaperItem].self, forKey: .wallpapers)
        playbackMode = try container.decode(PlaybackMode.self, forKey: .playbackMode)
        isExpanded = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wallpapers, forKey: .wallpapers)
        try container.encode(playbackMode, forKey: .playbackMode)
        // Don't encode isExpanded state
    }
    
    init(id: UUID = UUID(), name: String, wallpapers: [WallpaperItem] = [], isExpanded: Bool = false, playbackMode: PlaybackMode = .sequential) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.isExpanded = isExpanded
        self.playbackMode = playbackMode
    }
}

// MARK: - Wallpaper Models

/// Represents a wallpaper item in the application
struct WallpaperItem: Identifiable, Codable, Equatable {
    let id: UUID
    let path: URL
    let name: String
    var metadata: WallpaperMetadata?
    
    init(id: UUID = UUID(), path: URL, name: String? = nil) {
        self.id = id
        self.path = path
        self.name = name ?? path.lastPathComponent
    }
    
    /// Loads metadata for the wallpaper if available
    mutating func loadMetadata() {
        self.metadata = try? WallpaperMetadata.load(from: path)
    }
    
    /// Loads the wallpaper image
    func loadImage() -> NSImage? {
        return NSImage(contentsOf: path)
    }
    
    static func == (lhs: WallpaperItem, rhs: WallpaperItem) -> Bool {
        return lhs.id == rhs.id && lhs.path == rhs.path
    }
}

/// Stores metadata information about a wallpaper
struct WallpaperMetadata: Codable {
    let creationDate: Date?
    let fileSize: Int64
    let dimensions: CGSize?
    let colorSpace: String?
    let dpi: (x: Double, y: Double)?
    
    static func load(from url: URL) throws -> WallpaperMetadata {
        let resourceValues = try url.resourceValues(forKeys: [
            .creationDateKey,
            .fileSizeKey
        ])
        
        if let image = NSImage(contentsOf: url) {
            let rep = image.representations.first as? NSBitmapImageRep
            return WallpaperMetadata(
                creationDate: resourceValues.creationDate,
                fileSize: Int64(resourceValues.fileSize ?? 0),
                dimensions: image.size,
                colorSpace: rep?.colorSpaceName.rawValue,
                dpi: rep.map { (x: $0.pixelsWide.double, y: $0.pixelsHigh.double) }
            )
        }
        
        return WallpaperMetadata(
            creationDate: resourceValues.creationDate,
            fileSize: Int64(resourceValues.fileSize ?? 0),
            dimensions: nil,
            colorSpace: nil,
            dpi: nil
        )
    }
}

// MARK: - Playback Mode
enum PlaybackMode: String, Codable, CaseIterable {
    case sequential = "Sequential"
    case random = "Random"
    case shuffle = "Shuffle"
}

// MARK: - Display Mode
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

// MARK: - Error Types
enum WallpaperManagerError: Error {
    case invalidURL
    case invalidImage
    case playlistNotFound
    case playlistLimitExceeded
    case duplicatePlaylistName
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid file URL"
        case .invalidImage:
            return "Invalid image file"
        case .playlistNotFound:
            return "Playlist not found"
        case .playlistLimitExceeded:
            return "Maximum number of playlists reached"
        case .duplicatePlaylistName:
            return "A playlist with this name already exists"
        }
    }
}

// MARK: - Alert Types
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Preview Types
struct PlaylistPreviewData: Identifiable {
    let id: UUID
    let previewImages: [NSImage]
    let isActive: Bool
    
    init(id: UUID, previewImages: [NSImage], isActive: Bool) {
        self.id = id
        self.previewImages = previewImages
        self.isActive = isActive
    }
}

// MARK: - App State

/// Manages the global state of the application
final class AppState: ObservableObject {
    @Published var wallpapers: [WallpaperItem] = []
    @Published var selectedWallpaper: WallpaperItem?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    static let shared = AppState()
    
    private init() {}
    
    func addWallpaper(_ wallpaper: WallpaperItem) {
        if !wallpapers.contains(where: { $0.id == wallpaper.id }) {
            wallpapers.append(wallpaper)
        }
    }
    
    func removeWallpaper(_ wallpaper: WallpaperItem) {
        wallpapers.removeAll(where: { $0.id == wallpaper.id })
        if selectedWallpaper?.id == wallpaper.id {
            selectedWallpaper = nil
        }
    }
}

// MARK: - Theme Management

/// Manages theme settings for the application
final class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    static let shared = ThemeManager()
    
    private init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    func toggleTheme() {
        isDarkMode.toggle()
    }
}

// MARK: - Extensions

extension Double {
    var cgFloat: CGFloat {
        return CGFloat(self)
    }
}

extension Int {
    var double: Double {
        return Double(self)
    }
} 