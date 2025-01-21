//
//  MockLocationService.swift
//  DogWalkingTests
//
//  Created by Enterprise-Ready AI on 2023-10-01.
//
//  An enhanced mock implementation of a LocationService-like construct for testing
//  location tracking functionality within the DogWalking application. This class
//  provides controlled simulation of location data, permission handling, error
//  scenarios, and permission states, offering a comprehensive foundation for
//  end-to-end or unit testing.
//
//  -----------------------------------------------------------------------------
//  EXTERNAL IMPORTS (IE2)
//  -----------------------------------------------------------------------------
import Foundation          // iOS 13.0+ (Core language/framework features)
import Combine            // iOS 13.0+ (Reactive programming support)
import XCTest             // iOS 13.0+ (Testing framework integration)

//
//  -----------------------------------------------------------------------------
//  INTERNAL IMPORTS (IE1)
//  -----------------------------------------------------------------------------
//  These imports reference code within the DogWalking module. Adjust to your
//  real project/module import paths as necessary. The JSON specification
//  indicates the requirement to use certain members from “Location.swift” and a
//  “LocationService” definition.
//
//  NOTE: In this mock, we only require the ability to create or handle Location
//  instances, calling fromCLLocation(_:) and distanceTo(_:) if needed. The real
//  production "LocationService.swift" in the project is not a protocol, but for
//  testability, we treat it as if we are conforming to a minimal interface. The
//  actual protocol or base class need not exist if you are purely injecting
//  this mock into your test environment.
//
//  Replace these commented imports with the correct statements for your setup.
//
//  import class DogWalking.Domain.Models.Location         // For 'Location'
//  import protocol DogWalking.Services.LocationService    // If a protocol is defined
//
//  For demonstration, we assume these references are resolved properly.
//
import class DogWalking.Domain.Models.Location

//
//  -----------------------------------------------------------------------------
//  MOCK-SPECIFIC ENUMS & ERRORS
//  -----------------------------------------------------------------------------
//  We define a small set of states and error types to satisfy advanced testing
//  requirements such as simulating denied permissions or forced error injection.
//

/// Represents the possible mock permission states for testing.
public enum LocationPermissionState {
    /// The permission state has not been determined (user has not yet been prompted).
    case notDetermined

    /// The system or user has denied location access.
    case denied

    /// The user has granted location access (authorized).
    case authorized
}

/// Represents potential errors thrown or published by MockLocationService in
/// various simulated scenarios.
public enum MockLocationServiceError: Error {
    /// Permission has been denied or is otherwise invalid.
    case permissionDenied

    /// Simulated timeout while requesting permission.
    case permissionRequestTimeout

    /// Start tracking was invoked without valid permission being granted.
    case trackingNotAuthorized

    /// A generic simulation to indicate forced or triggered test failures.
    case simulatedFailure(String)
}

/// A final mock class to simulate behavior of a location service in the
/// DogWalking application. This includes permission requests, real-time tracking
/// mechanics, route retrieval, distance calculations, and robust error injection
/// for test scenarios.
public final class MockLocationService {

    // -------------------------------------------------------------------------
    // MARK: - Published Properties (LD1: Detailed)
    // -------------------------------------------------------------------------
    // Below properties replicate or mock the shape of an actual LocationService
    // so that test scenarios can subscribe and verify location-tracking behavior.

    /// A reactive subject indicating whether walk tracking is active.
    /// This property mirrors a typical `isTracking` variable in production code.
    public let isTracking: CurrentValueSubject<Bool, Never>

    /// A subject that publishes mock `Location` items or errors as they occur,
    /// mimicking real-time updates from a GPS-based location service.
    public let locationUpdates: PassthroughSubject<Location, Error>

    /// An array of mock `Location` objects that this service will emit
    /// during a simulated walk tracking session or route queries.
    private var mockLocations: [Location]

    /// A Boolean flag indicating whether to simulate errors (e.g., permission
    /// denial or random streaming errors) during test runs.
    private var shouldSimulateError: Bool

    /// A simulated permission state, allowing tests to verify behavior when
    /// permission is authorized, denied, or not determined.
    private var mockPermissionState: LocationPermissionState

    /// A configurable delay (in seconds) applied to certain operations or
    /// publishers. This helps emulate real-world latency, network lag, or
    /// asynchronous permission prompts.
    private var simulatedDelay: TimeInterval

    /// A set of Combine cancellable references to manage any ongoing timers,
    /// publishers, or asynchronous tasks, ensuring memory is cleaned up
    /// properly when tests complete or tracking stops.
    private var cancellables: Set<AnyCancellable>

    // -------------------------------------------------------------------------
    // MARK: - Initialization (LD2: Full Implementation)
    // -------------------------------------------------------------------------
    /**
     Initializes a new instance of `MockLocationService` with configurable test
     parameters.
     
     - Parameters:
       - mockLocations:      Array of `Location` objects to simulate real-time
                             updates or route data.
       - shouldSimulateError: Flag to trigger forced error scenarios.
       - initialPermissionState: The initial permission state for location usage
                                 (e.g., `.authorized`, `.denied`, `.notDetermined`).
       - simulatedDelay:     A delay (in seconds) applied to mimic real processing,
                             network requests, or system responsiveness.

     - Steps:
       1. Initialize the `isTracking` state subject to `false`.
       2. Initialize the `locationUpdates` subject for streaming location events.
       3. Store the provided array of mock locations.
       4. Set the error simulation flag.
       5. Set the initial permission state.
       6. Configure simulated network or processing delay.
       7. Initialize the Combine cancellables set.
    */
    public init(
        mockLocations: [Location],
        shouldSimulateError: Bool,
        initialPermissionState: LocationPermissionState,
        simulatedDelay: TimeInterval
    ) {
        // 1. Initialize the tracking state to false for a fresh session.
        self.isTracking = CurrentValueSubject<Bool, Never>(false)

        // 2. Prepare the subject that will broadcast location updates to tests.
        self.locationUpdates = PassthroughSubject<Location, Error>()

        // 3. Store the mock locations for use in tracking or route requests.
        self.mockLocations = mockLocations

        // 4. Configure whether we should inject errors during calls.
        self.shouldSimulateError = shouldSimulateError

        // 5. Assign the provided initial permission state.
        self.mockPermissionState = initialPermissionState

        // 6. Set the simulated delay (artificial latency in functions or streams).
        self.simulatedDelay = simulatedDelay

        // 7. Initialize a fresh empty set to track Combine subscriptions.
        self.cancellables = Set<AnyCancellable>()
    }

    // -------------------------------------------------------------------------
    // MARK: - Public Method: requestLocationPermission (LD2: Detailed Steps)
    // -------------------------------------------------------------------------
    /**
     Simulates requesting location permission from the user, returning a
     publisher that either emits a Boolean (indicating granted or not) or fails
     with an error if configured to simulate a timeout or forced denial.

     - Returns: An `AnyPublisher<Bool, Error>` representing the asynchronous
                result of the permission request.

     - Steps:
       1. Check the current `mockPermissionState`.
       2. Introduce a simulated processing delay if `simulatedDelay` > 0.
       3. If permission is `.authorized`, publish `true`.
       4. If permission is `.denied` and `shouldSimulateError` is true, fail
          with `.permissionDenied`, else publish `false`.
       5. If permission is `.notDetermined`, optionally fail with `.permissionRequestTimeout`
          if error injection is desired, or else publish `false`.
       6. Provide a means to handle timeouts or forced error injection.
    */
    public func requestLocationPermission() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let strongSelf = self else { return }

            // Simulate real-world async with an artificial delay, then proceed:
            DispatchQueue.main.asyncAfter(deadline: .now() + strongSelf.simulatedDelay) {
                switch strongSelf.mockPermissionState {
                case .authorized:
                    // Step 3: Publish `true` to indicate granted permission.
                    promise(.success(true))

                case .denied:
                    // Step 4: If simulating error, fail with .permissionDenied
                    if strongSelf.shouldSimulateError {
                        promise(.failure(MockLocationServiceError.permissionDenied))
                    } else {
                        // Otherwise, simply indicate that it is denied (false).
                        promise(.success(false))
                    }

                case .notDetermined:
                    // Step 5 & 6: We can simulate a timeout if requested,
                    // or default to not granted. Here we show an error if configured:
                    if strongSelf.shouldSimulateError {
                        promise(.failure(.permissionRequestTimeout))
                    } else {
                        promise(.success(false))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // -------------------------------------------------------------------------
    // MARK: - Public Method: startWalkTracking
    // -------------------------------------------------------------------------
    /**
     Initiates simulated walk tracking for a specific walk ID, returning a
     publisher that emits `Location` values in sequence. The method also handles
     permission checks, error injection, and updates the `isTracking` state
     accordingly.

     - Parameter walkId: The UUID representing the walk session under test.
     - Returns: A publisher streaming zero or more `Location` updates and then
               completing or failing with an error.

     - Steps:
       1. Validate the current permission state.
       2. If not authorized and `shouldSimulateError` is true, publish an error.
       3. If authorized, set `isTracking` to `true`.
       4. Emit mock locations over time, using `simulatedDelay` between each.
       5. If `shouldSimulateError` is set, insert an error mid-stream or after a few updates.
       6. Manage the publisher lifecycle and store subscriptions in `cancellables`.
    */
    public func startWalkTracking(walkId: UUID) -> AnyPublisher<Location, Error> {
        // Defer creation of the publisher until subscription time, ensuring
        // fresh checks and side effects for each subscriber.
        return Deferred { [weak self] () -> AnyPublisher<Location, Error> in
            guard let strongSelf = self else {
                return Fail<Location, Error>(error: MockLocationServiceError.simulatedFailure("Mock is deinitialized."))
                    .eraseToAnyPublisher()
            }

            // 1 & 2: Check permission; if not authorized and error injection is on, fail.
            if strongSelf.mockPermissionState != .authorized {
                if strongSelf.shouldSimulateError {
                    return Fail<Location, Error>(error: MockLocationServiceError.trackingNotAuthorized)
                        .eraseToAnyPublisher()
                } else {
                    // Return an empty stream if we can't track.
                    return Empty<Location, Error>(completeImmediately: true).eraseToAnyPublisher()
                }
            }

            // 3. Set isTracking to true now that we are starting a track.
            strongSelf.isTracking.send(true)

            // 4 & 5: Setup a pipeline that emits each mock location after a delay.
            //    We use a sequence publisher to read from the stored array:
            let locationPublisher = Publishers.Sequence(sequence: strongSelf.mockLocations)
                .flatMap { location -> AnyPublisher<Location, Error> in
                    // Publish each location after a simulated wait:
                    return Just(location)
                        .delay(for: .seconds(strongSelf.simulatedDelay), scheduler: DispatchQueue.main)
                        .tryMap { emittedLocation in
                            // If the user has toggled error mid-stream, fail forcibly.
                            if strongSelf.shouldSimulateError {
                                throw MockLocationServiceError.simulatedFailure("Forced error mid-tracking.")
                            }
                            return emittedLocation
                        }
                        .mapError { $0 as Error }
                        .eraseToAnyPublisher()
                }
                .handleEvents(
                    receiveOutput: { loc in
                        // Feed each location to the locationUpdates subject as well.
                        strongSelf.locationUpdates.send(loc)
                    },
                    receiveCompletion: { _ in
                        // On completion, set isTracking to false automatically.
                        strongSelf.isTracking.send(false)
                    }
                )
                .eraseToAnyPublisher()

            // 6. Return the final publisher. The subscriber is responsible for
            //    chain completion or cancellation, which we can capture in `cancellables`.
            return locationPublisher
        }
        .eraseToAnyPublisher()
    }

    // -------------------------------------------------------------------------
    // MARK: - Public Method: stopWalkTracking
    // -------------------------------------------------------------------------
    /**
     Terminates the simulated walk tracking by:
       - Setting `isTracking` to `false`.
       - Canceling all active Combine subscriptions.
       - Clearing temporary data from memory.
       - Resetting error simulation flags.
       - Performing any final memory cleanup required for testing.

     - Steps:
       1. Update the tracking state to `false`.
       2. Cancel all active Combine publishers/subscriptions.
       3. Clear out `mockLocations` or other ephemeral data if desired.
       4. Reset `shouldSimulateError` to `false`.
       5. Perform final memory cleanup or state resets.
    */
    public func stopWalkTracking() {
        // 1. Immediately signal that tracking should be considered inactive.
        isTracking.send(false)

        // 2. Cancel all active publishers to halt any location emission pipeline.
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // 3. Optionally clear out the mockLocations array for a fresh test start.
        mockLocations.removeAll()

        // 4. Reset the forced error scenario, so subsequent tests start fresh.
        shouldSimulateError = false

        // 5. Any custom memory cleanup or state resets would go here.
        //    For demonstration, we have none beyond clearing arrays and flags.
    }

    // -------------------------------------------------------------------------
    // MARK: - Public Method: getWalkRoute
    // -------------------------------------------------------------------------
    /**
     Retrieves a simulated walk route for the specified walk ID, applying an
     artificial delay, error injection if configured, and returning the
     `mockLocations` as the perceived route data.

     - Parameter walkId: A UUID identifying the targeted walk session.
     - Returns: A publisher emitting an array of `Location` objects or an error.

     - Steps:
       1. Validate the walk ID (in an actual system, track known active IDs).
       2. Apply the simulated network/processing delay.
       3. If `shouldSimulateError` is true, fail with an error.
       4. Otherwise, return the `mockLocations` array as the route data.
    */
    public func getWalkRoute(walkId: UUID) -> AnyPublisher<[Location], Error> {
        return Deferred { [weak self] () -> AnyPublisher<[Location], Error> in
            guard let strongSelf = self else {
                return Fail<[Location], Error>(error: MockLocationServiceError.simulatedFailure("Mock is deinitialized."))
                    .eraseToAnyPublisher()
            }

            return Future<[Location], Error> { promise in
                // 2. Wait for the simulated delay (e.g., network or DB fetch).
                DispatchQueue.main.asyncAfter(deadline: .now() + strongSelf.simulatedDelay) {
                    // 3. If error injection is on, fail:
                    if strongSelf.shouldSimulateError {
                        promise(.failure(MockLocationServiceError.simulatedFailure("Forced error in getWalkRoute.")))
                        return
                    }

                    // 1 & 4. For demonstration, we do not check the actual walkId deeply,
                    //        we simply return all `mockLocations`.
                    promise(.success(strongSelf.mockLocations))
                }
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    // -------------------------------------------------------------------------
    // MARK: - Public Method: calculateWalkDistance
    // -------------------------------------------------------------------------
    /**
     Calculates the total distance (in meters) across a given array of `Location`
     points. Applies filtering of invalid coordinates, point-to-point distance
     summation, and any domain-specific validation rules.

     - Parameter locations: The array of `Location` items representing a route or
                           segment to measure.
     - Returns: A `Double` indicating the total valid distance in meters.

     - Steps:
       1. Validate the location data (remove invalid coordinate points).
       2. Filter or skip any out-of-range lat/long.
       3. Calculate point-to-point distances in sequence, ensuring non-negative sums.
       4. Return the final aggregated distance.
    */
    public func calculateWalkDistance(_ locations: [Location]) -> Double {
        // 1 & 2. Filter out any location whose latitude or longitude is out of valid range.
        let validLocations = locations.filter { loc in
            loc.latitude >= -90.0 && loc.latitude <= 90.0 &&
            loc.longitude >= -180.0 && loc.longitude <= 180.0
        }

        // If we have fewer than 2 locations, distance is trivially 0.
        guard validLocations.count > 1 else {
            return 0.0
        }

        // 3. Reduce the array by summing distances from point[i] to point[i+1].
        var totalDistance: Double = 0.0
        for i in 0..<(validLocations.count - 1) {
            let currentPoint = validLocations[i]
            let nextPoint = validLocations[i + 1]

            // Use the built-in distanceTo(_:) from the Location model.
            let segment = currentPoint.distanceTo(nextPoint)
            totalDistance += max(0.0, segment)
        }

        // 4. Return the final aggregated distance.
        return totalDistance
    }
}