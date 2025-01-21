import Foundation // iOS 13.0+ (Essential iOS library for data types, error handling, etc.)
import Combine    // iOS 13.0+ (Reactive streams library for publishing/subscribing async data)
// MARK: - Internal Imports
import class DogWalking.Data.Repositories.AuthRepository.AuthRepository
import class DogWalking.Core.Utilities.BiometricAuthManager.BiometricAuthManager
import os.log     // iOS 13.0+ (System-level logging for security and monitoring)

/**
 An enumeration representing notable authentication-related events that can occur within the AuthUseCase,
 facilitating real-time tracking, logging, and security monitoring throughout the authentication flow.
 These events are published via `authEvents` for any observers to listen and respond accordingly.
 */
public enum AuthEvent {
    /// Event triggered when a credentials-based login starts.
    case loginStarted
    
    /// Event indicating that a credentials-based login operation succeeded.
    /// Includes the authenticated User object.
    case loginSucceeded(User)
    
    /// Event indicating that a credentials-based login operation failed.
    /// Includes an associated Error describing the reason.
    case loginFailed(Error)
    
    /// Event triggered when a biometric-based login begins.
    case biometricAuthStarted
    
    /// Event indicating that a biometric-based login operation succeeded.
    /// Includes the authenticated User object.
    case biometricAuthSucceeded(User)
    
    /// Event indicating that a biometric-based login operation failed.
    /// Includes an associated Error describing the reason.
    case biometricAuthFailed(Error)
    
    /// Event triggered when a token refresh process starts.
    case tokenRefreshStarted
    
    /// Event indicating that a token refresh process completed successfully.
    case tokenRefreshSucceeded
    
    /// Event indicating that a token refresh process has failed.
    /// Includes an associated Error describing the reason.
    case tokenRefreshFailed(Error)
}

/**
 A thread-safe, enterprise-grade use case class that coordinates advanced authentication business logic,
 including login with credentials, biometric authentication, secure token handling, and security monitoring.

 This class interacts with the AuthRepository to streamline the authentication workflow, handling details such as:
 - Input validation and suspicious activity checks.
 - Biometric authentication via the BiometricAuthManager.
 - Token refresh orchestration to maintain a valid session.
 - Emitting real-time AuthEvent states for logging, analytics, and UI notifications.

 Conforms to:
 - High security standards with thorough logging, error handling, and biometric usage.
 - The specification in "7.1 Authentication and Authorization" for multi-method authentication.
 - "7.3 Security Protocols" for monitoring and suspicious behavior detection.
 */
public final class AuthUseCase {
    
    // MARK: - Properties
    
    /**
     Reference to the authentication repository responsible for lower-level
     credential storage, token renewal, and network requests to the backend authentication service.
     */
    private let authRepository: AuthRepository
    
    /**
     Manages the device's biometric functionality, controlling Touch ID or Face ID login attempts
     along with thorough logging and fallback mechanisms.
     */
    private let biometricAuthManager: BiometricAuthManager
    
    /**
     A current user subject that publishes the latest authenticated User object
     or nil if unauthenticated. Observers can subscribe to track changes in real time.
     */
    public let currentUser: CurrentValueSubject<User?, Never>
    
    /**
     A subject used to emit `AuthEvent` values, allowing subscribers to receive
     immediate updates about authentication state changes, errors, and monitoring events.
     */
    public let authEvents: PassthroughSubject<AuthEvent, Never>
    
    /**
     Maintains a collection of AnyCancellable references for Combine subscriptions,
     preventing them from being deallocated prematurely.
     */
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /**
     Initializes the AuthUseCase with necessary dependencies, sets up real-time user
     synchronization from the repository, and configures security monitoring for authentication events.

     - Parameter authRepository: The AuthRepository instance used for login, registration, token refresh, etc.
     - Steps:
       1. Store a reference to the AuthRepository.
       2. Initialize and store a BiometricAuthManager instance.
       3. Create local CurrentValueSubject and PassthroughSubject for user and auth event tracking.
       4. Subscribe to AuthRepository's currentUser to synchronize user state updates.
       5. Set up additional monitoring or security checks if required.
     */
    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        self.biometricAuthManager = BiometricAuthManager.shared
        
        // Initialize local subjects to track user state and auth events.
        self.currentUser = CurrentValueSubject<User?, Never>(nil)
        self.authEvents = PassthroughSubject<AuthEvent, Never>()
        
        // Keep in sync with the repository's current user stream.
        self.authRepository.currentUser
            .sink { [weak self] user in
                self?.currentUser.send(user)
            }
            .store(in: &cancellables)
        
        os_log("AuthUseCase initialized with references to AuthRepository and BiometricAuthManager.",
               log: .default, type: .info)
    }
    
    // MARK: - Public Methods
    
    /**
     Authenticates a user using email and password credentials, with comprehensive validation
     and suspicious activity detection. Emits AuthEvents for lifecycle monitoring. Updates
     `currentUser` upon completion.

     - Parameters:
       - email:    The user's email string for login.
       - password: The user's password string for login.
     - Returns: A publisher emitting the authenticated `User` on success or an `Error` on failure.
     
     Steps:
      1. Emit a `.loginStarted` event for monitoring.
      2. Validate the input email and password for correctness (non-empty, format checks).
      3. Check for potential suspicious activity (placeholder logic).
      4. Call `authRepository.login(...)` with the validated credentials.
      5. On success, emit `.loginSucceeded(user)`, publish the user to `currentUser`.
      6. On error, emit `.loginFailed(error)`.
      7. Return an `AnyPublisher<User, Error>` representing the entire operation.
     */
    public func loginWithCredentials(email: String,
                                     password: String) -> AnyPublisher<User, Error> {
        // 1. Emit a start event for security monitoring or UI feedback.
        authEvents.send(.loginStarted)
        
        // 2. Validate input. If invalid, immediately fail.
        guard validateCredentialsFormat(email: email, password: password) else {
            let validationError = NSError(domain: "AuthUseCase",
                                          code: 1001,
                                          userInfo: [NSLocalizedDescriptionKey: "Invalid email or password format."])
            os_log("loginWithCredentials: Input validation failed for email: %{public}@",
                   log: .default, type: .error, email)
            authEvents.send(.loginFailed(validationError))
            return Fail(error: validationError).eraseToAnyPublisher()
        }
        
        // 3. Placeholder suspicious activity check. If suspicious, fail quickly.
        if checkForSuspiciousActivity(email: email) {
            let suspiciousError = NSError(domain: "AuthUseCase",
                                          code: 1002,
                                          userInfo: [NSLocalizedDescriptionKey: "Suspicious activity detected."])
            os_log("loginWithCredentials: Suspicious activity flagged for email: %{public}@",
                   log: .default, type: .error, email)
            authEvents.send(.loginFailed(suspiciousError))
            return Fail(error: suspiciousError).eraseToAnyPublisher()
        }
        
        // 4. Call repository login method to perform secure authentication.
        return authRepository.login(email: email,
                                    password: password,
                                    useBiometric: false)
            .handleEvents(receiveOutput: { [weak self] user in
                // 5. Emit success event and update current user.
                self?.authEvents.send(.loginSucceeded(user))
                self?.currentUser.send(user)
                os_log("loginWithCredentials: Successfully authenticated user: %{public}@",
                       log: .default, type: .info, user.email)
            }, receiveCompletion: { [weak self] completion in
                // 6. If error occurs, emit a failure event for detailed logging.
                if case .failure(let err) = completion {
                    self?.authEvents.send(.loginFailed(err))
                    os_log("loginWithCredentials: Repository login failed with error: %{public}@",
                           log: .default, type: .error, err.localizedDescription)
                }
            })
            .eraseToAnyPublisher()
    }
    
    /**
     Attempts to authenticate a user using biometric methods (Touch ID / Face ID). Provides
     a fallback mechanism if biometrics are unavailable or fail. Retrieves stored credentials,
     then calls the repository to complete authentication. Emits AuthEvents for each stage and
     updates `currentUser` upon success.

     - Returns: A publisher emitting the authenticated `User` on success or an `Error` on failure.

     Steps:
      1. Emit a `.biometricAuthStarted` event for monitoring.
      2. Check if biometric authentication is available via `biometricAuthManager`.
      3. Prompt the user to authenticate with biometrics.
      4. On success, retrieve stored credentials from Keychain (placeholder example).
      5. Perform credentials-based login through the repository.
      6. Emit either `.biometricAuthSucceeded(user)` or `.biometricAuthFailed(error)`.
      7. Update `currentUser` and return the user through the publisher pipeline.
     */
    public func loginWithBiometrics() -> AnyPublisher<User, Error> {
        // 1. Indicate the process is starting for watchers or logs.
        authEvents.send(.biometricAuthStarted)
        
        // 2. Check biometric availability.
        guard biometricAuthManager.canUseBiometrics() else {
            let noBioError = NSError(domain: "AuthUseCase",
                                     code: 2001,
                                     userInfo: [NSLocalizedDescriptionKey: "Biometric authentication is not available."])
            os_log("loginWithBiometrics: Biometrics not available or not enrolled.",
                   log: .default, type: .error)
            authEvents.send(.biometricAuthFailed(noBioError))
            return Fail(error: noBioError).eraseToAnyPublisher()
        }
        
        // 3. Verify credentials after a successful biometric prompt.
        return Future<User, Error> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(NSError(domain: "AuthUseCase",
                                                code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "Self deallocated."])))
            }
            
            // Request biometric authentication from the BiometricAuthManager.
            self.biometricAuthManager.authenticateUser { authResult in
                switch authResult {
                case .success:
                    // 4. If biometrics succeed, retrieve stored credentials from Keychain (placeholder).
                    // In a production scenario, we'd store user credentials or tokens in Keychain.
                    let storedEmail = self.retrieveStoredEmail() ?? ""
                    let storedPassword = self.retrieveStoredPassword() ?? ""
                    
                    // If credentials are missing or incomplete, fail quickly.
                    if storedEmail.isEmpty || storedPassword.isEmpty {
                        let fallbackError = NSError(domain: "AuthUseCase",
                                                    code: 2002,
                                                    userInfo: [NSLocalizedDescriptionKey: "No stored credentials found for fallback login."])
                        self.authEvents.send(.biometricAuthFailed(fallbackError))
                        return promise(.failure(fallbackError))
                    }
                    
                    // 5. Perform login through repository using retrieved credentials.
                    self.authRepository.login(email: storedEmail,
                                              password: storedPassword,
                                              useBiometric: true)
                        .sink(receiveCompletion: { completion in
                            if case .failure(let err) = completion {
                                self.authEvents.send(.biometricAuthFailed(err))
                                os_log("loginWithBiometrics: Credentials-based login failed after biometric success: %{public}@",
                                       log: .default, type: .error, err.localizedDescription)
                                return promise(.failure(err))
                            }
                        }, receiveValue: { user in
                            // 6. Emit success event, update current user, finish promise.
                            self.authEvents.send(.biometricAuthSucceeded(user))
                            self.currentUser.send(user)
                            os_log("loginWithBiometrics: Successfully authenticated user: %{public}@",
                                   log: .default, type: .info, user.email)
                            return promise(.success(user))
                        })
                        .store(in: &self.cancellables)
                    
                case .failure(let error):
                    // If biometric auth fails, emit event and return the error.
                    self.authEvents.send(.biometricAuthFailed(error))
                    os_log("loginWithBiometrics: Biometric authentication failed. Error: %{public}@",
                           log: .default, type: .error, error.localizedDescription)
                    return promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Manages a secure token refresh process to maintain an active session. Checks expiration,
     requests a token refresh from the repository, and updates stored sessions. Emits AuthEvents
     for success or failure and allows observers to track the refresh lifecycle.

     - Returns: A publisher emitting Void on success or an Error on failure.

     Steps:
      1. Emit a `.tokenRefreshStarted` event for monitoring.
      2. Check if a refresh is needed by verifying token expiration (placeholder in this method).
      3. Call `authRepository.refreshToken()` to attempt a refresh.
      4. On success, emit `.tokenRefreshSucceeded`.
      5. On failure, emit `.tokenRefreshFailed(error)`.
      6. Return a publisher that completes successfully or with an error.
     */
    public func handleTokenRefresh() -> AnyPublisher<Void, Error> {
        // 1. Emit an event indicating the refresh is starting.
        authEvents.send(.tokenRefreshStarted)
        
        // 2. Placeholder for internal checks to see if the token is truly expired or near expiry.
        // For demonstration, we always proceed with a refresh attempt.
        
        // 3. Trigger the repository's refreshToken flow, which updates tokens in Keychain.
        return authRepository.refreshToken()
            .handleEvents(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                
                switch completion {
                case .finished:
                    // 4. Emit success event if no errors.
                    self.authEvents.send(.tokenRefreshSucceeded)
                    os_log("handleTokenRefresh: Token refresh succeeded.", log: .default, type: .info)
                case .failure(let err):
                    // 5. Emit failure event if an error occurred.
                    self.authEvents.send(.tokenRefreshFailed(err))
                    os_log("handleTokenRefresh: Token refresh failed with error: %{public}@",
                           log: .default, type: .error, err.localizedDescription)
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helpers
    
    /**
     Validates the format of the provided email and password. In a production environment,
     this method can be extended with regex-based email checks, password complexity rules,
     and length constraints.

     - Parameters:
       - email:    The email string to validate.
       - password: The password string to validate.
     - Returns: A boolean flag indicating if the basic format is valid (non-empty in this demo).
     */
    private func validateCredentialsFormat(email: String, password: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedEmail.isEmpty && !trimmedPassword.isEmpty
    }
    
    /**
     A placeholder function demonstrating suspicious activity checks. In a live scenario,
     the client could call out to a security microservice or apply advanced heuristics,
     such as repeated login attempts from unknown IP addresses.

     - Parameter email: The email address under scrutiny.
     - Returns: True if suspicious activity is detected; false otherwise.
     */
    private func checkForSuspiciousActivity(email: String) -> Bool {
        // Demo logic: flag if the email domain is obviously suspicious
        if email.contains("suspicious-domain.com") {
            return true
        }
        return false
    }
    
    /**
     Retrieves a stored email from Keychain or similar secure storage. This placeholder
     returns a static example. An integrated approach would fetch actual data safely.

     - Returns: The stored email string, or nil if not found.
     */
    private func retrieveStoredEmail() -> String? {
        // In production, retrieve from Keychain or a persistent store. Placeholder:
        return "saved_user@example.com"
    }
    
    /**
     Retrieves a stored password from Keychain or similar secure storage. This placeholder
     returns a static value. A more robust approach would fetch an encrypted credential.

     - Returns: A stored password string, or nil if not found.
     */
    private func retrieveStoredPassword() -> String? {
        // In production, retrieve from secure storage. Placeholder:
        return "P@ssw0rd123"
    }
}