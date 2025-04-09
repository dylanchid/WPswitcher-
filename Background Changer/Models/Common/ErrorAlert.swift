import Foundation

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ErrorSeverity
    
    init(title: String, message: String, severity: ErrorSeverity = .error) {
        self.title = title
        self.message = message
        self.severity = severity
    }
}

enum ErrorSeverity: String, Codable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"
    
    var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "yellow"
        case .error: return "red"
        case .critical: return "purple"
        }
    }
} 