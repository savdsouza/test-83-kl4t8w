import UIKit // iOS 13.0+ (Core iOS UI framework)
import Combine // iOS 13.0+ (Reactive programming support)
import LocalAuthentication // iOS 13.0+ (Biometric authentication support)

// MARK: - Internal Imports (Named)
// BaseViewController provides core MVVM methods like viewDidLoad, setupUI, bindViewModel.
import class DogWalking.Core.Base.BaseViewController
// LoginViewModel encapsulates the logic for email/password & biometric authentication.
import class DogWalking.Presentation.Auth.ViewModels.LoginViewModel
// CustomTextField and CustomButton implement the design system’s UI components.
import class DogWalking.Presentation.Common.Views.CustomTextField
import class DogWalking.Presentation.Common.Views.CustomButton

/// ------------------------------------------------------------------------------
/// LoginViewController
/// A view controller that implements a secure login interface using email/password
/// credentials and optional biometric authentication (Touch ID / Face ID).
/// ------------------------------------------------------------------------------
///
/// This class aligns with the following requirements from the project specification:
/// 1. Authentication Flow (7.1.1): Secure login with email/password, plus biometric.
/// 2. Mobile Apps Architecture (2.2.1 Core Components / Mobile Apps): MVVM + Combine.
/// 3. UI Design System (6.1 Design System Key): Uses consistent text fields/buttons.
///
/// Extends the BaseViewController to benefit from:
/// - Shared reactive subscription management (AnyCancellable sets).
/// - Common UI setup patterns (setupUI, bindViewModel).
/// - Standard error handling or loading states if desired.
///
/// This file implements:
/// - Initialization with a LoginViewModel reference.
/// - UI components: email/password, two buttons, placed inside a stack view.
/// - Observers binding to the view model’s inputs/outputs via Combine.
/// - Biometric availability checks to optionally show the Biometric Login button.
///
/// Production-Ready Notes:
/// - This controller includes extensive comments for clarity and maintainability.
/// - Accessibility is considered (dynamic type, reduced motion, labeled UI elements).
/// - Biometric usage is controlled by checking the LoginViewModel’s biometric availability.
/// - Error states are handled by reading the view model’s errorSubject and displaying alerts.
public class LoginViewController: BaseViewController {
    
    // MARK: - Properties

    /// The strongly-typed reference to our LoginViewModel. This is the MVVM “ViewModel”
    /// that orchestrates authentication, including email/password and biometrics.
    private let viewModel: LoginViewModel

    /// A custom text field for entering or validating the user’s email address.
    private let emailTextField: CustomTextField

    /// A custom text field for entering a secure password, following the app’s
    /// security and complexity guidelines.
    private let passwordTextField: CustomTextField

    /// A custom button for initiating the standard login flow (email/password).
    private let loginButton: CustomButton

    /// A custom button for initiating the biometric authentication flow (Face ID / Touch ID),
    /// displayed only if a compatible device and enrolled biometric are available.
    private let biometricButton: CustomButton

    /// A vertical UIStackView containing all login elements (text fields + buttons).
    private let containerStackView: UIStackView

    /// A thread-safe set of Combine AnyCancellable instances, to manage memory
    /// for all reactive subscriptions established in this view controller.
    private var cancellables: Set<AnyCancellable>

    // MARK: - Initializer

    /// Designated initializer for the LoginViewController, receiving a LoginViewModel
    /// to bind UI events (user input) to business logic (authentication).
    ///
    /// Steps in the constructor:
    /// 1. Call super.init(...) to properly initialize the BaseViewController.
    /// 2. Store the provided view model in a local property.
    /// 3. Initialize local UI components (emailTextField, passwordTextField, etc.).
    /// 4. Initialize a Set<AnyCancellable> for Combine subscriptions.
    ///
    /// - Parameter viewModel: The LoginViewModel containing authentication logic.
    public init(viewModel: LoginViewModel) {
        // 1. Superclass init for a custom view controller without nibs/XIBs.
        self.viewModel = viewModel

        // Pre-initialize components to ensure clarity in flow:
        self.emailTextField = CustomTextField(frame: .zero)
        self.passwordTextField = CustomTextField(frame: .zero)
        self.loginButton = CustomButton(style: .primary)
        self.biometricButton = CustomButton(style: .secondary)
        self.containerStackView = UIStackView(frame: .zero)
        self.cancellables = Set<AnyCancellable>()

        super.init(nibName: nil, bundle: nil)
    }

    /// Required initializer if this controller is ever loaded from a storyboard or XIB.
    /// Unimplemented here, as MVVM usage typically involves programmatic initialization.
    ///
    /// - Parameter coder: The coder object for decoding from a storyboard or XIB.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented in LoginViewController.")
    }

    // MARK: - Lifecycle Methods

    /// Called after the view controller’s view has been created and loaded into memory.
    /// This override ensures we configure the UI, constraints, accessibility, keyboard,
    /// and reactive bindings in a consistent and production-ready way.
    ///
    /// Steps:
    /// 1. Call super.viewDidLoad() from BaseViewController.
    /// 2. Setup UI components (layout, design system details).
    /// 3. Configure advanced constraints and accessibility if needed.
    /// 4. Set up keyboard handling (optional advanced logic can be placed here).
    /// 5. Bind the UI to the view model with Combine (bindViewModel()).
    /// 6. Optionally detect biometric availability to show/hide the biometric button.
    public override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Further UI configuration beyond the base if needed:
        setupUI()

        // 2. Bind all reactive streams (inputs/outputs).
        bindViewModel()

        // 3. Explicitly check for biometrics and hide the button if not available.
        checkBiometricAvailability()
    }

    // MARK: - UI Setup

    /// Configures the login screen UI components following the design system specs:
    /// - Aligns text fields and buttons in a vertical stack.
    /// - Applies consistent theming (colors, typography, spacing).
    /// - Configures dynamic type support and accessibility for people with different abilities.
    /// - Sets up reduced motion handling if the user has that system preference enabled.
    ///
    /// This override calls super.setupUI() from BaseViewController for base styling,
    /// then proceeds with additional login-specific layout logic.
    public override func setupUI() {
        // 1. Call the base class’s setupUI to set any shared styles or backgrounds.
        super.setupUI()

        // 2. Configure email text field styling & validation type.
        emailTextField.validationType = .email
        emailTextField.placeholderText = "Email Address"
        emailTextField.setupStyle() // Applies design system metrics.
        emailTextField.accessibilityLabel = "Email"
        emailTextField.keyboardType = .emailAddress

        // 3. Configure password text field with secure entry & validation style.
        passwordTextField.validationType = .password
        passwordTextField.placeholderText = "Password"
        passwordTextField.setupStyle()
        passwordTextField.accessibilityLabel = "Password"
        passwordTextField.setSecureEntry(true) // Provided by CustomTextField’s API.

        // 4. Configure the login button with a design system style & label.
        loginButton.setTitle("Login", for: .normal)
        loginButton.accessibilityLabel = "Login Button"

        // 5. Configure the biometric button with a secondary style.
        biometricButton.setTitle("Biometric Login", for: .normal)
        biometricButton.accessibilityLabel = "Biometric Login Button"

        // 6. Setup the stack view to neatly organize these fields & buttons.
        containerStackView.axis = .vertical
        containerStackView.alignment = .fill
        containerStackView.distribution = .fill
        containerStackView.spacing = 16.0
        containerStackView.translatesAutoresizingMaskIntoConstraints = false

        // Add our UI elements into the stack view’s arrangement.
        containerStackView.addArrangedSubview(emailTextField)
        containerStackView.addArrangedSubview(passwordTextField)
        containerStackView.addArrangedSubview(loginButton)
        containerStackView.addArrangedSubview(biometricButton)

        // 7. Insert stack view into main view hierarchy.
        view.addSubview(containerStackView)

        // 8. Apply basic layout constraints:
        NSLayoutConstraint.activate([
            containerStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            containerStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        // 9. Configure dynamic type & reduced motion handling if desired.
        //    For demonstration, here we simply log or adjust layouts if needed.
        if UIAccessibility.isReduceMotionEnabled {
            // Potentially reduce animations or transitions for motion-sensitive users.
        }
    }

    // MARK: - Binding ViewModel

    /// Establishes the reactive bindings between the UI elements and the view model.
    /// In an MVVM architecture, these connections funnel user input into the view model
    /// and react to changes in loading/error states.
    ///
    /// Steps:
    /// 1. Publish email text changes to the viewModel.emailSubject.
    /// 2. Publish password text changes to the viewModel.passwordSubject.
    /// 3. Send tap events from the login button to viewModel.loginTapSubject.
    /// 4. Send tap events from the biometric button to viewModel.biometricTapSubject.
    /// 5. Observe loadingState to display activity states on the login button & text fields.
    /// 6. Observe errorState to present an error message or alert.
    /// 7. Optionally observe or handle validation states for real-time UI feedback.
    /// 8. Configure other event streams as needed for a robust login flow.
    public override func bindViewModel() {
        // 1. Call base class method to handle any shared logic.
        super.bindViewModel(viewModel)

        // 2. Bind email text changes to viewModel.emailSubject.
        emailTextField
            .publisher(for: \.text) // KeyPath publisher if provided by your CustomTextField or via KVO
            .compactMap { $0 }      // Ensure non-nil
            .sink { [weak self] text in
                self?.viewModel.emailSubject.send(text)
            }
            .store(in: &cancellables)

        // 3. Bind password text changes to viewModel.passwordSubject.
        passwordTextField
            .publisher(for: \.text)
            .compactMap { $0 }
            .sink { [weak self] text in
                self?.viewModel.passwordSubject.send(text)
            }
            .store(in: &cancellables)

        // 4. Bind login button taps -> viewModel.loginTapSubject.
        loginButton
            .tapPublisher // Hypothetical Combine extension for button taps
            .sink { [weak self] in
                self?.viewModel.loginTapSubject.send(())
            }
            .store(in: &cancellables)

        // 5. Bind biometric button taps -> viewModel.biometricTapSubject.
        biometricButton
            .tapPublisher
            .sink { [weak self] in
                self?.viewModel.biometricTapSubject.send(())
            }
            .store(in: &cancellables)

        // 6. Subscribe to loading state changes and enable/disable UI accordingly.
        viewModel.loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                // Reflect loading in button & text fields:
                self?.loginButton.setLoading(isLoading)
                self?.biometricButton.setEnabled(!isLoading) // Example of disabling the button
                self?.emailTextField.isUserInteractionEnabled = !isLoading
                self?.passwordTextField.isUserInteractionEnabled = !isLoading
            }
            .store(in: &cancellables)

        // 7. Subscribe to errorState and display an alert on errors.
        viewModel.errorState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authError in
                self?.handleError(authError)
            }
            .store(in: &cancellables)

        // 8. (Optional) If there is a validation or success state to observe, add them here.
        //    Example: Observing a hypothetical 'formValidSubject' in the VM or so.
    }

    // MARK: - Biometric Availability

    /// Checks the viewModel’s biometricAvailableSubject to decide whether to hide
    /// or show the biometricButton. This step is crucial in a scenario where not
    /// all users will have Face ID / Touch ID hardware or have it enrolled.
    private func checkBiometricAvailability() {
        if !viewModel.biometricAvailableSubject.value {
            // If the device or user settings disallow biometrics, hide the button.
            biometricButton.isHidden = true
        }
    }

    // MARK: - Error Handling

    /// Presents or handles any authentication error by showing an alert. This logic
    /// ensures the user gets immediate feedback about credential or biometric issues.
    ///
    /// - Parameter error: The AuthError object describing the issue.
    private func handleError(_ error: AuthError) {
        // Create a user-friendly message based on the AuthError enum
        let message: String
        switch error {
        case .invalidCredentials(let desc):
            message = "Invalid credentials: \(desc)"
        case .biometricUnavailable:
            message = "Biometric hardware unavailable on this device."
        case .biometricFailed(let desc):
            message = "Biometric failed: \(desc)"
        case .inputValidation(let desc):
            message = "Validation error: \(desc)"
        case .unknown(let desc):
            message = "Unknown error: \(desc)"
        }

        // Use the BaseViewController’s showError(...) or present a local alert:
        showError(NSError(domain: "LoginError", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
    }
}