import Foundation
import WallpaperTypes

/// Central mapping for converting domain errors to user-facing alert content
enum ErrorPresenter {
    struct AlertContent {
        let title: String
        let message: String
        let suggestion: String?
    }

    static func alertContent(for error: Error) -> AlertContent {
        if let w = error as? WallpaperTypes.WallpaperError {
            switch w {
            case .invalidScreen:
                return .init(title: "Invalid Screen", message: "The target screen is invalid.", suggestion: "Please ensure the target screen is valid.")
            case .setWallpaperFailed(let reason):
                return .init(title: "Failed to Set Wallpaper", message: reason, suggestion: "Ensure the image is valid and try again.")
            case .playlistNotFound:
                return .init(title: "Playlist Not Found", message: "The specified playlist could not be found.", suggestion: "Verify the playlist you selected still exists.")
            case .invalidURL(let msg):
                return .init(title: "Invalid Wallpaper URL", message: msg, suggestion: "Please ensure the file exists and you have permission to access it.")
            case .fileNotFound(let msg):
                return .init(title: "File Not Found", message: msg, suggestion: "Please verify the file exists and try again.")
            case .invalidImage(let msg):
                return .init(title: "Invalid Image File", message: msg, suggestion: "Please try with a different image file.")
            case .insufficientPermissions(let msg):
                return .init(title: "Insufficient Permissions", message: msg, suggestion: "Grant the necessary file access permissions in System Settings.")
            case .displayError(let msg):
                return .init(title: "Display Error", message: msg, suggestion: "Please check your display settings and try again.")
            case .rotationError(let msg):
                return .init(title: "Rotation Error", message: msg, suggestion: "Please check your rotation settings and try again.")
            case .playlistError(let msg):
                return .init(title: "Playlist Error", message: msg, suggestion: "Please check the playlist name or content.")
            case .metadataError(let msg):
                return .init(title: "Metadata Error", message: msg, suggestion: "The image file might be corrupted or unsupported.")
            case .networkError(let msg):
                return .init(title: "Network Error", message: msg, suggestion: "Check your internet connection and try again.")
            case .systemError(let underlying):
                return .init(title: "System Error", message: underlying.localizedDescription, suggestion: "Please try again later or contact support.")
            }
        }
        return .init(title: "Error", message: error.localizedDescription, suggestion: nil)
    }
}
