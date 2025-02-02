import Foundation

struct PlaylistStats: Codable {
    let totalWallpapers: Int
    let totalSize: Int64
    let lastModified: Date
    let createdAt: Date
    
    static func calculate(for playlist: Playlist) -> PlaylistStats {
        var totalSize: Int64 = 0
        
        for wallpaper in playlist.wallpapers {
            if let url = wallpaper.fileURL,
               let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return PlaylistStats(
            totalWallpapers: playlist.wallpapers.count,
            totalSize: totalSize,
            lastModified: Date(),
            createdAt: Date()
        )
    }
} 