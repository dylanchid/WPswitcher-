import Foundation
import WallpaperTypes
import AppKit
import OSLog

// MARK: - State Store with Middleware Support
@MainActor
public final class StateStore: ObservableObject {
    @Published public private(set) var state: AppState
    
    private let reducer: (inout AppState, AppAction) throws -> Void
    private let middlewares: [Middleware]
    private let logger = Logger(subsystem: "WallpaperManager", category: "StateStore")
    
    // Undo/Redo support
    private var stateHistory: [AppState] = []
    private var currentHistoryIndex: Int = -1
    private let maxHistorySize = 50
    
    // Concurrency control
    private let stateQueue = DispatchQueue(label: "com.wallpaperManager.stateQueue", qos: .userInitiated)
    private var isProcessingAction = false
    
    public init(
        initialState: AppState = AppState(),
        reducer: @escaping (inout AppState, AppAction) throws -> Void = appReducer,
        middlewares: [Middleware] = []
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middlewares = middlewares
        
        // Initialize history with initial state
        stateHistory = [initialState]
        currentHistoryIndex = 0
    }
    
    // MARK: - Action Dispatch
    public func dispatch(_ action: AppAction) async throws {
        // Prevent concurrent modifications
        guard !isProcessingAction else {
            throw AppError.stateManagement(.concurrentModification)
        }
        
        isProcessingAction = true
        defer { isProcessingAction = false }
        
        logger.debug("Dispatching action: \(String(describing: action))")
        
        do {
            // Run pre-action middlewares
            for middleware in middlewares {
                try await middleware.process(action: action, state: state)
            }
            
            // Handle special actions that don't modify state through reducer
            if await handleSpecialAction(action) {
                return
            }
            
            // Save current state for undo (before modification)
            saveStateSnapshot()
            
            // Apply reducer to modify state
            var newState = state
            try reducer(&newState, action)
            
            // Validate state consistency after reduction
            try validateStateConsistency(newState)
            
            // Update published state
            state = newState
            
            logger.debug("State updated successfully")
            
        } catch {
            logger.error("Action dispatch failed: \(error.localizedDescription)")
            
            // Set error in state for UI to handle
            var errorState = state
            errorState.lastError = error as? AppError ?? AppError.systemOperation(.serviceUnavailable(error.localizedDescription))
            state = errorState
            
            throw error
        }
    }
    
    // MARK: - Undo/Redo Operations
    public func undo() throws {
        guard canUndo else {
            throw AppError.stateManagement(.noUndoAvailable)
        }
        
        currentHistoryIndex -= 1
        state = stateHistory[currentHistoryIndex]
        logger.info("Undo performed, history index: \(currentHistoryIndex)")
    }
    
    public func redo() throws {
        guard canRedo else {
            throw AppError.stateManagement(.noRedoAvailable)
        }
        
        currentHistoryIndex += 1
        state = stateHistory[currentHistoryIndex]
        logger.info("Redo performed, history index: \(currentHistoryIndex)")
    }
    
    public var canUndo: Bool {
        currentHistoryIndex > 0
    }
    
    public var canRedo: Bool {
        currentHistoryIndex < stateHistory.count - 1
    }
    
    public func clearHistory() {
        stateHistory = [state]
        currentHistoryIndex = 0
        logger.info("State history cleared")
    }
    
    // MARK: - State Snapshots
    private func saveStateSnapshot() {
        // Remove any redo history when new action is performed
        if currentHistoryIndex < stateHistory.count - 1 {
            stateHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        // Add current state to history
        stateHistory.append(state)
        currentHistoryIndex = stateHistory.count - 1
        
        // Limit history size
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
            currentHistoryIndex = stateHistory.count - 1
        }
    }
    
    // MARK: - Special Action Handling
    private func handleSpecialAction(_ action: AppAction) async -> Bool {
        switch action {
        case .undo:
            try? undo()
            return true
            
        case .redo:
            try? redo()
            return true
            
        case .clearHistory:
            clearHistory()
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - State Validation
    private func validateStateConsistency(_ state: AppState) throws {
        // Validate active playlist exists
        if let activePlaylistId = state.activePlaylistId {
            guard state.playlists.contains(where: { $0.id == activePlaylistId }) else {
                throw AppError.stateManagement(.playlistNotFound)
            }
        }

        // Validate current wallpaper exists in wallpapers collection
        if let currentWallpaper = state.currentWallpaper {
            guard state.wallpapers.contains(where: { $0.id == currentWallpaper.id }) else {
                throw AppError.stateManagement(.invalidWallpaper)
            }
        }

        // Validate playlist wallpapers exist in main collection
        for playlist in state.playlists {
            for wallpaper in playlist.wallpapers {
                guard state.wallpapers.contains(where: { $0.id == wallpaper.id }) else {
                    throw AppError.stateManagement(.invalidWallpaper)
                }
            }
        }

        // Validate no duplicate IDs
        let wallpaperIds = state.wallpapers.map { $0.id }
        guard wallpaperIds.count == Set(wallpaperIds).count else {
            throw AppError.stateManagement(.corruptedState)
        }

        let playlistIds = state.playlists.map { $0.id }
        guard playlistIds.count == Set(playlistIds).count else {
            throw AppError.stateManagement(.corruptedState)
        }
    }
    
    // MARK: - State Persistence
    public func persistState() async throws {
        // This will be called by persistence middleware
        // Can also be called manually for explicit saves
        let persistenceMiddleware = middlewares.first { $0 is PersistenceMiddleware } as? PersistenceMiddleware
        try await persistenceMiddleware?.process(action: .updateUserProfile(state.userProfile), state: state)
    }
    
    public func loadState(from storage: StorageServiceProtocol) async throws {
        guard let savedState: AppState = try await storage.load(AppState.self, key: "appState") else {
            logger.info("No saved state found, using default state")
            return
        }
        
        // Validate loaded state
        try validateStateConsistency(savedState)
        
        state = savedState
        
        // Reset history to loaded state
        stateHistory = [savedState]
        currentHistoryIndex = 0
        
        logger.info("State loaded successfully")
    }
}

// MARK: - State Store Factory
public struct StateStoreFactory {
    public static func create(
        storage: StorageServiceProtocol,
        enableLogging: Bool = true
    ) -> StateStore {
        var middlewares: [Middleware] = []
        
        // Add validation middleware (always first)
        middlewares.append(ValidationMiddleware())
        
        // Add logging middleware if enabled
        if enableLogging {
            middlewares.append(LoggingMiddleware())
        }
        
        // Add persistence middleware (always last)
        middlewares.append(PersistenceMiddleware(storage: storage))
        
        return StateStore(middlewares: middlewares)
    }
    
    public static func createForTesting() -> StateStore {
        return StateStore(middlewares: [ValidationMiddleware()])
    }
}

// MARK: - State Store Extensions
extension StateStore {
    // Convenience methods for common operations
    
    public func addWallpaper(_ item: WallpaperItem) async throws {
        try await dispatch(.addWallpaper(item))
    }
    
    public func removeWallpaper(id: UUID) async throws {
        try await dispatch(.removeWallpaper(id))
    }
    
    public func createPlaylist(name: String) async throws -> UUID {
        let id = UUID()
        try await dispatch(.createPlaylist(name: name, id: id))
        return id
    }
    
    public func setActivePlaylist(id: UUID?) async throws {
        try await dispatch(.setActivePlaylist(id))
    }
    
    public func startRotation(playlistId: UUID) async throws {
        try await dispatch(.startRotation(playlistId: playlistId))
    }
    
    public func stopRotation() async throws {
        try await dispatch(.stopRotation)
    }
    
    public func setCurrentWallpaper(_ wallpaper: WallpaperItem?) async throws {
        try await dispatch(.setCurrentWallpaper(wallpaper))
    }
    
    public func clearError() async throws {
        try await dispatch(.clearError)
    }
}

// MARK: - Computed Properties
extension StateStore {
    public var activePlaylist: Playlist? {
        guard let id = state.activePlaylistId else { return nil }
        return state.playlists.first { $0.id == id }
    }
    
    public var hasWallpapers: Bool {
        !state.wallpapers.isEmpty
    }
    
    public var hasPlaylists: Bool {
        !state.playlists.isEmpty
    }
    
    public var isRotating: Bool {
        state.isRotationActive
    }
    
    public var currentError: AppError? {
        state.lastError
    }
}
