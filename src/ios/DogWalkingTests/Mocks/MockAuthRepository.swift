import Foundation // iOS 13.0+ (Core iOS functionality and threading)
import Combine    // iOS 13.0+ (Reactive programming for async operations)
import XCTest    // iOS 13.0+ (Testing framework functionality)

// MARK: - Internal Imports
// Using the provided paths and membership details:
// 1. The "User" class from "Domain/Models/User.swift"
// 2. The "AuthRepository" protocol from "Data/Repositories/AuthRepository.swift"
// In an actual project, replace these with the import statements appropriate for your build targets.
// For example:
//   @testable import DogWalking
//   import class Domain.Models.User
//   import protocol Data.Repositories.AuthRepository

/// A global concurrent queue utilized by the mock authentication repository.
/// It simulates the concurrency environment for thread-safe operations and test scheduling.
let mockQueue: DispatchQueue = DispatchQueue(label: "com.dogwalking.mockauth", qos: .userInitiated)

/// A global mock user object utilized for successful authentication scenarios.
/// Adjust its fields as needed to match domain and testing requirements.
let mockUser: User = User(
    id: UUID(uuidString: "c0deedc0-dead-beef-abcd-000000000000") ?? UUID(),
    email: "test@example.com",
    firstName: "Test",
    lastName: "User",
    userType: .owner
)

/// A predefined error utilized for negative testing paths. When "shouldSucceed" is false
/// (or when "customError" is set), this error may be published to simulate failure scenarios.
let mockError: NSError = NSError(
    domain: "com.dogwalking.auth",
    code: -1,
    userInfo: [NSLocalizedDescriptionKey: "Mock authentication error"]
)


/// A thread-safe mock implementation of the AuthRepository protocol. This class is designed
/// for unit testing authentication flows, enabling fully configurable success or failure outcomes,
/// adjustable response delays, and comprehensive call-count tracking. It publishes its currentUser
/// state through a Combine CurrentValueSubject, allowing tests to observe authentication state changes
/// in real time.
public final class MockAuthRepository: AuthRepository {
    
    // MARK: - Public Properties
    
    /// Publishes the current authenticated user (if any). Other classes can subscribe to
    /// this subject to detect changes in the authentication state.
    public var currentUser: CurrentValueSubject<User?, Never>
    
    /// A Boolean flag indicating whether operations should succeed (true) or fail (false).
    /// If set to false, all authentication methods will fail, returning either customError
    /// or mockError.
    public var shouldSucceed: Bool
    
    /// The artificial delay (in seconds) applied before completing each authentication method.
    /// This simulates network latency and asynchronous behavior for testing.
    public var mockDelay: TimeInterval
    
    /// The dispatch queue used to synchronize mock operations. All asynchronous tasks and
    /// shared state modifications occur on this queue to ensure thread safety.
    public let queue: DispatchQueue
    
    /// Tracks how many times the login(email:password:) method was called. This counter
    /// helps ensure that test scenarios accurately measure usage frequency.
    public var loginCallCount: Int
    
    /// Tracks how many times the register(...) method was called.
    public var registerCallCount: Int
    
    /// Tracks how many times the logout() method was called.
    public var logoutCallCount: Int
    
    /// An optional custom error to override the default mockError. If set, and "shouldSucceed"
    /// is false, this error is emitted instead of the default. This allows tests to evaluate
    /// specific error-handling paths.
    public var customError: Error?
    
    // MARK: - Initialization
    
    /**
     Initializes a thread-safe mock of the AuthRepository.
     
     - Parameters:
       - shouldSucceed: Determines whether the mock should simulate successful requests (true)
                        or failures (false).
       - mockDelay: The artificial delay (in seconds) to apply to each method, simulating network latency.
     
     Steps:
     1. Initializes a dispatch queue to ensure thread safety.
     2. Sets the shouldSucceed flag and mockDelay property.
     3. Instantiates a CurrentValueSubject with no current user.
     4. Resets all call count properties to zero.
     5. Resets any custom error to nil (no override).
     */
    public init(shouldSucceed: Bool, mockDelay: TimeInterval) {
        self.shouldSucceed = shouldSucceed
        self.mockDelay = mockDelay
        self.queue = mockQueue
        self.currentUser = CurrentValueSubject<User?, Never>(nil)
        
        self.loginCallCount = 0
        self.registerCallCount = 0
        self.logoutCallCount = 0
        self.customError = nil
    }
    
    // MARK: - AuthRepository Conformance
    
    /**
     Thread-safe mock implementation of the user login flow. Returns a publisher that emits
     either the mock user (if shouldSucceed is true) or a configured error.

     - Parameters:
       - email: The entered email address for authentication.
       - password: The entered password for authentication.
     - Returns: An AnyPublisher<User, Error> that completes asynchronously after mockDelay
                with either a successful user or an error.
     
     Steps:
     1. Increments the loginCallCount to track usage.
     2. Applies the configured mockDelay to simulate asynchronous network behavior.
     3. If shouldSucceed is true:
        - Updates currentUser to mockUser.
        - Emits the mockUser instance.
     4. If shouldSucceed is false:
        - Emits customError if set, otherwise emits mockError.
     */
    public func login(email: String, password: String) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(NSError(
                    domain: "com.dogwalking.mockauth",
                    code: -9999,
                    userInfo: [NSLocalizedDescriptionKey: "Self deallocated in mock login."]
                )))
            }
            
            self.queue.asyncAfter(deadline: .now() + self.mockDelay) {
                self.loginCallCount += 1
                
                if self.shouldSucceed {
                    // Simulate successful authentication
                    self.currentUser.send(mockUser)
                    promise(.success(mockUser))
                } else {
                    // Simulate a failed login
                    promise(.failure(self.customError ?? mockError))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Thread-safe mock implementation of the user registration flow. Returns a publisher that
     emits either the mock user (if shouldSucceed is true) or a configured error.

     - Parameters:
       - email: A string containing the user's email for new account registration.
       - password: A string containing the user’s password choice.
       - firstName: The new user’s first name.
       - lastName: The new user’s last name.
       - userType: Specifies whether the user is an owner or a walker.
     - Returns: An AnyPublisher<User, Error> that completes asynchronously, emitting either
                the newly registered (mock) user or an error.
     
     Steps:
     1. Increments the registerCallCount to track usage.
     2. Enforces the configured mockDelay to simulate network latency.
     3. If shouldSucceed is true:
        - Updates currentUser to mockUser (representing a newly registered user).
        - Emits mockUser to simulate registration success.
     4. If shouldSucceed is false:
        - Emits customError if set, otherwise mockError to simulate registration errors.
     */
    public func register(email: String,
                         password: String,
                         firstName: String,
                         lastName: String,
                         userType: UserType) -> AnyPublisher<User, Error> {
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(NSError(
                    domain: "com.dogwalking.mockauth",
                    code: -9999,
                    userInfo: [NSLocalizedDescriptionKey: "Self deallocated in mock register."]
                )))
            }
            
            self.queue.asyncAfter(deadline: .now() + self.mockDelay) {
                self.registerCallCount += 1
                
                if self.shouldSucceed {
                    // Simulate successful registration
                    self.currentUser.send(mockUser)
                    promise(.success(mockUser))
                } else {
                    // Simulate a failed registration
                    promise(.failure(self.customError ?? mockError))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Thread-safe mock implementation of the user logout flow. Returns a publisher that emits
     success or an error based on the configured behavior.

     - Returns: An AnyPublisher<Void, Error> that completes after mockDelay. It emits a Void
                value if shouldSucceed is true, or an error if shouldSucceed is false.
     
     Steps:
     1. Increments the logoutCallCount to track usage.
     2. Waits for mockDelay to simulate logout processing time.
     3. If shouldSucceed is true:
        - Sets currentUser to nil, indicating the user is logged out.
        - Emits a successful completion (Void).
     4. If shouldSucceed is false:
        - Emits customError if set, or mockError if customError is nil.
     */
    public func logout() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(NSError(
                    domain: "com.dogwalking.mockauth",
                    code: -9999,
                    userInfo: [NSLocalizedDescriptionKey: "Self deallocated in mock logout."]
                )))
            }
            
            self.queue.asyncAfter(deadline: .now() + self.mockDelay) {
                self.logoutCallCount += 1
                
                if self.shouldSucceed {
                    // Simulate successful logout
                    self.currentUser.send(nil)
                    promise(.success(()))
                } else {
                    // Simulate a failed logout
                    promise(.failure(self.customError ?? mockError))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Additional Mock Control Methods
    
    /**
     Resets all state and tracking properties to their initial values. This is useful for
     ensuring test isolation between consecutive test cases.
     
     Steps:
     1. Acquires the queue for thread-safe mutation.
     2. Resets currentUser, call counts, and any custom error to default.
     */
    public func reset() {
        queue.async {
            self.currentUser.send(nil)
            self.loginCallCount = 0
            self.registerCallCount = 0
            self.logoutCallCount = 0
            self.customError = nil
        }
    }
    
    /**
     Overrides the default mockError with a specified custom error. This allows tests to simulate
     distinct error scenarios beyond the generic error. If "shouldSucceed" is false and
     customError is set, all mock operations will fail with this custom error.

     - Parameter error: The error to use in place of the default mockError when simulating failures.
     
     Steps:
     1. Acquires the queue for thread-safe mutation.
     2. Assigns customError to the provided value.
     */
    public func setCustomError(_ error: Error) {
        queue.async {
            self.customError = error
        }
    }
}