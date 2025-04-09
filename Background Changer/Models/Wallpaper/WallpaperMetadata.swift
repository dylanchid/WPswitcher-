import Foundation
import AppKit
import os.log

/// Represents metadata for a wallpaper image
class WallpaperMetadata: NSObject {
    private let logger = Logger(subsystem: "com.backgroundchanger", category: "WallpaperMetadata")
    
    /// The URL of the image file
    let url: URL
    
    /// The name of the image file
    let name: String
    
    /// The dimensions of the image
    let size: CGSize
    
    /// The file size in bytes
    let fileSize: Int64
    
    /// The last modification date of the file
    let lastModified: Date
    
    /// The image format
    let format: String
    
    /// The aspect ratio of the image
    var aspectRatio: CGFloat {
        size.width / size.height
    }
    
    /// The file size in a human-readable format
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }
    
    /// The last modified date in a human-readable format
    var formattedLastModified: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: lastModified)
    }
    
    /// Creates a new WallpaperMetadata instance
    /// - Parameters:
    ///   - url: The URL of the image file
    ///   - name: The name of the image file
    ///   - size: The dimensions of the image
    ///   - fileSize: The file size in bytes
    ///   - lastModified: The last modification date
    ///   - format: The image format
    init(url: URL, name: String, size: CGSize, fileSize: Int64, lastModified: Date, format: String) {
        self.url = url
        self.name = name
        self.size = size
        self.fileSize = fileSize
        self.lastModified = lastModified
        self.format = format
        super.init()
    }
    
    /// Loads metadata from a URL asynchronously
    /// - Parameter url: The URL to load metadata from
    /// - Returns: A new WallpaperMetadata instance
    /// - Throws: WallpaperError if loading fails
    static func load(from url: URL) async throws -> WallpaperMetadata {
        logger.debug("Loading metadata from URL: \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("File not found at path: \(url.path)")
            throw WallpaperError.fileSystemError("File not found at path: \(url.path)")
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64,
              let lastModified = attributes[.modificationDate] as? Date else {
            logger.error("Failed to read file attributes for: \(url.path)")
            throw WallpaperError.fileSystemError("Failed to read file attributes")
        }
        
        logger.debug("Loading image from URL: \(url.path)")
        let image = try await NSImage(contentsOf: url)
        guard let image = image else {
            logger.error("Failed to load image from: \(url.path)")
            throw WallpaperError.invalidImage("Failed to load image")
        }
        
        let format = url.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png", "gif", "heic"].contains(format) else {
            logger.error("Unsupported image format: \(format) for file: \(url.path)")
            throw WallpaperError.invalidFormat("Unsupported image format: \(format)")
        }
        
        logger.debug("Successfully loaded metadata for: \(url.path)")
        return WallpaperMetadata(
            url: url,
            name: url.lastPathComponent,
            size: image.size,
            fileSize: fileSize,
            lastModified: lastModified,
            format: format
        )
    }
    
    /// Validates if the metadata represents a valid wallpaper
    /// - Returns: True if the metadata is valid
    func isValid() -> Bool {
        logger.debug("Validating metadata for: \(self.name)")
        
        guard size.width > 0 && size.height > 0 else {
            logger.error("Invalid image dimensions for: \(self.name)")
            return false
        }
        guard fileSize > 0 else {
            logger.error("Invalid file size for: \(self.name)")
            return false
        }
        guard !format.isEmpty else {
            logger.error("Empty format for: \(self.name)")
            return false
        }
        
        logger.debug("Metadata validation successful for: \(self.name)")
        return true
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? WallpaperMetadata else { return false }
        return url == other.url &&
               size == other.size &&
               fileSize == other.fileSize &&
               lastModified == other.lastModified &&
               format == other.format
    }
    
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(url)
        hasher.combine(size.width)
        hasher.combine(size.height)
        hasher.combine(fileSize)
        hasher.combine(lastModified)
        hasher.combine(format)
        return hasher.finalize()
    }
} 