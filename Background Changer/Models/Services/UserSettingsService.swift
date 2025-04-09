import Foundation

@MainActor
class UserSettingsService: ObservableObject, UserSettingsServiceProtocol {
    // MARK: - Published Properties
    @Published private(set) var userSettings: UserSettings
    @Published private(set) var userProfile: UserProfile
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // MARK: - Constants
    private let userSettingsKey = "userSettings"
    private let userProfileKey = "userProfile"
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Load or create default settings
        if let data = userDefaults.data(forKey: userSettingsKey),
           let settings = try? decoder.decode(UserSettings.self, from: data) {
            self.userSettings = settings
        } else {
            self.userSettings = UserSettings()
        }
        
        // Load or create default profile
        if let data = userDefaults.data(forKey: userProfileKey),
           let profile = try? decoder.decode(UserProfile.self, from: data) {
            self.userProfile = profile
        } else {
            self.userProfile = UserProfile()
        }
    }
    
    // MARK: - UserSettingsServiceProtocol Implementation
    
    func updateSettings(_ settings: UserSettings) async throws {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: userSettingsKey)
            userSettings = settings
        } catch {
            throw WallpaperError.saveFailed("Failed to save user settings: \(error.localizedDescription)")
        }
    }
    
    func updateProfile(_ profile: UserProfile) async throws {
        do {
            let data = try encoder.encode(profile)
            userDefaults.set(data, forKey: userProfileKey)
            userProfile = profile
        } catch {
            throw WallpaperError.saveFailed("Failed to save user profile: \(error.localizedDescription)")
        }
    }
    
    func resetSettings() async throws {
        let defaultSettings = UserSettings()
        let defaultProfile = UserProfile()
        
        do {
            try await updateSettings(defaultSettings)
            try await updateProfile(defaultProfile)
        } catch {
            throw WallpaperError.saveFailed("Failed to reset settings: \(error.localizedDescription)")
        }
    }
    
    func exportSettings() async throws -> Data {
        let exportData = SettingsExport(
            settings: userSettings,
            profile: userProfile,
            version: AppVersion.current.rawValue
        )
        
        do {
            return try encoder.encode(exportData)
        } catch {
            throw WallpaperError.saveFailed("Failed to export settings: \(error.localizedDescription)")
        }
    }
    
    func importSettings(_ data: Data) async throws {
        do {
            let importData = try decoder.decode(SettingsExport.self, from: data)
            
            // Validate version compatibility
            guard let version = AppVersion(rawValue: importData.version),
                  version <= AppVersion.current else {
                throw WallpaperError.invalidData("Settings from newer version \(importData.version) cannot be imported")
            }
            
            // Update settings and profile
            try await updateSettings(importData.settings)
            try await updateProfile(importData.profile)
        } catch let error as WallpaperError {
            throw error
        } catch {
            throw WallpaperError.loadFailed("Failed to import settings: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

private struct SettingsExport: Codable {
    let settings: UserSettings
    let profile: UserProfile
    let version: String
} 