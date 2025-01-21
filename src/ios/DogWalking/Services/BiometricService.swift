import Foundation // iOS 13.0+ (Core iOS framework functionality)
import Combine    // iOS 13.0+ (Thread-safe reactive programming support for authentication state)

// MARK: - Internal Imports
// Importing required internal classes/enums based on the JSON specification and provided source files.
import class DogWalking.Core.Utilities.BiometricAuthManager
import class DogWalking.Core.Utilities.KeychainManager

// NOTE: The JSON specification references a BiometricError enum from BiometricAuthManager,
// but the provided source code does not declare it. We define it here to fulfill the schema.
public enum BiometricError: Error {
    /// Thrown when biometric hardware/conditions are not available or not enrolled.
    case notAvailable
    /// Thrown when the maximum number of allowed attempts has been exceeded.
    case maxAttemptsExceeded
    /// Thrown when a timeout period is exceeded during a biometric operation.
    case timeout
    /// Thrown when authentication fails for a known reason, optionally with details.
    case authenticationFailed(String)
    /// Thrown for any unspecified or unknown error conditions.
    case unknown(String)
}

// MARK: - Global Constants
/// A string key used to indicate whether biometric authentication is enabled in secure storage.
public let BIOMETRIC_AUTH_KEY: String = "biometric_auth_enabled"

/// The maximum number of biometric authentication attempts allowed before forcing fallback or denial.
public let MAX_AUTH_ATTEMPTS: Int = 3

/// A timeout (in seconds) used for biometric authentication sequences.
public let AUTH_TIMEOUT: TimeInterval = 30.0

// MARK: - BiometricService
/**
 A thread-safe service class that manages high-level biometric authentication functionality
 with enhanced security features, comprehensive error handling, and secure state persistence.

 This class utilizes BiometricAuthManager for core biometric interactions and KeychainManager
 for securely storing user preferences (such as whether biometrics are currently enabled).
 It publishes authentication state changes via a PassthroughSubject for reactive subscribers.
 
 Usage Notes (High-Level):
 - Call `isBiometricAuthAvailable()` to determine whether biometrics can be used or are enabled.
 - Call `enableBiometricAuth` to turn on biometric auth, storing preferences in the Keychain.
 - Call `disableBiometricAuth` to turn off biometric auth, removing preferences from the Keychain.
 - Call `authenticateUser` to perform a real-time biometric check, respecting retry limits and timeouts.
 - When necessary, call `resetAuthenticationState` to clear counters and state in a secure fashion.
 */
@available(iOS 13.0, *)
public final class BiometricService {

    // MARK: - Singleton Instance

    /// A shared singleton instance of BiometricService, ensuring consistent management of biometric auth.
    public static let shared = BiometricService()

    // MARK: - Published Authentication State

    /**
     A Combine publisher that emits a Boolean indicating the current authentication state.
     True implies successful and current authentication, and False implies otherwise.
     This subject helps other parts of the application reactively respond to changes in authentication.
     */
    public let authenticationStatePublisher = PassthroughSubject<Bool, Never>()

    // MARK: - Internal Properties

    /// A dedicated serial queue for all methods that need a guaranteed, thread-safe environment.
    /// It prevents race conditions around reading/writing biometric-related state.
    private let serialQueue: DispatchQueue

    /**
     A lock used to protect and synchronize sensitive operations or shared variables like
     `authAttempts` within this class, thereby ensuring robust thread safety.
     */
    private let stateLock = NSLock()

    /**
     A counter tracking how many times an authentication attempt has been made. If this
     exceeds `MAX_AUTH_ATTEMPTS`, the service may deny further attempts until reset.
     */
    private var authAttempts: Int

    /**
     An internal property that holds the last time a biometric attempt was initiated.
     This allows the service to detect if a request is happening too soon or if
     a specified timeout has been exceeded.
     */
    private var lastAuthAttemptDate: Date?

    /**
     A cached indicator for whether biometric auth is currently enabled by the user.
     This value is securely persisted in the Keychain for multi-factor security
     and is loaded during initialization.
     */
    private var isBiometricEnabled: Bool

    // MARK: - Initializer

    /**
     A private initializer enforcing the singleton pattern. It initializes all
     thread-safety primitives, loads biometric preferences from the Keychain,
     and sets up any Reactive state watchers or observers that are needed.
     
     Steps:
      1. Create a dedicated serial queue for concurrency control.
      2. Initialize the state lock used to guard shared resources.
      3. Initialize the Combine publisher for authentication state updates.
      4. Set the authentication attempts counter to 0.
      5. Load saved biometric preference securely from the Keychain.
      6. Publish the initial authentication state if needed.
     */
    private init() {
        // 1. Dedicated serial queue
        self.serialQueue = DispatchQueue(label: "com.dogwalking.BiometricService.serialQueue",
                                         qos: .userInitiated)

        // 2. The NSLock is already declared as stateLock.
        // 3. authenticationStatePublisher is already declared.
        // 4. Initialize the authentication attempts
        self.authAttempts = 0

        // 5. Attempt to load the isBiometricEnabled preference from the Keychain.
        let retrieveResult = KeychainManager.shared.retrieveSecure(
            key: BIOMETRIC_AUTH_KEY,
            validateBiometric: false
        )
        switch retrieveResult {
        case .success(let storedData):
            if let storedData = storedData, let stringVal = String(data: storedData, encoding: .utf8) {
                self.isBiometricEnabled = (stringVal == "true")
            } else {
                self.isBiometricEnabled = false
            }
        case .failure:
            // If retrieving fails, gracefully default to disabled.
            self.isBiometricEnabled = false
        }

        // 6. Optional: We can publish an initial state if needed. For this service, we start as not authenticated.
        authenticationStatePublisher.send(false)
    }

    // MARK: - Availability Check

    /**
     Thread-safe method to check whether biometric authentication is both allowed by the device
     and enabled by the user. This method also considers whether the user has exceeded
     the allowed maximum number of attempts.
     
     Steps:
      1. Acquire the state lock to ensure exclusivity.
      2. Check device-level biometric capability (via BiometricAuthManager).
      3. Verify if user has manually enabled biometrics in the Keychain preferences.
      4. Check if the attempt limit has been exceeded.
      5. Release the lock.
      6. Return the final combined availability status as a Boolean.
     
     - Returns: True if biometrics are available, user enabled them, and attempts are not exceeded.
     */
    public func isBiometricAuthAvailable() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        // 2. Check device capability using BiometricAuthManager
        let deviceSupported = BiometricAuthManager.shared.canUseBiometrics()

        // 3. If user has not enabled biometrics, we consider it unavailable
        let userEnabled = isBiometricEnabled

        // 4. Check attempts
        let attemptsOK = (authAttempts < MAX_AUTH_ATTEMPTS)

        // Define final availability
        let combined = deviceSupported && userEnabled && attemptsOK
        return combined
    }

    // MARK: - Enable Biometric Auth

    /**
     Securely enables biometric authentication by performing an initial biometric check,
     updating preference in the Keychain, resetting attempt counters, and acknowledging
     the user’s choice for future sessions.
     
     Steps:
      1. Verify that biometrics are available on the device (via isBiometricAuthAvailable).
      2. Check if current time is within the allowed timeout window, or handle appropriately.
      3. Request an initial biometric authentication to confirm user identity.
      4. Handle any authentication errors or cancellations.
      5. Upon success, store the preference securely to the Keychain as "true".
      6. Update internal state and reset the auth attempts counter.
      7. Publish updated authentication state if needed.
      8. Invoke the completion handler with a Result<Bool, BiometricError>.
     
     - Parameter completion: A completion closure receiving a `Result<Bool, BiometricError>` indicating success or a specific error.
     */
    public func enableBiometricAuth(completion: @escaping (Result<Bool, BiometricError>) -> Void) {
        serialQueue.async {
            // 1. Check device-level and user-level availability toggles
            let canUse = BiometricAuthManager.shared.canUseBiometrics()
            if !canUse {
                completion(.failure(.notAvailable))
                return
            }

            // 2. Check for potential timeout rules
            //    For demonstration, if lastAuthAttemptDate is set, we see how long ago it was.
            if let lastAttempt = self.lastAuthAttemptDate {
                let elapsed = Date().timeIntervalSince(lastAttempt)
                if elapsed < AUTH_TIMEOUT {
                    // If we consider repeated enabling attempts not allowed within the same window,
                    // we can fail here with a .timeout
                    completion(.failure(.timeout))
                    return
                }
            }

            // 3. Perform an initial biometric authentication
            BiometricAuthManager.shared.authenticateUser { result in
                switch result {
                case .success(let successValue):
                    if successValue {
                        // 4. If success, we update the preference in Keychain to "true"
                        let dataToSave = Data("true".utf8)
                        let saveResult = KeychainManager.shared.saveSecure(
                            data: dataToSave,
                            key: BIOMETRIC_AUTH_KEY,
                            requiresBiometric: false
                        )
                        switch saveResult {
                        case .success:
                            // 5. Everything is successful, so update internal state
                            self.stateLock.lock()
                            self.isBiometricEnabled = true
                            self.authAttempts = 0
                            self.lastAuthAttemptDate = Date()
                            self.stateLock.unlock()

                            // 6. Optionally we can publish a new state
                            self.authenticationStatePublisher.send(true)

                            // 7. Signal to the caller that enabling was successful
                            completion(.success(true))
                        case .failure:
                            completion(.failure(.unknown("Failed to persist biometric preference")))
                        }
                    } else {
                        // Should not happen if successValue is true, but handle carefully
                        completion(.failure(.authenticationFailed("Biometric success was false.")))
                    }

                case .failure(let error):
                    // 4. Authentication error - map it to a known BiometricError
                    let mappedError = BiometricError.authenticationFailed("\(error.localizedDescription)")
                    completion(.failure(mappedError))
                }
            }
        }
    }

    // MARK: - Disable Biometric Auth

    /**
     Securely disables biometric authentication by removing preference data from the Keychain,
     resetting counters, and clearing relevant in-memory state. Returns a Boolean indicating
     success or failure of the operation.
     
     Steps:
      1. Acquire the state lock to avoid race conditions.
      2. Remove the preference from the Keychain.
      3. Reset in-memory state, including `isBiometricEnabled` and `authAttempts`.
      4. Release the state lock.
      5. Return the operation success as a Boolean.
     */
    @discardableResult
    public func disableBiometricAuth() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        // 2. Remove from keychain
        let removeResult = KeychainManager.shared.deleteSecure(key: BIOMETRIC_AUTH_KEY, requiresAuth: false)
        switch removeResult {
        case .success:
            // 3. Reset in-memory state
            self.isBiometricEnabled = false
            self.authAttempts = 0
            // Publish new state if needed (we're no longer aggregating sessions)
            self.authenticationStatePublisher.send(false)
            return true
        case .failure:
            // If removal fails, we still do best-effort reset
            self.isBiometricEnabled = false
            self.authAttempts = 0
            self.authenticationStatePublisher.send(false)
            return false
        }
    }

    // MARK: - Perform Biometric Authentication

    /**
     Executes a biometric authentication flow for the user, respecting the current attempt count,
     an optional timeout, and error handling. If the user is authenticated successfully, the
     `authenticationStatePublisher` is set to `true` and the attempt counter is reset.
     
     Steps:
      1. Acquire the state lock.
      2. Check if biometric auth is enabled by user preference.
      3. Check if allowed attempt limits have not been exceeded.
      4. Evaluate if we have exceeded any timeouts or if a new attempt can proceed.
      5. Call BiometricAuthManager to authenticate the user.
      6. Handle any authentication errors, incrementing or resetting the attempt counter.
      7. Update the in-memory authentication state, potentially publish changes.
      8. Release the lock.
      9. Call the completion handler with success or an error mapped to BiometricError.
     
     - Parameter completion: Closure invoked with `.success(true)` on success or a `.failure(BiometricError)` on error.
     */
    public func authenticateUser(completion: @escaping (Result<Bool, BiometricError>) -> Void) {
        serialQueue.async {
            self.stateLock.lock()

            // 2. Check if user preference is ON
            guard self.isBiometricEnabled else {
                self.stateLock.unlock()
                completion(.failure(.notAvailable))
                return
            }

            // 3. Check attempts
            guard self.authAttempts < MAX_AUTH_ATTEMPTS else {
                self.stateLock.unlock()
                completion(.failure(.maxAttemptsExceeded))
                return
            }

            // 4. Check the time-based rule, if any
            if let lastAttemptTime = self.lastAuthAttemptDate {
                let diff = Date().timeIntervalSince(lastAttemptTime)
                if diff < AUTH_TIMEOUT {
                    // We consider that we cannot re-auth within the same window or other logic
                    self.stateLock.unlock()
                    completion(.failure(.timeout))
                    return
                }
            }

            // Record the attempt start time
            self.lastAuthAttemptDate = Date()
            // We will increment attempts below after the result, or if we fail.

            // 5. Call BiometricAuthManager to authenticate
            BiometricAuthManager.shared.authenticateUser { result in
                // We must handle concurrency carefully and reacquire lock to update shared state.
                self.stateLock.lock()
                defer { self.stateLock.unlock() }

                switch result {
                case .success(let successValue):
                    if successValue {
                        // 6. On success, reset attempts and publish success
                        self.authAttempts = 0
                        self.authenticationStatePublisher.send(true)
                        completion(.success(true))
                    } else {
                        // Edge case: Rare scenario if result success but successValue = false
                        self.authAttempts += 1
                        completion(.failure(.authenticationFailed("Authentication returned false")))
                    }

                case .failure(let error):
                    // 6. Handle error: increment attempts, map the error
                    self.authAttempts += 1
                    // We can do a minimal mapping from generic Error to our BiometricError
                    let mappedError = BiometricError.authenticationFailed(error.localizedDescription)
                    self.authenticationStatePublisher.send(false)
                    completion(.failure(mappedError))
                }
            }
        }
    }

    // MARK: - Reset Authentication State

    /**
     Securely resets the current authentication state, clearing any stored preference or counters.
     This method can be used in scenarios where a fresh start is required (e.g., user logs out).
     
     Steps:
      1. Acquire the state lock.
      2. Reset `authAttempts` to 0.
      3. Clear stored user preference for biometric auth from Keychain.
      4. Update `isBiometricEnabled` to false.
      5. Publish the updated authentication state as `false`.
      6. Release the state lock.
     */
    public func resetAuthenticationState() {
        stateLock.lock()
        defer { stateLock.unlock() }

        // 2. Reset attempts
        self.authAttempts = 0

        // 3. Remove preference from Keychain
        _ = KeychainManager.shared.deleteSecure(key: BIOMETRIC_AUTH_KEY, requiresAuth: false)

        // 4. Mark it disabled
        self.isBiometricEnabled = false

        // 5. Publish changes
        self.authenticationStatePublisher.send(false)
    }
}