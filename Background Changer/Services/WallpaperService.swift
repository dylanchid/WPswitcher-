//
//  WallpaperService.swift
//

import Foundation

@MainActor
final class AppWallpaperService: AppWallpaperServiceProtocol {
    private let manager: WallpaperManager

    init(manager: WallpaperManager = WallpaperManager.create()) {
        self.manager = manager
    }

    func setWallpaper(from url: URL) async {
        await manager.setWallpaper(from: url)
    }

    func startRotation(interval: TimeInterval) {
        // Map to manager API that expects RotationInterval + optional custom interval
    manager.startRotation(interval: .custom, customInterval: interval)
    }

    func stopRotation() {
        manager.stopRotation()
    }

    func rotateToNext() throws {
        try manager.rotateToNext()
    }

    func rotateToPrevious() throws {
        try manager.rotateToPrevious()
    }
}
