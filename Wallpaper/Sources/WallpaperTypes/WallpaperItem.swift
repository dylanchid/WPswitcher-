import Foundation
import AppKit

/// Represents a wallpaper item in the application with enhanced validation and lazy loading
public struct WallpaperItem: Identifiable, Codable, Equatable, Sendable {
    /// Unique identifier for the wallpaper
    public let id: UUID
    /// URL pointing to the wallpaper file
    public let url: URL
    /// Display name of the wallpaper
    public var name: String
    /// Display mode for this wallpaper
    public var displayMode: DisplayMode
    /// Whether the wallpaper is marked as favorite
    public private(set) var isFavorite: Bool
    /// Set of tags associated with the wallpaper
    public private(set) var tags: Set<String>
    /// Creation date of the wallpaper entry
    public let createdAt: Date
    /// Last update date of the wallpaper entry
    public private(set) var updatedAt: Date
    /// Cached metadata about the wallpaper file (not persisted)
    private var _cachedMetadata: WallpaperMetadata?
    
    // MARK: - Coding Keys (exclude cached metadata)
    private enum CodingKeys: String, CodingKey {
        case id, url, name, displayMode, isFavorite, tags, createdAt, updatedAt
    }
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        displayMode: DisplayMode = .fillScreen,
        isFavorite: Bool = false,
        tags: Set<String> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.displayMode = displayMode
        self.isFavorite = isFavorite
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self._cachedMetadata = nil
    }
    
    // MARK: - Codable Implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        name = try container.decode(String.self, forKey: .name)
        displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .fillScreen
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        tags = try container.decodeIfPresent(Set<String>.self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        _cachedMetadata = nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(name, forKey: .name)
        try container.encode(displayMode, forKey: .displayMode)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    public static func == (lhs: WallpaperItem, rhs: WallpaperItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Validation
    /// Validates that the wallpaper file exists and is accessible
    public var isValid: Bool {
        guard url.isFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Validates that the file is a supported image format
    public var isSupportedFormat: Bool {
        let supportedExtensions = ["jpg", "jpeg", "png", "bmp", "tiff", "tif", "heic", "heif"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    /// Comprehensive validation
    public func validate() throws {
        guard isValid else {
            throw WallpaperError.fileNotFound(url.path)
        }
        guard isSupportedFormat else {
            throw WallpaperError.unsupportedFormat(url.pathExtension)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WallpaperError.invalidName("Name cannot be empty")
        }
    }
    
    // MARK: - Smart Metadata Loading
    /// Gets metadata with lazy loading and caching
    public func metadata() async throws -> WallpaperMetadata {
        // Return cached if available
        if let cached = _cachedMetadata {
            return cached
        }
        
        // Load and cache metadata
        let metadata = try await loadMetadata()
        return metadata
    }
    
    /// Preloads metadata and caches it internally
    public mutating func preloadMetadata() async throws {
        _cachedMetadata = try await metadata()
        self.updatedAt = Date()
    }
    
    private func loadMetadata() async throws -> WallpaperMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let image = NSImage(contentsOf: self.url) else {
                        continuation.resume(throwing: WallpaperError.invalidImage(self.url.path))
                        return
                    }
                    
                    let attributes = try FileManager.default.attributesOfItem(atPath: self.url.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    let metadata = WallpaperMetadata(
                        dimensions: CGSize(width: image.size.width, height: image.size.height),
                        fileSize: fileSize,
                        format: self.url.pathExtension.uppercased(),
                        colorSpace: "Unknown"
                    )
                    
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    /// Updates the updatedAt timestamp
    private mutating func touchUpdatedAt() {
        updatedAt = Date()
    }
    
    /// Sets the favorite status explicitly
    @discardableResult
    public mutating func setFavorite(_ favorite: Bool) -> Bool {
        guard isFavorite != favorite else { return isFavorite }
        isFavorite = favorite
        touchUpdatedAt()
        return isFavorite
    }
    
    /// Updates the display mode
    public mutating func setDisplayMode(_ mode: DisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        touchUpdatedAt()
    }
    
    /// Updates the name with validation
    public mutating func setName(_ newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw WallpaperError.invalidName("Name cannot be empty")
        }
        name = trimmedName
        touchUpdatedAt()
    }
    
    /// Updates the wallpaper's favorite status and returns the new state
    @discardableResult
    public mutating func toggleFavorite() -> Bool {
        isFavorite.toggle()
        touchUpdatedAt()
        return isFavorite
    }
    
    /// Adds multiple tags to the wallpaper
    /// - Parameter tags: The tags to add
    /// - Returns: The number of new tags added
    @discardableResult
    public mutating func addTags(_ newTags: Set<String>) -> Int {
        let validTags = newTags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let initialCount = tags.count
        tags.formUnion(validTags)
        return tags.count - initialCount
    }
    
    /// Adds a single tag to the wallpaper
    /// - Parameter tag: The tag to add
    /// - Returns: true if the tag was added, false if it was invalid or already present
    @discardableResult
    public mutating func addTag(_ tag: String) -> Bool {
        guard !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let (inserted, _) = tags.insert(tag)
        return inserted
    }
    
    /// Removes multiple tags from the wallpaper
    /// - Parameter tags: The tags to remove
    /// - Returns: The number of tags removed
    @discardableResult
    public mutating func removeTags(_ tagsToRemove: Set<String>) -> Int {
        let initialCount = tags.count
        tags.subtract(tagsToRemove)
        return initialCount - tags.count
    }
    
    /// Removes a single tag from the wallpaper
    /// - Parameter tag: The tag to remove
    /// - Returns: true if the tag was removed, false if it wasn't present
    @discardableResult
    public mutating func removeTag(_ tag: String) -> Bool {
        guard tags.contains(tag) else { return false }
        tags.remove(tag)
        return true
    }
    
    /// Checks if the wallpaper has specific tags
    /// - Parameter tags: The tags to check for
    /// - Returns: true if the wallpaper has all the specified tags
    public func hasTags(_ tagsToCheck: Set<String>) -> Bool {
        tags.isSuperset(of: tagsToCheck)
    }
    
    /// Checks if the wallpaper has a specific tag
    /// - Parameter tag: The tag to check for
    /// - Returns: true if the wallpaper has the specified tag
    public func hasTag(_ tag: String) -> Bool {
        tags.contains(tag)
    }
} 