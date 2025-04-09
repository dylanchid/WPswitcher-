import Foundation

/// Base protocol for all app errors
protocol AppError: LocalizedError {
    var errorCode: Int { get }
    var errorDescription: String? { get }
    var failureReason: String? { get }
    var recoverySuggestion: String? { get }
}

/// Represents different severity levels for errors
enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
}

/// Struct for presenting errors in the UI
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ErrorSeverity
    let error: AppError?
    
    init(title: String, message: String, severity: ErrorSeverity = .error, error: AppError? = nil) {
        self.title = title
        self.message = message
        self.severity = severity
        self.error = error
    }
} 