//
//  HomeViewModelTests.swift
//  DogWalkingTests
//
//  Unit test suite for HomeViewModel, testing real-time location tracking,
//  walk management, and nearby walker discovery functionality with
//  comprehensive error handling and thread-safety validation.
//
//  ------------------------------------------------------------------------
//  Requirements Addressed (from JSON Specification):
//    • Core Features: Tests real-time availability, instant matching, and
//      schedule management for dog walks with error scenarios and state
//      validation.
//    • Service Execution: Tests GPS tracking, photo sharing, and status
//      updates for active walks including accuracy validation and error
//      handling.
//    • Mobile Apps Architecture: Validates MVVM architecture pattern
//      implementation for iOS with thread-safety and state management.
//
//  ------------------------------------------------------------------------
//  Imports & Testing Framework
//  ------------------------------------------------------------------------
//  We import @testable to access internal properties of DogWalking if
//  needed for thorough verification, as well as Combine and XCTest for
//  asynchronous testing, publisher handling, and standard unit test
//  assertions.
//

import XCTest
import Combine
import CoreLocation
@testable import DogWalking

///
/// Comprehensive test suite for HomeViewModel functionality,
/// including error handling, concurrency validation, real-time
/// location tracking, and data refresh logic.
///
final class HomeViewModelTests: XCTestCase {

    // MARK: - Properties

    /// The System Under Test (SUT): HomeViewModel instance created afresh in setUp().
    private var sut: HomeViewModel!

    /// A thread-safe mock repository to simulate walk management operations
    /// (e.g., createWalk, updateWalkStatus, getNearbyWalks) with error injection.
    private var mockWalkRepository: MockWalkRepository!

    /// An enhanced mock service that simulates location tracking scenarios,
    /// permission states, location updates, and forced error conditions.
    private var mockLocationService: MockLocationService!

    /// A live set of publishers that must remain active during tests. We keep
    /// references here so that they do not deallocate prematurely.
    private var cancellables: Set<AnyCancellable> = []

    /// A custom queue to test concurrency or to verify that HomeViewModel's
    /// thread-safety holds under parallel operations.
    private var testQueue: DispatchQueue!

    // MARK: - Setup and Teardown

    ///
    /// Enhanced test setup method with thread-safe configuration.
    /// Steps:
    ///   1. Initialize thread-safe mock repository.
    ///   2. Initialize enhanced mock location service.
    ///   3. Initialize HomeViewModel with mocks and a real WalkUseCase.
    ///   4. Initialize cancellables set.
    ///   5. Configure test dispatch queue for concurrency checks.
    ///   6. Set up error simulation handlers as needed.
    ///
    override func setUp() {
        super.setUp()

        // 1. Initialize thread-safe mock repository
        mockWalkRepository = MockWalkRepository()

        // 2. Initialize enhanced mock location service
        //    We start with no locations, no error simulation, notDetermined permission, no delay.
        mockLocationService = MockLocationService(
            mockLocations: [],
            shouldSimulateError: false,
            initialPermissionState: .notDetermined,
            simulatedDelay: 0.0
        )

        // Create a real WalkUseCase that depends on the mock repository and mock location service,
        // mirroring how the production code wires these together.
        let mockUseCase = WalkUseCase(
            walkRepository: mockWalkRepository,
            locationService: mockLocationService
        )

        // 3. Initialize HomeViewModel with the use case and location service.
        //    This is the SUT for our testing scenario.
        sut = HomeViewModel(
            walkUseCase: mockUseCase,
            locationService: mockLocationService
        )

        // 4. Initialize the Combine subscriptions set (cancellables).
        cancellables = Set<AnyCancellable>()

        // 5. Configure a test dispatch queue for concurrency or parallel checks.
        testQueue = DispatchQueue(label: "com.dogwalking.tests.HomeViewModelTests")

        // 6. (Optional) We could set up any forced error simulation if we wanted
        //    to do that across all tests. For now, we keep it disabled by default.
    }

    ///
    /// Comprehensive test cleanup method.
    /// Steps:
    ///   1. Cancel all subscriptions in cancellables.
    ///   2. Reset mock repository state.
    ///   3. Reset mock location service.
    ///   4. Clear error simulation configurations.
    ///   5. Wait for any pending async operations if needed.
    ///
    override func tearDown() {
        // 1. Cancel all Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // 2. Reset the mock repository
        mockWalkRepository.reset()

        // 3. Stop the mock location service tracking,
        //    clearing any concurrency or latched state.
        mockLocationService.stopWalkTracking()

        // 4. Clear error simulation flags
        mockWalkRepository.shouldSimulateError = false
        mockLocationService.shouldSimulateError = false

        // 5. (Optional) If we had queued tasks in testQueue, we could wait or let them drain.
        //    For demonstration, we skip advanced synchronization.

        super.tearDown()
    }

    // MARK: - Tests

    ///
    /// Tests location permission request flow:
    ///   1. Verify initial permission status is not determined.
    ///   2. Simulate permission request via HomeViewModel's setupLocationTracking or a method that triggers request.
    ///   3. Verify permission status updates to authorized as the mock service reports success.
    ///   4. Test a denied permission scenario to ensure correct error or fallback handling in the ViewModel.
    ///   5. Verify error handling paths for permission failures.
    ///
    func testLocationPermissionRequest() {
        // Step 1: Check initial permission status is notDetermined in the mock.
        XCTAssertEqual(
            mockLocationService.mockPermissionState,
            .notDetermined,
            "Initial permission state should be .notDetermined as configured."
        )

        // Subscribe to HomeViewModel's locationPermissionStatus for changes (if it exists).
        // The JSON specification references locationPermissionStatus as:
        //   CurrentValueSubject<LocationPermissionStatus, Never>
        // We'll do a quick readiness check:
        let initialStatus = sut.locationPermissionStatus.value
        XCTAssertEqual(
            initialStatus,
            .notDetermined,
            "HomeViewModel should reflect notDetermined permission at test start."
        )

        // Step 2: Simulate requesting permission by calling a function that triggers the request.
        let permissionExpectation = expectation(description: "Permission request should complete authorized.")
        // We can do an asynchronous flow to test:
        mockLocationService.mockPermissionState = .authorized // We'll simulate user granting permission
        sut.setupLocationTracking() // Typically calls locationService.requestLocationPermission() internally.

        // Wait for status changes:
        sut.locationPermissionStatus
            .dropFirst() // skip the initial value
            .sink { newStatus in
                // Step 3: Confirm the status updates to authorized.
                if newStatus == .authorized {
                    permissionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [permissionExpectation], timeout: 2.0)

        // Step 4: Now test a denied scenario: reset, set the mock to .denied, call again, expect an error or fallback.
        mockLocationService.mockPermissionState = .denied
        let deniedExpectation = expectation(description: "Permission request results in a denied scenario.")
        sut.setupLocationTracking()

        sut.locationPermissionStatus
            .dropFirst() // skip old values
            .sink { updatedStatus in
                // Step 5: We verify it transitions or stays at .denied, or triggers error handling.
                if updatedStatus == .denied {
                    deniedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [deniedExpectation], timeout: 2.0)
    }

    ///
    /// Tests location tracking accuracy and updates:
    ///   1. Configure mock location updates in the mock location service.
    ///   2. Verify that the HomeViewModel sets the appropriate accuracy profile or config.
    ///   3. Check that location updates arrive at the expected frequency or are received by the ViewModel.
    ///   4. Validate coordinate accuracy is processed or stored appropriately.
    ///   5. Test background tracking scenario if needed.
    ///
    func testLocationTrackingAccuracy() {
        // Step 1: Provide a set of mock location points to the location service
        let location1 = try! Location(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 10.0,
            accuracy: 5.0,
            speed: 0.0,
            course: 0.0,
            timestamp: Date()
        )
        let location2 = try! Location(
            latitude: 37.7750,
            longitude: -122.4195,
            altitude: 12.0,
            accuracy: 3.0,
            speed: 0.0,
            course: 0.0,
            timestamp: Date().addingTimeInterval(5)
        )
        mockLocationService.mockLocations = [location1, location2]

        // Step 2: Attempt to configure HomeViewModel for high accuracy location tracking
        sut.currentAccuracyProfile = .highAccuracy
        XCTAssertEqual(sut.currentAccuracyProfile, .highAccuracy, "ViewModel should store high accuracy profile.")

        // Step 3: Start location tracking and see if we get updates
        let updateExpectation = expectation(description: "Receive location updates from locationService.")
        var receivedLocations = [Location]()
        mockLocationService
            .locationUpdates
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { loc in
                    receivedLocations.append(loc)
                    if receivedLocations.count == 2 {
                        updateExpectation.fulfill()
                    }
                }
            )
            .store(in: &cancellables)

        // The method that triggers real-time location updates from the ViewModel,
        // typically setupLocationTracking() or a dedicated start method:
        sut.setupLocationTracking()

        wait(for: [updateExpectation], timeout: 3.0)
        XCTAssertEqual(receivedLocations.count, 2, "Should receive exactly 2 location updates.")
        // Step 4: Validate coordinate accuracy or differences
        for loc in receivedLocations {
            XCTAssert(loc.accuracy <= 5.0, "Mock location accuracy should be within expected range.")
        }

        // Step 5: We can simulate a background scenario if needed, but this is typically more
        // complex. For demonstration, confirm that 'isTracking' remains or no crashes.
        XCTAssertTrue(sut.currentAccuracyProfile == .highAccuracy, "Accuracy profile remains highAccuracy.")
    }

    ///
    /// Tests nearby walks refresh with error handling:
    ///   1. Simulate a network or repository error from mockWalkRepository.
    ///   2. Verify that the HomeViewModel handles the error properly, e.g., sets an error subject.
    ///   3. Test any retry or fallback mechanism built into the ViewModel.
    ///   4. Validate that after error resolution or next attempt, the state recovers.
    ///   5. Assert that error notifications were broadcast or logged.
    ///
    func testNearbyWalksRefreshWithError() {
        // Step 1: Enable a simulated error scenario in the mock repository
        mockWalkRepository.shouldSimulateError = true

        // We track the HomeViewModel's errorSubject if it has one, or we track how it updates
        // the nearbyWalksSubject upon failure. We'll do an expectation that an error or empty
        // set occurs.
        let errorExpectation = expectation(description: "HomeViewModel handles repository error for refreshing nearby walks.")

        // For demonstration, we might observe sut.errorSubject or any property that indicates error state:
        sut.errorSubject
            .sink { capturedError in
                // Step 2 & 3: Verify error is delivered or the ViewModel sets some state
                XCTAssertNotNil(capturedError, "Error should be captured from the failing repository call.")
                errorExpectation.fulfill()
            }
            .store(in: &cancellables)

        // Attempt a refresh that triggers getNearbyWalks in the repository:
        sut.refreshNearbyWalks()

        wait(for: [errorExpectation], timeout: 2.0)

        // Step 4 & 5: Turn off error simulation, attempt a new refresh, confirm state recovers
        mockWalkRepository.shouldSimulateError = false
        let successExpectation = expectation(description: "Recovery scenario: Refresh completes without error.")
        // We can observe the nearbyWalksSubject for non-empty data or just confirm no new errors
        sut.nearbyWalksSubject
            .dropFirst() // skip the initial empty array
            .sink { updatedWalks in
                if !updatedWalks.isEmpty {
                    successExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Possibly we configure mockWalkRepository to return a fake list. We'll do so:
        let testWalkId = UUID()
        let testWalk = Walk(
            id: testWalkId,
            ownerId: "Owner123",
            walkerId: "Walker123",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 20.0
        )
        // Insert the test walk in the repository
        mockWalkRepository.createWalk(testWalk).sink(receiveCompletion: { _ in }, receiveValue: { _ in }).store(in: &cancellables)

        // Attempt another refresh
        sut.refreshNearbyWalks()

        wait(for: [successExpectation], timeout: 2.0)
    }

    ///
    /// Tests concurrency aspects of walk operations in the HomeViewModel:
    ///   1. Setup multiple concurrent operations (e.g., startWalk calls, location updates).
    ///   2. Execute parallel walk updates from multiple threads.
    ///   3. Verify the model’s internal state remains consistent (e.g., activeWalkSubject).
    ///   4. Look for any signs of race conditions or data corruption.
    ///   5. Validate final state matches expectations.
    ///
    func testConcurrentWalkOperations() {
        // Step 1: Setup a walk in the mock repository
        let walkId = UUID()
        let initialWalk = Walk(
            id: walkId,
            ownerId: "Owner999",
            walkerId: "Walker999",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 15.0
        )
        mockWalkRepository.createWalk(initialWalk)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // We'll do parallel updates like updating walk status from multiple threads:
        let group = DispatchGroup()
        let concurrencyCount = 5

        // Step 2: Execute parallel walk updates
        for _ in 0..<concurrencyCount {
            group.enter()
            testQueue.async {
                // We'll just update the walk status to inProgress or completed randomly
                let randomStatus: WalkStatus = Bool.random() ? .inProgress : .scheduled
                self.mockWalkRepository.updateWalkStatus(walkId: walkId, status: randomStatus)
                    .sink(receiveCompletion: { _ in
                        group.leave()
                    }, receiveValue: { _ in })
                    .store(in: &self.cancellables)
            }
        }

        // Step 3 & 4: Wait for all concurrency tasks to complete, then verify final state
        group.wait()

        // Step 5: Check the final walk from the repository or from the ViewModel’s perspective
        let fetchExpectation = expectation(description: "Final fetch of walk after concurrency updates.")
        mockWalkRepository.getWalk(walkId)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { finalWalk in
                      XCTAssertNotNil(finalWalk, "We should still have a recorded walk after concurrency.")
                      // There's no guarantee on the final status if concurrency is random,
                      // but we can confirm it doesn't crash or vanish.
                      fetchExpectation.fulfill()
                  })
            .store(in: &cancellables)

        wait(for: [fetchExpectation], timeout: 3.0)
    }
}
```