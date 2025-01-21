//
//  CoreDataManager.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-15.
//
//  This file defines a thread-safe singleton CoreDataManager class that facilitates
//  local data persistence, including offline-first capabilities, conflict resolution,
//  and comprehensive error handling. It manages CoreData contexts, background tasks,
//  and database clearing operations for the Dog Walking application.
//
//  ----------------------------------------------------------------------------------
//  Requirements Addressed (from JSON specification):
//    1) Data Management Strategy (offline-first, caching, thread-safety).
//    2) Database Architecture (manages local storage for user profiles, walk records).
//    3) System Overview (offline-first architecture handling migrations, synchronization).
//
//  ----------------------------------------------------------------------------------
//  Internal & External Imports
//  ----------------------------------------------------------------------------------
//  Using CoreData (iOS 13.0+ version) and Foundation (iOS 13.0+ version).
//  Importing entities DogEntity, UserEntity, WalkEntity for direct usage in clearDatabase.
//  In a typical Xcode project, these classes would be in the same module or imported
//  through the app target's dependencies.
//

import Foundation // iOS 13.0+ version
import CoreData   // iOS 13.0+ version

// Internal entity imports (same module or separate, depending on project setup).
// Ensuring we can reference DogEntity, UserEntity, WalkEntity for batch operations if needed.
// import Entities.DogEntity
// import Entities.UserEntity
// import Entities.WalkEntity

/**
 A thread-safe, production-ready singleton manager for the CoreData stack,
 ensuring robust local data persistence with offline-first capabilities and
 conflict resolution. It encapsulates:

 - A persistent container configured with automatic migration.
 - Main-thread (view) and background contexts for concurrency.
 - Utility methods for saving contexts, performing background tasks,
   and clearing all entities from the local database.

 The design follows enterprise-grade patterns to handle large-scale
 record operations, preventing data corruption or deadlocks by using
 proper concurrency strategies and error handling.

 Usage:
    let manager = CoreDataManager.shared
    let result = manager.saveContext(context: manager.viewContext)
*/
public final class CoreDataManager {

    // MARK: - Properties

    /// The shared singleton instance of CoreDataManager.
    /// Guaranteed to be thread-safe via dispatch_once at initialization.
    public static let shared: CoreDataManager = CoreDataManager()

    /// The NSPersistentContainer that manages the CoreData stack.
    public let container: NSPersistentContainer

    /// The main (view) context, tied to the main queue,
    /// used for UI-driven fetch/update operations.
    public let viewContext: NSManagedObjectContext

    /// A long-lived background context for batch or heavy operations,
    /// configured with private queue concurrency.
    public let backgroundContext: NSManagedObjectContext

    /// A store description that can be used to configure migration,
    /// history tracking, and other store-level options.
    public let storeDescription: NSPersistentStoreDescription

    // MARK: - Private Initializer

    /**
     Private initializer that configures the entire CoreData stack
     with a persistent container named "DogWalking", sets up
     concurrency, merge policies, and persistent history tracking.
     */
    private init() {
        // 1) Initialize persistent container with model name "DogWalking".
        let containerName = "DogWalking"
        container = NSPersistentContainer(name: containerName)

        // 2) Configure store description for automatic migrations and history tracking.
        storeDescription = container.persistentStoreDescriptions.first
            ?? NSPersistentStoreDescription()
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        // Reassigning the configured store description to container if needed:
        container.persistentStoreDescriptions = [storeDescription]

        // 3) Load persistent stores and handle potential errors.
        container.loadPersistentStores { [weak container] (_, error) in
            if let error = error {
                fatalError("CoreDataManager: Failed to load persistent stores: \(error.localizedDescription)")
            }
            guard let container = container else { return }
            // Additional store-related configurations post-load if necessary.
            // e.g., container.viewContext.automaticallyMergesChangesFromParent = true
        }

        // 4) Configure viewContext with .mainQueueConcurrencyType for UI usage.
        viewContext = container.viewContext
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true

        // 5) Create a background context with .privateQueueConcurrencyType.
        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

        // 6) From step #4 and #5, the merge policies enforce conflict resolution.
        // 7) Automatic merging of changes is enabled for cross-context updates.

        // 8) Persistent history tracking is already set in the storeDescription.

        // At this point, the stack is fully initialized for offline-first usage.
    }

    // MARK: - Public Methods

    /**
     Saves changes in the provided managed object context, handling
     errors and returning a Result<Void, Error> for robust error reporting.

     Steps:
       1) Check if the context has changes.
       2) Attempt to validate and save.
       3) Return a success or detailed error Result.

     - Parameter context: The NSManagedObjectContext to save.
     - Returns: A Result<Void, Error> indicating success or failure.
    */
    @discardableResult
    public func saveContext(context: NSManagedObjectContext) -> Result<Void, Error> {
        guard context.hasChanges else {
            // No changes to save, return success early.
            return .success(())
        }

        do {
            // Validate objects before saving.
            try context.save()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /**
     Executes a closure on the background context in a thread-safe manner,
     capturing any errors or successes within a Result<Void, Error>.

     Steps:
       1) Perform the closure within backgroundContext.performAndWait.
       2) Catch any thrown errors during execution.
       3) If context has changes, attempt to save them.
       4) Return success or error result.

     - Parameter block: A throwing closure that receives the background context.
     - Returns: A Result<Void, Error> capturing success or the error encountered.
    */
    @discardableResult
    public func performBackgroundTask(
        _ block: (NSManagedObjectContext) throws -> Void
    ) -> Result<Void, Error> {
        var operationResult: Result<Void, Error> = .success(())

        backgroundContext.performAndWait {
            do {
                // 1) Execute the caller-supplied block in a private queue context.
                try block(backgroundContext)

                // 2) If changes occurred, save them to disk.
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
            } catch {
                operationResult = .failure(error)
            }
        }

        // 3) Return the final result of the operation (success or failure).
        return operationResult
    }

    /**
     Safely removes all records from the local database, using batch
     deletes for known entities, then saves or rolls back the transaction.
     This process is performed on the background context, ensuring no
     UI blocking. If the operation succeeds, the viewContext is reset
     for a consistent fresh state.

     Steps:
       1) Perform an operation in the background context.
       2) Issue NSBatchDeleteRequests for DogEntity, UserEntity, WalkEntity.
       3) Save changes if successful; rollback if any fails.
       4) Reset the view context if everything completes.
       5) Return a success or error result.

     - Returns: A Result<Void, Error> indicating complete success or any error.
    */
    @discardableResult
    public func clearDatabase() -> Result<Void, Error> {
        var operationResult: Result<Void, Error> = .success(())
        backgroundContext.performAndWait {
            // Start a transaction-like block
            do {
                // List of entity names to batch delete
                let entityNames = ["DogEntity", "UserEntity", "WalkEntity"]

                // Perform batch deletes in sequence, rollback on any error
                for entityName in entityNames {
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    _ = try backgroundContext.execute(deleteRequest)
                }

                // If all deletes succeed, save the context
                try backgroundContext.save()

                // Reset the main view context for a clean slate
                viewContext.performAndWait {
                    viewContext.reset()
                }

                operationResult = .success(())
            } catch {
                // Roll back the background context changes on any failure
                backgroundContext.rollback()
                operationResult = .failure(error)
            }
        }
        return operationResult
    }
}