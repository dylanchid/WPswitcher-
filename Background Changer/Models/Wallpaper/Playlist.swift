import Foundation
import CoreData
import Wallpaper

@objc(PlaylistEntity)
public class PlaylistEntity: NSManagedObject, Identifiable {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistEntity> {
        return NSFetchRequest<PlaylistEntity>(entityName: "PlaylistEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var wallpapers: [URL]
    @NSManaged public var appearanceModeRaw: String
    @NSManaged public var playbackModeRaw: String

    public var appearanceMode: PlaylistAppearanceMode {
        get { PlaylistAppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    public var playbackMode: Wallpaper.PlaybackMode {
        get { Wallpaper.PlaybackMode(rawValue: playbackModeRaw) ?? .sequential }
        set { playbackModeRaw = newValue.rawValue }
    }
}

public enum PlaylistAppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light Mode"
        case .dark: return "Dark Mode"
        }
    }
} 