import Foundation

/// Represents a wallpaper item in the application
public struct WallpaperItem: Identifiable, Codable, Equatable {
    /// Unique identifier for the wallpaper
    public let id: UUID
    /// URL pointing to the wallpaper file
    public let url: URL
    /// Display name of the wallpaper
    public let name: String
    /// Whether the wallpaper is marked as favorite
    public private(set) var isFavorite: Bool
    /// Set of tags associated with the wallpaper
    public private(set) var tags: Set<String>
    /// Creation date of the wallpaper entry
    public let createdAt: Date
    /// Last update date of the wallpaper entry
    public let updatedAt: Date
    /// Metadata about the wallpaper file
    public var metadata: WallpaperMetadata?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isFavorite: Bool = false,
        tags: Set<String> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: WallpaperMetadata? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isFavorite = isFavorite
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
    
    public static func == (lhs: WallpaperItem, rhs: WallpaperItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Updates the wallpaper's favorite status and returns the new state
    @discardableResult
    public mutating func toggleFavorite() -> Bool {
        isFavorite.toggle()
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