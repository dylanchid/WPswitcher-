import Foundation

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var wallpapers: [WallpaperItem]
    var isExpanded: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, wallpapers
        // Don't persist isExpanded state
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        wallpapers = try container.decode([WallpaperItem].self, forKey: .wallpapers)
        isExpanded = false
    }
    
    init(id: UUID = UUID(), name: String, wallpapers: [WallpaperItem] = [], isExpanded: Bool = false) {
        self.id = id
        self.name = name
        self.wallpapers = wallpapers
        self.isExpanded = isExpanded
    }
} 