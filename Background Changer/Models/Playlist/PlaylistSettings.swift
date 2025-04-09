import Foundation

struct PlaylistSettings: Codable {
    var rotationInterval: TimeInterval
    var displayMode: DisplayMode
    var showOnAllSpaces: Bool
    var transitionEffect: TransitionEffect
    var transitionDuration: TimeInterval
    
    init(
        rotationInterval: TimeInterval = 60,
        displayMode: DisplayMode = .fillScreen,
        showOnAllSpaces: Bool = true,
        transitionEffect: TransitionEffect = .fade,
        transitionDuration: TimeInterval = 0.5
    ) {
        self.rotationInterval = rotationInterval
        self.displayMode = displayMode
        self.showOnAllSpaces = showOnAllSpaces
        self.transitionEffect = transitionEffect
        self.transitionDuration = transitionDuration
    }
}

enum TransitionEffect: String, Codable, CaseIterable {
    case fade = "Fade"
    case slide = "Slide"
    case dissolve = "Dissolve"
    case none = "None"
    
    var description: String {
        switch self {
        case .fade:
            return "Smooth fade between wallpapers"
        case .slide:
            return "Slide transition between wallpapers"
        case .dissolve:
            return "Cross-fade transition between wallpapers"
        case .none:
            return "Instant change between wallpapers"
        }
    }
} 