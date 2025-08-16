import AppKit
import Foundation

/// Represents the different ways a wallpaper can be displayed on the screen
public enum DisplayMode: String, Codable, CaseIterable {
    /// Fills the entire screen while maintaining aspect ratio
    case fillScreen = "Fill Screen"
    /// Fits the image to the screen while maintaining aspect ratio
    case fit = "Fit"
    /// Stretches the image to fill the screen
    case stretch = "Stretch"
    /// Centers the image on the screen
    case center = "Center"
    /// Tiles the image across the screen
    case tile = "Tile"
    
    /// Returns a human-readable description of the display mode
    public var description: String {
        switch self {
        case .fillScreen: return "Fills the entire screen, maintaining aspect ratio"
        case .fit: return "Fits the image to the screen while maintaining aspect ratio"
        case .stretch: return "Stretches the image to fill the screen"
        case .center: return "Centers the image on the screen"
        case .tile: return "Tiles the image across the screen"
        }
    }
    
    /// Returns the corresponding NSImageScaling value
    public var imageScaling: NSImageScaling {
        switch self {
        case .fillScreen: return .scaleProportionallyUpOrDown
        case .fit: return .scaleProportionallyDown
        case .stretch: return .scaleAxesIndependently
        case .center: return .scaleNone
        case .tile: return .scaleNone
        }
    }
    
    /// Returns whether the mode maintains aspect ratio
    public var maintainsAspectRatio: Bool {
        switch self {
        case .fillScreen, .fit: return true
        case .stretch, .center, .tile: return false
        }
    }
    
    /// Returns whether the mode fills the entire screen
    public var fillsScreen: Bool {
        switch self {
        case .fillScreen, .stretch, .tile: return true
        case .fit, .center: return false
        }
    }
}
