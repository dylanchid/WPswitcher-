import Foundation
import Dispatch
import WallpaperTypes
import OSLog

@MainActor @preconcurrency
public final class WallpaperRotationService: WallpaperRotationServiceProtocol {
    // MARK: - Properties
    private let wallpaperService: WallpaperServiceProtocol
    private var rotationTimer: DispatchSourceTimer?
    private var _isRotating: Bool = false
    private var _rotationInterval: TimeInterval = 300 // Default 5 minutes
    private var _isRotationEnabled: Bool = false
    private let logger = Logger(subsystem: "com.wallpaper", category: "WallpaperRotationService")
    
    // WallpaperRotationServiceProtocol properties
    nonisolated public var isRotationEnabled: Bool {
        get { _isRotationEnabled }
        set {
            Task { @MainActor in
                self._isRotationEnabled = newValue
                self.saveSettings()
                if newValue {
                    await self.startRotation(interval: self.rotationInterval)
                } else {
                    await self.stopRotation()
                }
            }
        }
    }
    nonisolated public var isRotating: Bool { _isRotating }
    nonisolated public var rotationInterval: TimeInterval { _rotationInterval }
    
    // MARK: - Initialization
    public init(wallpaperService: WallpaperServiceProtocol) {
        self.wallpaperService = wallpaperService
        loadSettings()
    }
    
    // MARK: - WallpaperRotationServiceProtocol Implementation
    
    public func startRotation(interval: TimeInterval) async {
        guard !isRotating else { return }
        
        _rotationInterval = interval
        _isRotating = true
        
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            Task { [weak self] in
                do {
                    try await self?.rotateToNext()
                } catch {
                    self?.logger.error("Rotation failed: \(error.localizedDescription)")
                }
            }
        }
        timer.resume()
        rotationTimer = timer
    }
    
    public func stopRotation() async {
        guard isRotating else { return }
        
        rotationTimer?.cancel()
        rotationTimer = nil
        _isRotating = false
    }
    
    public func start() async {
        await startRotation(interval: rotationInterval)
    }
    
    nonisolated public func stop() {
        Task { @MainActor in
            await self.stopRotation()
        }
    }
    
    public func setRotationInterval(_ interval: TimeInterval) async {
        guard interval > 0 else { return }
        
        _rotationInterval = interval
        saveSettings()
        
        // Restart timer if it's running
        if isRotating {
            await stopRotation()
            await startRotation(interval: interval)
        }
    }
    
    public func getNextWallpaper() async throws -> WallpaperItem? {
        let wallpaperList = try await wallpaperService.getWallpaperList()
        guard !wallpaperList.isEmpty else { return nil }
        
        if let currentWallpaper = try await wallpaperService.getCurrentWallpaper() {
            if let currentIndex = wallpaperList.firstIndex(where: { $0.id == currentWallpaper.id }) {
                let nextIndex = (currentIndex + 1) % wallpaperList.count
                return wallpaperList[nextIndex]
            }
        }
        
        // Default to first wallpaper if current can't be determined
        return wallpaperList.first
    }
    
    public func rotateToNext() async throws {
        let wallpaperList = try await wallpaperService.getWallpaperList()
        if let currentWallpaper = try await wallpaperService.getCurrentWallpaper() {
            if let currentIndex = wallpaperList.firstIndex(where: { $0.id == currentWallpaper.id }) {
                let nextIndex = (currentIndex + 1) % wallpaperList.count
                try await wallpaperService.setWallpaper(wallpaperList[nextIndex])
            }
        }
    }
    
    public func rotateToPrevious() async throws {
        let wallpaperList = try await wallpaperService.getWallpaperList()
        if let currentWallpaper = try await wallpaperService.getCurrentWallpaper() {
            if let currentIndex = wallpaperList.firstIndex(where: { $0.id == currentWallpaper.id }) {
                let previousIndex = (currentIndex - 1 + wallpaperList.count) % wallpaperList.count
                try await wallpaperService.setWallpaper(wallpaperList[previousIndex])
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        let settings: [String: Any] = [
            "isRotationEnabled": isRotationEnabled,
            "rotationInterval": rotationInterval
        ]
        UserDefaults.standard.set(settings, forKey: "wallpaperRotationSettings")
    }
    
    private func loadSettings() {
        if let settings = UserDefaults.standard.dictionary(forKey: "wallpaperRotationSettings") {
            _isRotationEnabled = settings["isRotationEnabled"] as? Bool ?? false
            _rotationInterval = settings["rotationInterval"] as? TimeInterval ?? 300
        }
    }
    
    deinit {
        rotationTimer?.cancel()
    }
}
