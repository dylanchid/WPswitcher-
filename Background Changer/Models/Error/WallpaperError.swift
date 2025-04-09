import Foundation

/// Errors that can occur during wallpaper operations
enum WallpaperError: AppError {
    // MARK: - Error Cases
    
    /// File System Errors
    case fileNotFound(String)
    case fileAccessDenied(String)
    case invalidURL(String)
    case invalidPath(String)
    
    /// Image Processing Errors
    case invalidImage(String)
    case imageLoadFailed(String)
    case metadataLoadFailed(String)
    case thumbnailGenerationFailed(String)
    
    /// System Errors
    case invalidScreen
    case setWallpaperFailed(String)
    case systemPermissionDenied(String)
    
    /// Playlist Errors
    case playlistNotFound(UUID)
    case playlistLimitExceeded
    case emptyPlaylist(UUID)
    case invalidPlaylistOperation(String)
    
    /// Data Management Errors
    case saveFailed(String)
    case loadFailed(String)
    case migrationFailed(String)
    case invalidData(String)
    
    // MARK: - AppError Implementation
    
    var errorCode: Int {
        switch self {
        case .fileNotFound: return 1001
        case .fileAccessDenied: return 1002
        case .invalidURL: return 1003
        case .invalidPath: return 1004
        case .invalidImage: return 1005
        case .imageLoadFailed: return 1006
        case .metadataLoadFailed: return 1007
        case .thumbnailGenerationFailed: return 1008
        case .invalidScreen: return 1009
        case .setWallpaperFailed: return 1010
        case .systemPermissionDenied: return 1011
        case .playlistNotFound: return 2001
        case .playlistLimitExceeded: return 2002
        case .emptyPlaylist: return 2003
        case .invalidPlaylistOperation: return 2004
        case .saveFailed: return 3001
        case .loadFailed: return 3002
        case .migrationFailed: return 3003
        case .invalidData: return 3004
        }
    }
    
    var errorDescription: String? {
        switch self {
        // File System Errors
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied to file: \(path)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
            
        // Image Processing Errors
        case .invalidImage(let path):
            return "Invalid or corrupted image at: \(path)"
        case .imageLoadFailed(let reason):
            return "Failed to load image: \(reason)"
        case .metadataLoadFailed(let reason):
            return "Failed to load image metadata: \(reason)"
        case .thumbnailGenerationFailed(let reason):
            return "Failed to generate thumbnail: \(reason)"
            
        // System Errors
        case .invalidScreen:
            return "Invalid or disconnected screen"
        case .setWallpaperFailed(let reason):
            return "Failed to set wallpaper: \(reason)"
        case .systemPermissionDenied(let permission):
            return "System permission denied: \(permission)"
            
        // Playlist Errors
        case .playlistNotFound(let id):
            return "Playlist not found with ID: \(id)"
        case .playlistLimitExceeded:
            return "Maximum number of playlists reached"
        case .emptyPlaylist(let id):
            return "Playlist is empty: \(id)"
        case .invalidPlaylistOperation(let reason):
            return "Invalid playlist operation: \(reason)"
            
        // Data Management Errors
        case .saveFailed(let reason):
            return "Failed to save data: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load data: \(reason)"
        case .migrationFailed(let reason):
            return "Data migration failed: \(reason)"
        case .invalidData(let reason):
            return "Invalid data format: \(reason)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .fileNotFound, .invalidPath:
            return "The specified file could not be found in the file system"
        case .fileAccessDenied, .systemPermissionDenied:
            return "The application doesn't have the required permissions"
        case .invalidImage, .imageLoadFailed:
            return "The image file is corrupted or in an unsupported format"
        case .playlistLimitExceeded:
            return "The maximum number of allowed playlists has been reached"
        case .emptyPlaylist:
            return "Cannot activate a playlist with no wallpapers"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound, .invalidPath:
            return "Please verify the file exists and try again"
        case .fileAccessDenied, .systemPermissionDenied:
            return "Check the app's permissions in System Settings"
        case .invalidImage, .imageLoadFailed:
            return "Try using a different image file"
        case .playlistLimitExceeded:
            return "Delete unused playlists to create new ones"
        case .emptyPlaylist:
            return "Add wallpapers to the playlist before activating it"
        default:
            return "Try again or contact support if the problem persists"
        }
    }
} 