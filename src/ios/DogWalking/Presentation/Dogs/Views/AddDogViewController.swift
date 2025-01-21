//
//  AddDogViewController.swift
//  DogWalking
//
//  View controller responsible for handling the addition of new dog profiles in the application,
//  implementing MVVM pattern with reactive data binding, supporting accessibility,
//  dark mode, and state restoration.
//
//  Created by Elite Software Architect Agent on 2023-10-25.
//  © 2023 DogWalking Inc. All rights reserved.
//
// MARK: - Imports
//
// • UIKit (iOS 13.0+) for fundamental UI components and event handling
// • Combine (iOS 13.0+) for reactive programming and data binding
// • Internal modules for BaseViewController, AddDogViewModel, and CustomTextField
//

import UIKit // iOS 13.0+ (Core iOS UI framework functionality)
import Combine // iOS 13.0+ (Reactive programming support)

// MARK: - Internal Imports
// Importing the BaseViewController, which provides standardized lifecycle handling and memory management.
import class DogWalking.Core.Base.BaseViewController

// Importing the AddDogViewModel, which contains the logical layer for creating a new dog profile.
import class DogWalking.Presentation.Dogs.ViewModels.AddDogViewModel
import var DogWalking.Presentation.Dogs.ViewModels.AddDogViewModel.nameSubject
import var DogWalking.Presentation.Dogs.ViewModels.AddDogViewModel.breedSubject
import var DogWalking.Presentation.Dogs.ViewModels.AddDogViewModel.birthDateSubject
import var DogWalking.Presentation.Dogs.ViewModels.AddDogViewModel.submitSubject
import var DogWalking.Presentation.Dogs.ViewModels.AddDogViewModel.validationState

// Importing CustomTextField, a specialized UI component with validation and styled error display.
import class DogWalking.Presentation.Common.Views.CustomTextField
import func DogWalking.Presentation.Common.Views.CustomTextField.validate
import func DogWalking.Presentation.Common.Views.CustomTextField.showError

///
/// AddDogViewController
/// --------------------
/// A dedicated view controller for adding new dog profiles, providing:
/// - Comprehensive form validation
/// - Real-time feedback via Combine
/// - Accessibility support
/// - Dark mode adaptability
/// - State restoration
///
/// Conforms to MVVM by binding UI elements to the AddDogViewModel.
///
public final class AddDogViewController: BaseViewController {
    
    // MARK: - Properties
    
    /// The view model responsible for managing logic behind dog profile creation.
    private let viewModel: AddDogViewModel
    
    /// A thread-safe set of Combine cancellables to store subscriptions.
    private var cancellables: Set<AnyCancellable>
    
    /// A custom text field for the dog's name input, featuring real-time validation.
    private let nameTextField: CustomTextField
    
    /// A custom text field for the dog's breed input, also featuring real-time validation.
    private let breedTextField: CustomTextField
    
    /// A date picker used to specify the dog's birth date.
    private let birthDatePicker: UIDatePicker
    
    /// A button that, when tapped, triggers dog profile submission logic through the viewModel.
    private let submitButton: UIButton
    
    /// A scroll view to support form scrolling, particularly when the keyboard appears.
    private let scrollView: UIScrollView
    
    /// A stack view that arranges form elements vertically in the scroll view.
    private let formStackView: UIStackView
    
    /// An activity indicator to show background loading or submission in progress.
    private let loadingIndicator: UIActivityIndicatorView
    
    /// A label meant for any top-level error messages that are not field-specific.
    private let errorLabel: UILabel
    
    /// A layout constraint that adjusts the scroll view's bottom or content offset
    /// when the keyboard appears or disappears.
    private var keyboardConstraint: NSLayoutConstraint
    
    // MARK: - Initializers
    
    /// Designated initializer for AddDogViewController.
    /// This method sets up the initial state, configures local properties, and
    /// registers for keyboard notifications for dynamic layout adjustments.
    ///
    /// Steps (as specified in the JSON definition):
    /// 1. Call super.init()
    /// 2. Store view model reference
    /// 3. Initialize UI components
    /// 4. Initialize cancellables set
    /// 5. Setup accessibility identifiers
    /// 6. Register for keyboard notifications
    ///
    /// - Parameter viewModel: The AddDogViewModel instance that drives profile creation logic.
    public init(viewModel: AddDogViewModel) {
        
        // 1. Call super.init() with nil nib/bundle by default.
        super.init(nibName: nil, bundle: nil)
        
        // 2. Store the view model reference for future usage in binding and logic.
        self.viewModel = viewModel
        
        // 3. Initialize UI components: text fields, date picker, button, etc.
        self.nameTextField = CustomTextField()
        self.breedTextField = CustomTextField()
        self.birthDatePicker = UIDatePicker()
        self.submitButton = UIButton(type: .system)
        self.scrollView = UIScrollView()
        self.formStackView = UIStackView()
        self.loadingIndicator = UIActivityIndicatorView(style: .medium)
        self.errorLabel = UILabel()
        
        // We start keyboardConstraint with a dummy constraint that we'll configure in setupUI.
        self.keyboardConstraint = NSLayoutConstraint()
        
        // 4. Initialize a fresh set of Combine AnyCancellable for memory-safety of subscriptions.
        self.cancellables = Set<AnyCancellable>()
        
        // 5. Setup accessibility identifiers for UI testing or accessibility overlays.
        self.nameTextField.accessibilityIdentifier = "AddDogViewController.nameTextField"
        self.breedTextField.accessibilityIdentifier = "AddDogViewController.breedTextField"
        self.birthDatePicker.accessibilityIdentifier = "AddDogViewController.birthDatePicker"
        self.submitButton.accessibilityIdentifier = "AddDogViewController.submitButton"
        self.scrollView.accessibilityIdentifier = "AddDogViewController.scrollView"
        self.formStackView.accessibilityIdentifier = "AddDogViewController.formStackView"
        self.loadingIndicator.accessibilityIdentifier = "AddDogViewController.loadingIndicator"
        self.errorLabel.accessibilityIdentifier = "AddDogViewController.errorLabel"
        
        // 6. Register for keyboard notifications to manage layout when the keyboard appears/disappears.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboard(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboard(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    /// Required initializer for using Storyboards or nib-based UI.
    /// We do not support this approach in the current flow, so it will throw a fatalError.
    ///
    /// - Parameter coder: The NSCoder used to decode the ViewController.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented in AddDogViewController.")
    }
    
    // MARK: - Lifecycle
    
    /// Deinitialization to remove keyboard notifications or any other observers.
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Called when the view is loaded into memory.
    /// According to specification steps:
    /// 1. Call super.viewDidLoad()
    /// 2. Setup UI components
    /// 3. Configure constraints
    /// 4. Bind view model
    /// 5. Setup keyboard handling
    /// 6. Configure accessibility
    /// 7. Apply theme
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // 2. Setup UI components
        setupUI()
        
        // 3. In a typical scenario, we might configure constraints either in setupUI or a separate method.
        //    For clarity, we keep it in setupUI itself.
        
        // 4. Bind view model
        bindViewModel()
        
        // 5. Setup keyboard handling is partially done via notifications; logic is in `handleKeyboard(_:).`
        
        // 6. Configure accessibility (some basic steps done in init, additional steps can be done here).
        self.view.accessibilityLabel = "AddDogViewController_MainView"
        
        // 7. Apply theme or additional styling if needed (dark mode checks, etc.).
        overrideUserInterfaceStyle = .unspecified  // letting iOS choose based on system or user preference
    }
    
    // MARK: - UI Setup
    
    /// Configures UI components and layout with support for dark mode and dynamic type.
    ///
    /// Steps (as per the JSON specification):
    /// 1. Configure scroll view with content insets
    /// 2. Setup form stack view with dynamic spacing
    /// 3. Configure text fields with validation
    /// 4. Setup date picker with constraints
    /// 5. Configure submit button with dynamic state
    /// 6. Setup loading indicator
    /// 7. Configure error label
    /// 8. Apply layout constraints
    /// 9. Setup dynamic type support
    /// 10. Configure dark mode adaptability
    public override func setupUI() {
        super.setupUI() // calls BaseViewController's default UI setup if needed
        
        // 1. Configure scroll view with content insets
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)
        
        // 2. Setup form stack view with dynamic spacing
        formStackView.axis = .vertical
        formStackView.alignment = .fill
        formStackView.distribution = .fill
        formStackView.spacing = 16.0
        formStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(formStackView)
        
        // 3. Configure text fields with validation
        //    We can set the placeholder and any domain-specific properties.
        nameTextField.placeholderText = "Enter Dog Name"
        nameTextField.validationType = .none // Could set a custom or name-based validation
        nameTextField.setupStyle()
        
        breedTextField.placeholderText = "Enter Dog Breed"
        breedTextField.validationType = .none
        breedTextField.setupStyle()
        
        // Add text fields to the form stack.
        formStackView.addArrangedSubview(nameTextField)
        formStackView.addArrangedSubview(breedTextField)
        
        // 4. Setup date picker with constraints
        birthDatePicker.datePickerMode = .date
        birthDatePicker.preferredDatePickerStyle = .wheels
        birthDatePicker.translatesAutoresizingMaskIntoConstraints = false
        formStackView.addArrangedSubview(birthDatePicker)
        
        // 5. Configure submit button with dynamic state
        submitButton.setTitle("Add Dog", for: .normal)
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        formStackView.addArrangedSubview(submitButton)
        
        // 6. Setup loading indicator
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.stopAnimating() // by default
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        formStackView.addArrangedSubview(loadingIndicator)
        
        // 7. Configure error label
        errorLabel.numberOfLines = 0
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        formStackView.addArrangedSubview(errorLabel)
        
        // 8. Apply layout constraints
        //    - ScrollView pinned to the view edges
        //    - formStackView pinned to scrollView edges
        //    - keyboardConstraint manages safe area bottom offset (initialized with 0, updated in handleKeyboard)
        NSLayoutConstraint.activate([
            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // formStackView constraints (pinned to scrollView with some padding).
            formStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            formStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            formStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            formStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            
            // Important: matching widths for horizontal scrolling if necessary.
            formStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // Keyboard constraint approach: set a bottom anchor or contentInset as needed.
        // For demonstration, we'll keep a constraint to the safe area for dynamic updates
        // in handleKeyboard. Let's attach it to the bottom of the view for a flexible offset:
        let kbConstraint = scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        kbConstraint.priority = .defaultHigh
        kbConstraint.isActive = true
        
        // Store in our property for updates.
        keyboardConstraint = kbConstraint
        
        // 9. Setup dynamic type support (already partially handled). We can let text fields
        //    scale with content size category, or we can add a .adjustsFontForContentSizeCategory
        nameTextField.adjustsFontForContentSizeCategory = true
        breedTextField.adjustsFontForContentSizeCategory = true
        
        // 10. Configure dark mode adaptability if needed. For now, we rely on iOS's automatic approach.
        //     Additional custom logic can be placed here if we want to do manual theming.
    }
    
    // MARK: - ViewModel Binding
    
    /// Sets up reactive data binding with comprehensive error handling.
    ///
    /// Steps (as per JSON):
    /// 1. Bind text field inputs to view model subjects
    /// 2. Bind date picker to birthDateSubject
    /// 3. Bind submit button to submitSubject
    /// 4. Subscribe to validation results
    /// 5. Handle loading states
    /// 6. Process error states
    /// 7. Manage success feedback
    /// 8. Store cancellables in set
    private func bindViewModel() {
        
        // 1. Bind text field inputs to view model subjects
        //    We'll do so via Combine's sink or text publisher approach.
        //    For demonstration, we assume a typical approach with text fields
        //    having a publisher or we do a control event approach.
        nameTextField
            .publisher(for: \.text)
            .compactMap { $0 ?? "" }
            .sink { [weak self] text in
                self?.viewModel.nameSubject.value = text
            }
            .store(in: &cancellables)
        
        breedTextField
            .publisher(for: \.text)
            .compactMap { $0 ?? "" }
            .sink { [weak self] text in
                self?.viewModel.breedSubject.value = text
            }
            .store(in: &cancellables)
        
        // 2. Bind date picker to birthDateSubject
        birthDatePicker
            .publisher(for: \.date) // Using Combine extension for UIDatePicker if available
            .sink { [weak self] date in
                self?.viewModel.birthDateSubject.value = date
            }
            .store(in: &cancellables)
        
        // 3. Bind submit button to submitSubject
        //    We'll do this via a button tap in submitButtonTapped() below,
        //    but if we want a reactive approach, we can do so with a control event publisher.
        
        // 4. Subscribe to validation results if the ViewModel has such a publisher.
        //    The specification references validationState, so let's subscribe:
        viewModel.validationState
            .sink { [weak self] valState in
                guard let self = self else { return }
                switch valState {
                case .valid:
                    // Clear any field-level or global error states
                    self.errorLabel.isHidden = true
                    self.errorLabel.text = nil
                case .invalid(let errors):
                    // For demonstration, show first error on errorLabel
                    self.errorLabel.isHidden = false
                    self.errorLabel.text = errors.first?.message
                }
            }
            .store(in: &cancellables)
        
        // 5. Handle loading states (assuming the base view model or a subject isLoadingSubject is exposed).
        viewModel.isLoadingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.loadingIndicator.startAnimating()
                    self.submitButton.isEnabled = false
                } else {
                    self.loadingIndicator.stopAnimating()
                    self.submitButton.isEnabled = true
                }
            }
            .store(in: &cancellables)
        
        // 6. Process error states (using errorSubject from the base).
        viewModel.errorSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                // Display the error in a user-friendly format
                self?.displayError(error.localizedDescription)
            }
            .store(in: &cancellables)
        
        // 7. Manage success feedback if the ViewModel has a success signal
        viewModel.successSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dog in
                // Dog creation successful, handle any success UI or navigate away.
                self?.showSuccessFeedback(for: dog)
            }
            .store(in: &cancellables)
        
        // 8. Store all cancellables in set (already done inline above).
    }
    
    // MARK: - Keyboard Handling
    
    /// Manages keyboard appearance and form scrolling or layout adjustments.
    ///
    /// Steps:
    /// 1. Extract keyboard frame
    /// 2. Calculate content offset
    /// 3. Animate layout changes
    /// 4. Update keyboard constraint
    /// 5. Scroll active field into view
    ///
    /// - Parameter notification: The keyboard notification containing sizing info.
    @objc private func handleKeyboard(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let endFrame = endFrameValue.cgRectValue
        
        // With iOS 13+, we can also check animation duration and curve.
        let animationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.3
        
        // 1. Keyboard frame extracted. We'll see if the keyboard is hidden vs shown:
        let isKeyboardShowing = notification.name == UIResponder.keyboardWillShowNotification
        
        // 2. If keyboard is showing, we adjust the scrollView bottom constraint by keyboard height.
        //    Otherwise, we set it to 0 or safe area.
        let newConstant: CGFloat = isKeyboardShowing ? endFrame.height : 0
        
        // 3. Animate layout changes
        UIView.animate(withDuration: animationDuration) { [weak self] in
            guard let self = self else { return }
            self.keyboardConstraint.constant = -newConstant
            self.view.layoutIfNeeded()
        }
        
        // 4. The keyboard constraint is updated above, re-laying out the scrollView.
        // 5. Optionally, we can scroll the currently active text field into view:
        if isKeyboardShowing, let activeField = view.findFirstResponder() as? UIView {
            // We'll compute an insets approach that scrolls the field into visible range.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollView.scrollRectToVisible(activeField.frame, animated: true)
            }
        }
    }
    
    // MARK: - Actions
    
    /// A helper method to handle the submit button's tap event. We forward the action
    /// to the viewModel by sending a Void event through `submitSubject`.
    @objc private func submitButtonTapped() {
        // Optionally perform local validation checks on text fields:
        let _ = nameTextField.validate()
        let _ = breedTextField.validate()
        
        // Send an event to the viewModel signaling the user is ready to create the dog profile.
        viewModel.submitSubject.send()
    }
    
    // MARK: - Additional Support Methods
    
    /// Displays an error in the top-level `errorLabel` and logs or announces it if necessary.
    /// - Parameter message: A user-readable error message.
    private func displayError(_ message: String) {
        errorLabel.isHidden = false
        errorLabel.text = "Error: \(message)"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    /// Shows success feedback, e.g., a message or a transition. Invoked when the
    /// dog creation is successful.
    /// - Parameter dog: The dog model that was just created.
    private func showSuccessFeedback(for dog: Dog) {
        // Example: Show an alert or move to another screen.
        let alert = UIAlertController(
            title: "Dog Profile Created",
            message: "Successfully created a profile for \(dog.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - State Restoration
    
    /// Encodes any relevant state needed to restore the view controller after it is destroyed.
    /// This includes text field contents, date picker value, etc.
    /// - Parameter coder: The NSCoder used to encode our state.
    public override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(nameTextField.text, forKey: "addDogVC_nameText")
        coder.encode(breedTextField.text, forKey: "addDogVC_breedText")
        coder.encode(birthDatePicker.date, forKey: "addDogVC_birthDate")
    }
    
    /// Decodes any relevant state previously stored, re-populating the UI upon restoration.
    /// - Parameter coder: The NSCoder from which to decode our state.
    public override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        if let restoredName = coder.decodeObject(forKey: "addDogVC_nameText") as? String {
            nameTextField.text = restoredName
        }
        if let restoredBreed = coder.decodeObject(forKey: "addDogVC_breedText") as? String {
            breedTextField.text = restoredBreed
        }
        if let restoredDate = coder.decodeObject(forKey: "addDogVC_birthDate") as? Date {
            birthDatePicker.date = restoredDate
        }
    }
    
    // MARK: - Exports
    
    /// Named export of the initializer per JSON specification: Allows external modules
    /// to instantiate AddDogViewController with a specified AddDogViewModel.
    @objc public func createInstance(viewModel: AddDogViewModel) -> AddDogViewController {
        return AddDogViewController(viewModel: viewModel)
    }
}
```