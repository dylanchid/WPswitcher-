import Foundation
import AppKit
import OSLog

// MARK: - Robust File System Monitoring with Recovery
public final class WallpaperFileMonitor {
    private var monitors: [URL: FileMonitorInfo] = [:]
    private let queue = DispatchQueue(label: "wallpaper.file.monitor", qos: .utility)
    private let logger = Logger(subsystem: "WallpaperManager", category: "FileMonitor")
    
    // Recovery and resilience
    private var recoveryAttempts: [URL: Int] = [:]
    private let maxRecoveryAttempts = 3
    private var monitoringEnabled = true
    
    public init() {}
    
    deinit {
        stopAllMonitoring()
    }
    
    // MARK: - Main Monitoring Interface
    public func monitorWallpaper(
        _ item: WallpaperItem,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        let url = item.url
        
        guard monitoringEnabled else {
            logger.warning("File monitoring is disabled")
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop existing monitor if present
            self.stopMonitoring(url)
            
            do {
                let monitor = try self.createFileMonitor(for: url, onChange: onChange)
                let monitorInfo = FileMonitorInfo(
                    monitor: monitor,
                    wallpaper: item,
                    onChange: onChange,
                    startDate: Date()
                )
                
                self.monitors[url] = monitorInfo
                self.recoveryAttempts[url] = 0
                
                self.logger.info("Started monitoring: \(url.lastPathComponent)")
                
            } catch {
                self.logger.error("Failed to start monitoring \(url.lastPathComponent): \(error.localizedDescription)")
                self.handleMonitoringError(url: url, error: error, onChange: onChange)
            }
        }
    }
    
    public func stopMonitoring(_ url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if let monitorInfo = self.monitors[url] {
                monitorInfo.monitor.cancel()
                self.monitors.removeValue(forKey: url)
                self.recoveryAttempts.removeValue(forKey: url)
                
                self.logger.info("Stopped monitoring: \(url.lastPathComponent)")
            }
        }
    }
    
    public func stopAllMonitoring() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for (url, monitorInfo) in self.monitors {
                monitorInfo.monitor.cancel()
            }
            
            self.monitors.removeAll()
            self.recoveryAttempts.removeAll()
            
            self.logger.info("Stopped all file monitoring")
        }
    }
    
    public func pauseMonitoring() {
        monitoringEnabled = false
        logger.info("File monitoring paused")
    }
    
    public func resumeMonitoring() {
        monitoringEnabled = true
        logger.info("File monitoring resumed")
    }
    
    // MARK: - Monitor Creation
    private func createFileMonitor(
        for url: URL,
        onChange: @escaping (FileChange, URL) -> Void
    ) throws -> DispatchSourceFileSystemObject {
        
        // Validate file exists and is accessible
        try validateFileAccess(at: url)
        
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            throw FileMonitorError.cannotOpenFile(url, errno: errno)
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.delete, .rename, .write, .extend, .attrib, .link, .revoke],
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let flags = source.data
            self.handleFileSystemEvent(flags: flags, url: url, onChange: onChange)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        return source
    }
    
    // MARK: - Event Handling
    private func handleFileSystemEvent(
        flags: DispatchSource.FileSystemEvent,
        url: URL,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        var detectedChanges: [FileChange] = []
        
        if flags.contains(.delete) {
            detectedChanges.append(.deleted)
            logger.warning("File deleted: \(url.lastPathComponent)")
        }
        
        if flags.contains(.rename) {
            detectedChanges.append(.renamed)
            logger.info("File renamed: \(url.lastPathComponent)")
        }
        
        if flags.contains(.write) || flags.contains(.extend) {
            detectedChanges.append(.modified)
            logger.debug("File modified: \(url.lastPathComponent)")
        }
        
        if flags.contains(.attrib) {
            detectedChanges.append(.attributesChanged)
            logger.debug("File attributes changed: \(url.lastPathComponent)")
        }
        
        if flags.contains(.link) {
            detectedChanges.append(.linkChanged)
            logger.debug("File link changed: \(url.lastPathComponent)")
        }
        
        if flags.contains(.revoke) {
            detectedChanges.append(.accessRevoked)
            logger.warning("File access revoked: \(url.lastPathComponent)")
        }
        
        // Process changes
        for change in detectedChanges {
            handleFileChange(change, url: url, onChange: onChange)
        }
    }
    
    private func handleFileChange(
        _ change: FileChange,
        url: URL,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        switch change {
        case .deleted, .accessRevoked:
            // Stop monitoring deleted/inaccessible files
            stopMonitoring(url)
            onChange(change, url)
            
        case .renamed:
            // Try to recover renamed files
            handleRenamedFile(url: url, onChange: onChange)
            
        case .modified, .attributesChanged, .linkChanged:
            // Validate file is still accessible before reporting change
            if validateFileAccessQuiet(at: url) {
                onChange(change, url)
            } else {
                onChange(.accessLost, url)
                attemptRecovery(url: url, onChange: onChange)
            }
        }
    }
    
    // MARK: - Recovery Logic
    private func handleRenamedFile(
        url: URL,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        // Try to find the file in the same directory
        let parentDirectory = url.deletingLastPathComponent()
        let originalName = url.deletingPathExtension().lastPathComponent
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: parentDirectory, includingPropertiesForKeys: nil)
            
            // Look for files with similar names
            let candidates = contents.filter { candidateURL in
                let candidateName = candidateURL.deletingPathExtension().lastPathComponent
                return candidateName.contains(originalName) || originalName.contains(candidateName)
            }
            
            if let newURL = candidates.first {
                logger.info("Found renamed file: \(url.lastPathComponent) -> \(newURL.lastPathComponent)")
                onChange(.renamedTo(newURL), url)
            } else {
                onChange(.renamed, url)
            }
            
        } catch {
            logger.error("Failed to search for renamed file: \(error.localizedDescription)")
            onChange(.renamed, url)
        }
    }
    
    private func attemptRecovery(
        url: URL,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        let currentAttempts = recoveryAttempts[url] ?? 0
        
        guard currentAttempts < maxRecoveryAttempts else {
            logger.error("Max recovery attempts reached for: \(url.lastPathComponent)")
            stopMonitoring(url)
            onChange(.recoveryFailed, url)
            return
        }
        
        recoveryAttempts[url] = currentAttempts + 1
        
        // Wait before retry
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(currentAttempts + 1)) { [weak self] in
            guard let self = self else { return }
            
            if self.validateFileAccessQuiet(at: url) {
                self.logger.info("File recovery successful: \(url.lastPathComponent)")
                onChange(.recovered, url)
                self.recoveryAttempts[url] = 0
            } else {
                self.logger.warning("Recovery attempt \(currentAttempts + 1) failed for: \(url.lastPathComponent)")
                self.attemptRecovery(url: url, onChange: onChange)
            }
        }
    }
    
    private func handleMonitoringError(
        url: URL,
        error: Error,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        logger.error("Monitoring error for \(url.lastPathComponent): \(error.localizedDescription)")
        
        // Try to create a polling-based monitor as fallback
        createPollingMonitor(for: url, onChange: onChange)
    }
    
    // MARK: - Fallback Polling Monitor
    private func createPollingMonitor(
        for url: URL,
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        let pollingInterval: TimeInterval = 5.0 // 5 seconds
        var lastModificationDate: Date?
        var lastFileSize: Int64?
        
        // Get initial state
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            lastModificationDate = attributes[.modificationDate] as? Date
            lastFileSize = attributes[.size] as? Int64
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
            self.queue.async {
                guard self.monitors[url] != nil else {
                    // Monitor was stopped, cancel timer
                    timer.invalidate()
                    return
                }
                
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let currentModificationDate = attributes[.modificationDate] as? Date
                    let currentFileSize = attributes[.size] as? Int64
                    
                    // Check for changes
                    if let lastDate = lastModificationDate,
                       let currentDate = currentModificationDate,
                       currentDate > lastDate {
                        onChange(.modified, url)
                    }
                    
                    if let lastSize = lastFileSize,
                       let currentSize = currentFileSize,
                       currentSize != lastSize {
                        onChange(.modified, url)
                    }
                    
                    // Update last known state
                    lastModificationDate = currentModificationDate
                    lastFileSize = currentFileSize
                    
                } catch {
                    // File no longer accessible
                    onChange(.accessLost, url)
                    self.stopMonitoring(url)
                    timer.invalidate()
                }
            }
        }
        
        // Store timer reference for cleanup
        let monitorInfo = FileMonitorInfo(
            monitor: nil,
            wallpaper: monitors[url]?.wallpaper ?? WallpaperItem(url: url, name: url.lastPathComponent),
            onChange: onChange,
            startDate: Date(),
            pollingTimer: timer
        )
        
        monitors[url] = monitorInfo
        logger.info("Started polling monitor for: \(url.lastPathComponent)")
    }
    
    // MARK: - File Validation
    private func validateFileAccess(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileMonitorError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileMonitorError.accessDenied(url)
        }
        
        // Check if file is a regular file (not directory, symlink, etc.)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw FileMonitorError.notAFile(url)
        }
    }
    
    private func validateFileAccessQuiet(at url: URL) -> Bool {
        do {
            try validateFileAccess(at: url)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Monitoring Status
    public func getMonitoringStatus() -> MonitoringStatus {
        return queue.sync {
            let activeMonitors = monitors.count
            let recoveryCount = recoveryAttempts.values.reduce(0, +)
            
            let oldestMonitor = monitors.values.min { $0.startDate < $1.startDate }
            let uptimeSeconds = oldestMonitor?.startDate.timeIntervalSinceNow.magnitude ?? 0
            
            return MonitoringStatus(
                isEnabled: monitoringEnabled,
                activeMonitors: activeMonitors,
                recoveryAttempts: recoveryCount,
                uptimeSeconds: uptimeSeconds
            )
        }
    }
    
    public func getMonitoredFiles() -> [URL] {
        return queue.sync {
            Array(monitors.keys)
        }
    }
    
    // MARK: - Batch Operations
    public func monitorWallpapers(
        _ wallpapers: [WallpaperItem],
        onChange: @escaping (FileChange, URL) -> Void
    ) {
        for wallpaper in wallpapers {
            monitorWallpaper(wallpaper, onChange: onChange)
        }
    }
    
    public func stopMonitoring(_ urls: [URL]) {
        for url in urls {
            stopMonitoring(url)
        }
    }
}

// MARK: - Supporting Types
public enum FileChange {
    case deleted
    case renamed
    case renamedTo(URL)
    case modified
    case attributesChanged
    case linkChanged
    case accessLost
    case accessRevoked
    case recovered
    case recoveryFailed
    
    public var isDestructive: Bool {
        switch self {
        case .deleted, .accessRevoked, .recoveryFailed:
            return true
        default:
            return false
        }
    }
    
    public var requiresAction: Bool {
        switch self {
        case .accessLost, .recoveryFailed, .deleted:
            return true
        default:
            return false
        }
    }
}

public enum FileMonitorError: LocalizedError {
    case fileNotFound(URL)
    case accessDenied(URL)
    case notAFile(URL)
    case cannotOpenFile(URL, errno: Int32)
    case monitoringDisabled
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .accessDenied(let url):
            return "Access denied: \(url.lastPathComponent)"
        case .notAFile(let url):
            return "Not a regular file: \(url.lastPathComponent)"
        case .cannotOpenFile(let url, let errno):
            return "Cannot open file \(url.lastPathComponent): \(String(cString: strerror(errno)))"
        case .monitoringDisabled:
            return "File monitoring is disabled"
        }
    }
}

private struct FileMonitorInfo {
    let monitor: DispatchSourceFileSystemObject?
    let wallpaper: WallpaperItem
    let onChange: (FileChange, URL) -> Void
    let startDate: Date
    let pollingTimer: Timer?
    
    init(
        monitor: DispatchSourceFileSystemObject?,
        wallpaper: WallpaperItem,
        onChange: @escaping (FileChange, URL) -> Void,
        startDate: Date,
        pollingTimer: Timer? = nil
    ) {
        self.monitor = monitor
        self.wallpaper = wallpaper
        self.onChange = onChange
        self.startDate = startDate
        self.pollingTimer = pollingTimer
    }
}

public struct MonitoringStatus {
    public let isEnabled: Bool
    public let activeMonitors: Int
    public let recoveryAttempts: Int
    public let uptimeSeconds: TimeInterval
    
    public var formattedUptime: String {
        let hours = Int(uptimeSeconds) / 3600
        let minutes = Int(uptimeSeconds) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - File Monitor Factory
public final class FileMonitorFactory {
    public static func createStandardMonitor() -> WallpaperFileMonitor {
        return WallpaperFileMonitor()
    }
    
    public static func createTestMonitor() -> WallpaperFileMonitor {
        let monitor = WallpaperFileMonitor()
        monitor.pauseMonitoring() // Start disabled for testing
        return monitor
    }
}
