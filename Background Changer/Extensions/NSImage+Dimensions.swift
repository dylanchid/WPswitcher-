import AppKit

// Add extension for NSImage dimensions
extension NSImage {
    var dimensions: (width: Int, height: Int)? {
        // Find the best representation (e.g., bitmap) to get dimensions
        // Using the first representation might not always be accurate if there are multiple (like vector + bitmap)
        // Iterating through representations to find a suitable one might be more robust.
        guard let rep = representations.first else { return nil }
        
        // Ensure the representation has pixel dimensions
        guard rep.pixelsWide > 0 && rep.pixelsHigh > 0 else {
             // If the first rep doesn't have pixel dimensions (e.g., vector),
             // try finding a bitmap representation.
             if let bitmapRep = representations.first(where: { $0 is NSBitmapImageRep }) as? NSBitmapImageRep {
                  return (bitmapRep.pixelsWide, bitmapRep.pixelsHigh)
             }
             // If still no valid dimensions, return nil
             return nil
        }
        
        return (rep.pixelsWide, rep.pixelsHigh)
    }
} 