import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)

// IE1: Internal imports from the provided paths.
// These ensure we use the base view model and walk-related domain/usecase logic.
import class Core.Base.BaseViewModel        // src/ios/DogWalking/Core/Base/BaseViewModel.swift
import class Domain.Models.Walk.Walk        // src/ios/DogWalking/Domain/Models/Walk.swift
import class Domain.UseCases.WalkUseCase.WalkUseCase // src/ios/DogWalking/Domain/UseCases/WalkUseCase.swift

/// Represents various booking-specific errors encountered during validation,
/// scheduling, or payment processes in the booking flow. This is a placeholder
/// for demonstration; real implementations may have more cases or data.
public enum BookingError: Error {
    /// Attempted to schedule or book a walk using a date that is already past.
    case dateInPast

    /// The selected walker is unavailable.
    case walkerUnavailable

    /// The chosen dog identifier was invalid or missing.
    case invalidDogSelection

    /// A conflict occurred during scheduling, e.g., overlapping times or double-booking.
    case bookingConflict

    /// Payment processing or authorization failed.
    case paymentFailed

    /// An unknown or unexpected error occurred.
    case unknown
}

/// A placeholder structure representing a matched walker for an instant booking scenario.
/// Real implementations may include estimated arrival times, cost details, or profile data.
public struct WalkerMatch {
    /// The unique identifier for the matched walker.
    public let walkerId: String

    /// An optional estimated start or arrival time for the walk.
    public let estimatedStartTime: Date?

    /// Creates a new WalkerMatch placeholder.
    /// - Parameters:
    ///   - walkerId: The matched walker's identifier as a String.
    ///   - estimatedStartTime: An optional Date indicating when the walker can begin.
    public init(walkerId: String, estimatedStartTime: Date?) {
        self.walkerId = walkerId
        self.estimatedStartTime = estimatedStartTime
    }
}

/// BookWalkViewModel is responsible for managing the dog walk booking flow,
/// including the selection of dates, walkers, and dogs, plus scheduling,
/// availability checks, instant matching, and comprehensive error handling.
/// It leverages a WalkUseCase to perform domain-level operations like scheduling
/// and matching, while providing reactive Combine publishers to notify interested
/// observers about changes and results.
public final class BookWalkViewModel: BaseViewModel {

    // MARK: - Dependencies

    /// A reference to the domain-level use case handling walk booking logic.
    /// This includes methods for scheduling walks, checking walker availability,
    /// and finding an instant match walker for last-minute bookings.
    public let walkUseCase: WalkUseCase

    // MARK: - Published Subjects (State & Events)

    /// The currently selected walk date subject. This subject holds the Date
    /// chosen by the user for the upcoming dog walk, defaulting to the current time.
    public let selectedDateSubject: CurrentValueSubject<Date, Never>

    /// The selected walker identifier subject. This holds the unique ID of the
    /// chosen walker, or nil if the user has not selected one (or if an instant
    /// match is in progress).
    public let selectedWalkerIdSubject: CurrentValueSubject<String?, Never>

    /// The selected dog identifier subject. This holds the UUID of the chosen dog,
    /// or nil if not yet selected by the user. Must be validated before booking.
    public let selectedDogIdSubject: CurrentValueSubject<UUID?, Never>

    /// A subject that publishes a completed Walk once the booking flow
    /// finishes successfully, either by scheduling or instant matching.
    public let bookingCompletedSubject: PassthroughSubject<Walk, Never>

    /// A subject that indicates whether the currently selected walker is available
    /// for the chosen date/time. Defaults to false until explicitly checked.
    public let walkerAvailabilitySubject: CurrentValueSubject<Bool, Never>

    /// A subject that publishes a successful instant match result. If an instant
    /// match is found, the booking flow can proceed quickly to confirmation.
    public let instantMatchSubject: PassthroughSubject<WalkerMatch, Never>

    /// A subject that publishes booking-related errors (e.g., scheduling conflicts,
    /// payment failures). Observers can subscribe to display user-facing alerts.
    public let bookingErrorSubject: PassthroughSubject<BookingError, Never>

    // MARK: - Internal/Private Properties

    /// A serial dispatch queue to ensure thread-safe access to view model state,
    /// including subjects and internal logic. This helps avoid race conditions
    /// when multiple async operations occur simultaneously.
    public let stateQueue: DispatchQueue

    /// A collection of Combine cancellables for managing the lifetime of subscriptions
    /// used in this view model, such as calls to walkUseCase methods.
    private var cancellables: Set<AnyCancellable>

    // MARK: - Initialization

    /// Initializes a new BookWalkViewModel with all required properties and sets up
    /// default state management.
    ///
    /// Steps:
    /// 1. Stores the provided walkUseCase reference for scheduling logic.
    /// 2. Initializes the reactive subjects that track selected date, walker ID, dog ID,
    ///    completion events, availability, instant match results, and errors.
    /// 3. Creates a dedicated stateQueue for thread safety.
    /// 4. Sets up any necessary subscriptions or bindings to the walkUseCase if desired.
    /// 5. Initializes the cancellables set to manage Combine pipelines.
    ///
    /// - Parameter walkUseCase: A domain use case for scheduling, availability checking,
    ///                          matching, and booking dog walks.
    public init(walkUseCase: WalkUseCase) {
        self.walkUseCase = walkUseCase

        // Init subjects with default or placeholder values.
        self.selectedDateSubject = CurrentValueSubject<Date, Never>(Date())
        self.selectedWalkerIdSubject = CurrentValueSubject<String?, Never>(nil)
        self.selectedDogIdSubject = CurrentValueSubject<UUID?, Never>(nil)
        self.bookingCompletedSubject = PassthroughSubject<Walk, Never>()
        self.walkerAvailabilitySubject = CurrentValueSubject<Bool, Never>(false)
        self.instantMatchSubject = PassthroughSubject<WalkerMatch, Never>()
        self.bookingErrorSubject = PassthroughSubject<BookingError, Never>()

        // Create a dedicated queue for thread-safety.
        self.stateQueue = DispatchQueue(label: "com.dogwalking.BookWalkViewModel.stateQueue",
                                        qos: .userInitiated)

        // Initialize the set of AnyCancellable for Combine subscriptions management.
        self.cancellables = Set<AnyCancellable>()

        super.init()

        // Optionally, subscribe to walkUseCase.walkUpdatePublisher here if you want
        // to observe real-time updates to the walk after scheduling, etc.
        // For demonstration, we skip or keep minimal usage as needed.
    }

    // MARK: - Functions

    /// Updates the selected walk date, performing basic validation (ensuring
    /// the date is in the future) and triggers a walker availability check if valid.
    ///
    /// Steps:
    /// 1. Ensure the provided date is not in the past; otherwise notify error.
    /// 2. Update selectedDateSubject on the internal state queue.
    /// 3. Attempt to check walker availability asynchronously.
    /// 4. Handle both success (updating walkerAvailabilitySubject) and failure states.
    /// 5. If invalid date, emit a dateInPast error on bookingErrorSubject.
    ///
    /// - Parameter date: The newly selected Date for the walk booking.
    public func updateSelectedDate(_ date: Date) {
        stateQueue.async { [weak self] in
            guard let self = self else { return }

            let now = Date()
            // Step 1: Validate date in future
            if date < now {
                self.bookingErrorSubject.send(.dateInPast)
                return
            }

            // Step 2: Update subject
            self.selectedDateSubject.send(date)

            // Step 3: Attempt availability check
            // We'll use checkWalkerAvailability and simply subscribe internally to update the subject.
            let availabilityPublisher = self.checkWalkerAvailability()
            let cancellable = availabilityPublisher
                .sink(receiveCompletion: { completion in
                    // If an error occurs, we can publish an error or handle it gracefully.
                    if case .failure = completion {
                        self.walkerAvailabilitySubject.send(false)
                    }
                }, receiveValue: { isAvailable in
                    // Step 4: Update the walkerAvailabilitySubject with the result.
                    self.walkerAvailabilitySubject.send(isAvailable)
                })
            self.cancellables.insert(cancellable)
        }
    }

    /// Checks the real-time availability of the selected walker for the chosen date,
    /// returning a publisher that emits a Bool indicating availability or fails with an Error.
    ///
    /// Steps:
    /// 1. Validate that both a walker ID and a selected date are present.
    /// 2. Call walkUseCase.checkWalkerAvailability with those parameters.
    /// 3. Subscribe to the returned publisher, updating internal states as needed.
    /// 4. Emit the final availability status or an error if the check fails.
    ///
    /// - Returns: An AnyPublisher<Bool, Error> that completes once availability is determined.
    public func checkWalkerAvailability() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BookingError.unknown))
                return
            }

            self.stateQueue.async {
                // Step 1: Validate walker & date
                guard
                    let walkerId = self.selectedWalkerIdSubject.value,
                    let date = self.selectedDateSubject.value as Date?
                else {
                    promise(.failure(BookingError.walkerUnavailable))
                    return
                }

                // To show loading UI while checking availability.
                self.setLoading(true)

                // Step 2: Call the domain use case.
                let publisher = self.walkUseCase.checkWalkerAvailability(walkerId: walkerId, walkDate: date)

                // Step 3: Subscribe
                let sub = publisher
                    .sink(receiveCompletion: { completion in
                        self.setLoading(false)
                        switch completion {
                        case .failure(let err):
                            // We can route error to handleError or emit to bookingErrorSubject as needed
                            self.handleError(err)
                            promise(.failure(err))
                        case .finished:
                            break
                        }
                    }, receiveValue: { isAvailable in
                        // We return isAvailable
                        promise(.success(isAvailable))
                    })

                self.cancellables.insert(sub)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Initiates an instant match process to find a suitable walker for the
    /// selected date/time if the user has not chosen a specific walker. Retrieves
    /// a matched walker from the domain layer or fails with an error.
    ///
    /// Steps:
    /// 1. Validate basic booking requirements (the user must have a selected date and dog).
    /// 2. Invoke walkUseCase.findInstantMatch for the given date/dog.
    /// 3. Update the selected walker ID upon success.
    /// 4. Emit the match result via instantMatchSubject.
    /// 5. Return a publisher for chaining or functional usage in the UI layer.
    ///
    /// - Returns: An AnyPublisher<WalkerMatch, Error> that completes after a
    ///            walker is found or an error occurs.
    public func findInstantMatch() -> AnyPublisher<WalkerMatch, Error> {
        return Future<WalkerMatch, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(BookingError.unknown))
                return
            }

            self.stateQueue.async {
                // Step 1: Validate booking requirements
                guard let date = self.selectedDateSubject.value as Date?,
                      let dogId = self.selectedDogIdSubject.value
                else {
                    promise(.failure(BookingError.invalidDogSelection))
                    return
                }

                // Optional: Set loading
                self.setLoading(true)

                // Step 2: Call the domain method for instant matching
                let pub = self.walkUseCase.findInstantMatch(walkDate: date, dogId: dogId)
                let sub = pub
                    .sink(receiveCompletion: { completion in
                        self.setLoading(false)
                        if case .failure(let err) = completion {
                            self.handleError(err)
                            promise(.failure(err))
                        }
                    }, receiveValue: { matchedWalker in
                        // Step 3: Update the selectedWalkerId
                        self.selectedWalkerIdSubject.send(matchedWalker.walkerId)

                        // Step 4: Emit the match result
                        self.instantMatchSubject.send(matchedWalker)

                        // Step 5: Return success
                        promise(.success(matchedWalker))
                    })
                self.cancellables.insert(sub)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Initiates the final booking of a walk, applying enhanced validation and error handling.
    /// It checks availability, constructs a walk request, handles potential scheduling conflicts,
    /// processes payment if necessary, and notifies observers of success/failure states.
    ///
    /// Steps:
    /// 1. Perform comprehensive validation (date, walker, dog).
    /// 2. Check final availability if needed.
    /// 3. Construct/prepare the Walk domain object.
    /// 4. Handle or detect booking conflicts.
    /// 5. Process payment authorization if required.
    /// 6. Call walkUseCase.scheduleWalk to finalize booking in the domain layer.
    /// 7. Handle success/failure. On success, update booking status and emit bookingCompletedSubject.
    /// 8. Return an AnyPublisher that completes with the booked Walk or a BookingError.
    ///
    /// - Returns: An AnyPublisher<Walk, BookingError> providing the final Walk or an error.
    public func bookWalk() -> AnyPublisher<Walk, BookingError> {
        return Future<Walk, BookingError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown))
                return
            }

            self.stateQueue.async {
                // Step 1: Comprehensive validation
                guard
                    let date = self.selectedDateSubject.value as Date?,
                    date >= Date()
                else {
                    promise(.failure(.dateInPast))
                    return
                }
                guard let dogId = self.selectedDogIdSubject.value else {
                    promise(.failure(.invalidDogSelection))
                    return
                }
                guard let walkerId = self.selectedWalkerIdSubject.value else {
                    promise(.failure(.walkerUnavailable))
                    return
                }

                // Indicate loading for UI.
                self.setLoading(true)

                // Step 2: (Optional) final availability check. We'll just do a quick call:
                let availabilityPub = self.walkUseCase.checkWalkerAvailability(walkerId: walkerId, walkDate: date)

                let sub = availabilityPub
                    .flatMap { isAvailable -> AnyPublisher<Walk, Error> in
                        guard isAvailable else {
                            throw BookingError.walkerUnavailable
                        }

                        // Step 3: Construct or prepare a Walk domain object.
                        // For demonstration, we'll create a minimal instance.
                        let newWalk = Walk(id: UUID(),
                                           ownerId: "Owner-ExampleID",
                                           walkerId: walkerId,
                                           dogId: dogId,
                                           scheduledStartTime: date,
                                           price: 25.0) // Example price

                        // Step 4: (Placeholder) handle or detect booking conflicts.
                        // We can skip or do minimal logic here, semantically.

                        // Step 5: (Placeholder) process payment or authorization if needed.
                        // We'll skip the actual payment logic for demonstration.

                        // Step 6: Call scheduleWalk
                        return self.walkUseCase.scheduleWalk(newWalk)
                    }
                    .sink(receiveCompletion: { completion in
                        self.setLoading(false)
                        switch completion {
                        case .failure(let err):
                            // Publish a domain-level error or map if needed
                            // and deliver as a BookingError.
                            let mappedError = (err as? BookingError) ?? .unknown
                            self.bookingErrorSubject.send(mappedError)
                            promise(.failure(mappedError))
                        case .finished:
                            // No action, success is in receiveValue
                            break
                        }
                    }, receiveValue: { bookedWalk in
                        // Step 7: On success, update booking status or do final tasks
                        self.bookingCompletedSubject.send(bookedWalk)
                        // Return success to the Future
                        promise(.success(bookedWalk))
                    })

                self.cancellables.insert(sub)
            }
        }
        .mapError { error -> BookingError in
            // If any bridging is needed from generic Errors to BookingError, do it here.
            return error
        }
        .eraseToAnyPublisher()
    }
}