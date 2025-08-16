import Foundation

/// Base protocol for all app errors
protocol AppError: LocalizedError {
    var errorCode: Int { get }
    var errorDescription: String? { get }
    var failureReason: String? { get }
    var recoverySuggestion: String? { get }
} 