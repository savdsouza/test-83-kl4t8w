//
//  AddDogViewModel.swift
//  DogWalking
//
//  This file defines the AddDogViewModel, a thread-safe view model responsible for
//  managing the addition of new dog profiles in the application using the MVVM pattern.
//  It includes comprehensive validation, real-time feedback, error handling, and
//  reactive data binding to fulfill the Pet Profile Management and Data Management
//  Strategy requirements.
//
//  Imports:
//  - Foundation (iOS 13.0+): Basic iOS functionality and date handling.
//  - Combine (iOS 13.0+): Reactive programming framework for thread-safe signal flows.
//  - BaseViewModel: Abstract base class providing loading & error subjects.
//  - DogUseCase: Business logic for validating and creating dog profiles.
//  - Dog: Domain model representing dog profiles with robust validation.

import Foundation // iOS 13.0+
import Combine    // iOS 13.0+

// MARK: - Internal Imports
import struct DogWalking.Dog  // src/ios/DogWalking/Domain/Models/Dog.swift
import class DogWalking.DogUseCase  // src/ios/DogWalking/Domain/UseCases/DogUseCase.swift
import class DogWalking.BaseViewModel // src/ios/DogWalking/Core/Base/BaseViewModel.swift

/// A high-level representation of a validation error that can occur
/// when input fields do not meet the required criteria. This struct
/// carries a human-readable message plus any additional details needed
/// for UI presentation or logging.
public struct ValidationError: Error, Equatable {
    /// A descriptive message explaining the validation failure.
    public let message: String

    /// Creates a new instance of ValidationError with the given message.
    /// - Parameter message: A string describing the validation issue.
    public init(message: String) {
        self.message = message
    }
}

/// An enumeration representing the result of validating a set of input fields.
/// This can be expanded to carry more context if necessary.
public enum ValidationResult {
    /// Validation succeeded with no errors.
    case success
    /// Validation failed with one or more detailed error messages.
    case failure([ValidationError])
}

/// The AddDogViewModel is responsible for managing the addition of new dog profiles
/// with robust validation, real-time feedback, and error handling. It makes use of
/// Combine for reactive data binding and depends on the DogUseCase for domain-level
/// creation and breed validation.
@MainActor
public final class AddDogViewModel: BaseViewModel {

    // MARK: - Public Subjects & Properties

    /// A reference to the business logic needed to create and validate dogs.
    public let dogUseCase: DogUseCase

    /// Subject tracking the dog's name input. Publishes String values.
    public let nameSubject: CurrentValueSubject<String, Never>

    /// Subject tracking the dog's breed input. Publishes String values.
    public let breedSubject: CurrentValueSubject<String, Never>

    /// Subject tracking the dog's birth date input. Publishes Date values.
    public let birthDateSubject: CurrentValueSubject<Date, Never>

    /// Subject tracking the dog's medical info. Publishes a dictionary of key-value pairs.
    public let medicalInfoSubject: CurrentValueSubject<[String: String], Never>

    /// Subject tracking the dog's weight in kilograms. Publishes Double values.
    public let weightSubject: CurrentValueSubject<Double, Never>

    /// Subject tracking an array of special instructions (one instruction per String).
    public let specialInstructionsSubject: CurrentValueSubject<[String], Never>

    /// Subject that callers can send a Void event to when the user attempts to create a dog.
    public let submitSubject: PassthroughSubject<Void, Never>

    /// Subject publishing successfully created Dog objects. Emits upon createDog completion.
    public let successSubject: PassthroughSubject<Dog, Never>

    /// Subject publishing validation error events for UI error presentation or logging.
    public let validationErrorSubject: PassthroughSubject<ValidationError, Never>

    /// A thread-safe collection of Combine cancellables for memory management of subscriptions.
    private var cancellables: Set<AnyCancellable>

    // MARK: - Initialization

    /// Initializes the AddDogViewModel with required dependencies and sets up
    /// the reactive streams for input validation and dog creation.
    ///
    /// Steps:
    ///  1. Call super.init() from BaseViewModel.
    ///  2. Store the injected dogUseCase dependency.
    ///  3. Initialize all subjects with default values.
    ///  4. Configure input validation bindings using debounce or direct observe.
    ///  5. Configure combined field validation across all inputs.
    ///  6. Handle error states and loading states.
    ///  7. Initialize the subscription set for memory management.
    ///
    /// - Parameter dogUseCase: The business logic for dog creation & breed validation.
    public init(dogUseCase: DogUseCase) {
        // 1. BaseViewModel initialization.
        self.dogUseCase = dogUseCase
        self.nameSubject = CurrentValueSubject<String, Never>("")
        self.breedSubject = CurrentValueSubject<String, Never>("")
        self.birthDateSubject = CurrentValueSubject<Date, Never>(Date())
        self.medicalInfoSubject = CurrentValueSubject<[String: String], Never>([:])
        self.weightSubject = CurrentValueSubject<Double, Never>(0.0)
        self.specialInstructionsSubject = CurrentValueSubject<[String], Never>([])
        self.submitSubject = PassthroughSubject<Void, Never>()
        self.successSubject = PassthroughSubject<Dog, Never>()
        self.validationErrorSubject = PassthroughSubject<ValidationError, Never>()
        self.cancellables = Set<AnyCancellable>()
        super.init()

        // 4. and 5. Setup all reactive bindings for validation and real-time feedback.
        setupBindings()
    }

    // MARK: - Public Methods

    /// Executes comprehensive validation of all input fields, returning a publisher
    /// that emits a ValidationResult with either success or failure containing
    /// detailed errors. This function leverages Combine to remain thread-safe and
    /// asynchronous.
    ///
    /// Steps:
    ///  1. Validate name length, ensuring it is not empty.
    ///  2. Validate breed by calling dogUseCase.validateBreed.
    ///  3. Validate that birth date is not in the future (or any other domain rule).
    ///  4. Check that medical info is non-empty if your domain requires it, or just ensure correctness.
    ///  5. Validate weight range is within acceptable bounds (e.g., 0.5 ... 200).
    ///  6. Check special instructions for length or domain restrictions.
    ///  7. Combine all results into a single ValidationResult.
    ///  8. Emit the result downstream to subscribers.
    ///
    /// - Returns: A publisher of type AnyPublisher<ValidationResult, Never> that completes
    ///            after performing all validations.
    public func validateInput() -> AnyPublisher<ValidationResult, Never> {
        return Future<ValidationResult, Never> { [weak self] promise in
            guard let self = self else {
                promise(.success(.failure([ValidationError(message: "ViewModel deinitialized.")])))
                return
            }

            // A local array of ValidationError(s) to accumulate any issues.
            var errors = [ValidationError]()

            // 1. Validate name is non-empty.
            let trimmedName = self.nameSubject.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                errors.append(ValidationError(message: "Dog name cannot be empty."))
            }

            // 2. Validate breed using dogUseCase. If validation fails, we catch the error.
            let breedValue = self.breedSubject.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if breedValue.isEmpty {
                errors.append(ValidationError(message: "Breed cannot be empty."))
            } else {
                do {
                    try self.dogUseCase.validateBreed(breedValue)
                } catch {
                    errors.append(ValidationError(message: "Invalid or unrecognized breed."))
                }
            }

            // 3. Validate birth date (cannot be in the future, or must be in plausible range).
            let currentDate = Date()
            if self.birthDateSubject.value > currentDate {
                errors.append(ValidationError(message: "Birth date cannot be in the future."))
            }

            // 4. Check medical info dictionary if domain requires a non-empty approach.
            let medicalInfo = self.medicalInfoSubject.value
            if medicalInfo.isEmpty {
                // Per domain logic, we may require at least one entry. If so, do:
                // errors.append(ValidationError(message: "At least one medical info entry is required."))
                // Otherwise, ignore if not mandatory.
            }

            // 5. Validate weight range (0.5 ... 200.0), matching domain model checks.
            let weight = self.weightSubject.value
            if weight < 0.5 || weight > 200.0 {
                errors.append(ValidationError(message: "Weight must be between 0.5 kg and 200.0 kg."))
            }

            // 6. Inspect special instructions array for domain-based checks if needed.
            // Example: no more than 10 instructions, each not empty.
            let instructions = self.specialInstructionsSubject.value
            if instructions.count > 10 {
                errors.append(ValidationError(message: "No more than 10 special instructions allowed."))
            }

            // 7. Combine all results in a single ValidationResult.
            if errors.isEmpty {
                promise(.success(.success))
            } else {
                promise(.success(.failure(errors)))
            }

        }.eraseToAnyPublisher()
    }

    /// Creates a new Dog profile with the validated input fields, using the dogUseCase.
    /// This function manages loading/error states from the BaseViewModel and publishes
    /// the created dog to successSubject if everything succeeds.
    ///
    /// Steps:
    ///  1. Perform final input validation by calling validateInput().
    ///  2. If validation fails, emit the first error or aggregated errors to
    ///     validationErrorSubject.
    ///  3. If validation passes, construct a new Dog instance from the form data.
    ///  4. Call dogUseCase.createDog() with the new dog. Manage loading state and handle errors.
    ///  5. Emit success result to successSubject upon completion.
    ///
    /// - Returns: A publisher AnyPublisher<Dog, Error> that emits the created Dog
    ///            or an Error if creation fails.
    public func createDog() -> AnyPublisher<Dog, Error> {
        return validateInput()
            .flatMap { [weak self] validationResult -> AnyPublisher<Dog, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "AddDogViewModel", code: -1, userInfo: nil))
                        .eraseToAnyPublisher()
                }

                switch validationResult {
                case .success:
                    // 3. Construct Dog instance from validated data.
                    let newDog = Dog(
                        id: UUID(),
                        ownerId: UUID(), // For demonstration, might need real owner ID from context
                        name: self.nameSubject.value,
                        breed: self.breedSubject.value,
                        birthDate: self.birthDateSubject.value,
                        medicalInfo: self.medicalInfoSubject.value,
                        active: true,
                        profileImageUrl: nil,
                        weight: self.weightSubject.value,
                        specialInstructions: self.specialInstructionsSubject.value
                    )

                    // 4. Wrap dogUseCase.createDog in a publisher, handle loading states.
                    self.setLoading(true)
                    return self.dogUseCase.createDog(dog: newDog, requestingUserId: UUID())
                        .handleEvents(receiveCompletion: { [weak self] _ in
                            self?.setLoading(false)
                        })
                        .mapError { $0 as Error }
                        .eraseToAnyPublisher()

                case .failure(let errors):
                    // 2. Emit errors to validationErrorSubject
                    if let firstError = errors.first {
                        self.validationErrorSubject.send(firstError)
                    }
                    // Return a fail publisher so the chain ends
                    return Fail(error: NSError(domain: "AddDogViewModel", code: 422, userInfo: [
                        NSLocalizedDescriptionKey: "Validation failed"
                    ])).eraseToAnyPublisher()
                }
            }
            // 5. On successful creation, forward the dog to successSubject
            .handleEvents(receiveOutput: { [weak self] dog in
                self?.successSubject.send(dog)
            })
            .eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    /// Configures the Combine-based reactive bindings that provide real-time
    /// feedback and error handling for the dog's input fields. This includes:
    /// - Setting up a debounced validation pipeline if desired.
    /// - Combining all fields to manage global validation state.
    /// - Binding the submitSubject to dispatch createDog logic.
    /// - Handling error chaining and analytics.
    ///
    /// Steps:
    ///  1. Setup optional debounced field validation subscriptions.
    ///  2. Combine input fields to produce a single validation state whenever any field changes.
    ///  3. Subscribe to submitSubject to trigger createDog logic.
    ///  4. Configure error passing and success handling.
    ///  5. Optionally integrate with analytics tracking for form usage.
    private func setupBindings() {
        // 1. (Optional) Debounced input validation for each field can be done by
        //    monitoring the subjects .debounce(for:scheduler:) and chaining sink.

        // Example: nameSubject
        nameSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // Real-time partial validations if desired.
                _ = self?.validateInput() // We could store or ignore result.
            }
            .store(in: &cancellables)

        // 2. Combine multiple fields if we want a single pipeline reflecting all changes:
        Publishers.CombineLatest6(
            nameSubject, breedSubject, birthDateSubject,
            medicalInfoSubject, weightSubject, specialInstructionsSubject
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _,_,_,_,_,_ in
            // Trigger or update real-time validation status if desired.
            _ = self?.validateInput()
        }
        .store(in: &cancellables)

        // 3. Bind submitSubject to invoke createDog logic.
        submitSubject
            .sink { [weak self] in
                guard let self = self else { return }
                // Attempt to createDog whenever submit is triggered.
                self.createDog()
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .failure(let err):
                            // Publish error from pipeline to errorSubject to display or log.
                            self.errorSubject.send(err)
                        case .finished:
                            break
                        }
                    }, receiveValue: { createdDog in
                        // Already handled by handleEvents, but can do extra logic if needed.
                    })
                    .store(in: &self.cancellables)
            }
            .store(in: &cancellables)

        // 4. Additional error handling or chaining is already set up in createDog pipeline.

        // 5. (Optional) Initialize analytics, e.g., track form usage or field changes.
        //    For demonstration, we skip a real analytics call.
    }
}