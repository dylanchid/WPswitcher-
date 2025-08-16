import Foundation
import Wallpaper

enum MigrationStatus: Equatable {
    case notStarted
    case inProgress(version: AppVersion)
    case completed
    case failed(error: String)
    
    static func == (lhs: MigrationStatus, rhs: MigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.inProgress(let lhsVersion), .inProgress(let rhsVersion)):
            return lhsVersion == rhsVersion
        case (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// Remove duplicate KeyboardShortcut - using the one from UserSettingsService instead 