import Foundation
import Darwin

class FileMonitor {
    private var monitors: [URL: DispatchSourceFileSystemObject] = [:]
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    func startMonitoring(_ url: URL) {
        guard url.isFileURL else { return }
        
        // Open file descriptor for monitoring
        let descriptor = Darwin.open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        
        // Create dispatch source for file system events
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.delete, .rename],
            queue: .main
        )
        
        // Set up event handler
        source.setEventHandler { [weak self] in
            self?.callback()
        }
        
        // Set up cancellation handler to close file descriptor
        source.setCancelHandler {
            Darwin.close(descriptor)
        }
        
        // Store and activate the monitor
        monitors[url] = source
        source.resume()
    }
    
    func stopMonitoring(_ url: URL) {
        if let source = monitors[url] {
            source.cancel()
            monitors.removeValue(forKey: url)
        }
    }
    
    deinit {
        // Clean up all monitors when the instance is deallocated
        monitors.values.forEach { $0.cancel() }
        monitors.removeAll()
    }
} 