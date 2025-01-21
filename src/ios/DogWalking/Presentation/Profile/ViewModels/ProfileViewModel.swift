import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)

// MARK: - Internal Imports
import Core/Base/BaseViewModel    // Base view model functionality with thread-safe operations
import Domain/UseCases/UserUseCase // Thread-safe user management business logic
import Domain/Models/User         // Secure user domain model

/// A specialized error type representing failures or edge cases within the profile view model.
/// This error handling mechanism is designed for robust user feedback and secure logging.
public enum ProfileError: Error {
    /// Indicates that the provided user ID was invalid or empty.
    case invalidUserId(String)

    /// Indicates that there is currently no user loaded in memory.
    case noCurrentUser(String)

    /// Indicates a validation issue with one of the profile fields (e.g., first name, phone).
    case invalidInput(String)

    /// Captures failures that occur during the update process, such as a repository or network error.
    case updateFailed(String)

    /// A catch-all for unexpected or unclassified errors.
    case unknown(String)
}

/// @MainActor annotation ensures all UI-bound operations are dispatched on the main thread,
/// enhancing safety in Swift Concurrency for UI updates.
@MainActor
public class ProfileViewModel: BaseViewModel {

    // MARK: - Public Properties (Exposed)
    //
    // These properties are exposed so that the UI layer or other observers can subscribe and react
    // to changes in user state, completion events, or errors published by this view model.

    /// A CurrentValueSubject holding an optional User (nil if no user is loaded).
    /// Observers can track the current user state in real-time.
    public let userSubject: CurrentValueSubject<User?, Never>

    /// A subject that emits whenever the profile has been successfully updated.
    /// Views and other layers can subscribe to trigger refreshes or transitions.
    public let profileUpdatedSubject: PassthroughSubject<Void, Never>

    /// A subject that emits profile-related errors. Observers can subscribe to display
    /// relevant alerts or logs. This subject never completes with a failure type, only `Never`.
    public let profileErrorSubject: PassthroughSubject<ProfileError, Never>

    // MARK: - Private/Internal Properties

    /// A serial DispatchQueue to ensure thread safety for shared resources and critical sections
    /// within the ProfileViewModel. All major operations should be funneled through this queue.
    private let serialQueue: DispatchQueue

    /// A reference to the user use case, which coordinates business logic, data fetching,
    /// and updates for user profiles. Ensures thread-safe calls to the domain layer.
    private let userUseCase: UserUseCase

    /// An in-memory cache that stores recently loaded user profiles keyed by user ID.
    /// This helps reduce redundant fetches and speeds up subsequent UI interactions.
    private let profileCache: NSCache<NSString, User>

    /// A debounce interval (in seconds) that can be applied when sending frequent update requests
    /// to avoid rapid-fire network calls or conflicting changes.
    private let updateDebounceInterval: TimeInterval

    // MARK: - Initialization

    /// Initializes the profile view model with all required dependencies and security configurations.
    /// This includes setting up thread safety, caching, and performance monitoring instruments.
    ///
    /// Steps:
    /// 1. Call super.init() to ensure base functionality from BaseViewModel is available.
    /// 2. Initialize a dedicated serial queue to handle state changes safely.
    /// 3. Retain the UserUseCase instance for domain-level requests.
    /// 4. Create a CurrentValueSubject<User?, Never> with an initial nil value representing no loaded user.
    /// 5. Create a PassthroughSubject<Void, Never> for notifying about successful profile updates.
    /// 6. Configure and set cache limits for the profileCache to handle memory usage effectively.
    /// 7. Perform any security audit logging initialization or placeholders for compliance audits.
    /// 8. Initialize an error handling system, exemplified by the profileErrorSubject.
    /// 9. Set up placeholders for performance monitoring or detailed instrumentation.
    ///
    /// - Parameters:
    ///   - userUseCase: An instance of the UserUseCase class, handling user-related data requests.
    ///   - debounceInterval: A TimeInterval specifying how long to wait before sending certain updates.
    public init(userUseCase: UserUseCase, debounceInterval: TimeInterval) {
        // 1. Call super.init() to utilize the BaseViewModel's initialization logic.
        super.init()

        // 2. Create a dedicated serial dispatch queue for synchronization of any shared mutable state.
        self.serialQueue = DispatchQueue(label: "com.dogwalking.ProfileViewModel.serialQueue",
                                         qos: .userInitiated)

        // 3. Store the userUseCase instance for domain-level user operations.
        self.userUseCase = userUseCase

        // 4. Initialize a CurrentValueSubject with nil, signifying no logged-in user at the start.
        self.userSubject = CurrentValueSubject<User?, Never>(nil)

        // 5. Initialize the subject signaling profile updates.
        self.profileUpdatedSubject = PassthroughSubject<Void, Never>()

        // 6. Configure a cache for profiles, setting a reasonable count limit to manage memory usage.
        let cache = NSCache<NSString, User>()
        cache.countLimit = 50 // Sample limit; can be tuned based on app usage or memory constraints.
        self.profileCache = cache

        // 7. Set up security audit logging placeholders or references to advanced logging frameworks.
        // Example: Logger.shared.security("[ProfileViewModel] Security logging initialized.")

        // 8. Initialize a subject for profile-specific errors.
        self.profileErrorSubject = PassthroughSubject<ProfileError, Never>()

        // 9. Set up any performance monitoring or instrumentation placeholders if needed (e.g., signposts).
        // Example: Logger.shared.debug("Performance monitoring for ProfileViewModel is enabled.")

        // Store the supplied debounce interval for future usage in update call scheduling.
        self.updateDebounceInterval = debounceInterval
    }

    // MARK: - Public Methods

    /// Loads the user profile data from cache if available; otherwise fetches from the user use case.
    /// This operation is thread-safe, setting a loading state for the duration of the process and
    /// publishing errors or results accordingly.
    ///
    /// Steps:
    /// - Check cache for existing profile keyed by userId.
    /// - Set loading state to true.
    /// - Validate userId format (non-empty, potential regex checks).
    /// - Execute domain request on the serial queue.
    /// - Use userUseCase.getUserProfile to fetch if cache is empty.
    /// - Update the cache and userSubject with the fetched user.
    /// - Log user profile access for security or compliance audits.
    /// - Set loading state to false once complete.
    /// - If errors occur, emit them via the errorSubject or convert to ProfileError as needed.
    ///
    /// - Parameter userId: The unique identifier of the user whose profile to load.
    /// - Returns: A publisher emitting the User on success or an Error upon failure.
    public func loadUserProfile(userId: String) -> AnyPublisher<User, Error> {
        // Check if there's a cached user profile for the given userId.
        if let cachedUser = profileCache.object(forKey: userId as NSString) {
            // Immediately return a just publisher if found in cache.
            return Just(cachedUser)
                .setFailureType(to: Error.self)
                .handleEvents(receiveSubscription: { [weak self] _ in
                    // Set loading state to true, then false quickly since this is from cache.
                    self?.setLoading(true)
                }, receiveOutput: { [weak self] user in
                    // Update userSubject with the cached user.
                    self?.userSubject.send(user)
                    // Log profile access
                    // Example: Logger.shared.security("Accessed cached profile for userId \(userId)")
                }, receiveCompletion: { [weak self] _ in
                    // End loading
                    self?.setLoading(false)
                })
                .eraseToAnyPublisher()
        }

        // Not in cache, proceed with a fresh load.
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(ProfileError.unknown("ProfileViewModel deinitialized.")))
            }

            // 1. Set loading state to true
            self.setLoading(true)

            // 2. Validate user ID format
            let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty else {
                self.setLoading(false)
                let error = ProfileError.invalidUserId("User ID cannot be empty.")
                self.profileErrorSubject.send(error)
                return promise(.failure(error))
            }

            // 3. Perform the use case call on self.serialQueue
            self.serialQueue.async {
                // Use userUseCase.getUserProfile publisher
                let userProfilePublisher = self.userUseCase.getUserProfile(userId: trimmedId)
                    .handleEvents(receiveOutput: { user in
                        // Update cache with fetched user
                        self.profileCache.setObject(user, forKey: trimmedId as NSString)
                        // Update userSubject
                        DispatchQueue.main.async {
                            self.userSubject.send(user)
                            // Example: Logger.shared.security("Loaded user profile from domain for userId \(trimmedId)")
                        }
                    })
                    .receive(on: DispatchQueue.main) // Switch to main to handle state transitions
                    .handleEvents(receiveCompletion: { completion in
                        // Turn off loading state upon completion
                        self.setLoading(false)
                    })
                    .catch { error -> AnyPublisher<User, Error> in
                        // Convert domain or generalized errors to a ProfileError if desired
                        // and publish them to the errorSubject.
                        let convertedError = error
                        self.errorSubject.send(convertedError)
                        return Fail(error: convertedError).eraseToAnyPublisher()
                    }

                // Sink the publisher to produce a result for the Future's promise.
                let _ = userProfilePublisher.sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let err):
                        // If there's an error, reject the promise
                        promise(.failure(err))
                    case .finished:
                        // Not typical to do anything specific on finished here
                        break
                    }
                }, receiveValue: { user in
                    // Successfully fetched user from domain
                    promise(.success(user))
                })
            }
        }
        .eraseToAnyPublisher()
    }

    /// Updates the current user's profile using secure validation and a debounced approach
    /// to prevent excessive network calls. Returns a publisher that emits the updated user
    /// or an error if the operation fails.
    ///
    /// Steps:
    /// - Execute the logic on the serial queue for thread safety.
    /// - Validate and sanitize input parameters (e.g., trim whitespace).
    /// - Check that a current user is loaded; otherwise fail with a noCurrentUser error.
    /// - Build an update batch (firstName, lastName, phone, profileImageUrl).
    /// - Debounce the network request by updateDebounceInterval to avoid rapid calls.
    /// - Call userUseCase.updateUserProfile to perform the actual update.
    /// - If successful, update the cache, userSubject, and fire profileUpdatedSubject.
    /// - Log or handle any errors, optionally implementing retry logic for transient failures.
    ///
    /// - Parameters:
    ///   - firstName: An optional new first name for the user.
    ///   - lastName: An optional new last name for the user.
    ///   - phone: An optional phone number.
    ///   - profileImageUrl: An optional URL for the user's profile picture.
    /// - Returns: A publisher emitting the updated User or an Error upon failure.
    public func updateProfile(firstName: String?,
                              lastName: String?,
                              phone: String?,
                              profileImageUrl: String?) -> AnyPublisher<User, Error> {
        // Use a Deferred publisher to wait until the subscription before scheduling tasks.
        return Deferred {
            Future<User, Error> { [weak self] promise in
                guard let self = self else {
                    return promise(.failure(ProfileError.unknown("ProfileViewModel deinitialized.")))
                }

                // Run everything on the serial queue to keep it thread-safe.
                self.serialQueue.async {
                    // 1. Validate existence of current user
                    guard let currentUser = self.userSubject.value else {
                        let error = ProfileError.noCurrentUser("No current user is loaded.")
                        self.profileErrorSubject.send(error)
                        return promise(.failure(error))
                    }

                    // 2. Validate input parameters (basic example: ensure non-empty for firstName/lastName if provided)
                    let trimmedFirstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedProfileImageUrl = profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)

                    // 3. Construct a safe update batch or directly call user.updateProfile
                    //    We'll do a local domain user object update, then pass it to userUseCase.
                    switch currentUser.updateProfile(firstName: trimmedFirstName,
                                                     lastName: trimmedLastName,
                                                     phone: trimmedPhone,
                                                     profileImageUrl: trimmedProfileImageUrl.flatMap(URL.init),
                                                     preferences: nil) {
                    case .failure(let userErr):
                        // Convert domain userErr to a ProfileError if needed.
                        let error = ProfileError.updateFailed("Local validation: \(userErr)")
                        self.profileErrorSubject.send(error)
                        return promise(.failure(error))
                    case .success:
                        break
                    }

                    // 4. Debounce the network request by sleeping for updateDebounceInterval
                    //    (In a real-world scenario, you'd likely use a Combine operator for debouncing,
                    //     but here we demonstrate a manual approach.)
                    Thread.sleep(forTimeInterval: self.updateDebounceInterval)

                    // 5. Now proceed with userUseCase.updateUserProfile, applying a retry for network failures.
                    self.setLoading(true)
                    let updatePublisher = self.userUseCase.updateUserProfile(user: currentUser)
                        .retry(2) // Implement basic retry logic for transient failures
                        .handleEvents(receiveOutput: { updatedUser in
                            // 6. Update the in-memory cache
                            self.profileCache.removeObject(forKey: updatedUser.id as NSString)
                            self.profileCache.setObject(updatedUser, forKey: updatedUser.id as NSString)

                            // 7. Update the userSubject to reflect the latest user data
                            DispatchQueue.main.async {
                                self.userSubject.send(updatedUser)
                            }
                            // Log security event
                            // Example: Logger.shared.security("Profile updated for userId: \(updatedUser.id)")
                        })
                        .receive(on: DispatchQueue.main)
                        .handleEvents(receiveCompletion: { _ in
                            // Turn off loading when done
                            self.setLoading(false)
                        })
                        .catch { error -> AnyPublisher<User, Error> in
                            // On error, convert or pass the error along
                            self.errorSubject.send(error)
                            let profileErr = ProfileError.updateFailed("Failed to update profile: \(error.localizedDescription)")
                            self.profileErrorSubject.send(profileErr)
                            return Fail(error: error).eraseToAnyPublisher()
                        }

                    // 8. Sink the updatePublisher to produce the final result
                    let _ = updatePublisher.sink(receiveCompletion: { completion in
                        switch completion {
                        case .failure(let err):
                            promise(.failure(err))
                        case .finished:
                            break
                        }
                    }, receiveValue: { updatedUser in
                        // 9. Emit event on profileUpdatedSubject
                        self.profileUpdatedSubject.send(())
                        // Successfully updated, resolve the Future
                        promise(.success(updatedUser))
                    })
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Retrieves the current user's user type (e.g., .owner or .walker) in a thread-safe manner.
    /// This method ensures access to `userSubject.value` occurs on the serial queue to avoid races.
    ///
    /// Steps:
    /// - Dispatch on serial queue.
    /// - Return userSubject.value?.userType if available; else nil.
    /// - Log the access attempt, potentially for audit or tracing.
    ///
    /// - Returns: An optional UserType, or nil if no user is currently loaded.
    public func getUserType() -> UserType? {
        var result: UserType?
        // Execute on the serial queue
        serialQueue.sync {
            result = userSubject.value?.userType
            // Example: Logger.shared.debug("Accessed current user type: \(String(describing: result))")
        }
        return result
    }
}