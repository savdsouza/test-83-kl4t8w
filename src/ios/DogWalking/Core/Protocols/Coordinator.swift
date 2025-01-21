//
//  Coordinator.swift
//  DogWalking - Core/Protocols
//
//  Created by Elite Software Architect Agent.
//  This file defines the core coordinator protocol responsible for
//  managing navigation flows and screen transitions across the iOS application.
//

import UIKit // UIKit (iOS 13.0+)

/// An enterprise-grade protocol that establishes the contract for organizing and
/// controlling navigation flows within the application, utilizing the Coordinator
/// design pattern. Conforming types must manage a UINavigationController
/// (for manipulations such as push, pop, and modal presentations) and maintain
/// a collection of child coordinators to oversee sub-navigation flows.
///
/// Thread-Safety:
/// All methods interacting with UIKit must be invoked on the main thread, as
/// UIKit is not thread-safe. Conformance to this protocol must ensure navigation
/// operations are dispatched to the main thread to preserve UI consistency.
///
/// Memory Management:
/// Each child coordinator should be strongly retained to maintain its lifetime
/// while active. Child coordinators should be removed upon completion of their
/// respective navigation flows to avoid memory leaks.
///
/// Deep Linking:
/// Implementations should incorporate handling for deep link URLs or universal links
/// by directing users to the appropriate screens. Deep linking flows can be unique
/// child coordinators or integrated logic within the start() method, depending on
/// the complexity of the link flow.
///
/// Navigation Styles Supported:
/// - Push navigation (hierarchical)
/// - Modal presentations (fullScreen, formSheet, etc.)
/// - Combination of both, depending on the user flow
///
/// Navigation Failure Handling:
/// Implementations should gracefully handle any errors that occur during navigation,
/// such as presenting user-friendly alerts or fallback flows, and gracefully reverting
/// the navigation stack to a stable state if necessary.
public protocol Coordinator: AnyObject {
    /// The primary navigation controller utilized to manage hierarchical
    /// and modal transitions. Implementations must guarantee that all
    /// push, pop, and present operations are performed on `navigationController`.
    ///
    /// - Important: This property should be accessed only from the main thread.
    var navigationController: UINavigationController { get }

    /// A collection of child coordinators responsible for overseeing
    /// sub-navigation flows within the application. This array must be used
    /// to store references to any new child coordinator so it remains in memory
    /// throughout its active state. Child coordinators should be removed
    /// from this array once their flows complete to prevent memory leaks.
    var childCoordinators: [Coordinator] { get set }

    /// Initiates the navigation flow of the coordinator, configuring and
    /// presenting the first screen or set of screens. This method must be
    /// called immediately after the coordinator is instantiated and assigned.
    ///
    /// Steps to Implement:
    /// 1. Initialize and configure the first view controller that this coordinator
    ///    will manage, injecting any required dependencies or view models.
    /// 2. Set up any additional state or configuration required for the subsequent
    ///    screens within this navigation flow.
    /// 3. Configure the initial navigation style (e.g., push or modal) based on
    ///    the flow requirements.
    /// 4. Present the view controller using `navigationController`'s methods on
    ///    the main thread to ensure UI consistency.
    /// 5. If any child coordinators are required for sub-flows, instantiate them
    ///    and store them in `childCoordinators`.
    /// 6. Assign necessary delegates or callbacks to maintain communication
    ///    between the coordinator and its managed view controllers.
    /// 7. Initialize any required shared states or data observers for the flow.
    /// 8. Handle error states gracefully if view controller initialization fails,
    ///    ensuring a fallback or user notification is presented.
    func start()
}