import Foundation
import WallpaperTypes
import AppKit
import OSLog

// MARK: - Smart Rotation Engine
public final class SmartRotationEngine {
    private var displayHistory: [WallpaperDisplay] = []
    private let maxHistorySize = 100
    private let logger = Logger(subsystem: "WallpaperManager", category: "SmartRotation")
    
    // User preference learning
    private var userInteractions: [UserInteraction] = []
    private let maxInteractionHistory = 500
    
    public init() {}
    
    // MARK: - Main Selection Method
    public func selectNextWallpaper(
        from playlist: Playlist,
        mode: PlaybackMode,
        context: RotationContext
    ) -> WallpaperItem? {
        guard !playlist.wallpapers.isEmpty else {
            logger.warning("Attempted to select from empty playlist")
            return nil
        }
        
        logger.debug("Selecting next wallpaper with mode: \(mode)")
        
        let selectedWallpaper: WallpaperItem?
        
        switch mode {
        case .smart:
            selectedWallpaper = selectSmartWallpaper(from: playlist, context: context)
        case .timeAware:
            selectedWallpaper = selectTimeBasedWallpaper(from: playlist, context: context)
        case .seasonal:
            selectedWallpaper = selectSeasonalWallpaper(from: playlist, context: context)
        case .adaptive:
            selectedWallpaper = selectAdaptiveWallpaper(from: playlist, context: context)
        case .moodBased:
            selectedWallpaper = selectMoodBasedWallpaper(from: playlist, context: context)
        case .sequential:
            selectedWallpaper = selectSequentialWallpaper(from: playlist, context: context)
        case .random:
            selectedWallpaper = selectRandomWallpaper(from: playlist)
        case .shuffle:
            selectedWallpaper = selectShuffleWallpaper(from: playlist, context: context)
        }
        
        // Record the selection
        if let selected = selectedWallpaper {
            recordWallpaperDisplay(selected, context: context)
            logger.debug("Selected wallpaper: \(selected.name)")
        }
        
        return selectedWallpaper
    }
    
    // MARK: - Smart Selection Algorithm
    private func selectSmartWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        let scores = playlist.wallpapers.map { wallpaper in
            calculateSmartScore(for: wallpaper, context: context)
        }
        
        let scoredWallpapers = Array(zip(playlist.wallpapers, scores))
        return weightedRandomSelection(from: scoredWallpapers)
    }
    
    private func calculateSmartScore(for wallpaper: WallpaperItem, context: RotationContext) -> Double {
        var score: Double = 100.0
        
        // Time-based scoring
        score *= timeRelevanceMultiplier(for: wallpaper, context: context)
        
        // Recency penalty
        score *= recencyPenalty(for: wallpaper)
        
        // User preference boost
        score *= userPreferenceMultiplier(for: wallpaper)
        
        // Display frequency balancing
        score *= displayFrequencyBalancing(for: wallpaper)
        
        // Context relevance
        score *= contextRelevanceMultiplier(for: wallpaper, context: context)
        
        // Quality scoring
        score *= qualityMultiplier(for: wallpaper)
        
        return max(0.1, score) // Ensure minimum score
    }
    
    // MARK: - Time-Based Selection
    private func selectTimeBasedWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        // Filter wallpapers suitable for current time
        let timeAppropriateWallpapers = playlist.wallpapers.filter { wallpaper in
            guard let metadata = wallpaper.metadata,
                  let timePreference = metadata.timeOfDayPreference else {
                return true // Include wallpapers without time preference
            }
            return timePreference.contains(currentHour)
        }
        
        if timeAppropriateWallpapers.isEmpty {
            return selectRandomWallpaper(from: playlist)
        }
        
        // Score time-appropriate wallpapers
        let scores = timeAppropriateWallpapers.map { wallpaper in
            var score = 100.0
            score *= recencyPenalty(for: wallpaper)
            score *= userPreferenceMultiplier(for: wallpaper)
            return score
        }
        
        let scoredWallpapers = Array(zip(timeAppropriateWallpapers, scores))
        return weightedRandomSelection(from: scoredWallpapers)
    }
    
    // MARK: - Seasonal Selection
    private func selectSeasonalWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        let currentSeason = getCurrentSeason()
        
        // Filter wallpapers by season tags
        let seasonalWallpapers = playlist.wallpapers.filter { wallpaper in
            wallpaper.tags.contains(currentSeason.rawValue) ||
            wallpaper.tags.isEmpty // Include untagged wallpapers
        }
        
        if seasonalWallpapers.isEmpty {
            return selectSmartWallpaper(from: playlist, context: context)
        }
        
        return selectSmartWallpaper(
            from: Playlist(id: playlist.id, name: playlist.name, wallpapers: seasonalWallpapers),
            context: context
        )
    }
    
    // MARK: - Adaptive Selection
    private func selectAdaptiveWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        // Adaptive mode learns from user behavior and system context
        let adaptiveScores = playlist.wallpapers.map { wallpaper in
            var score = calculateSmartScore(for: wallpaper, context: context)
            
            // Boost based on system state
            if context.isLowPowerMode {
                // Prefer simpler, less resource-intensive wallpapers
                if wallpaper.metadata?.fileSize ?? 0 < 5 * 1024 * 1024 { // Less than 5MB
                    score *= 1.3
                }
            }
            
            // Boost based on user activity patterns
            score *= activityPatternMultiplier(for: wallpaper, context: context)
            
            // Boost based on weather (if available)
            score *= weatherRelevanceMultiplier(for: wallpaper, context: context)
            
            return score
        }
        
        let scoredWallpapers = Array(zip(playlist.wallpapers, adaptiveScores))
        return weightedRandomSelection(from: scoredWallpapers)
    }
    
    // MARK: - Mood-Based Selection
    private func selectMoodBasedWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        let detectedMood = detectUserMood(context: context)
        
        let moodAppropriateWallpapers = playlist.wallpapers.filter { wallpaper in
            isMoodAppropriate(wallpaper: wallpaper, mood: detectedMood)
        }
        
        if moodAppropriateWallpapers.isEmpty {
            return selectSmartWallpaper(from: playlist, context: context)
        }
        
        return selectSmartWallpaper(
            from: Playlist(id: playlist.id, name: playlist.name, wallpapers: moodAppropriateWallpapers),
            context: context
        )
    }
    
    // MARK: - Traditional Selection Methods
    private func selectSequentialWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        guard let currentWallpaper = context.currentWallpaper else {
            return playlist.wallpapers.first
        }
        
        guard let currentIndex = playlist.wallpapers.firstIndex(where: { $0.id == currentWallpaper.id }) else {
            return playlist.wallpapers.first
        }
        
        let nextIndex = (currentIndex + 1) % playlist.wallpapers.count
        return playlist.wallpapers[nextIndex]
    }
    
    private func selectRandomWallpaper(from playlist: Playlist) -> WallpaperItem? {
        return playlist.wallpapers.randomElement()
    }
    
    private func selectShuffleWallpaper(from playlist: Playlist, context: RotationContext) -> WallpaperItem? {
        // Shuffle with anti-repetition logic
        let recentWallpapers = Set(displayHistory.suffix(min(playlist.wallpapers.count / 3, 10)).map { $0.wallpaperId })
        
        let availableWallpapers = playlist.wallpapers.filter { !recentWallpapers.contains($0.id) }
        
        if availableWallpapers.isEmpty {
            return playlist.wallpapers.randomElement()
        }
        
        return availableWallpapers.randomElement()
    }
    
    // MARK: - Scoring Multipliers
    private func timeRelevanceMultiplier(for wallpaper: WallpaperItem, context: RotationContext) -> Double {
        guard let metadata = wallpaper.metadata,
              let timePreference = metadata.timeOfDayPreference else {
            return 1.0
        }
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        return timePreference.contains(currentHour) ? 1.3 : 0.7
    }
    
    private func recencyPenalty(for wallpaper: WallpaperItem) -> Double {
        guard let lastDisplay = displayHistory.last(where: { $0.wallpaperId == wallpaper.id }) else {
            return 1.2 // Boost for never-displayed wallpapers
        }
        
        let hoursSince = Date().timeIntervalSince(lastDisplay.timestamp) / 3600
        
        // Full score restored after 24 hours
        return min(1.0, max(0.1, hoursSince / 24))
    }
    
    private func userPreferenceMultiplier(for wallpaper: WallpaperItem) -> Double {
        // Calculate preference based on user interactions
        let interactions = userInteractions.filter { $0.wallpaperId == wallpaper.id }
        
        if interactions.isEmpty {
            return 1.0
        }
        
        let positiveActions = interactions.filter { $0.type.isPositive }.count
        let negativeActions = interactions.filter { $0.type.isNegative }.count
        let totalActions = interactions.count
        
        if totalActions == 0 {
            return 1.0
        }
        
        let positiveRatio = Double(positiveActions) / Double(totalActions)
        let negativeRatio = Double(negativeActions) / Double(totalActions)
        
        // Range from 0.3 to 2.0
        return 0.3 + (1.7 * positiveRatio) - (0.7 * negativeRatio)
    }
    
    private func displayFrequencyBalancing(for wallpaper: WallpaperItem) -> Double {
        let wallpaperDisplayCount = displayHistory.filter { $0.wallpaperId == wallpaper.id }.count
        let averageDisplayCount = Double(displayHistory.count) / Double(max(1, displayHistory.map { $0.wallpaperId }.unique().count))
        
        if Double(wallpaperDisplayCount) < averageDisplayCount {
            return 1.2 // Boost underused wallpapers
        } else if Double(wallpaperDisplayCount) > averageDisplayCount * 1.5 {
            return 0.8 // Reduce overused wallpapers
        }
        
        return 1.0
    }
    
    private func contextRelevanceMultiplier(for wallpaper: WallpaperItem, context: RotationContext) -> Double {
        var multiplier = 1.0
        
        // Display resolution matching
        if let metadata = wallpaper.metadata {
            let wallpaperAspectRatio = metadata.dimensions.width / metadata.dimensions.height
            let screenAspectRatio = context.screenSize.width / context.screenSize.height
            
            let aspectRatioDifference = abs(wallpaperAspectRatio - screenAspectRatio)
            if aspectRatioDifference < 0.1 {
                multiplier *= 1.2 // Perfect aspect ratio match
            } else if aspectRatioDifference > 0.5 {
                multiplier *= 0.8 // Poor aspect ratio match
            }
        }
        
        // Battery level consideration
        if context.batteryLevel < 0.2 && context.isOnBattery {
            // Prefer smaller, simpler wallpapers when battery is low
            if let fileSize = wallpaper.metadata?.fileSize, fileSize < 3 * 1024 * 1024 {
                multiplier *= 1.1
            }
        }
        
        return multiplier
    }
    
    private func qualityMultiplier(for wallpaper: WallpaperItem) -> Double {
        guard let metadata = wallpaper.metadata else { return 1.0 }
        
        var qualityScore = 1.0
        
        // Resolution quality
        let pixelCount = metadata.dimensions.width * metadata.dimensions.height
        if pixelCount >= 3840 * 2160 { // 4K or higher
            qualityScore *= 1.2
        } else if pixelCount < 1920 * 1080 { // Below Full HD
            qualityScore *= 0.9
        }
        
        // Color depth
        if metadata.colorDepth >= 10 {
            qualityScore *= 1.1
        }
        
        // File size optimization (not too small, not too large)
        let fileSizeMB = Double(metadata.fileSize) / (1024 * 1024)
        if fileSizeMB >= 2 && fileSizeMB <= 15 {
            qualityScore *= 1.1
        } else if fileSizeMB < 0.5 || fileSizeMB > 30 {
            qualityScore *= 0.9
        }
        
        return qualityScore
    }
    
    private func activityPatternMultiplier(for wallpaper: WallpaperItem, context: RotationContext) -> Double {
        // This would analyze user activity patterns (work hours, leisure time, etc.)
        // For now, implement basic logic
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let isWeekday = !calendar.isDateInWeekend(Date())
        
        // Work hours detection
        if isWeekday && hour >= 9 && hour <= 17 {
            // Prefer calmer, less distracting wallpapers during work hours
            if wallpaper.tags.contains("minimal") || wallpaper.tags.contains("professional") {
                return 1.3
            }
            if wallpaper.tags.contains("vibrant") || wallpaper.tags.contains("busy") {
                return 0.7
            }
        }
        
        return 1.0
    }
    
    private func weatherRelevanceMultiplier(for wallpaper: WallpaperItem, context: RotationContext) -> Double {
        // This would integrate with weather APIs
        // For now, implement seasonal logic
        
        let season = getCurrentSeason()
        
        if wallpaper.tags.contains(season.rawValue) {
            return 1.2
        }
        
        // Opposite season penalty
        let oppositeSeason = season.opposite
        if wallpaper.tags.contains(oppositeSeason.rawValue) {
            return 0.8
        }
        
        return 1.0
    }
    
    // MARK: - Mood Detection
    private func detectUserMood(context: RotationContext) -> UserMood {
        // Simple mood detection based on time and context
        // In a real implementation, this could analyze:
        // - Calendar events
        // - Recent user interactions
        // - System usage patterns
        // - External data sources
        
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 6 && hour <= 9 {
            return .energetic
        } else if hour >= 10 && hour <= 16 {
            return .focused
        } else if hour >= 17 && hour <= 20 {
            return .relaxed
        } else {
            return .calm
        }
    }
    
    private func isMoodAppropriate(wallpaper: WallpaperItem, mood: UserMood) -> Bool {
        switch mood {
        case .energetic:
            return wallpaper.tags.contains("vibrant") || wallpaper.tags.contains("colorful") || wallpaper.tags.contains("sunrise")
        case .focused:
            return wallpaper.tags.contains("minimal") || wallpaper.tags.contains("clean") || wallpaper.tags.contains("professional")
        case .relaxed:
            return wallpaper.tags.contains("nature") || wallpaper.tags.contains("landscape") || wallpaper.tags.contains("peaceful")
        case .calm:
            return wallpaper.tags.contains("dark") || wallpaper.tags.contains("night") || wallpaper.tags.contains("minimal")
        }
    }
    
    // MARK: - Utility Methods
    private func weightedRandomSelection(from scoredWallpapers: [(WallpaperItem, Double)]) -> WallpaperItem? {
        guard !scoredWallpapers.isEmpty else { return nil }
        
        let totalScore = scoredWallpapers.reduce(0) { $0 + $1.1 }
        let randomValue = Double.random(in: 0...totalScore)
        
        var currentSum = 0.0
        for (wallpaper, score) in scoredWallpapers {
            currentSum += score
            if currentSum >= randomValue {
                return wallpaper
            }
        }
        
        return scoredWallpapers.last?.0
    }
    
    private func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .fall
        default: return .spring
        }
    }
    
    // MARK: - History Management
    private func recordWallpaperDisplay(_ wallpaper: WallpaperItem, context: RotationContext) {
        let display = WallpaperDisplay(
            wallpaperId: wallpaper.id,
            timestamp: Date(),
            duration: 0, // Will be updated when wallpaper changes
            userSkipped: false,
            context: context
        )
        
        displayHistory.append(display)
        
        // Update duration of previous display
        if displayHistory.count > 1 {
            let previousIndex = displayHistory.count - 2
            let duration = Date().timeIntervalSince(displayHistory[previousIndex].timestamp)
            displayHistory[previousIndex] = displayHistory[previousIndex].withDuration(duration)
        }
        
        // Limit history size
        if displayHistory.count > maxHistorySize {
            displayHistory.removeFirst(displayHistory.count - maxHistorySize)
        }
    }
    
    public func recordUserInteraction(_ interaction: UserInteraction) {
        userInteractions.append(interaction)
        
        // Limit interaction history
        if userInteractions.count > maxInteractionHistory {
            userInteractions.removeFirst(userInteractions.count - maxInteractionHistory)
        }
        
        logger.debug("Recorded user interaction: \(interaction.type) for wallpaper \(interaction.wallpaperId)")
    }
    
    public func recordWallpaperSkipped(_ wallpaperId: UUID) {
        if let lastIndex = displayHistory.lastIndex(where: { $0.wallpaperId == wallpaperId }) {
            displayHistory[lastIndex] = displayHistory[lastIndex].withUserSkipped(true)
        }
        
        // Also record as user interaction
        let interaction = UserInteraction(
            wallpaperId: wallpaperId,
            type: .skipped,
            timestamp: Date()
        )
        recordUserInteraction(interaction)
    }
}

// MARK: - Supporting Types
public struct WallpaperDisplay {
    let wallpaperId: UUID
    let timestamp: Date
    let duration: TimeInterval
    let userSkipped: Bool
    let context: RotationContext
    
    func withDuration(_ newDuration: TimeInterval) -> WallpaperDisplay {
        return WallpaperDisplay(
            wallpaperId: wallpaperId,
            timestamp: timestamp,
            duration: newDuration,
            userSkipped: userSkipped,
            context: context
        )
    }
    
    func withUserSkipped(_ skipped: Bool) -> WallpaperDisplay {
        return WallpaperDisplay(
            wallpaperId: wallpaperId,
            timestamp: timestamp,
            duration: duration,
            userSkipped: skipped,
            context: context
        )
    }
}

public struct UserInteraction {
    let wallpaperId: UUID
    let type: InteractionType
    let timestamp: Date
    
    public enum InteractionType {
        case liked
        case disliked
        case favorited
        case unfavorited
        case skipped
        case viewedLong // Viewed for more than expected duration
        case viewedShort // Viewed for less than expected duration
        case shared
        case setAsDesktop
        
        var isPositive: Bool {
            switch self {
            case .liked, .favorited, .viewedLong, .shared, .setAsDesktop:
                return true
            case .disliked, .unfavorited, .skipped, .viewedShort:
                return false
            }
        }
        
        var isNegative: Bool {
            return !isPositive
        }
    }
}

public struct RotationContext {
    let currentWallpaper: WallpaperItem?
    let screenSize: CGSize
    let isLowPowerMode: Bool
    let batteryLevel: Double
    let isOnBattery: Bool
    let userActivity: UserActivity
    let timeOfDay: TimeOfDay
    
    public init(
        currentWallpaper: WallpaperItem? = nil,
        screenSize: CGSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080),
        isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        batteryLevel: Double = 1.0,
        isOnBattery: Bool = false,
        userActivity: UserActivity = .unknown,
        timeOfDay: TimeOfDay = TimeOfDay.current
    ) {
        self.currentWallpaper = currentWallpaper
        self.screenSize = screenSize
        self.isLowPowerMode = isLowPowerMode
        self.batteryLevel = batteryLevel
        self.isOnBattery = isOnBattery
        self.userActivity = userActivity
        self.timeOfDay = timeOfDay
    }
}

public enum UserMood {
    case energetic
    case focused
    case relaxed
    case calm
}

public enum UserActivity {
    case working
    case leisure
    case presenting
    case gaming
    case unknown
}

public enum TimeOfDay {
    case earlyMorning  // 5-8 AM
    case morning       // 8-12 PM
    case afternoon     // 12-5 PM
    case evening       // 5-8 PM
    case night         // 8 PM-12 AM
    case lateNight     // 12-5 AM
    
    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<24: return .night
        default: return .lateNight
        }
    }
}

public enum Season: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"
    
    var opposite: Season {
        switch self {
        case .spring: return .fall
        case .summer: return .winter
        case .fall: return .spring
        case .winter: return .summer
        }
    }
}

// MARK: - Array Extension
extension Array where Element: Hashable {
    func unique() -> [Element] {
        return Array(Set(self))
    }
}
