import Foundation // iOS 13.0+ - Basic iOS functionality and data types
import Combine    // iOS 13.0+ - Reactive programming support for publishers/subjects
import XCTest    // iOS 13.0+ - Testing framework utilities and assertions

@testable import DogWalking

/// An error enumeration representing possible simulation errors in the mock repository.
enum MockWalkRepositoryError: Error {
    /// Represents a scenario in which the repository intentionally simulates a failure.
    case simulatedError
}

/// @testable mock implementation of WalkRepository for unit testing, providing controlled
/// test data, behavior verification, and error simulation capabilities. It addresses:
///  1) Service Execution - Mocks GPS tracking, photo sharing, and status updates
///  2) Walk Data Management - Manages in-memory walk data via thread-safe operations
final class MockWalkRepository: WalkRepository {

    // MARK: - Properties

    /// A lock to ensure thread-safe access to the walks dictionary and other mutable state.
    private let lock = NSLock()

    /// A subject emitting Walk objects whenever they are created or updated in the repository.
    let walkUpdates = PassthroughSubject<Walk, Never>()

    /// An in-memory store mapping walk IDs (UUID) to their corresponding Walk objects.
    private var walks: [UUID: Walk]

    /// A Boolean indicating whether this mock should simulate an error scenario.
    var shouldSimulateError: Bool

    /// A counter tracking how many times createWalk has been invoked.
    private(set) var createWalkCallCount: Int

    /// A counter tracking how many times getWalk has been invoked.
    private(set) var getWalkCallCount: Int

    /// A counter tracking how many times updateWalkStatus has been invoked.
    private(set) var updateWalkStatusCallCount: Int

    /// A counter tracking how many times addLocation has been invoked.
    private(set) var addLocationCallCount: Int

    /// A counter tracking how many times uploadWalkPhoto has been invoked.
    private(set) var uploadWalkPhotoCallCount: Int

    /// An optional delay (in seconds) that will be applied to publishers for simulating network latency.
    var simulatedDelay: TimeInterval

    // MARK: - Initializer

    /// Initializes the mock repository with thread-safe storage and default values.
    /// Steps:
    ///  1. Initialize NSLock for thread safety.
    ///  2. Initialize empty walks dictionary.
    ///  3. Initialize walkUpdates PassthroughSubject.
    ///  4. Set shouldSimulateError to false.
    ///  5. Set simulatedDelay to 0.
    ///  6. Initialize all call counts to 0.
    init() {
        self.walks = [:]
        self.shouldSimulateError = false
        self.simulatedDelay = 0
        self.createWalkCallCount = 0
        self.getWalkCallCount = 0
        self.updateWalkStatusCallCount = 0
        self.addLocationCallCount = 0
        self.uploadWalkPhotoCallCount = 0
    }

    // MARK: - WalkRepository Protocol Conformance

    /// Thread-safe mock implementation of walk creation with error simulation.
    /// Steps:
    ///  1. Acquire lock for thread safety.
    ///  2. Increment createWalkCallCount.
    ///  3. Check shouldSimulateError flag.
    ///  4. Validate walk data if not simulating error.
    ///  5. Store walk in walks dictionary if valid.
    ///  6. Emit walk through walkUpdates.
    ///  7. Release lock.
    ///  8. Apply simulated delay if set.
    ///  9. Return success or error publisher.
    func createWalk(_ walk: Walk) -> AnyPublisher<Walk, Error> {
        lock.lock()
        createWalkCallCount += 1

        let simulateError = shouldSimulateError
        if !simulateError {
            // Validation: ensure minimal data
            guard !walk.ownerId.trimmingCharacters(in: .whitespaces).isEmpty,
                  !walk.walkerId.trimmingCharacters(in: .whitespaces).isEmpty else {
                lock.unlock()
                return Fail<Walk, Error>(error: MockWalkRepositoryError.simulatedError)
                    .eraseToAnyPublisher()
            }
            walks[walk.id] = walk
            walkUpdates.send(walk)
        }
        lock.unlock()

        let publisher = Future<Walk, Error> { [weak self] promise in
            guard let self = self else { return }
            if simulateError {
                promise(.failure(MockWalkRepositoryError.simulatedError))
            } else {
                promise(.success(walk))
            }
        }

        return publisher
            .delay(for: .seconds(simulatedDelay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }

    /// Thread-safe mock implementation of walk retrieval with error simulation.
    /// Steps:
    ///  1. Acquire lock for thread safety.
    ///  2. Increment getWalkCallCount.
    ///  3. Check shouldSimulateError flag.
    ///  4. Retrieve walk from walks dictionary.
    ///  5. Release lock.
    ///  6. Apply simulated delay if set.
    ///  7. Return success or error publisher.
    func getWalk(_ walkId: UUID) -> AnyPublisher<Walk?, Error> {
        lock.lock()
        getWalkCallCount += 1

        let simulateError = shouldSimulateError
        let existingWalk = walks[walkId]
        lock.unlock()

        let publisher = Future<Walk?, Error> { promise in
            if simulateError {
                promise(.failure(MockWalkRepositoryError.simulatedError))
            } else {
                promise(.success(existingWalk))
            }
        }

        return publisher
            .delay(for: .seconds(simulatedDelay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }

    /// Thread-safe mock implementation of walk status update with error simulation.
    /// Steps:
    ///  1. Acquire lock for thread safety.
    ///  2. Increment updateWalkStatusCallCount.
    ///  3. Check shouldSimulateError flag.
    ///  4. Validate walk exists.
    ///  5. Update walk status in walks dictionary.
    ///  6. Emit updated walk through walkUpdates.
    ///  7. Release lock.
    ///  8. Apply simulated delay if set.
    ///  9. Return success or error publisher.
    func updateWalkStatus(walkId: UUID, status: WalkStatus) -> AnyPublisher<Walk, Error> {
        lock.lock()
        updateWalkStatusCallCount += 1

        let simulateError = shouldSimulateError
        let updatedWalk: Walk? = {
            guard var foundWalk = walks[walkId] else {
                return nil
            }
            foundWalk.status = status
            walks[walkId] = foundWalk
            walkUpdates.send(foundWalk)
            return foundWalk
        }()

        lock.unlock()

        let publisher = Future<Walk, Error> { promise in
            if simulateError {
                promise(.failure(MockWalkRepositoryError.simulatedError))
            } else if let theWalk = updatedWalk {
                promise(.success(theWalk))
            } else {
                promise(.failure(MockWalkRepositoryError.invalidProperty("Walk not found.")))
            }
        }

        return publisher
            .delay(for: .seconds(simulatedDelay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }

    /// Thread-safe mock implementation of location addition with error simulation.
    /// Steps:
    ///  1. Acquire lock for thread safety.
    ///  2. Increment addLocationCallCount.
    ///  3. Check shouldSimulateError flag.
    ///  4. Validate walk exists.
    ///  5. Add location to walk's locations array.
    ///  6. Emit updated walk through walkUpdates.
    ///  7. Release lock.
    ///  8. Apply simulated delay if set.
    ///  9. Return success or error publisher.
    func addLocation(walkId: UUID, location: Location) -> AnyPublisher<Void, Error> {
        lock.lock()
        addLocationCallCount += 1

        let simulateError = shouldSimulateError
        let foundWalk: Walk? = walks[walkId]

        if let existingWalk = foundWalk, !simulateError {
            var updatedWalk = existingWalk
            updatedWalk.locations.append(location)
            walks[walkId] = updatedWalk
            walkUpdates.send(updatedWalk)
        }

        lock.unlock()

        let publisher = Future<Void, Error> { promise in
            if simulateError {
                promise(.failure(MockWalkRepositoryError.simulatedError))
            } else if foundWalk == nil {
                promise(.failure(MockWalkRepositoryError.invalidProperty("Walk not found.")))
            } else {
                promise(.success(()))
            }
        }

        return publisher
            .delay(for: .seconds(simulatedDelay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }

    /// Thread-safe mock implementation of photo upload with error simulation.
    /// Steps:
    ///  1. Acquire lock for thread safety.
    ///  2. Increment uploadWalkPhotoCallCount.
    ///  3. Check shouldSimulateError flag.
    ///  4. Validate walk exists and photo data.
    ///  5. Generate mock photo URL.
    ///  6. Release lock.
    ///  7. Apply simulated delay if set.
    ///  8. Return success or error publisher.
    func uploadWalkPhoto(walkId: UUID, photoData: Data) -> AnyPublisher<String, Error> {
        lock.lock()
        uploadWalkPhotoCallCount += 1

        let simulateError = shouldSimulateError
        let foundWalk: Walk? = walks[walkId]
        let validPhotoData = !photoData.isEmpty
        lock.unlock()

        let publisher = Future<String, Error> { promise in
            if simulateError {
                promise(.failure(MockWalkRepositoryError.simulatedError))
            } else if foundWalk == nil {
                promise(.failure(MockWalkRepositoryError.invalidProperty("Walk not found.")))
            } else if !validPhotoData {
                promise(.failure(MockWalkRepositoryError.invalidProperty("Invalid photo data.")))
            } else {
                let mockUrl = "https://mockserver.local/photos/\(UUID().uuidString).jpg"
                promise(.success(mockUrl))
            }
        }

        return publisher
            .delay(for: .seconds(simulatedDelay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }

    // MARK: - Test Utility

    /// Thread-safe reset of all mock state for test isolation.
    /// Steps:
    ///  1. Acquire lock for thread safety.
    ///  2. Clear walks dictionary.
    ///  3. Reset shouldSimulateError to false.
    ///  4. Reset simulatedDelay to 0.
    ///  5. Reset all call counts to 0.
    ///  6. Release lock.
    func reset() {
        lock.lock()
        walks.removeAll()
        shouldSimulateError = false
        simulatedDelay = 0
        createWalkCallCount = 0
        getWalkCallCount = 0
        updateWalkStatusCallCount = 0
        addLocationCallCount = 0
        uploadWalkPhotoCallCount = 0
        lock.unlock()
    }
}