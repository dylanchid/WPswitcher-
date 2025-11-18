import CoreData
import OSLog

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    private static let logger = Logger(subsystem: "WallpaperManager", category: "Persistence")

    /// Error that can occur during persistence initialization
    enum PersistenceError: LocalizedError {
        case failedToLoadStore(Error)

        var errorDescription: String? {
            switch self {
            case .failedToLoadStore(let error):
                return "Failed to load persistent store: \(error.localizedDescription)"
            }
        }
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Background_Changer")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Configure merge policy for better conflict resolution
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error instead of crashing
                Self.logger.error("Failed to load persistent store: \(error.localizedDescription), \(error.userInfo)")

                // Attempt recovery by deleting corrupted store and retrying
                if let storeURL = storeDescription.url {
                    Self.attemptStoreRecovery(at: storeURL, container: self.container, inMemory: inMemory)
                }
            } else {
                Self.logger.info("Successfully loaded persistent store: \(storeDescription.url?.lastPathComponent ?? "unknown")")
            }
        }
    }

    /// Attempts to recover from a corrupted store by removing and recreating it
    private static func attemptStoreRecovery(at url: URL, container: NSPersistentContainer, inMemory: Bool) {
        logger.warning("Attempting store recovery at: \(url.path)")

        do {
            // Remove the corrupted store
            try FileManager.default.removeItem(at: url)

            // Also remove related files (shm, wal)
            let shmURL = url.appendingPathExtension("shm")
            let walURL = url.appendingPathExtension("wal")
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)

            // Retry loading the store
            container.loadPersistentStores { (_, retryError) in
                if let retryError = retryError {
                    logger.critical("Store recovery failed: \(retryError.localizedDescription)")
                    // At this point, the app may need user intervention
                    // Post notification for UI to handle
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PersistenceStoreFailure"),
                        object: nil,
                        userInfo: ["error": retryError]
                    )
                } else {
                    logger.info("Store recovery successful - data was reset")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PersistenceStoreRecovered"),
                        object: nil
                    )
                }
            }
        } catch {
            logger.critical("Failed to remove corrupted store: \(error.localizedDescription)")
            NotificationCenter.default.post(
                name: NSNotification.Name("PersistenceStoreFailure"),
                object: nil,
                userInfo: ["error": error]
            )
        }
    }

    /// Returns the view context for main thread operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Creates a new background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    /// Saves the view context if there are pending changes
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Self.logger.error("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}