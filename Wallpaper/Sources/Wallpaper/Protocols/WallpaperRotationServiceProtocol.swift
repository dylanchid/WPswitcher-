import Foundation
import WallpaperTypes

/// Protocol defining the wallpaper rotation service functionality
@preconcurrency
public protocol WallpaperRotationServiceProtocol {
    // MARK: - Properties
    var isRotating: Bool { get }
    var rotationInterval: TimeInterval { get }
    var isRotationEnabled: Bool { get set }
    
    // MARK: - Rotation Control
    func startRotation(interval: TimeInterval) async
    func stopRotation() async
    func rotateToNext() async throws
    func rotateToPrevious() async throws
    
    // MARK: - Additional Methods
    func start() async
    func stop()
    func setRotationInterval(_ interval: TimeInterval) async
    func getNextWallpaper() async throws -> WallpaperItem?
} 