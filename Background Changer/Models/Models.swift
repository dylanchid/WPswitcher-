import Foundation
import AppKit
import SwiftUI

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
    
    init(id: UUID = UUID(), name: String, wallpapers: [WallpaperItem] = [], isExpanded: Bool = false, playbackMode: PlaybackMode = .sequential) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.isExpanded = isExpanded
        self.playbackMode = playbackMode
    }
}

// MARK: - Wallpaper Item Model
struct WallpaperItem: Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    var isSelected: Bool
    
    init(id: UUID = UUID(), path: String, name: String, isSelected: Bool = false) {
        self.id = id
        self.path = path
        self.name = name
        self.isSelected = isSelected
    }
    
    enum CodingKeys: String, CodingKey {
        case id, path, name
        // Don't persist selection state
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        name = try container.decode(String.self, forKey: .name)
        isSelected = false
    }
    
    var fileURL: URL? {
        if path.hasPrefix("file://") {
            return URL(string: path)
        } else {
            return URL(fileURLWithPath: path)
        }
    }
}

// MARK: - Playback Mode
enum PlaybackMode: String, Codable {
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
enum WallpaperError: Error {
    case invalidScreen
    case invalidURL
    case setWallpaperFailed(String)
}

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