import Foundation

/// Represents a playlist of wallpapers with enhanced validation and management
@preconcurrency
public struct Playlist: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public private(set) var wallpapers: [WallpaperItem]
    public var playbackMode: PlaybackMode
    public var rotationInterval: TimeInterval
    public var maxWallpapers: Int
    
    // UI-only state, not persisted
    public var isExpanded: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, name, wallpapers, playbackMode, rotationInterval, maxWallpapers
        // Do not persist isExpanded
    }

    public init(
        id: UUID = UUID(),
        name: String,
        wallpapers: [WallpaperItem] = [],
        isExpanded: Bool = false,
        playbackMode: PlaybackMode = .sequential,
        rotationInterval: TimeInterval = 3600,
        maxWallpapers: Int = 50
    ) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.isExpanded = isExpanded
        self.playbackMode = playbackMode
        self.rotationInterval = rotationInterval
        self.maxWallpapers = maxWallpapers
    }

    // Resilient decoding: default fields added later
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        wallpapers = try container.decodeIfPresent([WallpaperItem].self, forKey: .wallpapers) ?? []
        playbackMode = try container.decodeIfPresent(PlaybackMode.self, forKey: .playbackMode) ?? .sequential
        rotationInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .rotationInterval) ?? 3600
        maxWallpapers = try container.decodeIfPresent(Int.self, forKey: .maxWallpapers) ?? 50
        isExpanded = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wallpapers, forKey: .wallpapers)
        try container.encode(playbackMode, forKey: .playbackMode)
        try container.encode(rotationInterval, forKey: .rotationInterval)
        try container.encode(maxWallpapers, forKey: .maxWallpapers)
        // isExpanded intentionally not encoded
    }
    
    // MARK: - Smart Wallpaper Management
    /// Adds a wallpaper to the playlist with validation
    public mutating func addWallpaper(_ item: WallpaperItem) throws {
        guard wallpapers.count < maxWallpapers else {
            throw WallpaperError.playlistError("Playlist limit exceeded (\(maxWallpapers) wallpapers)")
        }
        guard !wallpapers.contains(where: { $0.id == item.id }) else {
            throw WallpaperError.playlistError("Wallpaper already in playlist")
        }
        
        // Validate the wallpaper before adding
        try item.validate()
        
        wallpapers.append(item)
    }
    
    /// Removes a wallpaper from the playlist
    @discardableResult
    public mutating func removeWallpaper(_ item: WallpaperItem) -> Bool {
        guard let index = wallpapers.firstIndex(where: { $0.id == item.id }) else {
            return false
        }
        wallpapers.remove(at: index)
        return true
    }
    
    /// Removes wallpaper by ID
    @discardableResult
    public mutating func removeWallpaper(id: UUID) -> Bool {
        guard let index = wallpapers.firstIndex(where: { $0.id == id }) else {
            return false
        }
        wallpapers.remove(at: index)
        return true
    }
    
    /// Efficient reordering with validation
    public mutating func moveWallpaper(from source: IndexSet, to destination: Int) throws {
        guard source.allSatisfy({ $0 < wallpapers.count }) else {
            throw WallpaperError.playlistError("Invalid source index")
        }
        guard destination <= wallpapers.count else {
            throw WallpaperError.playlistError("Invalid destination index")
        }
        
        // Manual implementation of move operation
        let itemsToMove = source.sorted(by: >).map { wallpapers.remove(at: $0) }
        for (index, item) in itemsToMove.reversed().enumerated() {
            let insertIndex = min(destination + index, wallpapers.count)
            wallpapers.insert(item, at: insertIndex)
        }
    }
    
    /// Reorders wallpapers to match the provided order
    public mutating func reorderWallpapers(_ newOrder: [WallpaperItem]) throws {
        // Validate that all wallpapers are present
        guard newOrder.count == wallpapers.count else {
            throw WallpaperError.playlistError("Reorder count mismatch")
        }
        
        let newOrderIds = Set(newOrder.map { $0.id })
        let currentIds = Set(wallpapers.map { $0.id })
        
        guard newOrderIds == currentIds else {
            throw WallpaperError.playlistError("Reorder contains different wallpapers")
        }
        
        wallpapers = newOrder
    }
    
    /// Updates the playlist name with validation
    public mutating func setName(_ newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw WallpaperError.invalidName("Playlist name cannot be empty")
        }
        guard trimmedName.count <= 100 else {
            throw WallpaperError.invalidName("Playlist name too long (max 100 characters)")
        }
        name = trimmedName
    }
    
    /// Updates the max wallpapers limit
    public mutating func setMaxWallpapers(_ max: Int) throws {
        guard max > 0 else {
            throw WallpaperError.playlistError("Max wallpapers must be positive")
        }
        guard max <= 1000 else {
            throw WallpaperError.playlistError("Max wallpapers too high (limit: 1000)")
        }
        
        maxWallpapers = max
        
        // Trim existing wallpapers if necessary
        if wallpapers.count > max {
            wallpapers = Array(wallpapers.prefix(max))
        }
    }
    
    // MARK: - Computed Properties
    /// Whether the playlist is at capacity
    public var isFull: Bool {
        wallpapers.count >= maxWallpapers
    }
    
    /// Number of available slots
    public var availableSlots: Int {
        max(0, maxWallpapers - wallpapers.count)
    }
    
    /// Whether the playlist is empty
    public var isEmpty: Bool {
        wallpapers.isEmpty
    }
    
    /// Total size of all wallpapers in bytes (estimated based on file size)
    public var estimatedTotalSize: Int64 {
        // Calculate based on file size rather than metadata to avoid async calls
        wallpapers.compactMap { wallpaper in
            guard wallpaper.url.isFileURL else { return nil }
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: wallpaper.url.path)
                return attributes[.size] as? Int64
            } catch {
                return nil
            }
        }.reduce(0, +)
    }
    
    /// Validation of the entire playlist
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WallpaperError.invalidName("Playlist name cannot be empty")
        }
        
        guard wallpapers.count <= maxWallpapers else {
            throw WallpaperError.playlistError("Playlist exceeds maximum wallpapers")
        }
        
        // Validate all wallpapers
        for wallpaper in wallpapers {
            try wallpaper.validate()
        }
    }
}
