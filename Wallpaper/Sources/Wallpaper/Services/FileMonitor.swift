import Foundation
import Dispatch

/// Protocol defining file monitoring functionality
public protocol FileMonitor: AnyObject {
    func startMonitoring()
    func stopMonitoring()
}

/// Class that monitors file changes
public final class FileChangeMonitor: FileMonitor {
    // MARK: - Properties
    private let fileManager: FileManager
    private let paths: [String]
    private var fileDescriptors: [Int32] = []
    private var sources: [DispatchSourceFileSystemObject] = []
    private let queue: DispatchQueue
    private var isMonitoring: Bool = false
    
    // MARK: - Initialization
    public init(
        paths: [String],
        fileManager: FileManager = .default,
        queue: DispatchQueue = .main
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.queue = queue
    }
    
    // MARK: - FileMonitor Implementation
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        for path in paths {
            let fileDescriptor = open(path, O_EVTONLY)
            guard fileDescriptor >= 0 else { continue }
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: queue
            )
            
            source.setEventHandler { [weak self] in
                self?.handleFileChange(at: path)
            }
            
            source.setCancelHandler {
                close(fileDescriptor)
            }
            
            source.resume()
            fileDescriptors.append(fileDescriptor)
            sources.append(source)
        }
        
        isMonitoring = true
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        for source in sources {
            source.cancel()
        }
        
        sources.removeAll()
        fileDescriptors.removeAll()
        isMonitoring = false
    }
    
    // MARK: - Private Methods
    
    private func handleFileChange(at path: String) {
        // Notify observers of file change
        NotificationCenter.default.post(
            name: .fileDidChange,
            object: nil,
            userInfo: ["path": path]
        )
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Notifications
extension Notification.Name {
    public static let fileDidChange = Notification.Name("fileDidChange")
} 