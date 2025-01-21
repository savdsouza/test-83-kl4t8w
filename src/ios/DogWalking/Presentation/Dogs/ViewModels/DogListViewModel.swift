//
//  DogListViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect.
//  This file implements a ViewModel class that manages the presentation logic for
//  the dog list screen, adhering to MVVM architecture, offline-first strategies,
//  and reactive data binding. It addresses Pet Profile Management and the
//  Data Management Strategy outlined in the technical specifications.
//
//  Satisfies these Key Requirements from the JSON Specification:
//    • Pet Profile Management (Manage pet profiles in a list format with real-time updates)
//    • Data Management Strategy (Implements offline-first with local caching & syncing)
//

import Foundation // iOS 13.0+ (Basic iOS functionality and system types)
import Combine    // iOS 13.0+ (Reactive programming support for data binding)

// MARK: - Internal Imports
import class DogWalking.Domain.Models.Dog       // src/ios/DogWalking/Domain/Models/Dog.swift
import protocol DogWalking.Data.Repositories.DogRepository // src/ios/DogWalking/Data/Repositories/DogRepository.swift
import class DogWalking.Core.Base.BaseViewModel // src/ios/DogWalking/Core/Base/BaseViewModel.swift

/**
 A production-ready, enterprise-grade ViewModel that manages the dog list screen.
 It supports offline-first capabilities, reactive updates via Combine, and synchronizes
 with the repository layer for data retrieval and modification.

 This class fulfills Pet Profile Management by listing dogs with live updates,
 and also addresses the Data Management Strategy requirement by using local caching
 (through DogRepository's offline-first approach) and synchronization triggers.
 */
@MainActor
public final class DogListViewModel: BaseViewModel {

    // MARK: - Public Reactive Subjects

    /// A subject exposing the current list of dogs owned by the specified owner.
    /// Emitted changes are immediately reflected in any bound UI components.
    public let dogsSubject: CurrentValueSubject<[Dog], Never>

    /// A subject that broadcasts whenever a dog is selected by the user.
    /// Useful for routing logic or detail screen presentation.
    public let selectedDogSubject: PassthroughSubject<Dog, Never>

    /// A subject that indicates whether a synchronization action between
    /// local and remote data is currently in progress.
    public let isSyncing: CurrentValueSubject<Bool, Never>

    // MARK: - Internal/Private Subjects and Properties

    /// A subject that signals a user's intention to perform a refresh action.
    /// This can be triggered by pull-to-refresh or a dedicated UI button.
    internal let refreshTrigger: PassthroughSubject<Void, Never>

    /// A UUID representing the owner for whom the dog list is managed.
    private let ownerId: UUID

    /// An implementation of the DogRepository protocol for offline-first data interactions.
    private let repository: DogRepository

    /// A thread-safe set for managing this ViewModel’s Combine subscriptions.
    private var cancellables: Set<AnyCancellable>

    /// A dedicated serial dispatch queue ensuring thread-safe modifications
    /// of stateful properties like the dog list or synchronization flags.
    private let serialQueue: DispatchQueue

    // MARK: - Initialization

    /**
     Initializes the DogListViewModel with the required dependencies and configures
     all reactive bindings.

     Steps:
     1. Call super.init() from BaseViewModel.
     2. Assign the repository and ownerId to local properties.
     3. Create a serial queue for thread safety in data operations.
     4. Initialize all subjects (dogsSubject, selectedDogSubject, refreshTrigger, isSyncing).
     5. Set up a refresh trigger subscription with debounce.
     6. Configure basic error handling or retry logic if tasks fail.
     7. Immediately load initial data from local/offline cache.

     - Parameters:
       - repository: The DogRepository for retrieving and modifying dog data.
       - ownerId: A UUID representing the current owner whose dogs we are managing.
     */
    public init(repository: DogRepository,
                ownerId: UUID) {
        // 1. BaseViewModel constructor call
        super.init()

        // 2. Initialize repository reference and owner UUID
        self.repository = repository
        self.ownerId = ownerId

        // 3. Create a unique serial queue for thread-safe property updates
        serialQueue = DispatchQueue(label: "com.dogwalking.DogListViewModel.serialQueue",
                                    qos: .userInitiated)

        // 4. Initialize all reactive subjects with default values
        dogsSubject = CurrentValueSubject<[Dog], Never>([])
        selectedDogSubject = PassthroughSubject<Dog, Never>()
        refreshTrigger = PassthroughSubject<Void, Never>()
        isSyncing = CurrentValueSubject<Bool, Never>(false)

        // Initialize the set of cancellables for subscription management
        cancellables = Set<AnyCancellable>()

        // 5. Set up refresh trigger subscription with optional debounce/time-buffer
        refreshTrigger
            .debounce(for: .seconds(0.3), scheduler: serialQueue)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        // 6. (Optional) Additional error handling or retry config can be placed here.

        // 7. Load initial data from the repository/local cache
        _ = loadDogs()
    }

    // MARK: - Public Methods

    /**
     Loads the list of dogs from the repository for the current owner,
     providing offline-first support.

     Steps:
     1. Emit loading state to true.
     2. Perform the repository call on the serial queue.
     3. Retrieve the result from getDogs(ownerId).
     4. Transform the domain-specific errors or handle them.
     5. Update dogsSubject with the newly fetched array.
     6. Apply retry logic if desired (example placeholders).
     7. Emit loading state to false.
     8. Return a publisher that completes upon success or failure.
     */
    public func loadDogs() -> AnyPublisher<Void, Error> {
        let loadPublisher = PassthroughSubject<Void, Error>()

        // 1. Indicate that loading is active
        setLoading(true)

        // 2. Enqueue operation on our serial queue
        serialQueue.async { [weak self] in
            guard let strongSelf = self else { return }

            // Repository returns AnyPublisher<Result<[Dog], Error>, Never>
            strongSelf.repository.getDogs(ownerId: strongSelf.ownerId)
                .sink { _ in
                    // Completion for a Result-based publisher is .finished only
                    // since there's no real "failure" completion. We'll handle errors below in value closure.
                } receiveValue: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let dogs):
                        // 5. Update main dog list
                        self.dogsSubject.send(dogs)
                        // 7. Loading done
                        self.setLoading(false)
                        loadPublisher.send(())
                        loadPublisher.send(completion: .finished)

                    case .failure(let error):
                        // 4. Handle domain-specific errors
                        // Publish the error for the UI
                        self.errorSubject.send(error)
                        // 7. Still set loading to false
                        self.setLoading(false)
                        loadPublisher.send(completion: .failure(error))
                    }
                }
                .store(in: &strongSelf.cancellables)
        }

        // 8. The returned publisher completes when we manually send completion
        return loadPublisher.eraseToAnyPublisher()
    }

    /**
     Deletes a dog using an optimistic UI update approach with rollback support
     in case the operation fails.

     Steps:
     1. Check if the dog with `dogId` exists in the current list.
     2. Store the current list of dogs for rollback.
     3. Remove the dog from `dogsSubject` immediately (optimistic update).
     4. Call repository.deleteDog(dogId).
     5. On success, confirm removal.
     6. On failure, rollback to the previous dog list and emit the error.
     7. Return a publisher signifying success or failure.
     */
    public func deleteDog(dogId: UUID) -> AnyPublisher<Void, Error> {
        let deletePublisher = PassthroughSubject<Void, Error>()

        serialQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Validate dog presence
            let currentDogs = self.dogsSubject.value
            guard currentDogs.contains(where: { $0.id == dogId }) else {
                // If dog not found, we can either complete silently or send an error
                let notFoundError = NSError(domain: "DogListViewModel",
                                            code: 404,
                                            userInfo: [NSLocalizedDescriptionKey: "Dog not found in current list."])
                deletePublisher.send(completion: .failure(notFoundError))
                return
            }

            // 2. Store state for rollback
            let rollbackDogs = currentDogs

            // 3. Optimistically remove dog
            let updatedList = currentDogs.filter { $0.id != dogId }
            self.dogsSubject.send(updatedList)

            // 4. Call deleteDog from repository
            self.repository.deleteDog(id: dogId)
                .sink { _ in
                    // No .failure completion; the result is in the receiveValue block
                } receiveValue: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        // 5. Successfully confirmed removal
                        deletePublisher.send(())
                        deletePublisher.send(completion: .finished)

                    case .failure(let error):
                        // 6. Rollback
                        self.dogsSubject.send(rollbackDogs)
                        self.errorSubject.send(error)
                        deletePublisher.send(completion: .failure(error))
                    }
                }
                .store(in: &self.cancellables)
        }

        return deletePublisher.eraseToAnyPublisher()
    }

    /**
     Handles dog selection events, ensuring the chosen dog is valid,
     then emits it via `selectedDogSubject` for further processing,
     such as navigation or detail display.

     Steps:
     1. Validate that the selected Dog instance is part of the current list.
     2. Perform any concurrency-protected updates on `serialQueue`.
     3. Send the dog to `selectedDogSubject`.
     4. Optionally log the selection for analytics.
     */
    public func selectDog(_ dog: Dog) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            // 1. Check presence in current list
            let currentDogs = self.dogsSubject.value
            guard currentDogs.contains(where: { $0.id == dog.id }) else {
                // Invalid selection: dog not in the list. We ignore or log an error.
                return
            }

            // 3. Send selection
            self.selectedDogSubject.send(dog)

            // 4. Log analytics if desired (placeholder)
            // e.g.: print("Dog selected for analytics: \(dog.id)")
        }
    }

    /**
     Forces a refresh of the dog list, tracking synchronization status to prevent
     parallel or repetitive sync operations.

     Steps:
     1. Check if isSyncing is already true; if so, ignore.
     2. Set isSyncing to true.
     3. Trigger the repository's syncDogs with the current ownerId.
     4. Upon completion, call loadDogs to refresh local data.
     5. Reset isSyncing to false.
     6. Log the sync result or any errors for debugging.
     */
    public func refresh() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. If a sync is already in progress, we skip
            if self.isSyncing.value {
                return
            }

            // 2. Mark as syncing
            self.isSyncing.send(true)

            // 3. Perform dog synchronization
            self.repository.syncDogs(ownerId: self.ownerId)
                .sink { _ in
                    // No .failure completion, receiveValue block handles success/failure
                } receiveValue: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        // 4. Once synced, reload data from local store
                        _ = self.loadDogs()
                        // 5. Reset syncing
                        self.isSyncing.send(false)
                        // 6. Log success result
                        // e.g.: print("Dog sync completed successfully.")

                    case .failure(let error):
                        // On failure, still reset syncing
                        self.isSyncing.send(false)
                        // e.g.: print("Dog sync failed: \(error)")
                        self.errorSubject.send(error)
                    }
                }
                .store(in: &self.cancellables)
        }
    }
}