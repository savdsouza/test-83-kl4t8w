import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)

// MARK: - Internal Imports
// According to the JSON specification, these imports would reference the
// actual Swift files or modules in your project. Examples:
//
// import Core.Base.BaseViewModel
// import Domain.Models.Walk
// import Domain.UseCases.WalkUseCase
//
// Adjust them to match your build environment or module structure.

// MARK: - Global Error Enum

/// An error enumeration capturing possible failures in the WalkListViewModel.
public enum WalkListError: LocalizedError {
    case updateFailed
    case invalidWalkData
    case networkError

    public var errorDescription: String? {
        switch self {
        case .updateFailed:
            return "Failed to update walks."
        case .invalidWalkData:
            return "Encountered invalid walk data."
        case .networkError:
            return "A network error occurred while loading walks."
        }
    }
}

// MARK: - WalkListViewModel

/// A thread-safe view model for managing and displaying categorized lists of dog walks
/// with real-time updates, offline support, and efficient memory management.
/// Inherits from BaseViewModel to leverage loading/error state management.
@MainActor
public final class WalkListViewModel: BaseViewModel {

    // MARK: - Dependencies

    /// The use case providing walk-related business logic and real-time updates.
    private let walkUseCase: WalkUseCase

    // MARK: - Published Subjects

    /// A current-value publisher storing all available walks.
    public let walksSubject: CurrentValueSubject<[Walk], Never>

    /// A current-value publisher holding active (in-progress) walks.
    public let activeWalksSubject: CurrentValueSubject<[Walk], Never>

    /// A current-value publisher holding scheduled (not-yet-started) walks.
    public let scheduledWalksSubject: CurrentValueSubject<[Walk], Never>

    /// A current-value publisher holding completed walks.
    public let completedWalksSubject: CurrentValueSubject<[Walk], Never>

    // MARK: - Internal State

    /// A set for retaining Combine cancellables, ensuring subscriptions remain active.
    private var cancellables: Set<AnyCancellable>

    /// A mutual-exclusion lock ensuring thread safety during walk list modifications.
    private let updateLock: NSLock

    // MARK: - Initialization

    /**
     Initializes the view model with the required use case and sets up subjects,
     a synchronization lock, and fundamental subscriptions.

     Steps:
     1. Call super.init() from BaseViewModel.
     2. Store walkUseCase reference.
     3. Initialize walk list subjects with empty arrays.
     4. Initialize cancellables set for memory management.
     5. Initialize updateLock for thread safety.
     6. Subscribe to walk update publisher with error handling.
     7. Load initial walk data to populate categories.
     */
    public init(walkUseCase: WalkUseCase) {
        // 1. Explicitly call superclass initializer (BaseViewModel).
        self.walkUseCase = walkUseCase

        // 3. Initialize current-value subjects with empty arrays.
        self.walksSubject = CurrentValueSubject<[Walk], Never>([])
        self.activeWalksSubject = CurrentValueSubject<[Walk], Never>([])
        self.scheduledWalksSubject = CurrentValueSubject<[Walk], Never>([])
        self.completedWalksSubject = CurrentValueSubject<[Walk], Never>([])

        // 4. Initialize cancellables set.
        self.cancellables = Set<AnyCancellable>()

        // 5. Initialize NSLock for update synchronization.
        self.updateLock = NSLock()

        // Call BaseViewModel init.
        super.init()

        // 6. Set up subscription to real-time walk updates from WalkUseCase.
        subscribeToWalkUpdates()

        // 7. Perform initial data load for all walks.
        _ = loadWalks().sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    }

    // MARK: - Public Methods

    /**
     Loads and categorizes all walks with error handling and loading state management.

     Returns:
     A publisher (AnyPublisher<Void, Error>) that completes upon successful load or fails on error.

     Steps:
     1. Set loading state (isLoadingSubject) to true.
     2. Create a deferred publisher for asynchronous loading.
     3. Fetch the walks from walkUseCase.
     4. Categorize the loaded walks with filterWalks(_:).
     5. Set loading state to false.
     6. Handle errors by calling handleError(_:) and re-emitting them.
     */
    public func loadWalks() -> AnyPublisher<Void, Error> {
        setLoading(true)

        let publisher = Deferred {
            Future<Void, Error> { [weak self] promise in
                guard let strongSelf = self else {
                    promise(.failure(WalkListError.updateFailed))
                    return
                }

                strongSelf.walkUseCase.fetchWalks()
                    .sink { completion in
                        switch completion {
                        case .failure(let error):
                            // 6. Handle and propagate errors
                            strongSelf.setLoading(false)
                            strongSelf.handleError(error)
                            promise(.failure(error))
                        case .finished:
                            // Nothing additional on finish
                            break
                        }
                    } receiveValue: { walks in
                        // 4. Categorize using thread-safe filtering
                        strongSelf.filterWalks(walks)

                        // 5. Indicate completion and turn off loading
                        strongSelf.setLoading(false)
                        promise(.success(()))
                    }
                    .store(in: &strongSelf.cancellables)
            }
        }
        .eraseToAnyPublisher()

        return publisher
    }

    // MARK: - Private Methods

    /**
     Subscribes to the WalkUseCase's real-time walkUpdatePublisher. Whenever a new or updated
     Walk is published, it invokes handleWalkUpdate(_:) for thread-safe list modifications.
     */
    private func subscribeToWalkUpdates() {
        walkUseCase.walkUpdatePublisher
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    // Optionally handle or propagate walk update errors
                    self?.handleError(error)
                case .finished:
                    break
                }
            } receiveValue: { [weak self] updatedWalk in
                self?.handleWalkUpdate(updatedWalk)
            }
            .store(in: &cancellables)
    }

    /**
     Thread-safely categorizes walks into active, scheduled, and completed,
     updating the corresponding subjects. Overwrites the all-walks list as well.

     Steps:
     1. Acquire the updateLock.
     2. Filter or group walks by status.
     3. Sort each category by start time.
     4. Publish changes to walksSubject, activeWalksSubject, scheduledWalksSubject, and completedWalksSubject.
     5. Release the updateLock.
     */
    private func filterWalks(_ walks: [Walk]) {
        updateLock.lock()
        defer { updateLock.unlock() }

        // Sort all walks by startTime
        let sortedAll = walks.sorted { $0.startTime < $1.startTime }

        let active = sortedAll.filter { $0.status == .inProgress }
        let scheduled = sortedAll.filter { $0.status == .scheduled }
        let completed = sortedAll.filter { $0.status == .completed }

        walksSubject.send(sortedAll)
        activeWalksSubject.send(active)
        scheduledWalksSubject.send(scheduled)
        completedWalksSubject.send(completed)
    }

    /**
     Handles real-time updates for a given Walk by replacing any existing occurrence
     of that Walk in the local list with the new data, then re-categorizing.

     Steps:
     1. Acquire the updateLock.
     2. Remove the old instance of the walk (if present).
     3. Insert the updated walk into the all-walks array.
     4. Pass the result to filterWalks(_:) to refresh categories.
     5. Release the updateLock.
     6. Optionally notify UI of changes.
     */
    private func handleWalkUpdate(_ updatedWalk: Walk) {
        updateLock.lock()
        defer { updateLock.unlock() }

        var allCurrent = walksSubject.value
        // Remove any old instance
        if let index = allCurrent.firstIndex(where: { $0.id == updatedWalk.id }) {
            allCurrent.remove(at: index)
        }
        // Insert the updated version
        allCurrent.append(updatedWalk)

        // Re-filter entire set
        filterWalks(allCurrent)
    }
}