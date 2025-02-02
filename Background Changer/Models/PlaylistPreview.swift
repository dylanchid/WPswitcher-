import AppKit

struct PlaylistPreview: Identifiable {
    let id: UUID
    let previewImages: [NSImage]
    let isActive: Bool
    
    init(id: UUID, previewImages: [NSImage], isActive: Bool) {
        self.id = id
        self.previewImages = previewImages
        self.isActive = isActive
    }
} 