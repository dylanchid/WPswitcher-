import Foundation
import AppKit

// MARK: - Enhanced Error System with Recovery Actions

/// Rich error types with recovery actions and detailed context
/// Named AppError to avoid conflict with WallpaperTypes.WallpaperError
public enum AppError: LocalizedError, Equatable {
    case invalidImage(URL, reason: ImageErrorReason)
    case playlistOperation(PlaylistError)
    case systemOperation(SystemError)
    case stateManagement(StateError)
    case network(NetworkError)
    case permission(PermissionError)
    
    // MARK: - Image Error Reasons
    public enum ImageErrorReason: Equatable {
        case unsupportedFormat(String)
        case corruptedFile
        case tooLarge(size: Int64, maxSize: Int64)
        case tooSmall(dimensions: CGSize, minDimensions: CGSize)
        case invalidDimensions
        case insufficientColorDepth
        case encryptedOrProtected
        
        var description: String {
            switch self {
            case .unsupportedFormat(let format):
                return "Unsupported format: \(format)"
            case .corruptedFile:
                return "File appears to be corrupted"
            case .tooLarge(let size, let maxSize):
                return "File too large (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) > \(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)))"
            case .tooSmall(let dimensions, let minDimensions):
                return "Image too small (\(Int(dimensions.width))×\(Int(dimensions.height)) < \(Int(minDimensions.width))×\(Int(minDimensions.height)))"
            case .invalidDimensions:
                return "Invalid image dimensions"
            case .insufficientColorDepth:
                return "Insufficient color depth"
            case .encryptedOrProtected:
                return "Image is encrypted or protected"
            }
        }
    }
    
    // MARK: - Playlist Errors
    public enum PlaylistError: Equatable {
        case notFound(UUID)
        case empty
        case invalidName(String)
        case duplicateWallpaper(UUID)
        case maximumSizeReached(current: Int, maximum: Int)
        case corruptedData
        case migrationFailed(from: String, to: String)
        
        var description: String {
            switch self {
            case .notFound(let id):
                return "Playlist not found: \(id)"
            case .empty:
                return "Playlist is empty"
            case .invalidName(let name):
                return "Invalid playlist name: \(name)"
            case .duplicateWallpaper(let id):
                return "Wallpaper already exists in playlist: \(id)"
            case .maximumSizeReached(let current, let maximum):
                return "Playlist size limit reached (\(current)/\(maximum))"
            case .corruptedData:
                return "Playlist data is corrupted"
            case .migrationFailed(let from, let to):
                return "Failed to migrate from version \(from) to \(to)"
            }
        }
    }
    
    // MARK: - System Errors
    public enum SystemError: Equatable {
        case insufficientPermissions(String)
        case diskSpaceLow(available: Int64, required: Int64)
        case memoryPressure
        case displayNotFound
        case osVersionUnsupported(current: String, required: String)
        case serviceUnavailable(String)
        
        var description: String {
            switch self {
            case .insufficientPermissions(let operation):
                return "Insufficient permissions for: \(operation)"
            case .diskSpaceLow(let available, let required):
                return "Insufficient disk space (available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)), required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)))"
            case .memoryPressure:
                return "System under memory pressure"
            case .displayNotFound:
                return "Target display not found"
            case .osVersionUnsupported(let current, let required):
                return "OS version \(current) is not supported (requires \(required))"
            case .serviceUnavailable(let service):
                return "Service unavailable: \(service)"
            }
        }
    }
    
    // MARK: - State Management Errors
    public enum StateError: Equatable {
        case invalidWallpaper
        case playlistNotFound
        case noUndoAvailable
        case noRedoAvailable
        case corruptedState
        case migrationRequired
        case concurrentModification
        
        var description: String {
            switch self {
            case .invalidWallpaper:
                return "Invalid wallpaper item"
            case .playlistNotFound:
                return "Playlist not found in state"
            case .noUndoAvailable:
                return "No undo operation available"
            case .noRedoAvailable:
                return "No redo operation available"
            case .corruptedState:
                return "Application state is corrupted"
            case .migrationRequired:
                return "State migration required"
            case .concurrentModification:
                return "Concurrent state modification detected"
            }
        }
    }
    
    // MARK: - Network Errors
    public enum NetworkError: Equatable {
        case noConnection
        case timeout
        case invalidURL(String)
        case downloadFailed(statusCode: Int)
        case quotaExceeded
        
        var description: String {
            switch self {
            case .noConnection:
                return "No network connection"
            case .timeout:
                return "Network request timed out"
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .downloadFailed(let statusCode):
                return "Download failed with status code: \(statusCode)"
            case .quotaExceeded:
                return "Network quota exceeded"
            }
        }
    }
    
    // MARK: - Permission Errors
    public enum PermissionError: Equatable {
        case fileSystemAccess(String)
        case photoLibraryAccess
        case screenRecording
        case accessibility
        
        var description: String {
            switch self {
            case .fileSystemAccess(let path):
                return "File system access denied: \(path)"
            case .photoLibraryAccess:
                return "Photo library access denied"
            case .screenRecording:
                return "Screen recording permission required"
            case .accessibility:
                return "Accessibility permission required"
            }
        }
    }
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        case .invalidImage(let url, let reason):
            return "Cannot load image '\(url.lastPathComponent)': \(reason.description)"
        case .playlistOperation(let error):
            return "Playlist error: \(error.description)"
        case .systemOperation(let error):
            return "System error: \(error.description)"
        case .stateManagement(let error):
            return "State management error: \(error.description)"
        case .network(let error):
            return "Network error: \(error.description)"
        case .permission(let error):
            return "Permission error: \(error.description)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidImage(_, .tooLarge(_, let maxSize)):
            return "Please use an image smaller than \(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file))"
        case .invalidImage(_, .unsupportedFormat(let format)):
            return "The format '\(format)' is not supported. Please use JPEG, PNG, HEIC, or TIFF."
        case .invalidImage(_, .tooSmall(_, let minDimensions)):
            return "Please use an image at least \(Int(minDimensions.width))×\(Int(minDimensions.height)) pixels."
        case .playlistOperation(.empty):
            return "Add some wallpapers to the playlist before starting rotation."
        case .systemOperation(.diskSpaceLow):
            return "Free up some disk space and try again."
        case .permission(.fileSystemAccess):
            return "Grant file access permission in System Preferences > Security & Privacy."
        default:
            return nil
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .invalidImage(let url, .corruptedFile):
            return [
                .retry(title: "Try Again", action: { try await ImageProcessor.shared.repairImage(at: url) }),
                .ignore(title: "Skip This Image"),
                .reportIssue(title: "Report Issue")
            ]
        case .invalidImage(_, .unsupportedFormat):
            return [
                .ignore(title: "Skip This Image"),
                .openHelp(title: "Supported Formats", url: URL(string: "https://support.apple.com/guide/preview/supported-image-formats")!)
            ]
        case .playlistOperation(.empty):
            return [
                .openSettings(title: "Add Wallpapers", settingsTab: .wallpapers),
                .ignore(title: "Cancel")
            ]
        case .systemOperation(.insufficientPermissions):
            return [
                .openSystemPreferences(title: "Open Privacy Settings", pane: "Security"),
                .ignore(title: "Continue Without Permission")
            ]
        case .permission:
            return [
                .openSystemPreferences(title: "Grant Permissions", pane: "Security"),
                .openHelp(title: "Learn More", url: URL(string: "https://support.apple.com/guide/mac-help/control-access-to-files-and-folders-mchlp1203")!)
            ]
        default:
            return [.ignore(title: "Dismiss")]
        }
    }
}

// MARK: - Recovery Actions
public enum RecoveryAction {
    case retry(title: String, action: () async throws -> Void)
    case ignore(title: String)
    case reportIssue(title: String)
    case openSettings(title: String, settingsTab: SettingsTab)
    case openSystemPreferences(title: String, pane: String)
    case openHelp(title: String, url: URL)
    
    public enum SettingsTab {
        case general
        case wallpapers
        case playlists
        case rotation
        case display
        case advanced
    }
}

// MARK: - Error Context
public struct ErrorContext {
    public let timestamp: Date
    public let operation: String
    public let userContext: [String: Any]
    public let systemContext: SystemContext
    
    public init(
        timestamp: Date = Date(),
        operation: String,
        userContext: [String: Any] = [:],
        systemContext: SystemContext = SystemContext()
    ) {
        self.timestamp = timestamp
        self.operation = operation
        self.userContext = userContext
        self.systemContext = systemContext
    }
}

public struct SystemContext {
    public let osVersion: String
    public let appVersion: String
    public let memoryPressure: Bool
    public let diskSpace: Int64
    public let displayCount: Int
    
    public init(
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        memoryPressure: Bool = false,
        diskSpace: Int64 = 0,
        displayCount: Int = NSScreen.screens.count
    ) {
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.memoryPressure = memoryPressure
        self.diskSpace = diskSpace
        self.displayCount = displayCount
    }
}

// MARK: - Legacy Error Support
extension AppError {
    // Helper methods to create errors from legacy error types
    public static func systemError(_ error: NSError) -> AppError {
        return .systemOperation(.serviceUnavailable(error.localizedDescription))
    }

    public static func systemError(_ error: Error) -> AppError {
        return .systemOperation(.serviceUnavailable(error.localizedDescription))
    }

    public static func fileNotFound(_ path: String) -> AppError {
        return .systemOperation(.insufficientPermissions("File access: \(path)"))
    }

    public static func invalidURL(_ url: String) -> AppError {
        return .network(.invalidURL(url))
    }

    public static func playlistError(_ message: String) -> AppError {
        return .playlistOperation(.invalidName(message))
    }
}
