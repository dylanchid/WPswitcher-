//
//  AppWallpaperServiceProtocol.swift
//

import Foundation

@MainActor
protocol AppWallpaperServiceProtocol: AnyObject {
    func setWallpaper(from url: URL) async
    func startRotation(interval: TimeInterval)
    func stopRotation()
    func rotateToNext() throws
    func rotateToPrevious() throws
}
