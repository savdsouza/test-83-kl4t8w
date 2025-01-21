import Foundation // iOS 13.0+ core functionalities
import Combine    // iOS 13.0+ reactive programming
// Internal Imports (as specified in the JSON)
import Core/Base/BaseViewModel      // Provides BaseViewModel with isLoadingSubject & errorSubject
import Data/Repositories/AuthRepository // Provides AuthRepository with register(...) & validatePassword(...)

// MARK: - Supporting Types

/// Represents the overall validation state of user input fields.
public enum ValidationState {
    /// All input fields are valid.
    case valid
    
    /// Input fields fail validation. The associated string offers a human-readable explanation.
    case invalid(reason: String)
}

/// Describes validation errors encountered during input checks.
public enum ValidationError: Error, Equatable {
    /// Email is invalid or improperly formatted.
    case invalidEmail
    
    /// Password fails complexity checks. Associated reason string provides additional info.
    case invalidPassword(reason: String)
    
    /// The user has not provided first or last name.
    case emptyNames
    
    /// The user type (owner or walker) has not been selected.
    case userTypeNotSelected
    
    /// Too many failed attempts or other validation issues.
    case generalValidationFailure(description: String)
}

/// Represents the final result of a registration attempt.
public enum RegistrationResult: Equatable {
    /// Registration succeeded, carrying a newly created user or relevant success info.
    case success
    
    /// Registration completed but the user must verify or confirm details.
    case pendingVerification
}

/// An error representation for registration flow failures.
public enum RegistrationError: Error, Equatable {
    /// Rate limit has been exceeded or too many attempts within a time span.
    case rateLimited
    
    /// Underlying input validation error encountered.
    case validationFailed(ValidationError)
    
    /// Generic or server-provided error message.
    case generic(String)
    
    /// Unknown or unexpected issue not otherwise captured in this enum.
    case unknown(String)
}

// MARK: - RegisterViewModel

/// A ViewModel responsible for handling secure user registration, including:
/// - Comprehensive input validation (email, password complexity, sanitized names)
/// - Enhanced security monitoring (rate limiting, attempt tracking, logging)
/// - Reactive state management powered by Combine
/// - Orchestrating calls to AuthRepository for final registration
///
/// This class inherits from `BaseViewModel` for loading/error state broadcasting
/// and additional concurrency safeguards.
public final class RegisterViewModel: BaseViewModel {
    
    // MARK: - Properties
    
    /// Reference to the authentication repository used for user registration.
    private let authRepository: AuthRepository
    
    // MARK: Subjects (Inputs)
    
    /// Receives raw email input from the UI layer.
    public let emailSubject: PassthroughSubject<String, Never>
    
    /// Receives raw password input from the UI layer.
    public let passwordSubject: PassthroughSubject<String, Never>
    
    /// Receives raw first name input from the UI layer.
    public let firstNameSubject: PassthroughSubject<String, Never>
    
    /// Receives raw last name input from the UI layer.
    public let lastNameSubject: PassthroughSubject<String, Never>
    
    /// Receives user type selection (owner or walker) from the UI layer.
    public let userTypeSubject: PassthroughSubject<UserType, Never>
    
    /// A trigger subject for when the user taps the "Register" or "Submit" button.
    public let submitSubject: PassthroughSubject<Void, Never>
    
    // MARK: Subjects (Outputs / States)
    
    /// Publishes a Boolean indicating overall form validity at any point in time.
    public let isValidSubject: CurrentValueSubject<Bool, Never>
    
    /// Publishes the high-level validation state (valid/invalid) to the UI.
    public let validationStateSubject: CurrentValueSubject<ValidationState, Never>
    
    /// Publishes any validation errors captured during input checks.
    public let validationErrorSubject: PassthroughSubject<ValidationError, Never>
    
    // MARK: Registration Rate Limiter
    
    /// A cancellable reference used to manage registration attempt monitoring.
    /// This may incorporate debouncing or scheduled resets of attempt counters.
    public var registrationRateLimiter: AnyCancellable?
    
    // MARK: Private Properties
    
    /// Maintains the current count of registration attempts to enforce rate limiting.
    private var registrationAttempts: Int = 0
    
    /// Maximum number of registration attempts within a short time window.
    /// Exceeding this leads to rate limiting.
    private let maxRegistrationAttempts: Int = 5
    
    /// Time interval (in seconds) after which registration attempts reset to 0.
    private let registrationResetInterval: TimeInterval = 60.0
    
    // MARK: - Initialization
    
    /// Initializes the registration ViewModel with all needed reactive subjects,
    /// security logic, and references to the AuthRepository.
    ///
    /// Steps:
    /// 1. Calls super.init() from BaseViewModel for shared reactive setup.
    /// 2. Stores the provided AuthRepository reference for registration calls.
    /// 3. Initializes Combine subjects for email, password, first/last name, user type, and submission events.
    /// 4. Sets up isValidSubject and validationStateSubject with default values.
    /// 5. Configures a rate limiter to monitor registration attempts and reset counts periodically.
    /// 6. Wires up any advanced input validation with Combine pipelines (e.g. debouncing).
    ///
    /// - Parameter authRepository: The repository used to securely register new users.
    public init(authRepository: AuthRepository) {
        // 1. BaseViewModel init
        super.init()
        
        // 2. Store repository reference
        self.authRepository = authRepository
        
        // 3. Subjects initialization
        self.emailSubject = PassthroughSubject<String, Never>()
        self.passwordSubject = PassthroughSubject<String, Never>()
        self.firstNameSubject = PassthroughSubject<String, Never>()
        self.lastNameSubject = PassthroughSubject<String, Never>()
        self.userTypeSubject = PassthroughSubject<UserType, Never>()
        self.submitSubject = PassthroughSubject<Void, Never>()
        
        // 4. Default states for form validation
        self.isValidSubject = CurrentValueSubject<Bool, Never>(false)
        self.validationStateSubject = CurrentValueSubject<ValidationState, Never>(.invalid(reason: "Awaiting input"))
        self.validationErrorSubject = PassthroughSubject<ValidationError, Never>()
        
        // 5. Configure registration rate limiting
        //    We monitor each submit event, incrementing attempts and checking thresholds.
        //    We also set a timer-like mechanism to reset attempts after a designated interval.
        self.registrationRateLimiter = self.submitSubject
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.registrationAttempts += 1
                if strongSelf.registrationAttempts > strongSelf.maxRegistrationAttempts {
                    // Exceeding attempt limit => Send an error & log security
                    strongSelf.validationErrorSubject.send(.generalValidationFailure(description: "Rate limit exceeded"))
                    strongSelf.errorSubject.send(NSError(domain: "RegisterViewModel",
                                                        code: 1002,
                                                        userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"]))
                } else {
                    // If registration is valid, we proceed. The actual call to `register()` is handled manually.
                }
                // After each attempt, schedule a reset in X seconds
                strongSelf.scheduleRegistrationAttemptReset()
            }
        
        // 6. (Optional) Setup advanced input validation pipeline if we want to validate continuously.
        //    This is part of the `validateInput()` function that merges and filters user input over time.
    }
    
    // MARK: - Private Helpers
    
    /// Schedules a reset of the registration attempt counter after a fixed interval.
    /// This helps ensuring that the user can try again after some cooldown.
    private func scheduleRegistrationAttemptReset() {
        let currentValue = self.registrationAttempts
        DispatchQueue.global().asyncAfter(deadline: .now() + self.registrationResetInterval) { [weak self] in
            guard let self = self else { return }
            // If the current attempts haven't changed since scheduling, reset it
            // which means no further successful or new attempts happened during the wait.
            if self.registrationAttempts == currentValue {
                self.registrationAttempts = 0
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Validates and sanitizes all relevant input fields using Combine, returning an
    /// AnyPublisher that emits a `ValidationState` (valid or invalid).
    ///
    /// Steps:
    /// 1. Debounce input changes over a short interval to avoid repeated checks.
    /// 2. Merge or combine the streams of email, password, firstName, lastName, userType.
    /// 3. Sanitize each field by trimming whitespaces or removing unsafe characters.
    /// 4. Check email format, password complexity, non-empty names, and userType selection.
    /// 5. Emit either .valid or .invalid(reason: String).
    ///
    /// - Returns: A publisher that emits `ValidationState` whenever input changes or enough time passes.
    public func validateInput() -> AnyPublisher<ValidationState, Never> {
        // Combine user input streams into a single publisher. We'll use combineLatest for demonstration.
        let emailPub = emailSubject.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let pwdPub = passwordSubject.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let fNamePub = firstNameSubject.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let lNamePub = lastNameSubject.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let uTypePub = userTypeSubject
        
        return Publishers.CombineLatest5(emailPub, pwdPub, fNamePub, lNamePub, uTypePub)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .map { [weak self] (email, password, fName, lName, userType) -> ValidationState in
                guard let strongSelf = self else {
                    return .invalid(reason: "ViewModel deallocated")
                }
                
                // Email format check
                if !strongSelf.isValidEmail(email) {
                    return .invalid(reason: "Invalid email format")
                }
                
                // Password complexity
                if !strongSelf.authRepository.validatePassword(password) {
                    return .invalid(reason: "Password does not meet complexity requirements")
                }
                
                // Names not empty
                if fName.isEmpty || lName.isEmpty {
                    return .invalid(reason: "First and/or last name cannot be empty")
                }
                
                // UserType check
                // In a real scenario, we ensure userType is a valid selection from .owner or .walker
                // If we had an unknown case, we'd handle it. But here we have only two.
                
                // If we reach here, it's valid
                return .valid
            }
            .handleEvents(receiveOutput: { [weak self] state in
                // Update local subjects for UI reflection
                self?.validationStateSubject.send(state)
                switch state {
                case .valid:
                    self?.isValidSubject.send(true)
                case .invalid(let reason):
                    self?.isValidSubject.send(false)
                    self?.validationErrorSubject.send(.generalValidationFailure(description: reason))
                }
            })
            .eraseToAnyPublisher()
    }
    
    /// Attempts to register a new user with the current input fields,
    /// applying security checks, rate limiting, and final input validation.
    ///
    /// Steps:
    /// 1. Check if the rate limit is exceeded.
    /// 2. Set loading state to true via BaseViewModel.
    /// 3. Perform final input validation (redundant with continuous validation).
    /// 4. Sanitize and gather input values.
    /// 5. Call `authRepository.register(...)` to create a new user.
    /// 6. On success, emit `.success` in the returned `AnyPublisher`.
    /// 7. On failure, parse the error (validation, network, rate-limited).
    /// 8. Set loading state to false at the end.
    ///
    /// - Returns: A publisher that emits a `RegistrationResult` or a `RegistrationError`.
    public func register() -> AnyPublisher<RegistrationResult, RegistrationError> {
        // 1. Rate limit check
        if registrationAttempts > maxRegistrationAttempts {
            // Immediately fail if attempts are exhausted
            return Fail<RegistrationResult, RegistrationError>(error: .rateLimited)
                .eraseToAnyPublisher()
        }
        
        // 2. Indicate UI loading
        self.setLoading(true)
        
        // 3. We can rely on final input validation here using a one-time collection:
        let emailFuture = CurrentValueSubject<String, Never>("")
        let passwordFuture = CurrentValueSubject<String, Never>("")
        let firstNameFuture = CurrentValueSubject<String, Never>("")
        let lastNameFuture = CurrentValueSubject<String, Never>("")
        let userTypeFuture = CurrentValueSubject<UserType?, Never>(nil)
        
        // Because the actual subjects are ephemeral, we capture the latest values in a thread-safe manner.
        let validationCancellable = self.validateInput()
            .sink { [weak self] state in
                // We just observe the latest state to ensure we don't proceed with invalid data.
                guard let strongSelf = self else { return }
                switch state {
                case .valid:
                    // We proceed once the user triggers submission, so do nothing more here.
                    break
                case .invalid(let reason):
                    // We will store a quick local error
                    strongSelf.validationErrorSubject.send(.generalValidationFailure(description: reason))
                }
            }
        
        // 4. Sanitize & gather final input values from the subjects
        let emailCancellable = emailSubject
            .sink { emailFuture.send($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let passwordCancellable = passwordSubject
            .sink { passwordFuture.send($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let firstNameCancellable = firstNameSubject
            .sink { firstNameFuture.send($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let lastNameCancellable = lastNameSubject
            .sink { lastNameFuture.send($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let userTypeCancellable = userTypeSubject
            .sink { userTypeFuture.send($0) }
        
        // We'll combine them into a single future once to call the repository
        return Future<RegistrationResult, RegistrationError> { [weak self] promise in
            guard let strongSelf = self else {
                promise(.failure(.unknown("ViewModel deallocated")))
                return
            }
            
            let finalEmail = emailFuture.value
            let finalPassword = passwordFuture.value
            let finalFirst = firstNameFuture.value
            let finalLast = lastNameFuture.value
            guard let finalUserType = userTypeFuture.value else {
                let userTypeErr = ValidationError.userTypeNotSelected
                promise(.failure(.validationFailed(userTypeErr)))
                strongSelf.setLoading(false)
                return
            }
            
            // Perform ultimate sanity checks or call the repository if all good
            if finalEmail.isEmpty || finalPassword.isEmpty || finalFirst.isEmpty || finalLast.isEmpty {
                let valErr = ValidationError.generalValidationFailure(description: "Required fields are missing.")
                promise(.failure(.validationFailed(valErr)))
                strongSelf.setLoading(false)
                return
            }
            
            // 5. Attempt repository registration
            //    The repository returns AnyPublisher<User, Error>.
            strongSelf.authRepository.register(email: finalEmail,
                                               password: finalPassword,
                                               firstName: finalFirst,
                                               lastName: finalLast,
                                               userType: finalUserType)
                .mapError { err -> RegistrationError in
                    // Convert generic errors to our local RegistrationError
                    if let valErr = err as? ValidationError {
                        return .validationFailed(valErr)
                    } else {
                        // fallback
                        return .generic(err.localizedDescription)
                    }
                }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let regErr):
                        // 7. Handle error
                        promise(.failure(regErr))
                        // Security monitoring (logging) can be placed here if needed
                        strongSelf.setLoading(false)
                    }
                }, receiveValue: { user in
                    // 6. On success, we can consider it .success plus additional steps
                    promise(.success(.success))
                    strongSelf.setLoading(false)
                })
                .store(in: &strongSelf.cancellables)
            
        }
        .handleEvents(receiveCompletion: { [weak self] _ in
            // Clean up or log final states
            self?.setLoading(false)
            // Cancel local validation streams
            validationCancellable.cancel()
            emailCancellable.cancel()
            passwordCancellable.cancel()
            firstNameCancellable.cancel()
            lastNameCancellable.cancel()
            userTypeCancellable.cancel()
        })
        .eraseToAnyPublisher()
    }
    
    /// Handles a given validation error by updating state, logging, and
    /// notifying the UI layer through the relevant subject.
    ///
    /// Steps:
    /// 1. Update the `validationStateSubject` to invalid.
    /// 2. Emit the error via `validationErrorSubject` for the UI to display or handle.
    /// 3. Perform any security or monitoring logging as required.
    ///
    /// - Parameter error: The validation error that occurred.
    public func handleValidationError(_ error: ValidationError) {
        let reason: String
        switch error {
        case .invalidEmail:
            reason = "The provided email is invalid or empty."
        case .invalidPassword(let details):
            reason = "Password validation failed: \(details)"
        case .emptyNames:
            reason = "First/Last names cannot be empty."
        case .userTypeNotSelected:
            reason = "User type must be selected."
        case .generalValidationFailure(let desc):
            reason = "Validation failed: \(desc)"
        }
        
        // Update state to reflect invalid input
        self.validationStateSubject.send(.invalid(reason: reason))
        
        // Emit to UI
        self.validationErrorSubject.send(error)
        
        // Optionally, log via errorSubject for global error handling
        let nsError = NSError(domain: "RegisterViewModel",
                              code: 1003,
                              userInfo: [NSLocalizedDescriptionKey : reason])
        self.errorSubject.send(nsError)
    }
    
    // MARK: - Utility
    
    /// Inspects an email string using a basic regex to determine if the format is likely valid.
    /// Adjust the pattern to suit real-world constraints.
    ///
    /// - Parameter email: The email string to check.
    /// - Returns: True if it matches basic format, else false.
    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: email.utf16.count)
        return regex?.firstMatch(in: email, options: [], range: range) != nil
    }
}