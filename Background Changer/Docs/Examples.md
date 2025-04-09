# Background Changer Usage Examples

## Basic Wallpaper Management

### Adding Wallpapers

```swift
// Add a single wallpaper
let url = URL(fileURLWithPath: "/path/to/wallpaper.jpg")
try await WallpaperManager.shared.addWallpapers([url])

// Add multiple wallpapers
let urls = [
    URL(fileURLWithPath: "/path/to/wallpaper1.jpg"),
    URL(fileURLWithPath: "/path/to/wallpaper2.jpg")
]
try await WallpaperManager.shared.addWallpapers(urls)
```

### Removing Wallpapers

```swift
// Remove a single wallpaper
let url = URL(fileURLWithPath: "/path/to/wallpaper.jpg")
WallpaperManager.shared.removeWallpapers([url])

// Remove multiple wallpapers
let urls = [
    URL(fileURLWithPath: "/path/to/wallpaper1.jpg"),
    URL(fileURLWithPath: "/path/to/wallpaper2.jpg")
]
WallpaperManager.shared.removeWallpapers(urls)
```

## Display Settings

### Updating Display Mode

```swift
// Set wallpaper to fill screen
WallpaperManager.shared.updateDisplayMode(.fillScreen)

// Set wallpaper to fit screen
WallpaperManager.shared.updateDisplayMode(.fit)

// Set wallpaper to stretch
WallpaperManager.shared.updateDisplayMode(.stretch)

// Set wallpaper to center
WallpaperManager.shared.updateDisplayMode(.center)
```

### Managing Multiple Displays

```swift
// Show wallpaper on all spaces
WallpaperManager.shared.updateShowOnAllSpaces(true)

// Show wallpaper only on current space
WallpaperManager.shared.updateShowOnAllSpaces(false)
```

## Lazy Loading and Caching

### Loading Metadata

```swift
let wallpaper = WallpaperItem(
    id: UUID(),
    path: "/path/to/wallpaper.jpg",
    name: "wallpaper.jpg"
)

// Load metadata (will use cache if available)
let metadata = try await wallpaper.loadMetadata()
print("Width: \(metadata.width), Height: \(metadata.height)")

// Force reload metadata
let freshMetadata = try await wallpaper.reloadMetadata()
```

### Loading Images

```swift
let wallpaper = WallpaperItem(
    id: UUID(),
    path: "/path/to/wallpaper.jpg",
    name: "wallpaper.jpg"
)

// Load image (will use cache if available)
let image = try await wallpaper.loadImage()
```

### Preloading

```swift
// Preload metadata for all wallpapers
WallpaperManager.shared.preloadMetadata()

// Preload images for visible wallpapers
let visibleWallpapers = WallpaperManager.shared.allWallpapers.prefix(10)
WallpaperManager.shared.preloadImages(for: Array(visibleWallpapers))
```

## Error Handling

### Handling Loading Errors

```swift
do {
    let wallpaper = WallpaperItem(
        id: UUID(),
        path: "/path/to/wallpaper.jpg",
        name: "wallpaper.jpg"
    )
    
    let metadata = try await wallpaper.loadMetadata()
    let image = try await wallpaper.loadImage()
} catch let error as WallpaperError {
    switch error {
    case .invalidURL:
        print("Invalid URL")
    case .invalidImage:
        print("Invalid image file")
    case .metadataLoadFailed(let message):
        print("Failed to load metadata: \(message)")
    default:
        print("Unknown error: \(error)")
    }
}
```

### Handling Cache Errors

```swift
// Clear cache
WallpaperCache.shared.clearCache()

// Handle cache misses
if let cachedImage = WallpaperCache.shared.getImage(for: url) {
    // Use cached image
} else {
    // Load image from disk
    let image = try await wallpaper.loadImage()
}
```

## Performance Optimization

### Batch Processing

```swift
// Add multiple wallpapers with background processing
let urls = (1...100).map { i in
    URL(fileURLWithPath: "/path/to/wallpaper\(i).jpg")
}

try await WallpaperManager.shared.addWallpapers(urls)
```

### Memory Management

```swift
// Clear cache when memory is low
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    WallpaperCache.shared.clearCache()
}
```

## UI Integration

### Loading Indicators

```swift
struct WallpaperThumbnailView: View {
    let wallpaper: WallpaperItem
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = error {
                ErrorView(error: error)
            } else {
                // Display wallpaper
            }
        }
        .task {
            await loadWallpaper()
        }
    }
    
    private func loadWallpaper() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await wallpaper.loadImage()
        } catch {
            self.error = error
        }
    }
}
```

### Error Presentation

```swift
struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
} 