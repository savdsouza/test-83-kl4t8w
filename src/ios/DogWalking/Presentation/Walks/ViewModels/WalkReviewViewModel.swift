import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)

// MARK: - Internal Imports
// BaseViewModel for reactive properties and error handling.
import Core.Base.BaseViewModel

// Walk model for review data and photo management.
import Domain.Models.Walk

// Walk business logic including review submission and photo handling.
import Domain.UseCases.WalkUseCase

/// A lightweight structure representing a single photo upload item.
/// Can store additional metadata as needed (retry counts, timestamps, etc.).
private struct PhotoUpload {
    let data: Data
    var attemptCount: Int

    init(data: Data, attemptCount: Int = 0) {
        self.data = data
        self.attemptCount = attemptCount
    }
}

/// A generic FIFO queue supporting enqueue/dequeue operations for managing photo uploads.
private struct Queue<Element> {
    private var storage: [Element] = []

    /// Inserts an element at the back of the queue.
    mutating func enqueue(_ element: Element) {
        storage.append(element)
    }

    /// Removes and returns the element at the front of the queue, or nil if empty.
    mutating func dequeue() -> Element? {
        guard !storage.isEmpty else { return nil }
        return storage.removeFirst()
    }

    /// Checks whether the queue is empty.
    var isEmpty: Bool {
        storage.isEmpty
    }

    /// Returns the current count of items in the queue.
    var count: Int {
        storage.count
    }
}

/// @MainActor annotation ensures all UI and reactive updates occur on the main thread.
/// This view model handles walk review submission, including rating/notes and photo uploads,
/// supporting offline operation and input validation for a high-quality user experience.
@MainActor
public final class WalkReviewViewModel: BaseViewModel {

    // MARK: - Properties

    /// A reference to the use case class providing business logic for walk reviews, photo uploads,
    /// and finalizing the walk session.
    public let walkUseCase: WalkUseCase

    /// The unique identifier referencing the specific walk session to be reviewed.
    public let walkId: UUID

    /// Publishes the current rating (1.0 to 5.0) for the walk. Defaults to 0.0 if unset.
    public let ratingSubject: CurrentValueSubject<Double, Never>

    /// Publishes any textual notes for the walk review (e.g., feedback or additional comments).
    public let notesSubject: CurrentValueSubject<String, Never>

    /// Accepts raw photo data (e.g., JPEG) for upload during the review process.
    public let photoSubject: PassthroughSubject<Data, Never>

    /// Emits a signal when the user attempts to submit the review.
    public let submitSubject: PassthroughSubject<Void, Never>

    /// Indicates completion status of the entire review submission flow (true if successful).
    public let completionSubject: PassthroughSubject<Bool, Never>

    /// Publishes incremental upload progress (0.0 to 1.0) for photo uploads.
    public let uploadProgressSubject: PassthroughSubject<Double, Never>

    /// A separate collection of cancellables specifically for photo upload processes.
    private var photoCancellables: Set<AnyCancellable>

    /// A queue managing pending photo uploads. Supports potential offline operation or retries.
    private var photoUploadQueue: Queue<PhotoUpload>

    // MARK: - Constructor

    /// Initializes the view model with required dependencies and sets up reactive bindings.
    /// Steps performed:
    /// 1) Store walk use case reference.
    /// 2) Store walk ID.
    /// 3) Initialize reactive subjects with default values.
    /// 4) Set up input/output bindings (placeholder).
    /// 5) Initialize photo upload queue.
    /// 6) Configure offline support (placeholder).
    /// 7) Set up cleanup handlers (placeholder).
    ///
    /// - Parameters:
    ///   - walkUseCase: The use case object containing business logic for the review flow.
    ///   - walkId: The unique identifier for the walk to be reviewed.
    public init(walkUseCase: WalkUseCase, walkId: UUID) {
        self.walkUseCase = walkUseCase
        self.walkId = walkId

        // Subject initialization with default or placeholder values.
        self.ratingSubject = CurrentValueSubject<Double, Never>(0.0)
        self.notesSubject = CurrentValueSubject<String, Never>("")
        self.photoSubject = PassthroughSubject<Data, Never>()
        self.submitSubject = PassthroughSubject<Void, Never>()
        self.completionSubject = PassthroughSubject<Bool, Never>()
        self.uploadProgressSubject = PassthroughSubject<Double, Never>()

        // Initialize local photo upload queue and dedicated cancellables set.
        self.photoUploadQueue = Queue<PhotoUpload>()
        self.photoCancellables = Set<AnyCancellable>()

        super.init()

        // (Optional) Set up data-flow bindings, offline strategies, or cleanup in deinit if needed.
        // For demonstration, these are placeholders:
        // configureOfflineSupport() 
        // setUpBindings()
        // setUpCleanupHandlers()
    }

    // MARK: - Public Methods

    /// Submits the walk review with rating, notes, and queued photos, returning
    /// a publisher that emits completion or error. This is the entry point to finalize
    /// the review process and potentially trigger an update to back-end or offline storage.
    ///
    /// Steps:
    /// 1) Validate rating is between 1 and 5.
    /// 2) Check for pending photo uploads if logic demands all be done before final submission.
    /// 3) Update walk with rating and notes (under the hood, we might set fields on the walk).
    /// 4) Submit review through use case (walkUseCase).
    /// 5) Handle offline submission if needed (placeholder).
    /// 6) Process queued photos, uploading them in a chain or in parallel.
    /// 7) Emit completion event to completionSubject upon success.
    /// 8) Clean up resources or reset state if needed.
    ///
    /// - Returns: AnyPublisher<Void, Error> that completes on success or fails on error.
    public func submitReview() -> AnyPublisher<Void, Error> {
        let currentRating = ratingSubject.value
        let currentNotes = notesSubject.value

        // 1) Validate rating
        guard currentRating >= 1.0, currentRating <= 5.0 else {
            let validationError = NSError(domain: "WalkReview",
                                          code: 1001,
                                          userInfo: [NSLocalizedDescriptionKey:
                                                     "Rating must be between 1.0 and 5.0"])
            return Fail(error: validationError).eraseToAnyPublisher()
        }

        // 2) (Optional) Check for pending photos. This depends on business rules,
        //    e.g., do we allow submission if photos are not fully uploaded?
        //    For demonstration, we continue even if the queue isn't empty.

        // 3) & 4) Submit review with rating and notes via the use case.
        //    We assume walkUseCase.submitReview returns AnyPublisher<Void, Error>.
        //    If the real signature differs, adapt accordingly.
        // 5) Offline submission handling is left as a placeholder inside the pipeline.

        let reviewPipeline = walkUseCase.submitReview(walkId: walkId,
                                                      rating: currentRating,
                                                      notes: currentNotes)
            // If the submission is offline or partial, a fallback or local queue could be used.
            .flatMap { [weak self] _ -> AnyPublisher<Void, Error> in
                // 6) Process queued photos once the main review is submitted,
                //    to ensure partial info isn't lost. We'll chain them.
                guard let self = self else {
                    return Fail(error: NSError(domain: "WalkReview",
                                               code: 9999,
                                               userInfo: [NSLocalizedDescriptionKey:
                                                          "Self deallocated."]))
                          .eraseToAnyPublisher()
                }
                return self.uploadAllPendingPhotos()
            }
            .handleEvents(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure:
                    // Optionally handle logging or state rollback
                    break
                case .finished:
                    // 7) Emit completion event
                    self?.completionSubject.send(true)
                }
                // 8) (Optional) Cleanup resources or reset queue, states, etc.
            })
            .eraseToAnyPublisher()

        return reviewPipeline
    }

    /// Processes and uploads a single photo for the walk review, returning
    /// a publisher that emits the remote photo URL or an error if upload fails.
    ///
    /// Steps:
    /// 1) Validate photo data size/format (stub).
    /// 2) Compress photo if needed (stub).
    /// 3) Set loading state (using isLoadingSubject from BaseViewModel).
    /// 4) Queue photo if offline (stub).
    /// 5) Upload photo via walkUseCase.uploadWalkPhoto.
    /// 6) Update uploadProgressSubject as the upload proceeds.
    /// 7) Handle completion, clear loading, or set final states.
    /// 8) Update UI (error or success).
    /// 9) Retry on failure with backoff (e.g., .retry(3)).
    ///
    /// - Parameter photoData: Raw Data of the photo (e.g., JPEG).
    /// - Returns: AnyPublisher<String, Error> with the remote URL on success.
    public func uploadPhoto(_ photoData: Data) -> AnyPublisher<String, Error> {
        // 1) Validate size. (Example: disallow empty or overly large photos)
        guard !photoData.isEmpty else {
            let e = NSError(domain: "WalkReview",
                            code: 2001,
                            userInfo: [NSLocalizedDescriptionKey:
                                       "Photo data is empty."])
            return Fail(error: e).eraseToAnyPublisher()
        }

        // 2) Compress photo if needed (placeholder).
        let finalData = photoData // For demonstration, no change.

        // 3) Mark UI as loading for photo upload.
        self.setLoading(true)

        // 4) If offline, we might queue the photo. For demonstration, proceed to upload.

        // 5) & 6) Use the walkUseCase for uploading, tracking progress via custom means if the use case supports it.
        //    We'll do .retry(3) for a simple exponential backoff approach in real code if needed.
        //    Here, we chain .handleEvents to update progress.
        return walkUseCase.uploadWalkPhoto(walkId: walkId,
                                           photoData: finalData,
                                           metadata: "ReviewPhoto")
            .handleEvents(receiveOutput: { [weak self] _ in
                // Photo upload succeeded, set progress to 1.0
                self?.uploadProgressSubject.send(1.0)
            }, receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure:
                    // 8) On error, set loading false or update UI
                    self?.setLoading(false)
                case .finished:
                    // Clean up
                    self?.setLoading(false)
                }
            }, receiveCancel: { [weak self] in
                self?.setLoading(false)
            })
            // 9) Retry logic. For illustration, a 3-attempt immediate retry.
            //    A real implementation might do exponential backoff or
            //    incorporate .delay for better user experience.
            .retry(3)
            .eraseToAnyPublisher()
    }

    /// Transforms input events to output state, handling error flows and internal binding.
    /// This method is often used in MVVM to wire up user actions to updated UI states.
    ///
    /// Steps:
    /// 1) Set up rating validation binding.
    /// 2) Set up notes binding (sanitization).
    /// 3) Set up photo upload handling with compression or queue logic.
    /// 4) Configure offline support if necessary.
    /// 5) Set up submit action binding to call submitReview().
    /// 6) Handle errors by sending them to the errorSubject from BaseViewModel.
    /// 7) Return combined output state for the UI to subscribe.
    ///
    /// - Parameter input: A conceptual input struct capturing user events or actions.
    /// - Returns: A conceptual output struct that the UI can bind to for state updates.
    public func transform<Input, Output>(_ input: Input) -> Output {
        // Implementation placeholder to demonstrate MVVM input-output transformation.
        // Additional Combine pipelines can be established here, hooking up subjects
        // (ratingSubject, notesSubject, photoSubject, etc.) to produce an Output.

        // 1) e.g., ratingSubject.filter { $0 >= 1 && $0 <= 5 } ...
        // 2) e.g., notesSubject.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ...
        // 5) e.g., input.submitTappedPublisher.flatMap { self.submitReview() } ...
        // 6) handle errors with self.handleError(_:) from BaseViewModel
        // ...
        // 7) Return a typed output. For demonstration, we do not define it concretely.

        fatalError("transform(_:)_ method not fully implemented. Provide Input/Output bindings as needed.")
    }

    // MARK: - Private Helpers

    /// Uploads all pending photos in the `photoUploadQueue` sequentially,
    /// chaining each photo's upload. If any photo fails, the chain fails.
    /// Returns a publisher that completes upon all uploads finishing or
    /// fails if any single upload fails.
    private func uploadAllPendingPhotos() -> AnyPublisher<Void, Error> {
        // If the queue is empty, immediately succeed.
        guard !photoUploadQueue.isEmpty else {
            return Just(())
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        // Recursively process each item in the queue, returning a chained pipeline.
        return Deferred { [weak self] () -> AnyPublisher<Void, Error> in
            guard let self = self else {
                return Fail(error: NSError(domain: "WalkReview",
                                           code: 9999,
                                           userInfo: [NSLocalizedDescriptionKey:
                                                      "Self is nil in uploadAllPendingPhotos"]))
                    .eraseToAnyPublisher()
            }

            guard let nextItem = self.photoUploadQueue.dequeue() else {
                // If we unexpectedly find no item, succeed.
                return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            // Attempt uploadPhoto, then on success continue with remaining queue items.
            return self.uploadPhoto(nextItem.data)
                .flatMap { _ -> AnyPublisher<Void, Error> in
                    // After success, recursively call uploadAllPendingPhotos again.
                    return self.uploadAllPendingPhotos()
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}