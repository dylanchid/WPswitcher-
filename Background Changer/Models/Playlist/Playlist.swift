import Foundation
import AppKit
import SwiftUI

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var wallpapers: [WallpaperItem]
    var isExpanded: Bool
    var playbackMode: PlaybackMode
    var settings: PlaylistSettings
    var lastError: WallpaperError?
    
    enum CodingKeys: String, CodingKey {
        case id, name, wallpapers, playbackMode, settings
        // Don't persist isExpanded state or errors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        wallpapers = try container.decode([WallpaperItem].self, forKey: .wallpapers)
        playbackMode = try container.decode(PlaybackMode.self, forKey: .playbackMode)
        settings = try container.decode(PlaylistSettings.self, forKey: .settings)
        isExpanded = false
        lastError = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wallpapers, forKey: .wallpapers)
        try container.encode(playbackMode, forKey: .playbackMode)
        try container.encode(settings, forKey: .settings)
        // Don't encode isExpanded state or errors
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        wallpapers: [WallpaperItem] = [],
        isExpanded: Bool = false,
        playbackMode: PlaybackMode = .sequential,
        settings: PlaylistSettings = PlaylistSettings()
    ) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.isExpanded = isExpanded
        self.playbackMode = playbackMode
        self.settings = settings
        self.lastError = nil
    }
    
    var stats: PlaylistStats {
        PlaylistStats.calculate(for: self)
    }
    
    var selectedWallpapers: [WallpaperItem] {
        wallpapers.filter { $0.isSelected }
    }
    
    var validWallpapers: [WallpaperItem] {
        wallpapers.filter { $0.isValid }
    }
    
    var invalidWallpapers: [WallpaperItem] {
        wallpapers.filter { !$0.isValid }
    }
    
    mutating func addWallpaper(_ wallpaper: WallpaperItem) {
        guard !wallpapers.contains(where: { $0.id == wallpaper.id }) else { return }
        wallpapers.append(wallpaper)
    }
    
    mutating func removeWallpaper(at index: Int) {
        guard index >= 0 && index < wallpapers.count else { return }
        wallpapers.remove(at: index)
    }
    
    mutating func moveWallpaper(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < wallpapers.count,
              destinationIndex >= 0 && destinationIndex <= wallpapers.count else { return }
        
        let wallpaper = wallpapers.remove(at: sourceIndex)
        wallpapers.insert(wallpaper, at: destinationIndex)
    }
    
    mutating func updateSettings(_ newSettings: PlaylistSettings) {
        settings = newSettings
    }
    
    mutating func validateWallpapers() async {
        var validWallpapers: [WallpaperItem] = []
        var invalidWallpapers: [WallpaperItem] = []
        
        for var wallpaper in wallpapers {
            do {
                _ = try await wallpaper.loadMetadata()
                validWallpapers.append(wallpaper)
            } catch {
                invalidWallpapers.append(wallpaper)
            }
        }
        
        self.wallpapers = validWallpapers + invalidWallpapers
    }
    
    mutating func reloadMetadata() async {
        for index in wallpapers.indices {
            do {
                _ = try await wallpapers[index].reloadMetadata()
            } catch {
                lastError = error as? WallpaperError
            }
        }
    }
} 