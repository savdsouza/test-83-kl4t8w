//
//  ViewModelType.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-01.
//
//  This file defines a core protocol for all view models in the MVVM architecture
//  on iOS, leveraging reactive programming with the Combine framework. It ensures
//  each view model transforms input events into output states in a type-safe manner,
//  enabling robust data flow and error handling.
//
//  Imports and minimum deployment target versions:
//  - Foundation (iOS 13.0+): Provides fundamental data types, collections, and APIs.
//  - Combine (iOS 13.0+): Required for reactive programming support and publishers.
//

import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)

/// The `ViewModelType` protocol defines a standardized interface for view models
/// in an MVVM architecture, ensuring a consistent reactive data flow between the
/// UI layer (Views) and the underlying business logic. By conforming to this
/// protocol, each view model will:
/// - Expose precisely defined `Input` and `Output` associated types that describe
///   the events, actions, and data states.
/// - Implement a `transform(_:)` function that uses Combine for event processing,
///   error handling, memory management of subscriptions, and output generation.
///
/// Conforming view models should rely on Combine operators to handle asynchronous
/// operations, gracefully manage errors, and propagate state changes to bound views.
/// This pattern allows for clearer separation of concerns, increased testability,
/// and more predictable state management.
public protocol ViewModelType {

    // MARK: - Associated Types

    /// Represents the collection of possible user actions, view events, or inputs
    /// that the view model can receive. Typically, this is defined as a struct or
    /// an enum grouping all relevant interactions from the corresponding View.
    ///
    /// Example:
    /// ```
    /// struct MyViewModelInput {
    ///     let didTapButton: AnyPublisher<Void, Never>
    ///     let didAppear: AnyPublisher<Void, Never>
    /// }
    /// ```
    ///
    /// - Note: The `Input` type should cover both simple user events (like tapping
    ///   a button) and more complex scenarios (like text changes or lifecycle callbacks).
    associatedtype Input

    /// Represents the various outputs or state updates that the view model can produce.
    /// Typically, this is defined as a struct or an enum grouping the relevant data
    /// streams, ready to be bound to the View for UI updates. This could include:
    /// publishers for text fields, button states, validation results, or other state
    /// changes throughout the user flow.
    ///
    /// Example:
    /// ```
    /// struct MyViewModelOutput {
    ///     let isButtonEnabled: AnyPublisher<Bool, Never>
    ///     let errorMessage: AnyPublisher<String?, Never>
    /// }
    /// ```
    ///
    /// - Note: The `Output` type should account for all reactive streams or discrete
    ///   data events that the View needs to display, track, or react to.
    associatedtype Output

    // MARK: - Transformation Function

    /// Transforms the given `Input` (representing user actions and view events) into
    /// the corresponding `Output` (representing view states and data updates) by
    /// leveraging the Combine framework for reactive data binding.
    ///
    /// Steps Involved in This Transformation:
    /// 1. **Accept Input**:
    ///    - Collect all user-driven events (e.g., button taps, text changes, lifecycle events).
    /// 2. **Process with Combine**:
    ///    - Use a series of Combine operators (e.g., `map`, `filter`, `flatMap`) to manage
    ///      asynchronous workflows, apply business logic, or request data from services.
    /// 3. **Handle Errors**:
    ///    - Incorporate error-handling operators (e.g., `catch`, `retry`) for smooth user
    ///      experiences and robust failure recovery.
    /// 4. **Manage Subscriptions**:
    ///    - Ensure Combine subscriptions are appropriately managed or canceled to prevent
    ///      memory leaks and unintended behavior.
    /// 5. **Return Output**:
    ///    - Provide the output struct or object containing the reactive publishers or
    ///      synchronous data states essential for rendering the View.
    ///
    /// - Parameter input: The `Input` object encapsulating all relevant user actions,
    ///   view events, or external triggers that the ViewModel should respond to.
    /// - Returns: An instance of `Output` containing publishers or data fields that
    ///   the View can subscribe to and display. This output ideally covers all dynamic
    ///   pieces of information the user interface needs while ensuring type safety
    ///   and a reactive architecture.
    func transform(_ input: Input) -> Output
}