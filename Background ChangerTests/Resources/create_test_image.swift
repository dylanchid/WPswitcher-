import Foundation
import AppKit

// Create a test image
let size = NSSize(width: 800, height: 600)
let image = NSImage(size: size)
image.lockFocus()
NSColor.blue.setFill()
NSRect(origin: .zero, size: size).fill()
image.unlockFocus()

// Save the image
let url = URL(fileURLWithPath: "test-image.jpg")
if let tiffData = image.tiffRepresentation,
   let bitmapImage = NSBitmapImageRep(data: tiffData),
   let imageData = bitmapImage.representation(using: .jpeg, properties: [:]) {
    try? imageData.write(to: url)
    print("Test image created at: \(url.path)")
} else {
    print("Failed to create test image")
    exit(1)
} 