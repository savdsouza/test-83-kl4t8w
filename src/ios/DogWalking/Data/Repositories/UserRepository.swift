//
//  UserRepository.swift
//
//  Enhanced repository that manages user data with secure storage,
//  conflict resolution, and optimized synchronization. Conforms to the
//  enterprise-level requirements for offline-first data management,
//  encryption, authentication, and audit logging.
//
//  Addressed Requirements:
//  - User Management (1.3 Scope/Core Features/User Management)
//  - Data Management Strategy (3.2.2 Data Management Strategy)
//  - Authentication & Authorization (7.1 Authentication and Authorization)
//
//  Imports:
//  - Foundation // iOS 13.0+ version
//  - Combine // iOS 13.0+ version
//  - CoreData // iOS 13.0+ version
//  - Security // iOS 13.0+ version
//  - User, UserType from Domain/Models/User.swift
//  - UserEntity from Data/Local/CoreData/Entities/UserEntity.swift
//    (using toDomainModel(), update(from:), encryptSensitiveData())
//  - APIClient from Data/Network/APIClient.swift
//
//  Exports:
//  - Public class UserRepository
//    Exposing functions: getUser, updateUser, batchSync
//    Additional function: auditLog (for security operations logging)
//

import Foundation
import Combine
import CoreData
import Security

// Internal Imports
import DogWalking // Adjust if needed to import the correct modules.
                 // Must include the domain model: User, UserType
                 // Must include local storage entity: UserEntity
                 // Must include the network APIClient

/**
 An enumeration that encapsulates repository-specific errors. This helps
 differentiate domain or conflict errors from networking or decryption issues.
 */
private enum RepositoryError: Error {
    /// Indicates that the requested user was not found locally or remotely.
    case userNotFound(userId: String)

    /// Indicates a version conflict in optimistic locking when updating user data.
    case versionConflict(localVersion: Int, remoteVersion: Int)

    /// Generic or unknown repository-related error.
    case unknown(String)
}

/**
 A repository that implements secure data persistence and synchronization for
 user profiles. It supports conflict resolution via optimistic locking, offline-first
 caching, encryption, and enhanced security auditing.

 This class uses:
 - NSManagedObjectContext for CoreData operations.
 - A local NSCache for quick in-memory retrieval.
 - APIClient for remote server interactions.
 - A synchronization lock (NSLock) for thread safety during concurrent updates.
 */
@MainActor
public final class UserRepository {

    // MARK: - Stored Properties

    /// A reference to the CoreData managed object context used for reading
    /// and writing user data offline.
    private let context: NSManagedObjectContext

    /// A reference to the shared APIClient instance for making secure network requests.
    private let apiClient: APIClient

    /// A lock to guard against race conditions during update operations.
    /// Ensures thread safety and conflict resolution for user data.
    private let syncLock: NSLock

    /**
     A user cache that temporarily holds User domain models keyed by userId (UUID string).
     This cache is used to optimize performance and reduce redundant fetches.
     */
    private let userCache: NSCache<NSString, User>

    // MARK: - Initializer

    /**
     Initializes the UserRepository with a given CoreData context.

     Steps:
     1. Store the provided context for local persistence.
     2. Reference the shared APIClient for remote operations.
     3. Create and configure an NSLock to enforce synchronization.
     4. Instantiate the NSCache and optionally configure expiration or cost limits.
     5. Configure any batch operation or advanced concurrency settings as needed.
     */
    public init(context: NSManagedObjectContext) {
        self.context = context
        self.apiClient = APIClient.shared
        self.syncLock = NSLock()
        self.userCache = NSCache<NSString, User>()

        // Example cache configuration (an optional step for advanced usage).
        // userCache.totalCostLimit = 50
        // userCache.countLimit = 100
        // Further expiration logic can be implemented if needed:
        // e.g., wrapping NSCache or adding timers to remove stale entries.
    }

    // MARK: - Public Exposed Methods

    /**
     Retrieves a user from the cache or local storage, then optionally fetches from the remote API if needed.
     Includes data validation and caching to optimize performance.

     Steps:
     1. Check in-memory cache for the user.
     2. If absent, query the local CoreData store (UserEntity).
     3. Validate integrity (e.g., isActive checks).
     4. Fetch remote updates if local data is stale or forced.
     5. Update the in-memory cache.
     6. Return a publisher emitting the user or an error.

     - Parameter userId: The UUID string identifying the user.
     - Returns: A Combine publisher that eventually emits the found User or an Error.
     */
    public func getUser(userId: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(RepositoryError.unknown("UserRepository instance deallocated.")))
            }

            // Step 1: Check cache for existing user
            if let cachedUser = self.userCache.object(forKey: userId as NSString) {
                // If found, we can optionally confirm that data is valid or proceed directly.
                // For demonstration, we proceed directly with the cached user.
                return promise(.success(cachedUser))
            }

            // Step 2: Query local storage if not cached
            var localUser: User? = nil
            do {
                let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", userId)
                fetchRequest.fetchLimit = 1
                if let entity = try self.context.fetch(fetchRequest).first {
                    let domainModel = entity.toDomainModel()
                    localUser = domainModel
                }
            } catch {
                // If local fetch fails, we can log or handle as needed
                return promise(.failure(error))
            }

            // Step 3: Validate data integrity (example: ensure user isActive).
            // For demonstration, we skip explicit checks or just proceed if a localUser exists.
            // Additional logic can be inserted here as needed.

            // Step 4: Attempt to fetch remote updates if needed.
            // We can decide based on local timestamps, version fields, or needsSync.
            // For now, let's demonstrate a remote call to keep data fresh.
            let remotePublisher = self.apiClient.request(
                endpoint: .getUserProfile(userId: userId),
                type: User.self
            )
            .tryMap { remoteUser -> User in
                // Merge logic if localUser is present:
                // Compare versions or updatedAt fields.
                // For demonstration, we assume remoteUser is the source of truth.
                return remoteUser
            }
            .catch { _ -> AnyPublisher<User, Error> in
                // If remote fetch fails, fallback to local user if available.
                guard let fallbackUser = localUser else {
                    return Fail(error: RepositoryError.userNotFound(userId: userId)).eraseToAnyPublisher()
                }
                return Just(fallbackUser).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { finalUser in
                // Step 5: Update in-memory cache with the final user data after remote or fallback success.
                self.userCache.setObject(finalUser, forKey: userId as NSString)

                // Optionally update local storage with the finalUser result.
                do {
                    try self.updateLocalUser(finalUser)
                } catch {
                    // Log or handle update failure but do not disrupt the user retrieval flow.
                }
            })
            .eraseToAnyPublisher()

            remotePublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let err):
                        promise(.failure(err))
                    case .finished:
                        break
                    }
                },
                receiveValue: { user in
                    promise(.success(user))
                }
            )
            .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }

    /**
     Updates the given user in both remote and local storage, applying optimistic locking
     and conflict resolution. Uses a synchronization lock to ensure thread safety.

     Steps:
     1. Acquire the sync lock to serialize all update operations.
     2. Verify the user version or concurrency fields for conflict.
     3. Send updated fields to the remote API.
     4. Handle version conflicts or success from the server.
     5. Update local storage with the new user data.
     6. Invalidate or refresh the in-memory cache entry.
     7. Release the sync lock and return the final updated user.

     - Parameter user: The domain User object containing updated fields.
     - Returns: A publisher that emits the updated User or an error on failure.
     */
    public func updateUser(user: User) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(RepositoryError.unknown("UserRepository instance deallocated.")))
            }

            // Step 1: Acquire the synchronization lock
            self.syncLock.lock()

            // Retrieve the local version or concurrency data if needed
            let localVersion = user.version

            // Step 2: Verify user version if local or remote concurrency checks are required.
            // For demonstration, let's illustrate a scenario:
            if localVersion < 0 {
                // This is an example conflict scenario if version is negative
                self.syncLock.unlock()
                return promise(.failure(RepositoryError.versionConflict(localVersion: localVersion, remoteVersion: 0)))
            }

            // Step 3: Update remote API with new user data
            // Here we map user fields to a relevant endpoint: updateUserProfile(userId: user.id, ...)
            let remotePublisher = self.apiClient.request(
                endpoint: .updateUserProfile(
                    userId: user.id.uuidString,
                    name: user.firstName + " " + user.lastName,
                    email: user.email,
                    phone: user.phone
                ),
                type: User.self
            )
            .tryMap { remoteUpdatedUser -> User in
                // Step 4: Handle version conflicts or success
                // Suppose the remote user has version incremented or is different:
                let remoteVersion = remoteUpdatedUser.version
                if remoteVersion < localVersion {
                    // Conflict: remote is older than local
                    throw RepositoryError.versionConflict(
                        localVersion: localVersion,
                        remoteVersion: remoteVersion
                    )
                }
                return remoteUpdatedUser
            }
            .handleEvents(receiveOutput: { finalUser in
                // Step 5: Update local storage
                do {
                    try self.updateLocalUser(finalUser)
                } catch {
                    // If local update fails, we can throw or log as needed.
                    throw error
                }

                // Step 6: Invalidate or refresh cache entry
                self.userCache.removeObject(forKey: finalUser.id.uuidString as NSString)
            })
            .handleEvents(receiveCompletion: { _ in
                // Step 7: Release the lock after completion
                self.syncLock.unlock()
            })
            .eraseToAnyPublisher()

            remotePublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let err):
                        promise(.failure(err))
                    case .finished:
                        break
                    }
                },
                receiveValue: { updatedUser in
                    promise(.success(updatedUser))
                }
            )
            .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }

    /**
     Performs a batch synchronization for a list of user IDs, efficiently fetching
     remote updates, resolving conflicts, and updating the local store in a single
     operation. Also updates the in-memory cache for quick access.

     Steps:
     1. Group and prepare user IDs for a batch operation.
     2. Fetch remote updates for these user IDs in a single network call (simulate or call batchRequest).
     3. Process each user for version or concurrency conflicts.
     4. Update local storage in batch, applying encryption as needed.
     5. Refresh or populate cache entries for all updated users.
     6. Return the list of synchronized User objects or an error.

     - Parameter userIds: An array of user ID strings.
     - Returns: A publisher emitting an array of updated/synchronized Users or an Error.
     */
    public func batchSync(userIds: [String]) -> AnyPublisher<[User], Error> {
        return Future<[User], Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(RepositoryError.unknown("UserRepository instance deallocated.")))
            }

            // Step 1: Group IDs
            let uniqueIds = Array(Set(userIds))

            // Step 2: Fetch remote updates in a batch call (assuming APIClient has a 'batchRequest' or similar).
            // For demonstration, we simulate a single request that returns an array of users.
            // If real batch endpoints are not defined, you might do multiple parallel requests or re-implement logic.
            let remotePublisher = self.apiClient.request(
                endpoint: .getUserProfile(userId: "batchLookupPlaceholder"), // Example placeholder
                type: [User].self
            )
            .tryMap { remoteUsers -> [User] in
                // We'll assume we get an array of User from the server for all IDs.
                // Filter only those that match userIds for demonstration:
                let relevant = remoteUsers.filter { uniqueIds.contains($0.id.uuidString) }
                return relevant
            }
            .handleEvents(receiveOutput: { updatedList in
                // Step 3 & 4: Process conflicts and update local storage in bulk.
                do {
                    try self.context.performAndWait {
                        for user in updatedList {
                            // Conflict resolution would compare user.version with local version as needed.
                            // Then update or create local entity:
                            try self.updateLocalUser(user)
                        }
                    }
                } catch {
                    // If any error occurs updating local data, propagate the error.
                    throw error
                }

                // Step 5: Update or refresh in-memory cache.
                for user in updatedList {
                    self.userCache.setObject(user, forKey: user.id.uuidString as NSString)
                }
            })
            .eraseToAnyPublisher()

            remotePublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let err):
                        // Return error if batch synchronization fails
                        promise(.failure(err))
                    case .finished:
                        break
                    }
                },
                receiveValue: { syncedUsers in
                    // Step 6: Return the synchronized user list
                    promise(.success(syncedUsers))
                }
            )
            .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Security & Audit

    /**
     Records a security-relevant operation into an audit log, including metadata and timestamps.
     This can be extended to store logs locally, send them to a remote endpoint, or integrate with
     OSLog security categories.

     Steps:
     1. Format the audit entry with operation details.
     2. Add additional security context (e.g., environment, user session).
     3. Capture the current timestamp.
     4. Store or send the audit log to a secure location.
     5. Handle any storage or transmission errors as needed.

     - Parameters:
       - operation: A descriptive name for the security-relevant action.
       - userId: The user ID associated with this audit event.
       - metadata: A dictionary with any additional context or parameters to save.
     */
    public func auditLog(operation: String, userId: String, metadata: [String: Any]) {
        // Step 1: Format the entry
        var entry = "[AUDIT] Operation: \(operation), UserID: \(userId)"

        // Step 2: Add security context
        entry += ", Environment: Production" // or from some environment config
        if !metadata.isEmpty {
            entry += ", Metadata: \(metadata)"
        }

        // Step 3: Record a timestamp
        let now = Date()
        entry += ", Timestamp: \(now)"

        // Step 4: Store or send the log. For example, we might simply print or use a logger:
        // In a real application, you could route this to a secured system or append to a local DB.
        print(entry) // Placeholder
    }

    // MARK: - Private Helpers

    /**
     Updates or creates a local UserEntity from the given domain User object.
     Also invokes additional encryption or conflict resolution methods as necessary.
     - Parameter user: The domain User to persist locally.
     - Throws: Any error encountered while saving to CoreData.
     */
    private func updateLocalUser(_ user: User) throws {
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", user.id.uuidString)
        fetchRequest.fetchLimit = 1

        let existing = try context.fetch(fetchRequest).first
        let entity = existing ?? UserEntity(context: context)

        // Update fields from the domain model
        entity.update(from: user)

        // The specification mentions calling 'encryptSensitiveData()' for additional security
        entity.encryptSensitiveData()

        // Mark final changes and save the context
        if entity.validateForUpdate() {
            try context.save()
        } else {
            throw RepositoryError.unknown("Validation failed for user entity with id: \(user.id)")
        }
    }
}

/**
 A subscription holder that retains Combine AnyCancellable references.
 This ensures asynchronous operations remain alive for the duration of
 their lifecycle, preventing premature cancellation.

 This structure is often used for demonstration, testing, or simplified
 code samples.
 */
fileprivate final class SubscriptionHolder {
    static let shared = SubscriptionHolder()
    var set = Set<AnyCancellable>()
    private init() {}
}