import Foundation

/// Playback modes for playlists shared across modules
@preconcurrency
public enum PlaybackMode: String, Codable, CaseIterable {
    case sequential = "Sequential"
    case random = "Random"
    case shuffle = "Shuffle"

    public var description: String {
        switch self {
        case .sequential: return "Play wallpapers in order"
        case .random: return "Play wallpapers randomly"
        case .shuffle: return "Shuffle wallpapers once"
        }
    }
}
