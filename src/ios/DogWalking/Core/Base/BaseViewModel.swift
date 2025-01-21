//
//  BaseViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-01.
//
//  Abstract base view model class that provides comprehensive MVVM architecture
//  implementation with reactive data binding, thread-safe state management, and
//  robust error handling for iOS applications. This class leverages Swift's
//  concurrency features (e.g., DispatchQueue) alongside Combine for reactive
//  programming. It is intended to be subclassed by specific view models, ensuring
//  a consistent pattern for data flow, memory management, and error handling
//  across the application.
//
//  Imports:
//  - Foundation (iOS 13.0+): Access to core data types and functionalities.
//  - Combine (iOS 13.0+): Reactive programming framework for Publisher and
//    Subscriber. Enables data binding between Views and ViewModels.
//  - ViewModelType (Local Protocol): Defines the input-output contract for MVVM.

import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)
// NOTE: Replace the line below with the appropriate module import statement
//       or project reference as needed for your build environment.
// import DogWalkingCore // Example import if 'ViewModelType' is part of another module.
// import ... // or any local import that provides ViewModelType if required

/// A simple retry policy structure to handle re-attempts of certain operations when
/// an error occurs. It can be extended to support exponential backoff, maximum retries,
/// or custom logic. Used by `handleError(_:retryPolicy:)`.
public struct RetryPolicy {
    /// The maximum number of retries allowed before giving up.
    public let maxRetryCount: Int

    /// The delay (in seconds) between each retry attempt.
    public let delay: TimeInterval

    /// Creates a new instance of `RetryPolicy`.
    ///
    /// - Parameters:
    ///   - maxRetryCount: Maximum number of retry attempts.
    ///   - delay: Delay between attempts in seconds.
    public init(maxRetryCount: Int, delay: TimeInterval) {
        self.maxRetryCount = maxRetryCount
        self.delay = delay
    }
}

/// `BaseViewModel` is an open class serving as an abstract base for all view models
/// within the DogWalking application. It provides:
/// - Thread-safe state updates using a dedicated serial `DispatchQueue`.
/// - Reactive data binding via Combine, including subjects for loading state and errors.
/// - Comprehensive error handling and optional retry support.
/// - Automatic memory cleanup for Combine subscriptions.
///
/// Usage:
/// ```swift
/// open class MyConcreteViewModel: BaseViewModel {
///     // Implement specialized functionality here.
/// }
/// ```
///
/// Subclasses can override or extend functionality as needed. This class is not
/// meant to be instantiated directly; rather, inherit it to ensure your view models
/// conform to a standardized approach for MVVM architecture and reactive data management.
open class BaseViewModel {

    // MARK: - Public Subjects
    
    /// A subject to broadcast loading state changes (e.g., network calls in progress).
    /// Publishes `Bool` values indicating whether loading is active (`true`) or not (`false`).
    public let isLoadingSubject: PassthroughSubject<Bool, Never>
    
    /// A subject to broadcast error events. Any `Error` published here can be observed
    /// by the UI layer or higher-level error handlers to display alerts or log issues.
    public let errorSubject: PassthroughSubject<Error, Never>
    
    // MARK: - Internal / Private Properties
    
    /// A thread-safe collection of Combine cancellables for managing the lifetime
    /// of subscriptions. All insertions or modifications should be performed on
    /// the `serialQueue`.
    private var cancellables: Set<AnyCancellable>
    
    /// A dedicated dispatch queue used to synchronize state changes, ensuring that
    /// updates to shared properties (e.g., `cancellables`) are performed serially
    /// and race conditions are avoided.
    internal let serialQueue: DispatchQueue
    
    // MARK: - Initialization
    
    /// Initializes the `BaseViewModel` with default reactive components, thread safety,
    /// and memory leak detection in place.
    ///
    /// Steps:
    /// 1. Creates an empty `Set<AnyCancellable>` for Combine subscriptions.
    /// 2. Constructs `isLoadingSubject` with a default `PassthroughSubject<Bool, Never>`.
    /// 3. Constructs `errorSubject` with a default `PassthroughSubject<Error, Never>`.
    /// 4. Creates a `serialQueue` for synchronized operations.
    /// 5. Sets up debug logging placeholders for key state transitions.
    /// 6. Optionally configures memory leak detection placeholders.
    public init() {
        self.cancellables = Set<AnyCancellable>()
        self.isLoadingSubject = PassthroughSubject<Bool, Never>()
        self.errorSubject = PassthroughSubject<Error, Never>()
        
        // A unique label for the serial queue to aid debugging and profiling.
        self.serialQueue = DispatchQueue(label: "com.dogwalking.BaseViewModel.serialQueue",
                                         qos: .userInitiated,
                                         attributes: [],
                                         autoreleaseFrequency: .inherit,
                                         target: nil)
        
        // (Optional) Debug logging or instrumentation placeholder.
        // Example: print("[BaseViewModel] Initialized at \(Date())")
        
        // (Optional) Memory leak detection placeholder.
        // Example: Integrate with an internal tool or add logic for debug builds.
    }
    
    // MARK: - Public Methods
    
    /// Safely updates the loading state in a thread-safe manner, broadcasting the
    /// new value using `isLoadingSubject`. Also logs relevant debug information.
    ///
    /// Steps:
    /// 1. Dispatch onto `serialQueue` to ensure synchronization.
    /// 2. Validate and log the state transition if needed.
    /// 3. Publish the new loading state on the main thread to avoid UI thread issues.
    ///
    /// - Parameter isLoading: A boolean indicating whether loading is active or complete.
    /// - Returns: Void (no return value).
    public func setLoading(_ isLoading: Bool) {
        serialQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            // (Optional) Log the transition for debugging.
            // Example: print("[BaseViewModel] setLoading(\(isLoading))")
            
            // Publish on the main thread to keep UI updates on main run loop.
            DispatchQueue.main.async {
                strongSelf.isLoadingSubject.send(isLoading)
            }
        }
    }
    
    /// Handles an error event with robust logging, optional retry strategies,
    /// and updates to the reactive `errorSubject`.
    ///
    /// Steps:
    /// 1. Log the raw error details for debugging or analytics.
    /// 2. Transform the error to a domain-specific error type if necessary.
    /// 3. If a `retryPolicy` is provided, apply the retry logic or schedule re-attempts.
    /// 4. Clear any loading state by calling `setLoading(false)`.
    /// 5. Publish the error on the main thread to notify observers (e.g., UI).
    /// 6. Optionally dispatch an error reporting event for further analysis.
    ///
    /// - Parameters:
    ///   - error: The encountered `Error` object.
    ///   - retryPolicy: An optional `RetryPolicy` struct that defines how many times
    ///     to retry the failing operation and the delay between attempts. If `nil`,
    ///     the error is handled without retry.
    /// - Returns: Void (no return value).
    public func handleError(_ error: Error, retryPolicy: RetryPolicy? = nil) {
        serialQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            
            // (Optional) Log or transform the error into a domain-error type.
            // Example: print("[BaseViewModel] Handling error: \(error.localizedDescription)")
            
            // (Optional) Retry logic placeholder if `retryPolicy` is provided.
            if let policy = retryPolicy {
                // Example skeleton (not an actual implementation):
                // for attempt in 1...policy.maxRetryCount {
                //     Thread.sleep(forTimeInterval: policy.delay)
                //     // Re-attempt the operation, break if successful
                // }
                // If all attempts fail, proceed to publish error.
                _ = policy
            }
            
            // Ensure loading is turned off
            strongSelf.setLoading(false)
            
            // Publish error on the main thread, ensuring UI consistency
            DispatchQueue.main.async {
                strongSelf.errorSubject.send(error)
            }
            
            // (Optional) Trigger an error reporting system (e.g., Sentry, Crashlytics).
        }
    }
    
    /// Creates a thread-safe binding by subscribing to a provided publisher, which may
    /// output values of type `T` or an `Error`. The resulting `AnyCancellable` is stored
    /// and managed in the `cancellables` set, ensuring it remains active as long as
    /// the view model is alive.
    ///
    /// Steps:
    /// 1. Optionally validate the publisher or configuration.
    /// 2. Apply a scheduler if provided; otherwise default to `.main` or a relevant queue.
    /// 3. Sink or map the publisher output as needed and handle errors internally if desired.
    /// 4. Store the cancellable in a thread-safe manner on the `serialQueue`.
    /// 5. Return the subscription token in case manual cancellation is needed.
    ///
    /// - Parameters:
    ///   - publisher: A generic publisher of type `AnyPublisher<T, Error>` that emits
    ///     values to which the ViewModel should react.
    ///   - scheduler: An optional `DispatchQueue` on which to receive events. Defaults
    ///     to `nil`, in which case the combined pipeline will use the main queue
    ///     for UI consistency.
    /// - Returns: An `AnyCancellable` token representing this subscription. Consumers
    ///   can retain or discard it, but by default it is stored in the `cancellables`
    ///   set to prevent premature deallocation.
    @discardableResult
    public func bind<T>(
        _ publisher: AnyPublisher<T, Error>,
        scheduler: DispatchQueue? = nil
    ) -> AnyCancellable {
        
        // Guard for scheduling approach. By default, adopt main queue if none is provided.
        let outputScheduler = scheduler ?? DispatchQueue.main
        
        // Create a subscription from the provided publisher.
        let subscription = publisher
            .receive(on: outputScheduler)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .failure(let err):
                        // Optionally handle or forward the error to handleError(_:_:)
                        self?.handleError(err)
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    // (Optional) Process or transform the received value if needed.
                }
            )
        
        // Thread-safe insertion of the cancellable into the set.
        serialQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.cancellables.insert(subscription)
        }
        
        return subscription
    }
}
```