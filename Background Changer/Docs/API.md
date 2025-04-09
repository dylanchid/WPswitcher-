# API Documentation

## WallpaperMetadata

The `WallpaperMetadata` class represents metadata for a wallpaper image.

### Properties

- `url: URL` - The URL of the image file
- `name: String` - The name of the image file
- `size: CGSize` - The dimensions of the image
- `fileSize: Int64` - The file size in bytes
- `lastModified: Date` - The last modification date
- `format: String` - The image format
- `aspectRatio: CGFloat` - The aspect ratio of the image (width/height)
- `formattedFileSize: String` - Human-readable file size
- `formattedLastModified: String` - Formatted last modified date

### Methods

- `init(url:name:size:fileSize:lastModified:format:)` - Creates a new metadata instance
- `load(from url: URL) async throws -> WallpaperMetadata` - Loads metadata from a URL
- `isValid() -> Bool` - Validates if the metadata represents a valid wallpaper

## WallpaperItem

The `WallpaperItem` struct represents a single wallpaper with lazy loading capabilities.

### Properties

- `id: UUID` - Unique identifier
- `path: String` - File path
- `name: String` - Display name
- `isSelected: Bool` - Selection state
- `metadata: WallpaperMetadata?` - Cached metadata
- `lastError: WallpaperError?` - Last error encountered
- `fileURL: URL?` - URL of the wallpaper file
- `isValidFormat: Bool` - Whether the format is supported
- `isValidSize: Bool` - Whether the dimensions are valid
- `isValid: Bool` - Whether the wallpaper is valid and accessible

### Methods

- `init(id:path:name:isSelected:metadata:)` - Creates a new wallpaper item
- `loadMetadata() async throws -> WallpaperMetadata` - Loads metadata asynchronously
- `reloadMetadata() async throws -> WallpaperMetadata` - Forces metadata reload
- `clearCache()` - Clears cached data
- `loadBatch(_ items: [WallpaperItem]) async throws -> [WallpaperItem]` - Loads multiple wallpapers

## WallpaperError

The `WallpaperError` enum represents errors that can occur during wallpaper operations.

### Cases

- `invalidURL(String)` - Invalid or inaccessible URL
- `invalidImage(String)` - Invalid or corrupted image
- `metadataLoadFailed(String)` - Failed to load metadata
- `cacheError(String)` - Cache operation failed
- `fileSystemError(String)` - File system operation failed
- `invalidFormat(String)` - Invalid image format
- `invalidSize(String)` - Invalid image dimensions
- `networkError(String)` - Network operation failed
- `permissionDenied(String)` - Permission denied

### Properties

- `errorDescription: String?` - Human-readable error description
- `recoverySuggestion: String?` - Suggested recovery action
- `errorCode: Int` - Numeric error code

## Best Practices

1. **Error Handling**
   - Always check `isValid` before using a wallpaper
   - Handle all errors appropriately
   - Use the recovery suggestions when available

2. **Performance**
   - Use `loadBatch` for loading multiple wallpapers
   - Clear cache when appropriate using `clearCache()`
   - Leverage the metadata cache for repeated operations

3. **Validation**
   - Check `isValidFormat` and `isValidSize` before processing
   - Validate metadata using `isValid()`
   - Handle invalid states gracefully

4. **Memory Management**
   - Clear cache when wallpapers are no longer needed
   - Use weak references when storing wallpapers
   - Monitor memory usage in large collections

## Examples

```swift
// Loading a single wallpaper
let wallpaper = WallpaperItem(id: UUID(), path: "/path/to/image.jpg", name: "Wallpaper")
do {
    let metadata = try await wallpaper.loadMetadata()
    print("Size: \(metadata.size)")
    print("Format: \(metadata.format)")
} catch {
    print("Error: \(error.localizedDescription)")
}

// Loading multiple wallpapers
let wallpapers = [wallpaper1, wallpaper2, wallpaper3]
do {
    let loadedWallpapers = try await WallpaperItem.loadBatch(wallpapers)
    for wallpaper in loadedWallpapers {
        print("Loaded: \(wallpaper.name)")
    }
} catch {
    print("Error: \(error.localizedDescription)")
}

// Handling errors
if let error = wallpaper.lastError {
    print("Error: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Try this: \(suggestion)")
    }
}
``` 