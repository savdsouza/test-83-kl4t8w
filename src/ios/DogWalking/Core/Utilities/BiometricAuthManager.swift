import Foundation // iOS 13.0+ (Core iOS framework)
import LocalAuthentication // iOS 13.0+ (iOS biometric authentication framework)
import Logger // iOS 13.0+ (Enhanced security logging for biometric authentication events)

// MARK: - Global Constants

/// The user-facing reason message displayed during the biometric prompt.
public let BIOMETRIC_REASON: String = NSLocalizedString(
    "Authenticate to access the Dog Walking app",
    comment: "Biometric authentication reason"
)

/// The fallback title displayed if biometric authentication fails or is not available.
public let BIOMETRIC_FALLBACK_TITLE: String = NSLocalizedString(
    "Enter Passcode",
    comment: "Biometric fallback title"
)

/// The maximum number of biometric authentication attempts allowed before forcing a fallback or denying.
public let MAX_AUTH_ATTEMPTS: Int = 3

// MARK: - BiometricAuthManager

/// A thread-safe singleton class that manages biometric authentication using TouchID/FaceID
/// with comprehensive security logging, fallback mechanisms, and secure context management.
public final class BiometricAuthManager {
    
    // MARK: - Singleton Instance
    
    /// The shared singleton instance of `BiometricAuthManager`.
    public static let shared = BiometricAuthManager()
    
    // MARK: - Properties
    
    /// The `LAContext` used for biometric operations. It is configured and maintained securely.
    private var context: LAContext
    
    /// A dedicated dispatch queue to synchronize access and preserve thread safety.
    private let authQueue: DispatchQueue
    
    /// Tracks the current number of authentication attempts made with biometrics.
    private var authAttempts: Int
    
    /// Indicates whether a biometric authentication process is currently in progress.
    private var isAuthenticating: Bool
    
    /// A logger instance for recording security and diagnostic information.
    private let logger = Logger(subsystem: "com.dogwalking.ios", category: "BiometricAuth")

    // MARK: - Initializer
    
    /// A private initializer that enforces the singleton pattern. It sets up
    /// the secure context configuration, initializes tracking variables, and logs
    /// the successful creation of the `BiometricAuthManager`.
    private init() {
        // 1. Establish a concurrent queue to safely manage biometric operations.
        self.authQueue = DispatchQueue(
            label: "com.dogwalking.biometricAuthQueue",
            attributes: .concurrent
        )
        
        // 2. Instantiate and configure an LAContext with secure settings.
        let initialContext = LAContext()
        initialContext.localizedFallbackTitle = BIOMETRIC_FALLBACK_TITLE
        
        // 3. Initialize class properties for state tracking.
        self.context = initialContext
        self.authAttempts = 0
        self.isAuthenticating = false
        
        // 4. Log the successful creation of the manager for auditing.
        logger.debug("SECURITY-EVENT: BiometricAuthManager initialized successfully.")
    }
    
    // MARK: - Public Methods
    
    /// Thread-safe check for the device's biometric capability and enrollment status.
    /// - Returns: A Boolean indicating whether biometric authentication is available and configured.
    public func canUseBiometrics() -> Bool {
        return authQueue.sync {
            // 1. Create a fresh LAContext to check the current biometric state.
            let checkContext = LAContext()
            var error: NSError?
            
            // 2. Determine if the device can evaluate a biometric policy (TouchID/FaceID).
            let canEvaluate = checkContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            
            // 3. Log the outcome of the biometric capability check.
            if let evalError = error {
                logger.debug("SECURITY-EVENT: canUseBiometrics() -> false (Error: \(evalError.localizedDescription))")
                return false
            } else {
                logger.debug("SECURITY-EVENT: canUseBiometrics() -> \(canEvaluate)")
                return canEvaluate
            }
        }
    }
    
    /// Thread-safe biometric authentication method that handles user prompts,
    /// logs security events, monitors authentication attempts, and provides fallback.
    /// - Parameter completion: A closure that returns a `Result<Bool, Error>` indicating success or failure.
    public func authenticateUser(completion: @escaping (Result<Bool, Error>) -> Void) {
        authQueue.async {
            // 1. Ensure we are not already in an authentication flow.
            guard !self.isAuthenticating else {
                self.logger.debug("SECURITY-EVENT: Auth request denied. Another authentication is in progress.")
                completion(.failure(NSError(domain: "BiometricAuthManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "An authentication process is already in progress."
                ])))
                return
            }
            
            // 2. Check if the maximum attempts have been exceeded.
            guard self.authAttempts < MAX_AUTH_ATTEMPTS else {
                self.logger.debug("SECURITY-EVENT: Auth request denied. Exceeded maximum allowed attempts (\(MAX_AUTH_ATTEMPTS)).")
                completion(.failure(NSError(domain: "BiometricAuthManager", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Maximum biometric authentication attempts exceeded."
                ])))
                return
            }
            
            // 3. Update internal state to reflect that we are now authenticating.
            self.isAuthenticating = true
            
            // 4. Configure a new LAContext with fallback title and reason.
            self.context.localizedFallbackTitle = BIOMETRIC_FALLBACK_TITLE
            
            // NOTE: Using deviceOwnerAuthentication for a passcode fallback,
            // which includes biometric if available and passcode if necessary.
            self.context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: BIOMETRIC_REASON
            ) { success, error in
                
                // 5. Log the authentication attempt details for security auditing.
                let attemptIndex = self.authAttempts + 1
                self.logger.debug("SECURITY-EVENT: authenticateUser() -> Attempt #\(attemptIndex)")
                
                // 6. Update the attempts counter.
                self.authAttempts += 1
                
                // 7. Process the result of the biometric evaluation.
                if success {
                    self.logger.debug("SECURITY-EVENT: Biometric authentication succeeded on attempt #\(attemptIndex).")
                    self.isAuthenticating = false
                    completion(.success(true))
                } else if let authError = error {
                    self.logger.error("SECURITY-EVENT: Biometric authentication failed.", error: authError)
                    self.isAuthenticating = false
                    completion(.failure(authError))
                } else {
                    // If error is unexpectedly nil but no success, we treat as failure.
                    let unknownError = NSError(domain: "BiometricAuthManager", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "Unknown error occurred during biometric authentication."
                    ])
                    self.logger.error("SECURITY-EVENT: Biometric authentication encountered an unknown error.", error: unknownError)
                    self.isAuthenticating = false
                    completion(.failure(unknownError))
                }
            }
        }
    }
    
    /// Thread-safe detection of the available biometric authentication type (TouchID/FaceID).
    /// - Returns: A `LABiometryType` value indicating which type is supported, if any.
    public func getBiometricType() -> LABiometryType {
        return authQueue.sync {
            let checkContext = LAContext()
            var error: NSError?
            
            // 1. Check if biometrics are available to identify the type.
            guard checkContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                self.logger.debug("SECURITY-EVENT: getBiometricType() -> LABiometryNone (Error: \(error?.localizedDescription ?? "N/A"))")
                return .none
            }
            
            // 2. Detect the actual biometric type (TouchID/FaceID).
            let type = checkContext.biometryType
            self.logger.debug("SECURITY-EVENT: getBiometricType() -> \(type.rawValue)")
            return type
        }
    }
    
    /// Thread-safe reset of the internal `LAContext` and authentication tracking variables.
    /// This is useful to clear any stale state or after repeated failures.
    public func resetContext() {
        authQueue.async(flags: .barrier) {
            // 1. Invalidate the current LAContext to discard any existing state.
            self.context.invalidate()
            
            // 2. Create a fresh LAContext with secure fallback settings.
            let newContext = LAContext()
            newContext.localizedFallbackTitle = BIOMETRIC_FALLBACK_TITLE
            self.context = newContext
            
            // 3. Reset attempt counters and authentication status.
            self.authAttempts = 0
            self.isAuthenticating = false
            
            // 4. Log the context reset event.
            self.logger.debug("SECURITY-EVENT: BiometricAuthManager context reset. Attempts cleared.")
        }
    }
}