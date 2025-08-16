# Wallpaper Package

A Swift package for managing desktop wallpapers on macOS. This package provides a high-level API for setting, rotating, and managing wallpapers with support for multiple displays.

## Features

- Set wallpapers for single or multiple displays
- Support for different display modes (Fill, Fit, Stretch, Center, Tile)
- Wallpaper rotation with configurable intervals
- Wallpaper playlist management
- Error handling and logging
- Support for favorites and tags
- Secure file access handling

## Requirements

- macOS 11.0 or later
- Swift 5.5 or later

## Installation

### Swift Package Manager

Add the package to your project's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Wallpaper.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import Wallpaper
import AppKit

// Initialize the wallpaper manager
let wallpaperService = WallpaperDisplayService()
let wallpaperManager = WallpaperManager(wallpaperService: wallpaperService)

// Set a wallpaper
let wallpaperURL = URL(fileURLWithPath: "/path/to/wallpaper.jpg")
try await wallpaperManager.setWallpaper(from: wallpaperURL)

// Set wallpaper for a specific screen
if let screen = NSScreen.screens.first {
    try await wallpaperManager.setWallpaper(from: wallpaperURL, for: screen)
}

// Set display mode
wallpaperManager.displayMode = .fillScreen

// Start wallpaper rotation
try await wallpaperManager.startRotation(interval: 3600) // Rotate every hour
```

### Advanced Usage

```swift
// Create a playlist
let playlist = Playlist(
    id: UUID(),
    name: "Nature",
    wallpapers: [],
    rotationInterval: 3600
)

// Add wallpapers to playlist
let urls = [URL(fileURLWithPath: "/path/to/wallpaper1.jpg"),
            URL(fileURLWithPath: "/path/to/wallpaper2.jpg")]
let wallpapers = try await wallpaperManager.addWallpapers(from: urls)

// Set up rotation
wallpaperManager.startRotation(interval: playlist.rotationInterval)

// Handle errors
do {
    try await wallpaperManager.setWallpaper(from: wallpaperURL)
} catch let error as WallpaperError {
    print("Failed to set wallpaper: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
}
```

## API Documentation

### WallpaperManager

The main class for managing wallpapers.

#### Properties
- `currentWallpaperPath: String` - Path to the current wallpaper
- `displayMode: DisplayMode` - Current display mode
- `showOnAllSpaces: Bool` - Whether to show wallpaper on all spaces

#### Methods
- `setWallpaper(from:for:mode:)` - Set wallpaper for a specific screen
- `startRotation(interval:)` - Start wallpaper rotation
- `stopRotation()` - Stop wallpaper rotation
- `addWallpapers(from:)` - Add multiple wallpapers
- `removeWallpaper(_:)` - Remove a wallpaper

### WallpaperItem

Represents a wallpaper with metadata.

#### Properties
- `id: UUID` - Unique identifier
- `url: URL` - File URL
- `name: String` - Display name
- `isFavorite: Bool` - Whether the wallpaper is favorited
- `tags: Set<String>` - Associated tags
- `createdAt: Date` - Creation date
- `updatedAt: Date` - Last update date

### DisplayMode

Enumeration of available display modes:
- `fillScreen` - Fill the entire screen
- `fit` - Fit the image while maintaining aspect ratio
- `stretch` - Stretch to fill the screen
- `center` - Center the image
- `tile` - Tile the image

## Error Handling

The package provides comprehensive error handling through the `WallpaperError` type. All errors include:
- Localized description
- Recovery suggestion (when applicable)
- Underlying error (when available)

## Logging

The package uses the system logger for debugging and error tracking. Logs can be viewed in Console.app with the subsystem "com.wallpaper".

## License

This package is available under the MIT license. See the LICENSE file for more info. 