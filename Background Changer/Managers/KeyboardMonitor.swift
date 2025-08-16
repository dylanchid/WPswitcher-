import AppKit

@MainActor
protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didDetectShortcut shortcut: KeyboardShortcut)
}

class KeyboardMonitor {
    // MARK: - Properties
    private var monitor: Any?
    weak var delegate: KeyboardMonitorDelegate?
    
    // MARK: - Public Methods
    static func create() -> KeyboardMonitor {
        return KeyboardMonitor()
    }
    
    func startMonitoring() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Check for undo/redo shortcuts
            if event.keyCode == 6 { // 'z' key
                if event.modifierFlags.contains(.command) {
                    if event.modifierFlags.contains(.shift) {
                        let shortcut = KeyboardShortcut(action: .nextWallpaper, keyCode: 6, modifiers: [.command, .shift])
                        self.delegate?.keyboardMonitor(self, didDetectShortcut: shortcut)
                        return nil
                    } else {
                        let shortcut = KeyboardShortcut(action: .previousWallpaper, keyCode: 6, modifiers: [.command])
                        self.delegate?.keyboardMonitor(self, didDetectShortcut: shortcut)
                        return nil
                    }
                }
            }
            
            return event
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
} 