//
//  RegisterViewController.swift
//  DogWalking
//
//  This file implements a view controller for user registration, handling
//  comprehensive validation, accessibility support, and a secure registration
//  flow with email/password and user type selection. It leverages Combine
//  for real-time feedback and integrates with the RegisterViewModel.
//
//  Created by Elite Software Architect on 2023-10-01.
//  © 2023 DogWalking Inc. All rights reserved.
//

import UIKit // iOS 13.0+
import Combine // iOS 13.0+

// MARK: - Internal Imports
import Core/Base/BaseViewController
import Presentation/Auth/ViewModels/RegisterViewModel
import Presentation/Common/Views/CustomTextField
import Presentation/Common/Views/CustomButton

/// A view controller responsible for handling the user registration interface,
/// integrating real-time validation, accessibility, and security best practices.
/// Inherits from BaseViewController to leverage shared UI setup, error handling,
/// and memory-safe Combine subscriptions.
public final class RegisterViewController: BaseViewController {

    // MARK: - Properties

    /// The registration view model, providing input subjects and output publishers
    /// for a secure and reactive user registration flow.
    private let viewModel: RegisterViewModel

    /// Custom text field for the user's email input, configured with accessibility,
    /// validation style, and dynamic layout constraints.
    private let emailTextField: CustomTextField = {
        let tf = CustomTextField()
        tf.validationType = .email
        tf.placeholderText = "Email Address"
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.accessibilityLabel = "Email"
        return tf
    }()

    /// Custom text field for the user's password input, configured with secure text
    /// entry, validation style, and dynamic layout constraints.
    private let passwordTextField: CustomTextField = {
        let tf = CustomTextField()
        tf.validationType = .password
        tf.isSecureTextEntry = true
        tf.placeholderText = "Password"
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.accessibilityLabel = "Password"
        return tf
    }()

    /// Custom text field for the user's first name input.
    /// No built-in validation style, but required field in final checks.
    private let firstNameTextField: CustomTextField = {
        let tf = CustomTextField()
        tf.validationType = .none
        tf.placeholderText = "First Name"
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.accessibilityLabel = "First Name"
        return tf
    }()

    /// Custom text field for the user's last name input.
    /// No built-in validation style, but required field in final checks.
    private let lastNameTextField: CustomTextField = {
        let tf = CustomTextField()
        tf.validationType = .none
        tf.placeholderText = "Last Name"
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.accessibilityLabel = "Last Name"
        return tf
    }()

    /// A segmented control allowing the user to select their account type:
    /// Owner or Walker. Maps to the ViewModel's userTypeSubject.
    private let userTypeSegmentControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Owner", "Walker"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.accessibilityLabel = "Account Type"
        return sc
    }()

    /// The registration button, implemented as a custom button with loading states
    /// and consistent design system styling. Tapping it triggers the registration flow.
    private let registerButton: CustomButton = {
        let button = CustomButton(style: .primary)
        button.setTitle("Register", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Register Button"
        return button
    }()

    /// A set of AnyCancellable references for Combine subscriptions, ensuring memory safety.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    /// Initializes the register view controller with a given view model.
    /// Sets up the required UI components, accessibility configurations,
    /// and Combine-related subscriptions for real-time form validation.
    ///
    /// - Parameter viewModel: The RegisterViewModel responsible for handling
    ///   input validation and registration logic.
    public init(viewModel: RegisterViewModel) {
        // 1. Assign the provided view model before calling super.init
        self.viewModel = viewModel

        // 2. Call super.init for BaseViewController
        super.init(nibName: nil, bundle: nil)

        // 3. Further initialization can occur here if needed
        //    (e.g., advanced theming or extended property setup).
    }

    /// Required initializer for using RegisterViewController from storyboards or XIBs.
    /// Not supported in this scenario, so we throw a fatalError.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for RegisterViewController.")
    }

    // MARK: - View Lifecycle

    /// Called after the controller's view is loaded into memory. This override sets up
    /// UI components, applies constraints, configures accessibility elements,
    /// and initiates any Combine subscriptions by calling bindViewModel.
    public override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Configure the UI
        setupUI()

        // 2. Bind the view model with Combine
        bindViewModel()
    }

    /// Configures the UI components' appearance, layout, accessibility, and interactive
    /// behaviors. Also prepares the register button's target-action for triggering
    /// registration logic.
    public override func setupUI() {
        super.setupUI() // Call BaseViewController's default UI setup if needed

        // 1. Set the navigation title for clarity on larger navigation bars
        navigationItem.title = "Register"

        // 2. Add subviews
        view.addSubview(emailTextField)
        view.addSubview(passwordTextField)
        view.addSubview(firstNameTextField)
        view.addSubview(lastNameTextField)
        view.addSubview(userTypeSegmentControl)
        view.addSubview(registerButton)

        // 3. Configure additional UI properties if needed (background color, theme, etc.)
        view.backgroundColor = .systemBackground

        // 4. Add target for userTypeSegmentControl to capture selection changes
        userTypeSegmentControl.addTarget(self, action: #selector(didChangeUserType(_:)), for: .valueChanged)

        // 5. Add target for register button to trigger handleRegistration
        registerButton.addTarget(self, action: #selector(handleRegistration), for: .touchUpInside)

        // 6. Activate layout constraints for all UI components with
        //    extensive detail for an enterprise-grade code style

        NSLayoutConstraint.activate([
            // Email TextField Constraints
            emailTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),

            // Password TextField Constraints
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),

            // First Name TextField Constraints
            firstNameTextField.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 16),
            firstNameTextField.leadingAnchor.constraint(equalTo: passwordTextField.leadingAnchor),
            firstNameTextField.trailingAnchor.constraint(equalTo: passwordTextField.trailingAnchor),
            firstNameTextField.heightAnchor.constraint(equalToConstant: 50),

            // Last Name TextField Constraints
            lastNameTextField.topAnchor.constraint(equalTo: firstNameTextField.bottomAnchor, constant: 16),
            lastNameTextField.leadingAnchor.constraint(equalTo: firstNameTextField.leadingAnchor),
            lastNameTextField.trailingAnchor.constraint(equalTo: firstNameTextField.trailingAnchor),
            lastNameTextField.heightAnchor.constraint(equalToConstant: 50),

            // UserType Segmented Control Constraints
            userTypeSegmentControl.topAnchor.constraint(equalTo: lastNameTextField.bottomAnchor, constant: 24),
            userTypeSegmentControl.leadingAnchor.constraint(equalTo: lastNameTextField.leadingAnchor),
            userTypeSegmentControl.trailingAnchor.constraint(equalTo: lastNameTextField.trailingAnchor),
            userTypeSegmentControl.heightAnchor.constraint(equalToConstant: 32),

            // Register Button Constraints
            registerButton.topAnchor.constraint(equalTo: userTypeSegmentControl.bottomAnchor, constant: 32),
            registerButton.leadingAnchor.constraint(equalTo: userTypeSegmentControl.leadingAnchor),
            registerButton.trailingAnchor.constraint(equalTo: userTypeSegmentControl.trailingAnchor),
            registerButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Binding Methods

    /// Sets up reactive data binding with the RegisterViewModel using Combine. This
    /// includes publishing user input changes to the view model subjects, as well as
    /// subscribing to loading, validation, and error outputs for real-time updates.
    private func bindViewModel() {
        // Combine subscription for real-time text changes → viewModel subjects

        // Email
        emailTextField
            .publisher(for: \.text)
            .sink { [weak self] newText in
                guard let self = self, let text = newText else { return }
                self.viewModel.emailSubject.send(text)
            }
            .store(in: &cancellables)

        // Password
        passwordTextField
            .publisher(for: \.text)
            .sink { [weak self] newText in
                guard let self = self, let text = newText else { return }
                self.viewModel.passwordSubject.send(text)
            }
            .store(in: &cancellables)

        // First Name
        firstNameTextField
            .publisher(for: \.text)
            .sink { [weak self] newText in
                guard let self = self, let text = newText else { return }
                self.viewModel.firstNameSubject.send(text)
            }
            .store(in: &cancellables)

        // Last Name
        lastNameTextField
            .publisher(for: \.text)
            .sink { [weak self] newText in
                guard let self = self, let text = newText else { return }
                self.viewModel.lastNameSubject.send(text)
            }
            .store(in: &cancellables)

        // Subscribe to validation state for enabling/disabling the register button
        viewModel.isValidSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isValid in
                self?.registerButton.isEnabled = isValid
                self?.registerButton.alpha = isValid ? 1.0 : 0.5
            }
            .store(in: &cancellables)

        // Subscribe to loading state for the register button's loading display
        viewModel.isLoadingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.registerButton.setLoading(isLoading)
            }
            .store(in: &cancellables)

        // Subscribe to errors and display them with showError function from BaseViewController
        viewModel.errorSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
    }

    // MARK: - User Actions

    /// Invoked when the user changes the selection in the segmented control, mapping
    /// the choice to the appropriate UserType in the view model.
    ///
    /// - Parameter sender: The UISegmentedControl whose value changed.
    @objc private func didChangeUserType(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        if index == 0 {
            viewModel.userTypeSubject.send(.owner)
        } else {
            viewModel.userTypeSubject.send(.walker)
        }
    }

    /// Handles the registration button tap by validating inputs, showing loading
    /// states, disabling interaction, and calling the view model's registration flow.
    /// Real-time feedback is provided through Combine subscriptions (loading, error, etc.).
    @objc private func handleRegistration() {
        // 1. Attempt to register through the view model
        //    This triggers a publish flow that we can subscribe to here if desired.
        viewModel.register()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                // Re-enable user interaction and hide loading if an error occurs
                switch completion {
                case .finished:
                    // Possibly navigate to a success screen or do post-registration steps
                    break
                case .failure(let error):
                    // This error can also come through errorSubject, but handle any local logic here
                    self?.showError(error)
                }
            }, receiveValue: { [weak self] result in
                // On successful registration, proceed to next screen or show confirmation
                // Here we might navigate to a main/home screen or show a message
                self?.navigationController?.popViewController(animated: true)
            })
            .store(in: &cancellables)
    }
}