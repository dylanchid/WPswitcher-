import Foundation
import AppKit
import os.log

/// Represents a single wallpaper with lazy loading capabilities
struct WallpaperItem: Identifiable, Codable {
    private let logger = Logger(subsystem: "com.backgroundchanger", category: "WallpaperItem")
    
    let id: UUID
    let path: String
    let name: String
    var isSelected: Bool
    private var _metadata: WallpaperMetadata?
    var lastError: WallpaperError?
    
    init(id: UUID = UUID(), path: String, name: String, isSelected: Bool = false, metadata: WallpaperMetadata? = nil) {
        self.id = id
        self.path = path
        self.name = name
        self.isSelected = isSelected
        self._metadata = metadata
        self.lastError = nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, path, name, metadata
        // Don't persist selection state or errors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        path = try container.decode(String.self, forKey: .path)
        name = try container.decode(String.self, forKey: .name)
        _metadata = try container.decodeIfPresent(WallpaperMetadata.self, forKey: .metadata)
        isSelected = false
        lastError = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(_metadata, forKey: .metadata)
        // Don't encode isSelected state or errors
    }
    
    /// The URL of the wallpaper file
    var fileURL: URL? {
        if path.hasPrefix("file://") {
            return URL(string: path)
        } else {
            return URL(fileURLWithPath: path)
        }
    }
    
    /// The cached metadata of the wallpaper
    var metadata: WallpaperMetadata? {
        get {
            logger.debug("Getting metadata for wallpaper: \(self.name)")
            if _metadata == nil, let url = fileURL {
                _metadata = WallpaperCache.shared.getMetadata(for: url)
                if _metadata != nil {
                    logger.debug("Retrieved metadata from cache for: \(self.name)")
                }
            }
            return _metadata
        }
        set {
            logger.debug("Setting metadata for wallpaper: \(self.name)")
            _metadata = newValue
        }
    }
    
    /// Validates if the wallpaper format is supported
    var isValidFormat: Bool {
        guard let url = fileURL else { return false }
        let validExtensions = ["jpg", "jpeg", "png", "gif", "heic"]
        return validExtensions.contains(url.pathExtension.lowercased())
    }
    
    /// Validates if the wallpaper size is valid
    var isValidSize: Bool {
        guard let metadata = metadata else { return false }
        return metadata.size.width > 0 && metadata.size.height > 0
    }
    
    /// Checks if the wallpaper is valid and accessible
    var isValid: Bool {
        guard let url = fileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path) && isValidFormat
    }
    
    /// Clears the cached data for this wallpaper
    func clearCache() {
        if let url = fileURL {
            WallpaperCache.shared.removeImage(for: url)
            WallpaperCache.shared.removeMetadata(for: url)
        }
    }
    
    /// Loads metadata for the wallpaper asynchronously
    /// - Returns: The loaded metadata
    /// - Throws: WallpaperError if loading fails
    func loadMetadata() async throws -> WallpaperMetadata {
        logger.debug("Loading metadata for wallpaper: \(self.name)")
        
        guard let url = fileURL else {
            logger.error("Invalid file path: \(self.path)")
            throw WallpaperError.invalidURL("Invalid file path: \(path)")
        }
        
        if let cachedMetadata = WallpaperCache.shared.getMetadata(for: url) {
            logger.debug("Using cached metadata for: \(self.name)")
            return cachedMetadata
        }
        
        do {
            logger.debug("Loading fresh metadata for: \(self.name)")
            let metadata = try await WallpaperMetadata.load(from: url)
            WallpaperCache.shared.setMetadata(metadata, for: url)
            logger.debug("Successfully loaded metadata for: \(self.name)")
            return metadata
        } catch {
            logger.error("Failed to load metadata for \(self.name): \(error.localizedDescription)")
            throw WallpaperError.metadataLoadFailed(error.localizedDescription)
        }
    }
    
    /// Reloads metadata for the wallpaper, bypassing cache
    /// - Returns: The reloaded metadata
    /// - Throws: WallpaperError if reloading fails
    func reloadMetadata() async throws -> WallpaperMetadata {
        clearCache()
        return try await loadMetadata()
    }
    
    /// Loads a batch of wallpapers asynchronously
    /// - Parameter items: The wallpapers to load
    /// - Returns: Array of loaded wallpapers
    /// - Throws: WallpaperError if loading fails
    static func loadBatch(_ items: [WallpaperItem]) async throws -> [WallpaperItem] {
        try await withThrowingTaskGroup(of: WallpaperItem.self) { group in
            for var item in items {
                group.addTask {
                    _ = try await item.loadMetadata()
                    return item
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }
    
    func loadImage() async throws -> NSImage {
        guard let url = fileURL else {
            throw WallpaperError.invalidURL
        }
        
        // Check cache first
        if let cachedImage = WallpaperCache.shared.getImage(for: url) {
            return cachedImage
        }
        
        do {
            let image = try await NSImage(contentsOf: url)
            guard let image = image else {
                throw WallpaperError.invalidImage
            }
            
            // Cache the image
            WallpaperCache.shared.setImage(image, for: url)
            
            return image
        } catch {
            throw WallpaperError.invalidImage
        }
    }
} 