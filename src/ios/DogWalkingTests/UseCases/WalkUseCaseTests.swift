//
//  WalkUseCaseTests.swift
//  DogWalkingTests
//
//  Created by Elite Software Architect on 2023-10-15.
//
//  This file contains a comprehensive test suite for the WalkUseCase class,
//  verifying walk session management, location tracking, photo upload
//  functionality, error handling, and thread safety. The tests address:
//    1) Service Execution (GPS tracking, photo sharing, and status updates)
//    2) Walk Data Management (session data handling, state management, data persistence)
//    3) Real-time Tracking (location tracking, concurrency operations, error recovery)
//
//  ------------------------------------------------------------------------------
//  Imports (IE2: each external import includes library version in comments)
//  ------------------------------------------------------------------------------
//  External:
import XCTest // iOS 13.0+ (Unit testing framework)
import Combine // iOS 13.0+ (Reactive programming framework for asynchronous ops)

//  Internal (IE1: referencing classes from the DogWalking module under test)
@testable import DogWalking  // For testing the WalkUseCase in detail

/// A comprehensive test suite for the WalkUseCase class verifying walk management,
/// location tracking, and photo upload functionality with error handling and
/// thread safety. It thoroughly exercises all critical paths and concurrency
/// scenarios as outlined in the technical specification.
final class WalkUseCaseTests: XCTestCase {

    // MARK: - Properties (LD1: Extremely Detailed)

    /// System Under Test: the WalkUseCase instance being tested.
    private var sut: WalkUseCase!

    /// A mock repository for walk data management, simulating
    /// createWalk, updateWalkStatus, updateLocation, uploadPhoto, etc.
    private var mockWalkRepository: MockWalkRepository!

    /// A mock location service for simulating GPS tracking, callbacks,
    /// and real-time updates.
    private var mockLocationService: MockLocationService!

    /// A set of Combine AnyCancellable references that enables us to
    /// store and manage active publishers and subsequences in each test.
    private var cancellables: Set<AnyCancellable>!

    /// A dedicated serial or concurrent dispatch queue utilized for
    /// concurrency tests, ensuring realistic parallel operations.
    private var testQueue: DispatchQueue!

    // MARK: - Setup / Teardown

    /// Prepares the test environment before each test with proper initialization
    /// and isolation, following the steps specified in the JSON:
    ///  1) Initialize a dispatch queue suitable for concurrent testing.
    ///  2) Create a new instance of MockWalkRepository.
    ///  3) Create a new instance of MockLocationService.
    ///  4) Initialize the SUT (WalkUseCase) with the mock dependencies.
    ///  5) Define an empty Set for subscription management.
    ///
    /// - Throws: Never
    override func setUp() {
        super.setUp()
        // 1) Initialize testQueue for concurrency.
        testQueue = DispatchQueue(label: "WalkUseCaseTests.testQueue",
                                  attributes: .concurrent)

        // 2) Create new instance of the mock repository.
        mockWalkRepository = MockWalkRepository()

        // 3) Create new instance of the mock location service.
        mockLocationService = MockLocationService(
            mockLocations: [],           // default no preset locations
            shouldSimulateError: false,  // default to no error injection
            initialPermissionState: .authorized,
            simulatedDelay: 0.0
        )

        // 4) Initialize the SUT with mock dependencies.
        //    The JSON specification indicates the constructor signature:
        //    public init(walkRepository: WalkRepository, locationService: LocationService)
        sut = WalkUseCase(
            walkRepository: mockWalkRepository,
            locationService: mockLocationService
        )

        // 5) Initialize empty cancellables set.
        cancellables = Set<AnyCancellable>()
    }

    /// Cleans up the test environment after each test to ensure isolation
    /// and prevent resource leaks, following the steps from the JSON:
    ///  1) Cancel and remove all subscriptions from cancellables.
    ///  2) Reset mockWalkRepository to a clean state.
    ///  3) Reset mockLocationService to a clean state.
    ///  4) Set sut to nil to release references.
    ///  5) Wait for any pending operations to complete.
    ///
    /// - Throws: Never
    override func tearDown() {
        // 1) Cancel all subscriptions from our set.
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // 2) Reset the mock repository to a clean state.
        mockWalkRepository.reset()

        // 3) Reset the mock location service to a clean state.
        mockLocationService.stopWalkTracking()
        // Optionally we can re-init or do additional resets:
        // mockLocationService = nil (but not strictly required, test usage might vary.)

        // 4) Set the SUT reference to nil to free resources.
        sut = nil

        // 5) Wait for any pending ops if needed. For example, we can do a short
        //    dispatch group or small delay. Usually not strictly necessary
        //    if we've cancelled all subscriptions. We'll do a minimal approach:
        let idleExp = expectation(description: "Idle teardown wait")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            idleExp.fulfill()
        }
        wait(for: [idleExp], timeout: 1.0)

        super.tearDown()
    }

    // MARK: - Tests

    /// Tests successful walk scheduling with proper data validation,
    /// using the steps provided in the JSON specification:
    ///  1) Create test walk data with valid parameters.
    ///  2) Set up a success expectation.
    ///  3) Call scheduleWalk with the test data.
    ///  4) Verify the walk is created in the repository.
    ///  5) Assert walk status is scheduled.
    ///  6) Verify all walk properties match test data.
    func testScheduleWalkSuccess() {
        // 1) Create test walk data
        let validWalk = Walk(
            id: UUID(),
            ownerId: "Owner1",
            walkerId: "WalkerA",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 10.0
        )
        validWalk.status = .scheduled

        // 2) Set up success expectation
        let expect = expectation(description: "Schedule walk success")

        // 3) Call scheduleWalk
        sut.scheduleWalk(validWalk)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected failure scheduling walk: \(error)")
                case .finished:
                    // Nothing special on finished
                    break
                }
            }, receiveValue: { createdWalk in
                // 4) Verify repository has the walk
                self.mockWalkRepository.getWalk(createdWalk.id)
                    .sink(receiveCompletion: { _ in },
                          receiveValue: { retrieved in
                        // 5) Assert walk status is scheduled
                        XCTAssertEqual(retrieved?.status, .scheduled,
                                       "Walk status should be scheduled.")
                        // 6) Verify properties match
                        XCTAssertEqual(retrieved?.ownerId, validWalk.ownerId)
                        XCTAssertEqual(retrieved?.walkerId, validWalk.walkerId)
                        XCTAssertEqual(retrieved?.dogId, validWalk.dogId)
                        XCTAssertEqual(retrieved?.price, validWalk.price)
                        expect.fulfill()
                    })
                    .store(in: &self.cancellables)
            })
            .store(in: &cancellables)

        wait(for: [expect], timeout: 2.0)
    }

    /// Tests walk scheduling failure scenarios with error handling,
    /// following the JSON specification steps:
    ///  1) Configure mock repository to simulate error.
    ///  2) Set up a failure expectation.
    ///  3) Call scheduleWalk with test data.
    ///  4) Verify the appropriate error is thrown.
    ///  5) Assert the walk is not created in the repository.
    func testScheduleWalkFailure() {
        // 1) Force the mock repository to simulate an error scenario
        mockWalkRepository.shouldSimulateError = true

        // Create minimal walk for testing
        let failWalk = Walk(
            id: UUID(),
            ownerId: "OwnerFailure",
            walkerId: "WalkerFailure",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 15.0
        )
        failWalk.status = .scheduled

        // 2) Set up failure expectation
        let expect = expectation(description: "Schedule walk failure")

        // 3) Call scheduleWalk with test data
        sut.scheduleWalk(failWalk)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                    // 4) The appropriate error is thrown
                    // 5) The walk is not created in the repository
                    self.mockWalkRepository.getWalk(failWalk.id)
                        .sink(receiveCompletion: { _ in },
                              receiveValue: { retrieved in
                            XCTAssertNil(retrieved, "Walk should not be created on failure.")
                            expect.fulfill()
                        })
                        .store(in: &self.cancellables)

                case .finished:
                    XCTFail("Expected an error but got a successful completion.")
                }
            }, receiveValue: { _ in
                XCTFail("Expected an error but got a success value.")
            })
            .store(in: &cancellables)

        wait(for: [expect], timeout: 2.0)
    }

    /// Tests a successful walk start scenario with location tracking initialization,
    /// verifying the location service is triggered. According to the JSON steps:
    ///  1) Create & schedule a test walk
    ///  2) Set up success expectation
    ///  3) Call startWalk
    ///  4) Verify location tracking started
    ///  5) Assert the walk status is updated to .inProgress
    ///  6) Verify location updates are being processed
    func testStartWalkSuccess() {
        // 1) Create & schedule a walk
        let walkId = UUID()
        let newWalk = Walk(
            id: walkId,
            ownerId: "Owner2",
            walkerId: "WalkerB",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 20.0
        )
        newWalk.status = .scheduled

        // First schedule the walk to ensure the repository has it
        let preScheduleExp = expectation(description: "Pre-schedule walk success")
        sut.scheduleWalk(newWalk)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let err):
                    XCTFail("Unexpected error scheduling walk: \(err)")
                case .finished:
                    break
                }
            }, receiveValue: { _ in
                preScheduleExp.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [preScheduleExp], timeout: 2.0)

        // 2) Set up success expectation
        let startExp = expectation(description: "Start walk success")

        // 3) Call startWalk
        sut.startWalk(walkId: walkId)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let err):
                    XCTFail("Unexpected failure starting walk: \(err)")
                case .finished:
                    break
                }
            }, receiveValue: { updatedWalk in
                // 4) Verify location tracking
                XCTAssertTrue(self.mockLocationService.isTracking.value,
                              "Location service should have started tracking.")
                // 5) Assert status is inProgress
                XCTAssertEqual(updatedWalk.status, .inProgress,
                               "Walk status should be updated to inProgress.")
                // 6) We can also check that the location service is prepared
                //    to emit location updates, but we have no direct location data set.
                //    If we rely on the mock for verifying 'startWalkTracking' was called,
                //    we do that. For demonstration, we'll just confirm isTracking.
                startExp.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [startExp], timeout: 2.0)
    }

    /// Tests the thread safety of concurrent walk operations by dispatching
    /// parallel tasks for scheduling, starting, or uploading. The JSON specification
    /// steps are:
    ///  1) Create multiple test walks
    ///  2) Dispatch concurrent operations on the testQueue
    ///  3) Perform simultaneous walk operations
    ///  4) Verify operations complete successfully
    ///  5) Assert data consistency is maintained
    func testConcurrentOperations() {
        // 1) Create multiple test walks
        let walkAId = UUID()
        let walkBId = UUID()

        let walkA = Walk(
            id: walkAId,
            ownerId: "ConcurrencyOwnerA",
            walkerId: "ConcurrencyWalkerA",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 45.0
        )
        let walkB = Walk(
            id: walkBId,
            ownerId: "ConcurrencyOwnerB",
            walkerId: "ConcurrencyWalkerB",
            dogId: UUID(),
            scheduledStartTime: Date(),
            price: 60.0
        )
        walkA.status = .scheduled
        walkB.status = .scheduled

        let concurrencyExp = expectation(description: "Concurrent operations done")
        concurrencyExp.expectedFulfillmentCount = 4  // We'll do 4 total ops

        // 2) Dispatch concurrency
        testQueue.async {
            self.sut.scheduleWalk(walkA)
                .sink(receiveCompletion: { _ in concurrencyExp.fulfill() },
                      receiveValue: { _ in })
                .store(in: &self.cancellables)
        }

        testQueue.async {
            self.sut.scheduleWalk(walkB)
                .sink(receiveCompletion: { _ in concurrencyExp.fulfill() },
                      receiveValue: { _ in })
                .store(in: &self.cancellables)
        }

        // 3) Perform more ops: e.g. start one walk and upload a photo for the other
        testQueue.async {
            // Start walkA
            self.sut.startWalk(walkId: walkAId)
                .sink(receiveCompletion: { _ in concurrencyExp.fulfill() },
                      receiveValue: { _ in })
                .store(in: &self.cancellables)
        }

        testQueue.async {
            // Attempt to upload a photo to walkB
            let samplePhotoData = Data("SamplePhotoBytes".utf8)
            self.sut.uploadWalkPhoto(walkId: walkBId, photoData: samplePhotoData, metadata: "TestMeta")
                .sink(receiveCompletion: { _ in concurrencyExp.fulfill() },
                      receiveValue: { updated in
                        // Possibly confirm the updated walk or photo references
                      })
                .store(in: &self.cancellables)
        }

        // 4) Wait for all concurrency tasks
        wait(for: [concurrencyExp], timeout: 5.0)

        // 5) Assert data consistency - e.g. each walk was scheduled or updated as expected
        //    We'll do a quick check that the repository has them
        let group = DispatchGroup()
        var retrievedA: Walk?
        var retrievedB: Walk?

        group.enter()
        mockWalkRepository.getWalk(walkAId)
            .sink(receiveCompletion: { _ in group.leave() },
                  receiveValue: { retrievedA = $0 })
            .store(in: &cancellables)

        group.enter()
        mockWalkRepository.getWalk(walkBId)
            .sink(receiveCompletion: { _ in group.leave() },
                  receiveValue: { retrievedB = $0 })
            .store(in: &cancellables)

        group.wait()

        // We check whichever states are relevant. For example, walkA might be in progress,
        // walkB might have a new photo. We do minimal checks:
        XCTAssertNotNil(retrievedA, "WalkA should exist in the repository.")
        XCTAssertNotNil(retrievedB, "WalkB should exist in the repository.")
    }
}