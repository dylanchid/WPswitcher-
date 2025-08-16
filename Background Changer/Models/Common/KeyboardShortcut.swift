import Foundation
import AppKit

/// Enum representing shortcut actions
public enum ShortcutAction: String, Codable, CaseIterable {
    case nextWallpaper = "Next Wallpaper"
    case previousWallpaper = "Previous Wallpaper"
    case toggleRotation = "Toggle Rotation"
    case showPreferences = "Show Preferences"
    case addWallpaper = "Add Wallpaper"
    
    public var description: String {
        return rawValue
    }
}

/// Struct representing a keyboard shortcut
public struct KeyboardShortcut: Codable, Identifiable {
    public var id: UUID
    public var action: ShortcutAction
    public var keyCode: UInt16
    private var modifierFlags: UInt
    
    public var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifierFlags) }
        set { modifierFlags = newValue.rawValue }
    }
    
    public init(id: UUID = UUID(),
         action: ShortcutAction,
         keyCode: UInt16,
         modifiers: NSEvent.ModifierFlags) {
        self.id = id
        self.action = action
        self.keyCode = keyCode
        self.modifierFlags = modifiers.rawValue
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, action, keyCode, modifierFlags
    }
}
