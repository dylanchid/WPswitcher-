import Foundation
import UniformTypeIdentifiers

extension URL {
    var isValidImageFile: Bool {
        guard isFileURL else { return false }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        
        // Verify it's an image
        guard let typeIdentifier = try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
              let type = UTType(typeIdentifier),
              type.conforms(to: .image) else {
            return false
        }
        
        return true
    }
} 