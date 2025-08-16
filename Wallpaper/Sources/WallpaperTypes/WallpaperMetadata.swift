import Foundation
import AppKit

/// Contains metadata information about a wallpaper file
public struct WallpaperMetadata: Codable, Equatable, Sendable {
    /// Dimensions of the wallpaper image
    public let dimensions: CGSize
    /// Size of the wallpaper file in bytes
    public let fileSize: Int64
    /// Format of the image (e.g., JPEG, PNG, HEIC)
    public let format: String
    /// Color space of the image
    public let colorSpace: String?
    /// DPI (dots per inch) of the image
    public let dpi: Double?
    
    /// Cached aspect ratio value
    private let _aspectRatio: Double
    
    public init(
        dimensions: CGSize,
        fileSize: Int64,
        format: String,
        colorSpace: String? = nil,
        dpi: Double? = nil
    ) {
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.format = format
        self.colorSpace = colorSpace
        self.dpi = dpi
        self._aspectRatio = dimensions.width / dimensions.height
    }
    
    /// Returns the file size in a human-readable format (e.g., "1.2 MB")
    /// Uses the system's ByteCountFormatter for localized output
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    /// Returns the aspect ratio of the image (width/height)
    /// This value is cached during initialization for better performance
    public var aspectRatio: Double {
        _aspectRatio
    }
    
    /// Returns whether the image is in landscape orientation (width > height)
    /// Uses the cached aspect ratio for efficiency
    public var isLandscape: Bool {
        _aspectRatio > 1.0
    }
    
    /// Returns whether the image is in portrait orientation (height > width)
    /// Uses the cached aspect ratio for efficiency
    public var isPortrait: Bool {
        _aspectRatio < 1.0
    }
    
    /// Returns whether the image is square (width == height)
    /// Uses the cached aspect ratio for efficiency
    public var isSquare: Bool {
        abs(_aspectRatio - 1.0) < .ulpOfOne
    }
    
    /// Returns whether the image is considered high resolution (DPI >= 300)
    public var isHighResolution: Bool {
        guard let dpi = dpi else { return false }
        return dpi >= 300
    }
    
    /// Returns whether the image is in a wide color space (e.g., Display P3)
    public var isWideColorSpace: Bool {
        guard let colorSpace = colorSpace else { return false }
        return colorSpace.contains("P3") || colorSpace.contains("Wide")
    }
} 