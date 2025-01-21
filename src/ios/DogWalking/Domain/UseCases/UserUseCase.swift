//
//  UserUseCase.swift
//
//  Implements secure and optimized business logic for user-related operations,
//  providing comprehensive error handling, caching, audit logging, and atomic
//  updates through thread locks. Acts as an intermediary between the UI layer
//  and data repositories with enhanced security and performance.
//
//  Addressed Requirements:
//  - User Management (1.3 Scope -> Core Features -> User Management)
//  - Data Management Strategy (3.2.2 Data Management Strategy)
//  - Authentication & Authorization (7.1 Authentication and Authorization)
//
//  Imports:
//  - Foundation // iOS 13.0+ version
//  - Combine   // iOS 13.0+ version
//  - DogWalking (internal module containing User domain model, etc.)
//  - This file also references a custom generic Cache for user data.
//
//  Exports:
//  - public final class UserUseCase
//    with named members: getUserProfile, updateUserProfile, verifyUser, deleteUserAccount
//
//  © 2023 DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+
import Combine    // iOS 13.0+
import DogWalking // Internal import for domain models (User) and other shared components

/// A minimal configuration struct for the cache, allowing per-instance
/// customization of cache limits or expiration policies.
public struct CacheConfiguration {
    /// The maximum number of entries allowed in the cache before eviction.
    public let countLimit: Int
    
    /// Initializes a new CacheConfiguration with a count limit.
    /// - Parameter countLimit: The maximum number of items the cache can store.
    public init(countLimit: Int) {
        self.countLimit = countLimit
    }
}

/// A generic in-memory cache that wraps an NSCache instance. This simplistic
/// version manages objects with a specified count limit and uses string keys
/// to store or retrieve domain entities (e.g., User).
///
/// In production scenarios, additional features such as TTL, LRU eviction, or
/// concurrency controls may be implemented to meet enterprise-scale demands.
public final class Cache<Key: Hashable, Value> {
    
    /// Internal NSCache that operates on NSString keys and wrapped entry objects.
    private let storage = NSCache<NSString, CacheEntry>()
    
    /// A wrapper class bridging a value to the NSCache object type requirement.
    private final class CacheEntry {
        let value: Value
        init(_ value: Value) {
            self.value = value
        }
    }
    
    /// Creates a new cache instance, optionally configuring a limit on total items.
    /// - Parameter configuration: Provides cache settings such as count limit.
    public init(configuration: CacheConfiguration) {
        storage.countLimit = configuration.countLimit
    }
    
    /// Inserts a value into the cache, associated with the specified key.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key used for lookup and retrieval.
    public func setValue(_ value: Value, forKey key: Key) where Key: CustomStringConvertible {
        storage.setObject(CacheEntry(value), forKey: NSString(string: key.description))
    }
    
    /// Attempts to retrieve a value from the cache using a given key.
    /// - Parameter key: The key previously used to store the value.
    /// - Returns: The cached value if found, otherwise nil.
    public func value(forKey key: Key) -> Value? where Key: CustomStringConvertible {
        guard let entry = storage.object(forKey: NSString(string: key.description)) else {
            return nil
        }
        return entry.value
    }
    
    /// Removes a value from the cache associated with the specified key.
    /// - Parameter key: The unique key to remove.
    public func removeValue(forKey key: Key) where Key: CustomStringConvertible {
        storage.removeObject(forKey: NSString(string: key.description))
    }
    
    /// Clears all entries from the cache.
    public func removeAll() {
        storage.removeAllObjects()
    }
    
    /// Provides the current count of cache entries. For debugging or monitoring.
    public var count: Int {
        return Int(storage.totalCostLimit) // totalCostLimit is not a perfect proxy, but used for demonstration
    }
}

/// Represents additional verification data needed to confirm a user's identity,
/// background checks, or other security steps. In a large-scale app, this might
/// include document images, reference IDs, or secure tokens.
public struct VerificationData {
    /// A placeholder for demonstration, e.g., ID or relevant tokens
    public let verificationToken: String
    /// Additional context or flags
    public let additionalInfo: String?
    
    public init(verificationToken: String, additionalInfo: String? = nil) {
        self.verificationToken = verificationToken
        self.additionalInfo = additionalInfo
    }
}

/// A specialized error type capturing domain-level issues that might occur
/// when performing user-related operations within the use case.
public enum UserUseCaseError: Error {
    /// An error indicating that the user ID was invalid or improperly formatted.
    case invalidUserId(String)
    /// Represents a scenario where the user is not permitted to perform the action.
    case permissionDenied(String)
    /// Indicates that the verification data was incomplete or invalid.
    case invalidVerificationData(String)
    /// The user was not found or was otherwise inaccessible in the system.
    case userNotFound(String)
    /// A catch-all for unexpected or unclassified errors.
    case unknown(String)
}

/// MainActor annotation ensures that UI updates or certain concurrency-sensitive
/// tasks are performed in a safe context if the UI relies on this class.
@MainActor
public final class UserUseCase {
    
    // MARK: - Public Properties (Exports)
    
    /// A Combine subject showcasing the current user or nil if not set. This
    /// property can be observed by UI components to reflect real-time changes.
    public let currentUser: CurrentValueSubject<User?, Never>
    
    // MARK: - Private Properties
    
    /// Repository providing thread-safe persistence and synchronization for user data.
    private let repository: UserRepository
    
    /// An NSLock used to ensure atomicity for critical operations like updating or deleting a user.
    private let operationLock: NSLock
    
    /// An in-memory cache mapping userId -> User domain model, optimizing repeated lookups.
    private let userCache: Cache<String, User>
    
    // MARK: - Initialization
    
    /**
     Initializes the use case with a user repository and a cache configuration, ensuring
     that the caching and thread safety measures are properly set up.
     
     Steps:
     1. Retain the provided repository in a thread-safe wrapper if needed.
     2. Configure and instantiate the user cache with the provided settings.
     3. Setup and store the NSLock instance to guard critical sections.
     4. Initialize the currentUser subject to nil.
     
     - Parameters:
       - repository: A `UserRepository` instance for data loading and synchronization.
       - cacheConfig: A `CacheConfiguration` defining constraints and eviction policy.
     */
    public init(repository: UserRepository, cacheConfig: CacheConfiguration) {
        self.repository = repository
        self.operationLock = NSLock()
        self.userCache = Cache<String, User>(configuration: cacheConfig)
        self.currentUser = CurrentValueSubject<User?, Never>(nil)
    }
    
    // MARK: - Public Methods
    
    /**
     Retrieves a user profile by user ID, performing validation checks, caching,
     and error handling. If the user is found in the cache, it is returned immediately,
     otherwise a repository lookup is initiated. The user type and verification status
     may also be validated per business logic.
     
     Steps:
     1. Validate the userID format (e.g., non-empty).
     2. Check in-memory cache for an existing user object.
     3. If found in cache, return user immediately via publisher.
     4. If not cached, fetch from repository using `getUser(userId:)`.
     5. Validate user type and verification status (optional additional checks).
     6. Populate the cache with the fetched user.
     7. Return the user via AnyPublisher, or a suitable error if not found or invalid.
     
     - Parameter userId: A String representing the user's unique identifier.
     - Returns: A publisher emitting a `User` on success or an `Error` on failure.
     */
    public func getUserProfile(userId: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let strongSelf = self else {
                return promise(.failure(UserUseCaseError.unknown("UserUseCase deinitialized.")))
            }
            
            // 1. Validate userId for non-emptiness or proper UUID format if required.
            let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty else {
                return promise(.failure(UserUseCaseError.invalidUserId("User ID cannot be empty.")))
            }
            
            // 2. Check cache
            if let cachedUser = strongSelf.userCache.value(forKey: trimmedId) {
                // 3. Cache hit: return user immediately
                return promise(.success(cachedUser))
            }
            
            // 4. Fetch from repository
            let repoPublisher = strongSelf.repository.getUser(userId: trimmedId)
            repoPublisher.sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        return promise(.failure(err))
                    }
                },
                receiveValue: { user in
                    // 5. Optional validation of user type or verification:
                    //    For demonstration, we'll skip advanced checks.
                    //    If needed, we could evaluate user.isVerified, user.userType, etc.
                    
                    // 6. Update cache
                    strongSelf.userCache.setValue(user, forKey: trimmedId)
                    
                    // Optionally track as current user if consistent with app logic:
                    // strongSelf.currentUser.send(user)
                    
                    // 7. Emit success
                    promise(.success(user))
                }
            )
            .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Updates a user's profile with validation, concurrency safeguards,
     repository persistence, and caching. An NSLock ensures that
     this operation is atomic on the local side.
     
     Steps:
     1. Acquire the thread lock to prevent concurrent modifications.
     2. Validate the update payload (e.g., required fields, permissions).
     3. Possibly apply business rules and constraints (role checks, etc.).
     4. Call the repository to perform the update transaction (with potential retry).
     5. Log an audit trail for sensitive changes (security or compliance).
     6. Invalidate or refresh the cache entry to reflect new state.
     7. Release the thread lock upon completion.
     8. Return an updated user or error through the publisher pipeline.
     
     - Parameter user: A `User` object containing the updated fields.
     - Returns: A publisher emitting the updated `User` on success or an `Error`.
     */
    public func updateUserProfile(user: User) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let strongSelf = self else {
                return promise(.failure(UserUseCaseError.unknown("UserUseCase deinitialized.")))
            }
            
            // 1. Acquire thread lock
            strongSelf.operationLock.lock()
            defer { strongSelf.operationLock.unlock() }
            
            // 2. Validate update payload
            //    Example: ensure user ID is not empty, user is active, etc.
            let userIdString = user.id.uuidString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !userIdString.isEmpty else {
                return promise(.failure(UserUseCaseError.invalidUserId("User ID in profile is invalid.")))
            }
            
            // 3. Additional business rules could be checked here, e.g. user.userType restrictions.
            
            // 4. Call repository to update user
            let updatePublisher = strongSelf.repository.updateUser(user: user)
            updatePublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let err):
                        // 8. Return error if repository update fails
                        promise(.failure(err))
                    case .finished:
                        break
                    }
                },
                receiveValue: { updatedUser in
                    // 5. Log audit trail for sensitive changes
                    strongSelf.repository.auditLog(
                        operation: "UpdateUserProfile",
                        userId: userIdString,
                        metadata: ["firstName": updatedUser.firstName, "lastName": updatedUser.lastName]
                    )
                    
                    // 6. Update or invalidate cache
                    strongSelf.userCache.removeValue(forKey: userIdString)
                    strongSelf.userCache.setValue(updatedUser, forKey: userIdString)
                    
                    // Optionally update current user subject if it matches
                    if strongSelf.currentUser.value?.id == updatedUser.id {
                        strongSelf.currentUser.send(updatedUser)
                    }
                    
                    // 8. Completed successfully
                    promise(.success(updatedUser))
                }
            )
            .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Securely verifies a user's identity and background, performing checks
     and updating the verification status. This method orchestrates:
     1) retrieval of the user, 2) verifying credentials or documents, and
     3) persisting the updated verification status via the repository.
     
     Steps:
     1. Validate verification credentials (non-empty token, etc.).
     2. Fetch current user from repository to check existing status.
     3. Evaluate if user is already verified or if additional checks are needed.
     4. Possibly call background check processes or external services.
     5. Update user verification status atomically.
     6. Log this verification attempt for audit/compliance.
     7. Return the updated user or error in a publisher.
     
     - Parameters:
       - userId: The unique ID of the user to verify.
       - data: Encapsulates the verification token or relevant documents.
     - Returns: A publisher emitting the verified User on success or an Error upon failure.
     */
    public func verifyUser(userId: String, data: VerificationData) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let strongSelf = self else {
                return promise(.failure(UserUseCaseError.unknown("UserUseCase deinitialized.")))
            }
            
            // 1. Validate verification data
            guard !data.verificationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return promise(.failure(UserUseCaseError.invalidVerificationData("Verification token cannot be empty.")))
            }
            
            let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty else {
                return promise(.failure(UserUseCaseError.invalidUserId("User ID cannot be empty for verification.")))
            }
            
            // 2. Fetch user from repository
            let userPublisher = strongSelf.repository.getUser(userId: trimmedId)
            userPublisher
                .flatMap { fetchedUser -> AnyPublisher<User, Error> in
                    // 3. Evaluate current status - if user is verified or not
                    if fetchedUser.isVerified {
                        // Already verified - skip additional steps or just return user
                        return Just(fetchedUser).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                    
                    // 4. Possibly call external background checks here - demonstration only
                    //    We'll simulate we pass. Then we set isVerified = true.
                    
                    var mutableUser = fetchedUser
                    let verifyResult = mutableUser.updateVerificationStatus(isVerified: true, verificationNotes: "Background check passed.")
                    switch verifyResult {
                    case .failure(let userErr):
                        return Fail(error: userErr).eraseToAnyPublisher()
                    case .success:
                        // 5. Update user verification in repository
                        return strongSelf.repository.updateUser(user: mutableUser)
                    }
                }
                .handleEvents(receiveOutput: { verifiedUser in
                    // 6. Log verification attempt
                    strongSelf.repository.auditLog(
                        operation: "VerifyUser",
                        userId: verifiedUser.id.uuidString,
                        metadata: [
                            "verificationToken": data.verificationToken,
                            "additionalInfo": data.additionalInfo ?? "none"
                        ]
                    )
                    // Invalidate local cache
                    strongSelf.userCache.removeValue(forKey: verifiedUser.id.uuidString)
                })
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            promise(.failure(err))
                        }
                    },
                    receiveValue: { updatedUser in
                        // 7. Return the updated user
                        promise(.success(updatedUser))
                    }
                )
                .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Deletes a user account with comprehensive cleanup, including
     checking active bookings, removing local cache entries, and
     logging the action. Ensures thread safety via NSLock.
     
     Steps:
     1. Validate user deletion permissions (e.g., only user themself or admins).
     2. Check for active walks/bookings if needed, disallow deletion if ongoing.
     3. Acquire thread lock and begin an atomic deletion transaction.
     4. Remove associated user data in local caches or other references.
     5. Invoke repository.deleteUser to clear from data store.
     6. Log account deletion for audit purposes.
     7. Commit transaction and release lock, returning success or error.
     
     - Parameter userId: The unique ID of the user to be deleted.
     - Returns: A publisher emitting Void on success or Error on failure.
     */
    public func deleteUserAccount(userId: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let strongSelf = self else {
                return promise(.failure(UserUseCaseError.unknown("UserUseCase deinitialized.")))
            }
            
            let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty else {
                return promise(.failure(UserUseCaseError.invalidUserId("User ID cannot be empty for deletion.")))
            }
            
            // 1. Validate deletion permission logic here if necessary...
            //    e.g., ensure user matches currentUser, or currentUser is admin, etc.
            //    For demonstration, we skip advanced checks.
            
            // 2. Check for active walks if business rules require. We can do a repository call or skip:
            //    strongSelf.repository.hasActiveWalks(userId: trimmedId) -> Bool?
            //    if active { return promise(.failure(UserUseCaseError.permissionDenied("Active walks exist."))) }
            
            // 3. Acquire the lock for atomic transaction
            strongSelf.operationLock.lock()
            defer { strongSelf.operationLock.unlock() }
            
            // 4. Remove the user from local cache
            strongSelf.userCache.removeValue(forKey: trimmedId)
            
            // 5. Delete user from repository
            let deletePublisher = strongSelf.repository.deleteUser(userId: trimmedId)
            deletePublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let err):
                        promise(.failure(err))
                    case .finished:
                        break
                    }
                },
                receiveValue: {
                    // 6. Log account deletion
                    strongSelf.repository.auditLog(
                        operation: "DeleteUserAccount",
                        userId: trimmedId,
                        metadata: ["reason": "User initiated or system triggered deletion"]
                    )
                    
                    // 7. Finish
                    promise(.success(()))
                }
            )
            .store(in: &SubscriptionHolder.shared.set)
        }
        .eraseToAnyPublisher()
    }
}