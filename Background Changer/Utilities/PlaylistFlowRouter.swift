import Foundation
import SwiftUI
import Wallpaper

enum PlaylistFlow: Identifiable, Equatable {
    case create
    case rename(Wallpaper.Playlist)

    var id: String {
        switch self {
        case .create: return "create"
        case .rename(let p): return "rename-\(p.id.uuidString)"
        }
    }

    static func == (lhs: PlaylistFlow, rhs: PlaylistFlow) -> Bool {
        switch (lhs, rhs) {
        case (.create, .create):
            return true
        case let (.rename(a), .rename(b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

@MainActor
final class PlaylistFlowRouter: ObservableObject {
    @Published var activeFlow: PlaylistFlow?
    weak var coordinator: PlaylistCoordinator?

    func startCreate() {
        coordinator?.startCreateFlow()
    }

    func startRename(_ playlist: Wallpaper.Playlist) {
        coordinator?.startEditFlow(playlist: playlist)
    }

    func dismiss() { activeFlow = nil }
    
    func present<Content: View>(view: Content, as presentationStyle: PresentationStyle) {
        // For now, we'll just set the active flow to trigger UI updates
        // In a more complete implementation, this would handle actual presentation
        switch presentationStyle {
        case .sheet:
            activeFlow = .create // This is simplified - you'd want more specific flows
        case .window, .popover:
            // Handle other presentation styles
            break
        }
    }
}

enum PresentationStyle {
    case sheet
    case window
    case popover
}
