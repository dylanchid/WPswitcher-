import Foundation

/// Represents errors that can occur during wallpaper operations
public enum WallpaperError: LocalizedError {
    /// Invalid screen specified
    case invalidScreen
    /// Failed to set wallpaper
    case setWallpaperFailed(String)
    /// Playlist not found
    case playlistNotFound
    /// Invalid URL provided
    case invalidURL(String)
    /// File not found at the specified path
    case fileNotFound(String)
    /// Invalid or unsupported image format
    case invalidImage(String)
    /// Insufficient permissions to perform the operation
    case insufficientPermissions(String)
    /// Error related to display settings
    case displayError(String)
    /// Error during wallpaper rotation
    case rotationError(String)
    /// Error related to playlist operations
    case playlistError(String)
    /// Error reading or processing image metadata
    case metadataError(String)
    /// Network error during download
    case networkError(String)
    /// System-level error
    case systemError(Error)
    /// Unsupported file format
    case unsupportedFormat(String)
    /// Invalid name provided
    case invalidName(String)
    
    /// Returns a localized description of the error
    public var errorDescription: String? {
        switch self {
        case .invalidScreen:
            return "Invalid screen specified"
        case .setWallpaperFailed(let message):
            return "Failed to set wallpaper: \(message)"
        case .playlistNotFound:
            return "Playlist not found"
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .fileNotFound(let message):
            return "File not found: \(message)"
        case .invalidImage(let message):
            return "Invalid image: \(message)"
        case .insufficientPermissions(let message):
            return "Insufficient permissions: \(message)"
        case .displayError(let message):
            return "Display error: \(message)"
        case .rotationError(let message):
            return "Rotation error: \(message)"
        case .playlistError(let message):
            return "Playlist error: \(message)"
        case .metadataError(let message):
            return "Metadata error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .invalidName(let message):
            return "Invalid name: \(message)"
        }
    }
    
    /// Returns a localized suggestion for recovering from the error
    public var recoverySuggestion: String? {
        switch self {
        case .invalidScreen:
            return "Please ensure the target screen is valid."
        case .setWallpaperFailed:
            return "Please try again. If the issue persists, ensure the image is valid and accessible."
        case .playlistNotFound:
            return "The specified playlist could not be found. Please check the playlist ID."
        case .invalidURL:
            return "Please check the URL and try again."
        case .fileNotFound:
            return "Please verify the file exists and try again."
        case .invalidImage:
            return "Please use a supported image format (JPEG, PNG, HEIC)."
        case .insufficientPermissions:
            return "Please grant the necessary permissions and try again."
        case .displayError:
            return "Please check your display settings and try again."
        case .rotationError:
            return "Please check your rotation settings and try again."
        case .playlistError:
            return "Please verify your playlist settings and try again."
        case .metadataError:
            return "Please verify the image metadata and try again."
        case .networkError:
            return "Please check your internet connection and try again."
        case .systemError:
            return "Please try again later or contact support if the issue persists."
        case .unsupportedFormat:
            return "Please use a supported image format (JPEG, PNG, HEIC, BMP, TIFF)."
        case .invalidName:
            return "Please provide a valid name for the wallpaper."
        }
    }
    
    /// Returns whether the error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .systemError:
            return false
        default:
            return true
        }
    }
    
    /// Returns the error code for logging purposes
    public var errorCode: String {
        switch self {
        case .invalidScreen: return "W000"
        case .setWallpaperFailed: return "W001"
        case .playlistNotFound: return "W002"
        case .invalidURL: return "W003"
        case .fileNotFound: return "W004"
        case .invalidImage: return "W005"
        case .insufficientPermissions: return "W006"
        case .displayError: return "W007"
        case .rotationError: return "W008"
        case .playlistError: return "W009"
        case .metadataError: return "W010"
        case .networkError: return "W011"
        case .systemError: return "W012"
        case .unsupportedFormat: return "W013"
        case .invalidName: return "W014"
        }
    }
} 