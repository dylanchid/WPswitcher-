import SwiftUI
import AppKit

/// A view that displays a thumbnail of a wallpaper in a playlist with drag and drop support
struct PlaylistThumbnailView: View {
    // MARK: - Properties
    
    /// The image to display
    let image: NSImage
    
    /// The wallpaper item associated with this thumbnail
    let wallpaper: WallpaperItem
    
    /// The index of the wallpaper in the playlist
    let index: Int
    
    /// Whether the thumbnail is currently being dragged
    let isDragged: Bool
    
    /// Whether this thumbnail is a drop target
    let isDropTarget: Bool
    
    /// Action to perform when the thumbnail is tapped
    let onTap: () -> Void
    
    /// Action to perform when dragging starts
    let onDragStart: () -> Void
    
    /// Action to perform when dragging ends
    let onDragEnd: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Drop target indicator
            if isDropTarget {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2)
                    .frame(height: 60)
                    .position(x: 0, y: 30)
                    .accessibilityLabel("Drop target indicator")
            }
            
            // Thumbnail image
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(6)
                .onTapGesture(perform: onTap)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.dragLink.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { _ in
                            NSCursor.closedHand.push()
                        }
                        .onEnded { _ in
                            NSCursor.pop()
                        }
                )
                .draggable(wallpaper.id.uuidString) {
                    onDragStart()
                    NSCursor.closedHand.push()
                    return Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                }
                .opacity(isDragged ? 0.5 : 1.0)
                .accessibilityLabel("\(wallpaper.name) thumbnail")
                .accessibilityHint("Double tap to select, drag to reorder")
        }
    }
}

// MARK: - Preview Provider

struct PlaylistThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock image
        let mockImage = NSImage(size: NSSize(width: 100, height: 100))
        mockImage.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 100, height: 100)).fill()
        mockImage.unlockFocus()
        
        // Create a mock wallpaper
        let mockWallpaper = WallpaperItem(
            id: UUID(),
            path: "/path/to/wallpaper.jpg",
            name: "Preview Wallpaper",
            isSelected: false
        )
        
        // Preview with different states
        Group {
            // Normal state
            PlaylistThumbnailView(
                image: mockImage,
                wallpaper: mockWallpaper,
                index: 0,
                isDragged: false,
                isDropTarget: false,
                onTap: {},
                onDragStart: {},
                onDragEnd: {}
            )
            .frame(width: 60, height: 60)
            .previewDisplayName("Normal")
            
            // Dragged state
            PlaylistThumbnailView(
                image: mockImage,
                wallpaper: mockWallpaper,
                index: 0,
                isDragged: true,
                isDropTarget: false,
                onTap: {},
                onDragStart: {},
                onDragEnd: {}
            )
            .frame(width: 60, height: 60)
            .previewDisplayName("Dragged")
            
            // Drop target state
            PlaylistThumbnailView(
                image: mockImage,
                wallpaper: mockWallpaper,
                index: 0,
                isDragged: false,
                isDropTarget: true,
                onTap: {},
                onDragStart: {},
                onDragEnd: {}
            )
            .frame(width: 60, height: 60)
            .previewDisplayName("Drop Target")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 