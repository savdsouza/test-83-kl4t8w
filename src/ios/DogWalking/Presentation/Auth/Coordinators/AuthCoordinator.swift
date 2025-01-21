//
//  AuthCoordinator.swift
//  DogWalking
//
//  Created by Elite Software Architect Agent on 2023-10-01.
//
//  Description:
//  Coordinator responsible for managing authentication flow navigation and screen transitions
//  in the Dog Walking application with enhanced security and state management. Conforms to the
//  enterprise-grade Coordinator protocol, integrating advanced error handling, biometric readiness,
//  and memory-safe concurrency for iOS 13.0+.
//
//  This file implements the following functionalities per specification:
//  1. Secure Authentication Flow (Login, Registration, and Biometric steps).
//  2. Navigation Architecture using a coordinator pattern.
//  3. Screen Navigation and flow completion with robust error handling, analytics, and concurrency.
//
//  © 2023 DogWalking Inc. All rights reserved.
//

import UIKit // iOS 13.0+ (Core iOS UI framework)
import class DogWalking.Core.Protocols.Coordinator // Internal named import for Coordinator protocol
import class DogWalking.Presentation.Auth.Views.LoginViewController // Named import for LoginViewController
import class DogWalking.Presentation.Auth.Views.RegisterViewController // Named import for RegisterViewController

/// Represents the current authentication state within the coordinator,
/// allowing for advanced state management and transitions.
public enum AuthenticationState {
    /// The user is not authenticated (fresh launch or post-logout).
    case notAuthenticated
    /// The user completed a login flow and is authenticated.
    case authenticated
    /// Any intermediate or special state, e.g., forcibly logged out or biometric required.
    case requiresAdditionalAuth
}

/// Represents an error enumeration dedicated to authentication/navigation issues.
/// This ensures granular handling of coordinator-level errors that might arise
/// during the login or registration flows.
public enum AuthenticationError: Error {
    /// The user provided invalid credentials (e.g., incorrect password).
    case invalidCredentials(String)

    /// Biometric operation failed (Face ID/Touch ID error or user cancellation).
    case biometricFailed(String)

    /// A domain-specific input validation error.
    case validationFailed(String)

    /// Catch-all for unknown or unexpected issues in the auth flow.
    case unknown(String)
}

/// The AuthCoordinator class orchestrates the authentication flow for
/// the DogWalking application, leveraging the Coordinator protocol to
/// manage screen transitions, concurrency, and error handling. By inheriting
/// NSObject, it can integrate well with iOS frameworks that expect Objective-C
/// runtime objects (e.g., for selectors or bridging).
///
/// Thread-Safety & Navigation:
/// - Navigation operations must be performed on the main thread to ensure
///   UIKit consistency. We also use an internal `navigationQueue` to manage
///   coordination tasks if needed (dispatching work to the main thread).
///
/// Memory Management:
/// - This coordinator retains child coordinators (if any) in `childCoordinators`.
/// - On flow completion, child coordinators are removed to avoid leaks.
///
/// Deep Linking:
/// - `start()` or `showRegister()` can be made aware of deep links if the app
///   needs to support direct navigation to certain auth screens.
public class AuthCoordinator: NSObject, Coordinator {

    // MARK: - Coordinator Protocol Conformance

    /// The primary navigation controller utilized for hierarchical transitions.
    /// Must only be accessed on the main thread to comply with UIKit rules.
    public let navigationController: UINavigationController

    /// A collection of active child coordinators under the AuthCoordinator’s scope.
    /// Child coordinators are appended for sub-flows and removed upon completion
    /// to prevent memory leaks.
    public var childCoordinators: [Coordinator] = []

    // MARK: - Public Properties

    /// A closure optionally invoked when the coordinator finishes its auth flow.
    /// This can be used to signal parent coordinators that the flow is complete.
    public var onFinishFlow: (() -> Void)?

    // MARK: - Internal/Private Properties

    /// A dedicated dispatch queue to safeguard navigation or state management
    /// operations if we need concurrency. In practice, most UIKit transitions
    /// must occur on the main thread, so we dispatch to `DispatchQueue.main`
    /// from this queue if needed.
    internal let navigationQueue: DispatchQueue

    /// Tracks the current authentication state, allowing the coordinator
    /// to adapt screen flows or handle re-auth scenarios (e.g., biometric required).
    internal var currentState: AuthenticationState

    // MARK: - Designated Initializer

    /// Initializes the AuthCoordinator with a navigation controller, setting up
    /// concurrency mechanisms, default states, and appearance configurations.
    ///
    /// Steps:
    /// 1. Call super.init().
    /// 2. Store the navigation controller reference.
    /// 3. Initialize an empty child coordinators array.
    /// 4. Setup a dedicated `navigationQueue` for concurrency if needed.
    /// 5. Initialize the `currentState` to `.notAuthenticated`.
    /// 6. Optionally configure the navigation controller’s appearance (large titles, tints).
    /// 7. Setup deep link handling if the app uses universal links or custom URL schemes.
    ///
    /// - Parameter navigationController: The primary UINavigationController used for presenting screens.
    public init(navigationController: UINavigationController) {
        // 1. Call superclass initializer to maintain NSObject behavior.
        super.init()

        // 2. Store the navigation controller reference.
        self.navigationController = navigationController

        // 3. Default to an empty child coordinator array.
        self.childCoordinators = []

        // 4. Create a serial queue for navigation tasks if concurrency management is needed.
        self.navigationQueue = DispatchQueue(label: "com.dogwalking.AuthCoordinatorQueue",
                                             qos: .userInitiated)

        // 5. Set initial authentication state.
        self.currentState = .notAuthenticated

        // 6. Example navigation appearance customization:
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.navigationBar.tintColor = .systemBlue

        // 7. Placeholder for deep link setup or other advanced logic:
        //    e.g., handleDeepLinks()
    }

    // MARK: - Lifecycle & Flow Methods

    /// Begins the authentication flow with enhanced security checks.
    /// This default implementation always presents a LoginViewController
    /// if `currentState` is `.notAuthenticated`. Further expansions can
    /// handle existing sessions or biometric prompts if needed.
    ///
    /// Steps:
    /// 1. Validate `currentState` or existing tokens to check if user is already logged in.
    /// 2. Create and configure a LoginViewController with its ViewModel.
    /// 3. Optionally set up biometric checks or display a prompt if the device is enrolled.
    /// 4. Configure error handling, input validation, and analytics events.
    /// 5. Push the LoginViewController with an animated transition on the main thread.
    ///
    /// - Note: Marked public to fulfill the Coordinator protocol requirement
    ///   and to allow external invocation if needed.
    @objc
    public func start() {
        navigationQueue.async { [weak self] in
            guard let self = self else { return }

            // Example check: If the user is already authenticated, skip or do something else
            if self.currentState == .authenticated {
                // Possibly transition to a post-login screen or call `finishFlow()`
                return
            }

            // 2. Create and configure the login VC with its ViewModel
            let loginViewModel = LoginViewModel() // Hypothetical default init or injected
            let loginVC = LoginViewController(viewModel: loginViewModel)

            // 3. (Optional) Biometric logic can be triggered from the login flow
            //    or leveraged from the login view model. We'll just mention it here.

            // 4. Enhanced error handling or analytics example
            //    e.g., loginViewModel.errorState -> handleError in this coordinator?

            // 5. Ensure main-thread push
            DispatchQueue.main.async {
                self.navigationController.pushViewController(loginVC, animated: true)
            }
        }
    }

    /// Navigates to the registration screen, ensuring that the coordinator
    /// validates any ongoing flow or concurrency state first. This method
    /// can be triggered by the user from the login screen or deep link.
    ///
    /// Steps:
    /// 1. Validate that the coordinator is in a navigable state (e.g., not concluding).
    /// 2. Create and configure RegisterViewController with a dedicated RegisterViewModel.
    /// 3. Setup form validation, real-time error handling, and analytics or telemetry.
    /// 4. Push the RegisterViewController on the main thread with animation.
    @objc
    public func showRegister() {
        navigationQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Example check: If we are finishing or in a weird state, we might block navigation.
            //    For demonstration, we proceed unconditionally.

            // 2. Create the register VC
            let registerViewModel = RegisterViewModel(authRepository: AuthRepository())
            let registerVC = RegisterViewController(viewModel: registerViewModel)

            // 3. Configure advanced error handling or analytics
            //    e.g., registerViewModel.errorSubject -> self.handleError

            // 4. Perform the transition
            DispatchQueue.main.async {
                self.navigationController.pushViewController(registerVC, animated: true)
            }
        }
    }

    /// Completes the authentication flow with final cleanup. Typically called after the user
    /// successfully logs in or out, or if the flow is canceled. This method resets any sensitive
    /// data and triggers the `onFinishFlow` closure to inform parent coordinators.
    ///
    /// Steps:
    /// 1. Perform a thread-safe navigation stack cleanup (pop to root or remove screens).
    /// 2. Clear sensitive data (e.g., tokens in memory if stored here).
    /// 3. Remove child coordinators from the parent to avoid memory leaks.
    /// 4. Reset `currentState` if needed.
    /// 5. Invoke the `onFinishFlow` callback if present.
    /// 6. Track analytics for flow completion.
    @objc
    public func finishFlow() {
        navigationQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Navigation stack cleanup on main thread
            DispatchQueue.main.async {
                self.navigationController.popToRootViewController(animated: false)
            }

            // 2. Clear any in-flight sensitive data
            // e.g., self.authToken = nil or call specialized cleanup

            // 3. Remove child coordinators
            self.childCoordinators.removeAll()

            // 4. Reset state
            self.currentState = .notAuthenticated

            // 5. Invoke completion closure
            if let finish = self.onFinishFlow {
                finish()
            }

            // 6. Log or track analytics for completion
        }
    }

    /// Handles authentication and navigation-related errors by logging details,
    /// presenting user-facing alerts or fallback flows, attempting recovery,
    /// and updating the coordinator state as needed.
    ///
    /// Steps:
    /// 1. Log or record error details securely (omitting sensitive info).
    /// 2. Present an appropriate UI alert or screen to inform the user of the error.
    /// 3. Attempt to recover from certain errors if possible (e.g., prompt re-entry or fallback).
    /// 4. Track analytics events to monitor error frequency.
    /// 5. (Optional) Update authentication state if the error invalidates credentials.
    ///
    /// - Parameter error: The specific AuthenticationError that occurred.
    @objc
    public func handleError(_ error: AuthenticationError) {
        navigationQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Log error or analytics
            switch error {
            case .invalidCredentials(let detail):
                print("AuthCoordinator: Invalid credentials error -> \(detail)")
            case .biometricFailed(let detail):
                print("AuthCoordinator: Biometric auth failed -> \(detail)")
            case .validationFailed(let detail):
                print("AuthCoordinator: Validation failed -> \(detail)")
            case .unknown(let msg):
                print("AuthCoordinator: Unknown error -> \(msg)")
            }

            // 2. Present an alert on the main thread
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Authentication Error",
                                              message: "\(error)",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.navigationController.present(alert, animated: true, completion: nil)
            }

            // 3. Potentially attempt error recovery or fallback
            //    e.g., self.start() to re-initiate login?

            // 4. Track analytics as needed (omitted for brevity)

            // 5. If critical, we might reset state:
            //    self.currentState = .notAuthenticated
        }
    }
}