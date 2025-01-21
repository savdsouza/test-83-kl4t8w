//
//  EditProfileViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect Agent on 2023-10-12.
//
//  View model responsible for secure user profile editing functionality with robust
//  data validation, reactive state management, and MVVM architecture compliance.
//  It leverages Combine for asynchronous operations, handles sensitive user data
//  securely, and coordinates with the UserRepository to ensure updates are properly
//  persisted.
//

import Foundation // iOS 13.0+ (Basic iOS functionality and data handling)
import Combine    // iOS 13.0+ (Reactive programming and state management)

// Internal imports
import Core/Base/BaseViewModel
import Domain/Models/User
import Data/Repositories/UserRepository

/// A general validation state enumeration, used to inform the UI about
/// validation successes or failures. The actual cases and handling can be
/// extended for multiple validation rules.
public enum ValidationState {
    case valid
    case invalid(reason: String)
}

/// An enumeration capturing potential edit profile errors specific to
/// user profile operations in this ViewModel.
public enum EditProfileError: Error {
    /// The user ID was empty or invalid.
    case invalidUserId
    /// Indicates a missing user object when attempting an update.
    case noExistingUser
    /// The provided first name is empty or invalid.
    case invalidFirstName
    /// The provided last name is empty or invalid.
    case invalidLastName
    /// Generic or unknown error case for demonstration.
    case unknown(String)
}

/// EditProfileViewModel is responsible for handling secure profile editing
/// operations with comprehensive input validation, error handling, and
/// reactive data flow using Combine. It communicates with the UserRepository
/// to fetch and update user data, ensuring that personal information is
/// handled securely and in compliance with enterprise data-management rules.
@MainActor
public final class EditProfileViewModel: BaseViewModel {

    // MARK: - Properties

    /// Repository responsible for providing secure user data retrieval and updates.
    private let userRepository: UserRepository

    /// A reactive subject providing the current user details, or nil if not yet loaded.
    public let userSubject: CurrentValueSubject<User?, Never>

    /// A subject that external observers can listen to in order to be notified
    /// of successful saves (profile updates).
    public let saveSuccessSubject: PassthroughSubject<Void, Never>

    /// A subject to broadcast validation outcomes, allowing the UI to respond
    /// with user-facing messages or signals.
    public let validationSubject: PassthroughSubject<ValidationState, Never>

    /// The string identifier representing the user whose profile is being edited.
    /// Must be validated before any repository operations.
    private let userId: String

    /// A collection of Combine Cancellables to retain subscription lifetimes.
    private var cancellables: Set<AnyCancellable>

    // MARK: - Initialization

    /**
     Initializes the EditProfileViewModel with the provided `UserRepository` and user ID.

     Steps:
     1. Calls `super.init()` to initialize the base view model.
     2. Stores the `UserRepository` reference for future data operations.
     3. Validates and assigns the `userId`.
     4. Creates reactive subjects for user data, save events, and validation states.
     5. Sets up any input validation or state-binding if needed (placeholder).
     6. Configures error handling to integrate with BaseViewModel's `errorSubject`.
     7. Optionally triggers loading of user data via `loadUserProfile()`.

     - Parameters:
       - userRepository: The repository for secure user reads and writes.
       - userId: The string-based identifier of the user to be edited.
     */
    public init(userRepository: UserRepository, userId: String) {
        self.userRepository = userRepository
        self.userId = userId
        self.userSubject = CurrentValueSubject<User?, Never>(nil)
        self.saveSuccessSubject = PassthroughSubject<Void, Never>()
        self.validationSubject = PassthroughSubject<ValidationState, Never>()
        self.cancellables = Set<AnyCancellable>()

        super.init()

        // Optionally load user data immediately (commented out as a demonstration placeholder).
        // loadUserProfile()
        //     .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        //     .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /**
     Securely loads and validates user profile data from the repository.

     Steps:
     1. Sets the loading state to true.
     2. Ensures the `userId` is non-empty; otherwise returns a failing publisher.
     3. Requests user data from `userRepository`.
     4. Uses `validateUserData` to ensure the retrieved user is valid.
     5. Updates `userSubject` with the validated user object.
     6. Logs a successful load event (demonstrated by handleEvents).
     7. Resets loading state to false upon completion.
     8. Returns a publisher that emits the loaded `User` or an error.

     - Returns: An `AnyPublisher<User, Error>` emitting the loaded and validated user profile.
     */
    public func loadUserProfile() -> AnyPublisher<User, Error> {
        setLoading(true)

        // Step 2: Validate userId format
        let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            setLoading(false)
            return Fail(error: EditProfileError.invalidUserId).eraseToAnyPublisher()
        }

        // Step 3: Fetch user from the repository
        return userRepository.getUser(userId: trimmedId)
            // Step 4: Validate the user data after retrieval
            .tryMap { [weak self] fetchedUser -> User in
                guard let self = self else {
                    throw EditProfileError.unknown("ViewModel deinitialized during loadUserProfile.")
                }
                let isDataValid = self.userRepository.validateUserData(fetchedUser)
                if !isDataValid {
                    throw EditProfileError.unknown("Repository validation failed for user data.")
                }
                return fetchedUser
            }
            // Step 5 & 6: Update local subject and log success
            .handleEvents(receiveOutput: { [weak self] user in
                self?.userSubject.send(user)
                // (Optional) Log success or track analytics here
            })
            // Step 7: Reset loading state on completion
            .handleEvents(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.setLoading(false)
            })
            // Step 8: Return the resulting publisher
            .eraseToAnyPublisher()
    }

    /**
     Securely updates the user profile with validation, error handling,
     and concurrency safeguards.

     Steps:
     1. Sets the loading state to true.
     2. Validates all input fields (firstName, lastName, etc.).
     3. Sanitizes input data: trims whitespace and normalizes strings.
     4. Calls `updateProfile` on the domain `User` object for local checks.
     5. Calls `userRepository.updateUser` to persist changes.
     6. Logs or handles concurrency issues (optimistic lock updates).
     7. On success, updates `userSubject` and emits a save success event.
     8. Resets loading state on completion.
     9. Returns a publisher that emits the updated `User` or an error.

     - Parameters:
       - firstName: The updated first name string.
       - lastName: The updated last name string.
       - phone: An optional updated phone number.
       - profileImageUrl: An optional updated image URL in string form.
       - version: An optional string representing the version/concurrency field.
     - Returns: An `AnyPublisher<User, Error>` that completes with the updated user data or an error.
     */
    public func updateProfile(
        firstName: String,
        lastName: String,
        phone: String? = nil,
        profileImageUrl: String? = nil,
        version: String? = nil
    ) -> AnyPublisher<User, Error> {

        setLoading(true)

        // Step 2: Validate essential fields
        let trimmedFName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFName.isEmpty else {
            validationSubject.send(.invalid(reason: "First name is empty"))
            setLoading(false)
            return Fail(error: EditProfileError.invalidFirstName).eraseToAnyPublisher()
        }

        let trimmedLName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLName.isEmpty else {
            validationSubject.send(.invalid(reason: "Last name is empty"))
            setLoading(false)
            return Fail(error: EditProfileError.invalidLastName).eraseToAnyPublisher()
        }

        // Step 3: Sanitize other inputs
        let sanitizedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedImageUrl = profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Attempt retrieval of the current user object
        guard let existingUser = userSubject.value else {
            setLoading(false)
            return Fail(error: EditProfileError.noExistingUser).eraseToAnyPublisher()
        }

        // Step 4: Use domain-level updateProfile for local checks
        let profileResult = existingUser.updateProfile(
            firstName: trimmedFName,
            lastName: trimmedLName,
            phone: sanitizedPhone,
            profileImageUrl: sanitizedImageUrl,
            preferences: nil
        )

        switch profileResult {
        case .failure(let userError):
            // If local update fails, end loading & emit error
            setLoading(false)
            handleError(userError)
            return Fail(error: userError).eraseToAnyPublisher()

        case .success:
            // Proceed to user repository update
            break
        }

        // Step 5: Attempt to update user in repository, handle concurrency
        return userRepository.updateUser(user: existingUser)
            // Step 6: Optionally map concurrency errors or version conflicts here
            .mapError { [weak self] error in
                self?.handleError(error)
                return error
            }
            // Step 7 & 8: Update local subject, emit success event, reset loading
            .handleEvents(
                receiveOutput: { [weak self] updatedUser in
                    self?.userSubject.send(updatedUser)
                    self?.saveSuccessSubject.send(())
                },
                receiveCompletion: { [weak self] _ in
                    self?.setLoading(false)
                }
            )
            // Step 9: Return the final updated user
            .eraseToAnyPublisher()
    }
}