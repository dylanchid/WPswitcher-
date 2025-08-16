import Foundation
import AppKit
import SwiftUI



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