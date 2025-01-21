//
//  LoginViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-01.
//
//  Description:
//  This file defines the LoginViewModel class, which handles secure user authentication
//  in the DogWalking iOS application. It incorporates both email/password login and
//  biometric-based authentication using Face ID or Touch ID. This view model follows
//  MVVM principles (Model-View-ViewModel) alongside reactive data flows via Combine,
//  ensuring a clean separation of concerns and robust error handling.
//
//  The class extends BaseViewModel, inheriting loading/error handling subjects and
//  concurrency mechanisms. AuthRepository is utilized for backend authentication
//  operations, while BiometricAuthManager is used for secure, device-level biometric
//  checks. All inputs and outputs are exposed as Combine subjects or publishers so
//  that the View layer can easily bind and react to state changes in real time.
//
//  Imports:
//  - Foundation (iOS 13.0+): Core language features, data structures, and OS services.
//  - Combine (iOS 13.0+): Reactive streams for binding, transformations, and error handling.
//
//  Internal Dependencies:
//  - BaseViewModel: Provides isLoadingSubject and a custom errorSubject for reactive state.
//  - AuthRepository: Executes credential-based login and token management.
//  - BiometricAuthManager: Performs biometric checks and potentially stores sensitive credentials.
//
//  Usage:
//  Instantiate this view model in your SwiftUI or UIKit ViewController. Bind UI elements
//  such as text fields and buttons to the published subjects (emailSubject, passwordSubject,
//  loginTapSubject, etc.). Observe changes to isValidFormSubject, biometricAvailableSubject,
//  or any published errors to update the UI.
//
//  License: © 2023 DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+ (Core iOS functionality)
import Combine    // iOS 13.0+ (Reactive programming support)

// MARK: - Internal Imports (Named)
import Core.Base.BaseViewModel     // Provides BaseViewModel with loading/error handling
import Data.Repositories.AuthRepository
import Core.Utilities.BiometricAuthManager

/// A custom error enumeration representing authentication-related failures, such as
/// invalid credentials, biometric issues, or general login errors.
/// Conforms to Error, allowing easy integration with Combine pipelines and
/// the parent's reactive errorSubject.
public enum AuthError: Error {
    /// Thrown when email or password credentials are invalid or rejected by the backend.
    case invalidCredentials(String)
    
    /// Thrown if biometric hardware is not available, not enrolled, or otherwise inaccessible.
    case biometricUnavailable
    
    /// Thrown if the biometric prompt fails, times out, or the user cancels the flow.
    case biometricFailed(String)
    
    /// Thrown upon various input validation failures (e.g., malformed email address).
    case inputValidation(String)
    
    /// A catch-all error for unexpected or unknown failures in the authentication process.
    case unknown(String)
}

///
/// @MainActor
/// The LoginViewModel class is responsible for handling both email/password and
/// biometric authentication flows, validating user input, updating form states,
/// and providing reactive outputs for consumption by the View layer.
///
@MainActor
public final class LoginViewModel: BaseViewModel {
    
    // MARK: - Public Subjects & Publishers
    
    /// Subject used to observe changes to the user's email input.
    /// Typically bound to a text field in the UI.
    public let emailSubject: PassthroughSubject<String, Never>
    
    /// Subject used to observe changes to the user's password input.
    /// Typically bound to a secure text field in the UI.
    public let passwordSubject: PassthroughSubject<String, Never>
    
    /// Subject triggered when the user taps the login button.
    /// Subscribing to this leads to an attempt at email/password login.
    public let loginTapSubject: PassthroughSubject<Void, Never>
    
    /// Subject triggered when the user taps the biometric login button.
    /// Subscribing to this leads to a biometric-based authentication flow.
    public let biometricTapSubject: PassthroughSubject<Void, Never>
    
    /// Publishes a boolean reflecting the availability of biometric authentication
    /// (Face ID or Touch ID) on the user’s device.
    public let biometricAvailableSubject: CurrentValueSubject<Bool, Never>
    
    /// Publishes a boolean indicating whether the form input (email/password) is valid.
    /// This can be used to enable or disable the login button in the UI.
    public let isValidFormSubject: CurrentValueSubject<Bool, Never>
    
    // MARK: - Internal / Private Properties
    
    /// A reference to the authentication repository used for secure login requests,
    /// token management, and any server-side validations relevant to the login flow.
    private let authRepository: AuthRepository
    
    /// A reference to the BiometricAuthManager, enabling the view model to perform
    /// Face ID / Touch ID checks, store and retrieve credentials, and handle fallback.
    private let biometricAuthManager: BiometricAuthManager
    
    /// A set of cancellables capturing Combine subscriptions. This ensures that
    /// any pipelines remain active for the lifetime of the view model.
    private var cancellables: Set<AnyCancellable>
    
    /// A regular expression pattern used to validate email syntax.
    /// The default below is a common pattern for basic checking; it can be customized.
    private let emailRegex: String
    
    // MARK: - Initialization
    
    ///
    /// Initializes the LoginViewModel with an AuthRepository dependency for server authentication
    /// and sets up reactive bindings, including form validation and tap event handling.
    ///
    /// Steps:
    /// 1. Call super.init() to set up BaseViewModel state.
    /// 2. Store the provided AuthRepository instance.
    /// 3. Acquire a shared instance of BiometricAuthManager.
    /// 4. Initialize all Combine subjects and the cancellables set.
    /// 5. Configure input validation pipelines for email/password.
    /// 6. Determine and publish whether biometrics are available.
    /// 7. Observe tap subjects (loginTapSubject, biometricTapSubject) to trigger login flows.
    /// 8. Set up general error handling and retry logic as needed.
    ///
    /// - Parameter authRepository: The repository used for backend authentication operations.
    ///
    public init(authRepository: AuthRepository) {
        // 1. Call the parent class initializer to set up base reactive components.
        super.init()
        
        // 2. Store authRepository for usage in login flows.
        self.authRepository = authRepository
        
        // 3. Acquire a shared instance of BiometricAuthManager for biometric flows.
        self.biometricAuthManager = BiometricAuthManager.shared
        
        // 4. Initialize Combine subjects and the cancellables set.
        self.emailSubject = PassthroughSubject<String, Never>()
        self.passwordSubject = PassthroughSubject<String, Never>()
        self.loginTapSubject = PassthroughSubject<Void, Never>()
        self.biometricTapSubject = PassthroughSubject<Void, Never>()
        self.biometricAvailableSubject = CurrentValueSubject<Bool, Never>(false)
        self.isValidFormSubject = CurrentValueSubject<Bool, Never>(false)
        self.cancellables = Set<AnyCancellable>()
        
        // Provide a fairly common email regex; can be customized for stricter checks.
        self.emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        
        // 5. Configure input validation bindings via Combine pipeline.
        setupInputValidationBindings()
        
        // 6. Check if biometrics are available on this device.
        let canBiometrics = biometricAuthManager.canUseBiometrics()
        biometricAvailableSubject.send(canBiometrics)
        
        // 7. Observe tap subjects to trigger login flows.
        setupTapHandlers()
        
        // 8. Further specialized error handling or retry logic
        //    can be set up here, as needed.
    }
    
    // MARK: - Private Setup Methods
    
    /// Sets up a reactive pipeline that listens to emailSubject and passwordSubject,
    /// and automatically updates isValidFormSubject with the outcome of form validation.
    /// This ensures the UI can immediately reflect the form’s validity state.
    private func setupInputValidationBindings() {
        // Combine both email and password streams into a validation check.
        Publishers.CombineLatest(emailSubject, passwordSubject)
            .map { [weak self] (email, password) -> Bool in
                guard let self = self else { return false }
                // Perform the validation logic whenever email or password changes.
                return self.validateForm(email: email, password: password)
            }
            .sink { [weak self] isValid in
                self?.isValidFormSubject.send(isValid)
            }
            .store(in: &cancellables)
    }
    
    /// Subscribes to loginTapSubject and biometricTapSubject, invoking the corresponding
    /// login routines (email/password or biometric-based) when they emit.
    private func setupTapHandlers() {
        // When the user taps the normal login button, attempt a standard login flow.
        loginTapSubject
            .sink { [weak self] in
                self?.handleEmailPasswordLogin()
            }
            .store(in: &cancellables)
        
        // When the user taps the biometric login button, attempt a biometric-based flow.
        biometricTapSubject
            .sink { [weak self] in
                self?.handleBiometricLogin()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Validation Method
    
    ///
    /// Validates email format and password complexity requirements. If any condition fails,
    /// the result is false and can be used to disable the login button or prompt an error.
    ///
    /// Steps:
    /// 1. Check the email against the regex pattern.
    /// 2. Check password length >= 8 characters.
    /// 3. Check presence of uppercase, lowercase, digit, and special char.
    /// 4. Return whether all validation criteria passed.
    ///
    /// - Parameters:
    ///   - email:    The user’s email input string.
    ///   - password: The user’s password input string.
    ///
    /// - Returns: A boolean indicating if the form meets all validation requirements.
    ///
    public func validateForm(email: String, password: String) -> Bool {
        // 1. Validate email syntax via regex.
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let isEmailValid = emailPred.evaluate(with: email)
        if !isEmailValid {
            return false
        }
        
        // 2. Check password length.
        guard password.count >= 8 else {
            return false
        }
        
        // 3. Check password complexity (basic example).
        //    - At least one uppercase letter,
        //    - At least one lowercase letter,
        //    - At least one digit,
        //    - At least one special character.
        let uppercase = CharacterSet.uppercaseLetters
        let lowercase = CharacterSet.lowercaseLetters
        let digits = CharacterSet.decimalDigits
        let specials = CharacterSet(charactersIn: "!@#$%^&*()_-+=~`|]}[{;:'<,>.?/")
        
        func containsChar(from set: CharacterSet) -> Bool {
            return password.rangeOfCharacter(from: set) != nil
        }
        
        guard containsChar(from: uppercase),
              containsChar(from: lowercase),
              containsChar(from: digits),
              containsChar(from: specials) else {
            return false
        }
        
        // If all checks pass, the form is valid.
        return true
    }
    
    // MARK: - Private Helpers to Trigger Login
    
    /// Convenience method that delegates to performLogin() after retrieving the latest email/password.
    private func handleEmailPasswordLogin() {
        // Read the latest values from the form pipelines. Typically, your View might track these
        // values directly, but here we store them for demonstration or short-time usage.
        // In a real scenario, you might want to store them in class properties or in local subscription.
        var latestEmail = ""
        var latestPassword = ""
        
        // We can set up a short subscription to read the current values from the combine pipeline:
        let emailSub = emailSubject
            .sink { input in
                latestEmail = input
            }
        let passwordSub = passwordSubject
            .sink { input in
                latestPassword = input
            }
        
        // Cancel these after reading once.
        emailSub.cancel()
        passwordSub.cancel()
        
        // Perform the actual login flow with the retrieved credentials.
        performLogin(email: latestEmail, password: latestPassword)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        // On success or normal completion, do nothing special here.
                        break
                    case .failure(let authErr):
                        // Pipeline error: forward it to the parent's errorSubject.
                        self?.errorSubject.send(authErr)
                    }
                },
                receiveValue: { [weak self] user in
                    // The user object indicates a successful login and can be used
                    // to navigate or update the UI with user info.
                    // e.g., self?.navigateToHomeScreen()
                    // or store user in a global session if required.
                    
                    // For demonstration, do nothing special here except log success.
                    print("Successfully logged in user: \(user.email)")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Convenience method that delegates to performBiometricLogin() for Face ID / Touch ID flows.
    private func handleBiometricLogin() {
        performBiometricLogin()
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let authErr):
                        // If biometric fails or no stored credentials, publish error.
                        self?.errorSubject.send(authErr)
                    }
                },
                receiveValue: { [weak self] user in
                    // On success, we have a fully authenticated user.
                    print("Biometric login succeeded for user: \(user.email)")
                    // Possibly navigate to main screen or store user session.
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Core Authentication Flows
    
    ///
    /// Executes secure login using email and password credentials.
    /// Returns a publisher that emits the authenticated User or an AuthError.
    ///
    /// Steps:
    /// 1. Broadcast that loading is active.
    /// 2. Sanitize the input credentials if needed (trim whitespace).
    /// 3. Invoke authRepository.login for the backend authentication request.
    /// 4. If successful, optionally store credentials for biometric login.
    /// 5. Map any errors to AuthError and handle token refresh or retry logic if necessary.
    /// 6. Broadcast that loading is complete on completion.
    /// 7. Return a publisher that emits a User on success or AuthError on failure.
    ///
    /// - Parameters:
    ///   - email: The user’s email address for login.
    ///   - password: The user’s password.
    ///
    /// - Returns: An AnyPublisher<User, AuthError> representing the async login result.
    ///
    public func performLogin(email: String, password: String) -> AnyPublisher<User, AuthError> {
        setLoading(true) // (1) Loading started
        
        let sanitizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // (3) Call the repository's login. The repository returns AnyPublisher<User, Error>.
        return authRepository.login(email: sanitizedEmail, password: sanitizedPassword, useBiometric: false)
            // (5) Convert any Error to AuthError. You can add more nuanced mapping as needed.
            .mapError { error -> AuthError in
                // Basic error bridging:
                if let nsErr = error as NSError?, nsErr.code == 1001 {
                    return .invalidCredentials("Email or password was empty.")
                }
                return .unknown("Failed to login with credentials: \(error.localizedDescription)")
            }
            // Insert optional token refresh or retry logic here if needed.
            // For demonstration, we simply pass the result downstream.
            
            // (4) Store credentials for future biometric usage only on success.
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.biometricAuthManager.storeCredentials(email: sanitizedEmail, password: sanitizedPassword)
            }, receiveCompletion: { [weak self] _ in
                // (6) When completion (failure or success) arrives, end loading.
                self?.setLoading(false)
            })
            .eraseToAnyPublisher()
    }
    
    ///
    /// Executes login using biometric authentication (Face ID or Touch ID).
    /// If successful, retrieves previously stored credentials and performs a normal
    /// email/password login internally.
    ///
    /// Steps:
    /// 1. Broadcast that loading is active.
    /// 2. Verify that biometrics are available; fail early if not.
    /// 3. Request user authentication with the system biometric prompt.
    /// 4. Upon success, retrieve stored credentials from the secure location.
    /// 5. Perform a normal login flow using those credentials.
    /// 6. Handle any errors (e.g., missing credentials, auth failure).
    /// 7. Broadcast that loading is complete on completion, returning a publisher.
    ///
    /// - Returns: An AnyPublisher<User, AuthError> that emits the authenticated user on success,
    ///            or an error if biometric or credential retrieval fails.
    ///
    public func performBiometricLogin() -> AnyPublisher<User, AuthError> {
        setLoading(true)
        
        // (2) Early check for biometrics availability.
        guard biometricAuthManager.canUseBiometrics() else {
            setLoading(false)
            return Fail(error: AuthError.biometricUnavailable)
                .eraseToAnyPublisher()
        }
        
        // (3) We wrap the biometric prompt in a Future, bridging from
        // callback-based LAContext to Combine’s asynchronous flow.
        let biometricFuture = Future<Void, AuthError> { [weak self] promise in
            self?.biometricAuthManager.authenticateUser { result in
                switch result {
                case .success:
                    promise(.success(())) // Biometric authentication success
                case .failure(let error):
                    // Distinguish system errors or user cancellation/timeouts if needed.
                    promise(.failure(.biometricFailed("Biometric auth failed: \(error.localizedDescription)")))
                }
            }
        }
        
        // (4) Then we retrieve stored credentials (placeholder function).
        // If none are stored, we fail with an appropriate AuthError.
        func retrieveStoredCredentials() -> (String, String)? {
            // For demonstration, we assume the manager can retrieve them.
            // Real implementations might reference Keychain or internal memory.
            if let credentials = biometricAuthManager.getStoredCredentials() {
                return credentials
            }
            return nil
        }
        
        // Combine the Future with a flatMap that triggers the actual login.
        return biometricFuture
            .flatMap { [weak self] _ -> AnyPublisher<User, AuthError> in
                guard let self = self else {
                    return Fail(error: AuthError.unknown("LoginViewModel deinitialized"))
                        .eraseToAnyPublisher()
                }
                
                // (4) Now that biometric auth succeeded, retrieve stored credentials.
                guard let (email, password) = retrieveStoredCredentials() else {
                    return Fail(error: AuthError.biometricFailed("No stored credentials found for biometric login."))
                        .eraseToAnyPublisher()
                }
                
                // (5) Perform normal email/password login with stored credentials.
                return self.performLogin(email: email, password: password)
            }
            .handleEvents(receiveCompletion: { [weak self] _ in
                // (7) End loading once the entire process completes or fails.
                self?.setLoading(false)
            })
            .eraseToAnyPublisher()
    }
}

// MARK: - BiometricAuthManager Extension (Placeholder for Storing Credentials)
//
// The JSON specification references a "storeCredentials" function. The actual BiometricAuthManager
// code does not explicitly define it. Here, we add a small extension to show how it might be done.
//
extension BiometricAuthManager {
    /// Stores the user's credentials (email/password) securely, presumably in Keychain or
    /// an encrypted container. This is referenced in the view model to enable biometric login.
    ///
    /// - Parameters:
    ///   - email:    The user's email address.
    ///   - password: The user's password.
    public func storeCredentials(email: String, password: String) {
        // Implementation detail: In a real-world scenario, you'd securely encrypt and store
        // these in the Keychain, associating them with a biometric policy. For demonstration:
        // e.g., KeychainManager.shared.saveSecure(data: someEncryptedData, key: "BiometricLoginKey", requiresBiometric: true)
        logger.debug("StoreCredentials => (email: \(email), password: ****)")
        
        // For demonstration, we simply store them in memory:
        GlobalCredentialStorage.sharedEmail = email
        GlobalCredentialStorage.sharedPassword = password
    }
    
    /// Retrieves stored credentials for the user if available. This is a placeholder that
    /// references a hypothetical global in-memory store. In production, you'd read Keychain data.
    ///
    /// - Returns: A tuple containing (email, password) or nil if none found.
    public func getStoredCredentials() -> (String, String)? {
        guard let e = GlobalCredentialStorage.sharedEmail,
              let p = GlobalCredentialStorage.sharedPassword else {
            return nil
        }
        return (e, p)
    }
}

/// A simple global struct simulating credential storage in memory. In a real application,
/// you would store credentials in Keychain with the appropriate security classes.
fileprivate struct GlobalCredentialStorage {
    static var sharedEmail: String?
    static var sharedPassword: String?
}