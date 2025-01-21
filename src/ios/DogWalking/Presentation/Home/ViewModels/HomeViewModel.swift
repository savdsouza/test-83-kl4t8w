//
//  HomeViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-20.
//
//  This file defines a thread-safe view model (HomeViewModel) managing the home
//  screen state and business logic. It integrates with the WalkUseCase for walk
//  lifecycle operations, the LocationService for battery-optimized location
//  tracking, and the BaseViewModel for reactive data handling, error broadcasts,
//  and loading state management. The design aims to provide robust error handling,
//  memory-safe concurrency, and real-time updates to support the dog walking app's
//  home screen features.
//
//  ----------------------------------------------------------------------------------
//  JSON Specification Requirements Addressed:
//    • Real-time availability, instant matching, and schedule management (Core Features).
//    • Service execution with battery-optimized GPS tracking, photo sharing, and status updates.
//    • Native iOS MVVM architecture, offline-first with background location services.
//    • Comprehensive error handling, thread-safe state management, and Combine-based reactivity.
//
//  ----------------------------------------------------------------------------------

import Foundation       // Foundation (iOS 13.0+), for threading, data types
import Combine         // Combine (iOS 13.0+), for reactive publishers/subscribers
import CoreLocation    // CoreLocation (iOS 13.0+), for location services

// Internal imports from the project, per JSON specification
import Core_Base_BaseViewModel        // Imported as "BaseViewModel" from: src/ios/DogWalking/Core/Base/BaseViewModel.swift
import Domain_Models_Walk             // Imported as "Walk" from: src/ios/DogWalking/Domain/Models/Walk.swift
import Domain_UseCases_WalkUseCase    // Imported as "WalkUseCase" from: src/ios/DogWalking/Domain/UseCases/WalkUseCase.swift
import Services_LocationService       // Imported as "LocationService" from: src/ios/DogWalking/Services/LocationService.swift

/// @MainActor ensures that all UI-bound operations happen on the main thread.
/// This class inherits from `BaseViewModel`, which provides loading/error state
/// management, thread safety, and Combine cancellable handling.
@MainActor
public final class HomeViewModel: BaseViewModel {

    // MARK: - Dependencies & State

    /// A reference to the walk use case, providing walk lifecycle operations (schedule, start, end).
    public let walkUseCase: WalkUseCase

    /// A reference to the location service, handling battery-optimized location tracking.
    public let locationService: LocationService

    /// Publishes the currently active walk for real-time UI updates. May be nil if no active walk.
    public let activeWalkSubject: CurrentValueSubject<Walk?, Never>

    /// Publishes the list of nearby walks (or walk opportunities) for the home screen display.
    public let nearbyWalksSubject: CurrentValueSubject<[Walk], Never>

    /// Publishes the current user location, if available, for map display and query filtering.
    public let currentLocationSubject: CurrentValueSubject<CLLocation?, Never>

    /// A set of Combine cancellables retained for any asynchronous pipelines associated with this view model.
    public var cancellables: Set<AnyCancellable>

    /// A dedicated dispatch queue for thread-safe state updates, ensuring we avoid race conditions.
    public let stateQueue: DispatchQueue

    /// Tracks the current location accuracy profile, reflecting battery usage vs. precision.
    public var currentAccuracyProfile: LocationAccuracyProfile

    // MARK: - Initialization

    /// Initializes the HomeViewModel with required dependencies, thread safety, location configuration,
    /// and reactive error handling. Inherits error/loading subjects from BaseViewModel.
    ///
    /// Steps:
    ///  1. Call super.init() for BaseViewModel setup.
    ///  2. Store walkUseCase and locationService references.
    ///  3. Initialize thread-safe subjects (activeWalkSubject, nearbyWalksSubject, currentLocationSubject).
    ///  4. Create a dedicated dispatch queue for state updates.
    ///  5. Set an initial accuracy profile to .balanced for moderate battery usage.
    ///  6. Initialize a cancellables set for Combine subscriptions.
    ///  7. Optionally set up location tracking or error handling logic (retry, etc.).
    ///
    /// - Parameters:
    ///   - walkUseCase: The business logic object for scheduling/starting/ending walks.
    ///   - locationService: The battery-optimized location manager for real-time or background updates.
    public init(walkUseCase: WalkUseCase,
                locationService: LocationService) {
        // 1. Perform base class initialization (loads isLoadingSubject, errorSubject, etc.).
        super.init()

        // 2. Store references to actual dependencies.
        self.walkUseCase = walkUseCase
        self.locationService = locationService

        // 3. Initialize our thread-safe subjects with default values.
        self.activeWalkSubject = CurrentValueSubject<Walk?, Never>(nil)
        self.nearbyWalksSubject = CurrentValueSubject<[Walk], Never>([])
        self.currentLocationSubject = CurrentValueSubject<CLLocation?, Never>(nil)

        // 4. Create a dispatcher for state updates. We can use a serial or concurrent queue.
        //    The JSON calls for "Create serial queue for state updates," but a label is enough.
        self.stateQueue = DispatchQueue(label: "com.dogwalking.homeviewmodel.stateQueue")

        // 5. Set an initial accuracy profile, from .balanced or .lowPower, etc.
        self.currentAccuracyProfile = .balanced

        // 6. Initialize a blank cancellables set.
        self.cancellables = Set<AnyCancellable>()

        // 7. (Optional) Additional configuration or error handling setup can be done here.
        //    For instance, we can set up location or error subscriptions.
    }

    // MARK: - Public Functions

    /// Starts a scheduled walk session with real-time location tracking and updates the active walk state.
    ///
    /// Steps:
    ///  1. Ensure we operate on our stateQueue for thread safety.
    ///  2. Set the loading state to true.
    ///  3. Invoke `walkUseCase.startWalk(walkId:)` with retry logic as needed.
    ///  4. Configure high-accuracy location tracking by updating `currentAccuracyProfile`.
    ///  5. Start location updates in the location service, passing .highAccuracy.
    ///  6. Publish the newly started walk to `activeWalkSubject` upon success.
    ///  7. Handle any errors, set loading to false, and pass the error to the base errorSubject.
    ///  8. Return an `AnyPublisher<Walk, Error>` that completes once the walk is fully started.
    ///
    /// - Parameter walkId: A UUID identifying the walk to start.
    /// - Returns: A publisher emitting the active `Walk` object or an error.
    public func startWalk(walkId: UUID) -> AnyPublisher<Walk, Error> {
        return Future<Walk, Error> { [weak self] promise in
            guard let self = self else { return }
            self.stateQueue.async {
                // Step 2. Indicate loading.
                self.setLoading(true)

                // Step 3. Call walkUseCase.startWalk
                let startPublisher = self.walkUseCase.startWalk(walkId: walkId)
                    .flatMap { startedWalk -> AnyPublisher<Walk, Error> in
                        // Step 4. Configure high accuracy location
                        self.currentAccuracyProfile = .highAccuracy

                        // Step 5. Start location updates (battery-optimized).
                        return self.locationService.startWalkTracking(walkId: walkId, accuracyProfile: .highAccuracy)
                            .first() // wait for at least one location event to confirm tracking started
                            .mapError { $0 as Error }
                            .map { _ in startedWalk }
                            .eraseToAnyPublisher()
                    }
                    .handleEvents(receiveCompletion: { completion in
                        // On completion, loading can be turned off if an error occurs or finishing.
                        switch completion {
                        case .failure:
                            self.setLoading(false)
                        case .finished:
                            break
                        }
                    })
                    .eraseToAnyPublisher()

                // Sink to finalize and pass result back
                let sinkRef = startPublisher.sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            self.handleError(error)
                            promise(.failure(error))
                        case .finished:
                            break
                        }
                        // Ensure we do not remain in loading state if there's a failure
                        // or if we've already updated the state after success.
                    },
                    receiveValue: { startedWalk in
                        // Step 6. Publish to activeWalkSubject
                        self.stateQueue.async {
                            self.activeWalkSubject.value = startedWalk
                        }
                        // Step 7. End loading and confirm success
                        self.setLoading(false)
                        promise(.success(startedWalk))
                    }
                )

                self.cancellables.insert(sinkRef)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Safely ends the current active walk session, stops location tracking, and returns the completed walk.
    ///
    /// Steps:
    ///  1. Operate on stateQueue for thread safety.
    ///  2. Set loading state to true.
    ///  3. Invoke `walkUseCase.endWalk()` with error handling and retry if needed.
    ///  4. Stop location tracking in locationService.
    ///  5. Reset location accuracy profile to .balanced or a default.
    ///  6. Clear the activeWalkSubject, setting it to nil.
    ///  7. Handle errors and finalize loading states.
    ///  8. Return a publisher emitting the ended `Walk` object or an error.
    ///
    /// - Returns: A publisher emitting the completed `Walk` or failing on error.
    public func endWalk() -> AnyPublisher<Walk, Error> {
        return Future<Walk, Error> { [weak self] promise in
            guard let self = self else { return }
            self.stateQueue.async {
                self.setLoading(true)

                // Step 3. Use walkUseCase to end the current walk
                let endPublisher = self.walkUseCase.endWalk()
                    .handleEvents(receiveOutput: { _ in
                        // Step 4. Stop location tracking
                        self.locationService.stopWalkTracking()
                        // Step 5. Reset accuracy
                        self.currentAccuracyProfile = .balanced
                    })
                    .eraseToAnyPublisher()

                let sinkRef = endPublisher.sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            self.handleError(error)
                            self.setLoading(false)
                            promise(.failure(error))
                        case .finished:
                            break
                        }
                    },
                    receiveValue: { endedWalk in
                        // Step 6. Clear active walk subject
                        self.stateQueue.async {
                            self.activeWalkSubject.value = nil
                        }
                        // Step 7. Final loading state
                        self.setLoading(false)
                        promise(.success(endedWalk))
                    }
                )

                self.cancellables.insert(sinkRef)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Thread-safe refresh of nearby walks to display real-time availability on the home screen.
    ///
    /// Steps:
    ///  1. Set loading state to true with thread safety.
    ///  2. Retrieve current location from `currentLocationSubject`.
    ///  3. Perform a fetch of nearby walks (placeholder) via the domain or service layer.
    ///  4. Filter and sort the results by proximity.
    ///  5. Update `nearbyWalksSubject` on the serial queue.
    ///  6. Handle errors gracefully, possibly with retry logic.
    ///  7. End loading state.
    ///
    /// In a real implementation, you'd likely call an actual method on walkUseCase or a separate
    /// "NearbyWalksUseCase" to get walk listings from a server or local DB. This example uses
    /// placeholders to demonstrate structure.
    public func refreshNearbyWalks() {
        self.stateQueue.async {
            self.setLoading(true)

            // Step 2. Get current location for reference
            guard let userLocation = self.currentLocationSubject.value else {
                // If no location available, we cannot fetch. End loading, do nothing or handle error.
                self.setLoading(false)
                return
            }

            // Step 3. A placeholder publisher simulating a fetch of walks near userLocation
            // For demonstration, create an immediate success with an empty array or random data.
            let placeholderNearbyWalksPublisher = Future<[Walk], Error> { promise in
                // Simulate a small network or local DB fetch
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    // For demonstration, return an empty array
                    promise(.success([]))
                }
            }
            .eraseToAnyPublisher()

            let sinkRef = placeholderNearbyWalksPublisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        // Step 6. Handle errors: we can forward to handleError
                        self.handleError(error)
                        self.setLoading(false)
                    case .finished:
                        break
                    }
                },
                receiveValue: { newWalks in
                    // Step 4. Filter/sort by proximity. (Here newWalks is empty, so skip.)
                    let sortedWalks = newWalks.sorted { a, b -> Bool in
                        // If there was location data in Walk, we could compare distance from userLocation
                        return a.id.uuidString < b.id.uuidString
                    }

                    // Step 5. Update subject
                    self.stateQueue.async {
                        self.nearbyWalksSubject.value = sortedWalks
                    }
                    // Step 7. End loading
                    self.setLoading(false)
                }
            )

            self.cancellables.insert(sinkRef)
        }
    }

    /// Configures and initiates battery-optimized location tracking for the home screen,
    /// requesting user permissions, subscribing to location updates, handling errors,
    /// and managing background location usage as needed.
    ///
    /// Steps:
    ///  1. Request location permission from the locationService.
    ///  2. Assign or configure the currentAccuracyProfile as needed.
    ///  3. Subscribe to location updates with battery optimization considerations.
    ///  4. On location changes, update `currentLocationSubject` on the state queue.
    ///  5. Handle location authorization changes or errors with fallback options.
    ///  6. Enable background mode if the specification requires (placeholder).
    ///  7. React to errors by calling `handleError(_:)`.
    public func setupLocationTracking() {
        // Step 1. Request location permission
        locationService.requestLocationPermission()
            .sink { completion in
                if case let .failure(locationError) = completion {
                    // Step 7. Call handleError for location issues
                    self.handleError(locationError)
                }
            } receiveValue: { isGranted in
                if isGranted {
                    // Step 2. We can set an initial profile or keep the default.
                    self.currentAccuracyProfile = .balanced

                    // Step 3. We subscribe to locationService's indefinite location updates for the home screen.
                    //         Actually, locationService sets up publishers internally. We can demonstrate
                    //         a subscription to sync currentLocationSubject automatically.
                    self.bind(self.locationService.locationUpdates
                        .mapError { $0 as Error }
                        .receive(on: DispatchQueue.main) // ensure UI receives updates on main
                    ).sink(
                        receiveCompletion: { completion in
                            if case let .failure(err) = completion {
                                self.handleError(err)
                            }
                        },
                        receiveValue: { newLocation in
                            // Step 4. Update subject on stateQueue (then forward to main queue or keep it).
                            self.stateQueue.async {
                                self.currentLocationSubject.value = newLocation
                            }
                        }
                    )
                } else {
                    // Permission denied or restricted
                    self.handleError(LocationServiceError.unauthorized)
                }
            }
            .store(in: &cancellables)

        // Step 6. If the specification demanded background mode, we could call some method in locationService.
        // For demonstration, we skip it or treat locationService as the manager.
    }
}