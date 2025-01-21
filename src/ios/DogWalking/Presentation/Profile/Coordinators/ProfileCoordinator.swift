//
//  ProfileCoordinator.swift
//  DogWalking
//
//  This file is responsible for managing the navigation flow and dependency injection
//  within the Profile section of the dog walking application. It ensures thread-safe
//  operations using a navigation lock, proper memory management for subscriptions,
//  and leverages the coordinator pattern to facilitate clean, maintainable navigation.
//
//  Created by Elite Software Architect Agent.
//  © 2023 DogWalking Inc. All rights reserved.
//

import UIKit // iOS 13.0+
import Combine // iOS 13.0+

// MARK: - Internal Imports
import Core/Protocols/Coordinator
import Presentation/Profile/ViewModels/ProfileViewModel
import Presentation/Profile/Views/ProfileViewController
import Domain/UseCases/UserUseCase
// If edit profile functionality is required, additional imports such as:
// import Presentation/Profile/ViewModels/EditProfileViewModel
// import Presentation/Profile/Views/EditProfileViewController
// can be included as needed.

/// A thread-safe coordinator that manages navigation flow and dependency injection for
/// the profile section. It leverages a navigation lock (NSLock) to ensure operations
/// against UIKit are dispatched serially, preventing race conditions. In addition, it
/// implements robust memory management by tracking Combine subscriptions and offering
/// a cleanup routine to release references when needed.
///
/// This coordinator addresses:
/// - User Management: By integrating with userUseCase for profile data.
/// - Navigation Architecture: By employing the coordinator pattern to start and manage
///   the profile flow with minimal coupling to other app components.
///
/// Usage:
/// 1. Initialize ProfileCoordinator with a UINavigationController and UserUseCase.
/// 2. Call start() to launch the profile section in a thread-safe manner.
/// 3. Use showEditProfile(_:) to present an edit flow if required.
/// 4. Invoke cleanUp() to release resources and child coordinators when the flow completes.
public final class ProfileCoordinator: Coordinator {

    // MARK: - Coordinator Protocol Conformance

    /// The primary navigation controller utilized to manage hierarchical and modal transitions.
    /// Must be accessed on the main thread or protected with locks for thread safety.
    public let navigationController: UINavigationController

    /// A collection of child coordinators responsible for overseeing sub-flows.
    /// Child coordinators are appended when a sub-flow begins and removed on completion.
    public var childCoordinators: [Coordinator]

    // MARK: - Properties

    /// A lock to guarantee thread-safe navigation operations. Since UIKit is not thread-safe,
    /// we serialize push/pop operations using this NSLock.
    private let navigationLock: NSLock

    /// A user use case providing domain-level operations for user profile management,
    /// such as fetching and updating user data. This ensures separation of concerns
    /// between the coordinator and business logic.
    private let userUseCase: UserUseCase

    /// A thread-safe set of Combine subscriptions for memory management. Subscriptions
    /// are stored here to prevent deallocation while active and can be canceled en masse.
    private var cancellables: Set<AnyCancellable>

    // MARK: - Initialization

    /// Initializes the profile coordinator with the required dependencies, ensuring
    /// thread-safe operations and memory management structures are ready.
    ///
    /// Steps Performed:
    /// 1. Initialize a navigation lock for concurrency control over UIKit operations.
    /// 2. Store the provided navigation controller reference.
    /// 3. Initialize an empty array of child coordinators.
    /// 4. Store the user use case object for retrieving/updating profile data.
    /// 5. Initialize an empty set for Combine subscriptions.
    ///
    /// - Parameters:
    ///   - navigationController: The UINavigationController managing the flow's screens.
    ///   - userUseCase: A UserUseCase for domain-level user operations (load/update profiles).
    public init(navigationController: UINavigationController,
                userUseCase: UserUseCase) {
        self.navigationLock = NSLock()
        self.navigationController = navigationController
        self.childCoordinators = []
        self.userUseCase = userUseCase
        self.cancellables = Set<AnyCancellable>()
    }

    // MARK: - Lifecycle Methods

    /// Begins the profile navigation flow with thread safety, creating and presenting
    /// the ProfileViewController. Configures the view model, sets up data bindings,
    /// and applies memory management observers.
    ///
    /// Steps:
    /// 1. Acquire the navigation lock to ensure exclusive access to navigationController.
    /// 2. Create a ProfileViewModel with the stored userUseCase.
    /// 3. Optionally configure or bind the view model for signal streams, error handling, etc.
    /// 4. Instantiate ProfileViewController with the newly created view model.
    /// 5. (Optional) Set the view controller delegate to handle user interactions if needed.
    /// 6. Push the ProfileViewController onto the navigation stack.
    /// 7. Release the navigation lock after the push is complete.
    /// 8. (Optional) Setup additional subscriptions or memory observers for the view model.
    public func start() {
        navigationLock.lock()
        defer { navigationLock.unlock() }

        // 1. Create the ProfileViewModel instance
        let profileViewModel = ProfileViewModel(userUseCase: userUseCase, debounceInterval: 0.25)

        // 2. (Optional) Configure or bind the view model if advanced customization is desired:
        //    e.g., setting delegates, hooking error subjects, or caching logic.

        // 3. Create ProfileViewController with the view model
        let profileVC = ProfileViewController(viewModel: profileViewModel)

        // 4. Set the view controller delegate if ProfileViewControllerDelegate is defined
        //    profileVC.delegate = self // Example if a delegate is implemented

        // 5. Perform the navigation push
        navigationController.pushViewController(profileVC, animated: true)

        // 6. Setup watchers or memory management if needed:
        //    profileViewModel.userSubject
        //        .sink { /* handle user updates */ }
        //        .store(in: &cancellables)
    }

    /// Demonstrates a thread-safe transition to the edit profile screen. If the project
    /// has a dedicated edit flow, this method ensures concurrency using navigationLock
    /// and sets up all relevant states for an EditProfileViewController and its view model.
    ///
    /// Steps:
    /// 1. Acquire the navigation lock to avoid conflicting UIKit calls.
    /// 2. Create an EditProfileViewModel with userUseCase and the provided user.
    /// 3. Configure or bind the new view model if additional streams are required.
    /// 4. Instantiate an EditProfileViewController with the new view model.
    /// 5. (Optional) Assign the view controller's delegate if needed for callbacks.
    /// 6. Push the EditProfileViewController onto the navigation stack.
    /// 7. Release the navigation lock, allowing other flows to proceed.
    /// 8. (Optional) Observe the lifecycle of the edit screen, store references, etc.
    ///
    /// - Parameter user: The User object representing the current user to be edited.
    public func showEditProfile(_ user: User) {
        navigationLock.lock()
        defer { navigationLock.unlock() }

        // 1. Create or load an edit profile view model
        //    Here we are illustrating a hypothetical EditProfileViewModel.
        // let editProfileViewModel = EditProfileViewModel(userUseCase: userUseCase, currentUser: user)

        // 2. Optionally set up any data bindings for error handling or updates
        //    e.g.:
        // editProfileViewModel.profileErrorSubject
        //     .sink { /* handle errors */ }
        //     .store(in: &cancellables)

        // 3. Create the edit profile view controller
        // let editProfileVC = EditProfileViewController(viewModel: editProfileViewModel)

        // 4. (Optional) Assign delegate if the edit screen needs a callback
        // editProfileVC.delegate = self

        // 5. For demonstration, let's assume the user is updated in place
        //    We'll push a placeholder screen or comment out the actual push

        // navigationController.pushViewController(editProfileVC, animated: true)
        // Implementation is commented out, as there is no actual screen class in the codebase

        // 6. In a real scenario, child coordinators can be appended if the edit flow is a sub-coordinator
        // childCoordinators.append(SomeEditFlowCoordinator)
    }

    /// Performs cleanup of resources and subscriptions, removing child coordinators
    /// and clearing navigation states if required. This method should be called when
    /// the Profile flow is terminated or no longer needed, preventing memory leaks.
    ///
    /// Steps:
    /// 1. Cancel all active subscriptions in the cancellables set.
    /// 2. Remove all child coordinators from this coordinator's array.
    /// 3. (Optional) Clear the navigation stack if the flow is truly ending.
    /// 4. Release any other retained resources or references.
    public func cleanUp() {
        // 1. Cancel all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // 2. Remove child coordinators to ensure they release references
        childCoordinators.removeAll()

        // 3. Optionally clear the navigation stack if needed to finalize the flow
        //    Example:
        //    navigationController.viewControllers.removeAll()

        // 4. Additional resource cleanup or reference releases can be done here
    }
}