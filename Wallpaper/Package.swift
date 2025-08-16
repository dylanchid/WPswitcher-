// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Wallpaper",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Wallpaper",
            targets: ["Wallpaper"]),
        .library(
            name: "WallpaperTypes",
            targets: ["WallpaperTypes"])
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WallpaperTypes",
            dependencies: [],
            path: "Sources/WallpaperTypes"),
        .target(
            name: "Wallpaper",
            dependencies: ["WallpaperTypes"],
            path: "Sources/Wallpaper"),
        .testTarget(
            name: "WallpaperTests",
            dependencies: ["Wallpaper"])
    ]
)
