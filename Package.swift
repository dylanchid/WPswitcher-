// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BackgroundChanger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "BackgroundChanger",
            targets: ["BackgroundChanger"]
        )
    ],
    dependencies: [
        .package(path: "Wallpaper")
    ],
    targets: [
        .executableTarget(
            name: "BackgroundChanger",
            dependencies: [
                .product(name: "Wallpaper", package: "Wallpaper"),
                .product(name: "WallpaperTypes", package: "Wallpaper")
            ],
            path: "Background Changer"
        ),
        .testTarget(
            name: "BackgroundChangerTests",
            dependencies: ["BackgroundChanger"],
            path: "Background ChangerTests"
        )
    ]
) 