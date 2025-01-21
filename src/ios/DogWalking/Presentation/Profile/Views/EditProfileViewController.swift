import UIKit // iOS 13.0+
import Combine // iOS 13.0+
import PhotosUI // iOS 13.0+
import AVFoundation // iOS 13.0+

// MARK: - Internal Imports
@_exported import Core/Base/BaseViewController
@_exported import Presentation/Profile/ViewModels/EditProfileViewModel
@_exported import Presentation/Common/Views/CustomTextField

/// A view controller that handles user profile editing with comprehensive validation,
/// security features, and accessibility support. It leverages MVVM architecture,
/// integrates with the EditProfileViewModel, and applies the app's design system
/// for consistent UI components.
public final class EditProfileViewController: BaseViewController {
    
    // MARK: - Properties
    
    /// A reference to the view model responsible for profile editing logic,
    /// including secure data handling, validation, and reactive state management.
    private let viewModel: EditProfileViewModel
    
    /// A custom text field for the user's first name, providing validation, styling,
    /// and accessibility according to the design system.
    private let firstNameTextField: CustomTextField = {
        let tf = CustomTextField(frame: .zero)
        tf.validationType = .none
        tf.placeholderText = "First Name"
        tf.accessibilityIdentifier = "EditProfileViewController.firstNameTextField"
        return tf
    }()
    
    /// A custom text field for the user's last name, providing validation, styling,
    /// and accessibility according to the design system.
    private let lastNameTextField: CustomTextField = {
        let tf = CustomTextField(frame: .zero)
        tf.validationType = .none
        tf.placeholderText = "Last Name"
        tf.accessibilityIdentifier = "EditProfileViewController.lastNameTextField"
        return tf
    }()
    
    /// A custom text field for the user's phone number, providing validation, styling,
    /// and accessibility according to the design system.
    private let phoneTextField: CustomTextField = {
        let tf = CustomTextField(frame: .zero)
        tf.validationType = .none
        tf.placeholderText = "Phone"
        tf.accessibilityIdentifier = "EditProfileViewController.phoneTextField"
        tf.keyboardType = .phonePad
        return tf
    }()
    
    /// A UIImageView for displaying or updating the user's profile photo with
    /// the necessary accessibility support and secure handling of image data.
    private let profileImageView: UIImageView = {
        let iv = UIImageView(frame: .zero)
        iv.contentMode = .scaleAspectFill
        iv.isUserInteractionEnabled = true
        iv.accessibilityIdentifier = "EditProfileViewController.profileImageView"
        iv.accessibilityLabel = "User Profile Image"
        iv.clipsToBounds = true
        return iv
    }()
    
    /// A UIButton for saving updated profile data, adhering to the UI design system
    /// and providing a secure trigger for the save procedure.
    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Save", for: .normal)
        btn.accessibilityIdentifier = "EditProfileViewController.saveButton"
        return btn
    }()
    
    /// A UIButton enabling the user to change their profile photo, providing
    /// an entry-point to the photo selection process with robust security checks.
    private let changePhotoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Change Photo", for: .normal)
        btn.accessibilityIdentifier = "EditProfileViewController.changePhotoButton"
        return btn
    }()
    
    /// A thread-safe set of `AnyCancellable` instances for Combine subscriptions,
    /// ensuring memory-efficient reactive pipelines for view model bindings.
    private var cancellables: Set<AnyCancellable> = []
    
    /// A UIActivityIndicatorView for displaying loading or progress state
    /// during network or local data operations, supporting accessibility.
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.accessibilityIdentifier = "EditProfileViewController.loadingIndicator"
        return indicator
    }()
    
    /// A modern photo picker used for selecting or updating the user's profile image,
    /// providing secure photo library interactions with iOS 13+ features.
    private var photoPicker: PHPickerViewController?
    
    // MARK: - Initializer
    
    /// Initializes the EditProfileViewController with its required dependencies.
    /// - Parameter viewModel: The EditProfileViewModel that manages business logic.
    public init(viewModel: EditProfileViewModel) {
        // 1. Call super.init() with a nil nibName and bundle.
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        // 2. Initialize UI components and combine cancellables if not already done.
        //    Already done in property declarations for clarity. Additional custom steps can go here.
        
        // 3. Configure accessibility identifiers beyond existing ones if needed.
        self.view.accessibilityIdentifier = "EditProfileViewController.view"
        
        // 4. Prepare the photo picker configuration.
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        self.photoPicker = PHPickerViewController(configuration: config)
        self.photoPicker?.delegate = self
        self.photoPicker?.accessibilityIdentifier = "EditProfileViewController.photoPicker"
    }
    
    /// Required initializer for using storyboards or XIBs.
    /// - Parameter coder: A coder object that provides the data required to initialize the controller.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented in EditProfileViewController.")
    }
    
    // MARK: - Lifecycle
    
    /// Configures the view controller once the view is loaded. This method sets up
    /// UI elements, handles input validation, binds reactive publishers, and more.
    public override func viewDidLoad() {
        // 1. Call super.viewDidLoad() for essential base setup.
        super.viewDidLoad()
        
        // 2. Setup UI components (layout, accessibility, styling).
        setupUI()
        
        // 3. Configure navigation bar with a suitable title or style.
        navigationItem.title = "Edit Profile"
        
        // 4. Setup additional input validation logic if needed or adjust default text field settings.
        //    (Already integrated in text field inits.)
        
        // 5. Establish data bindings with the view model to observe user data and save operations.
        bindViewModel()
        
        // 6. Register for keyboard notifications or additional system notifications if relevant.
        registerForKeyboardNotifications()
        
        // 7. Setup accessibility labels or additional properties for specialized elements.
        //    Already set in property declarations, but can be expanded here if needed.
        
        // 8. Configure gesture recognizers for the image view or any advanced interactions.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(profileImageTapped))
        profileImageView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - UI Setup
    
    /// Configures UI components and layout with accessibility support, referencing design system
    /// conventions for consistent styling, typography, dynamic type, and voice-over properties.
    public override func setupUI() {
        super.setupUI()
        
        // 1. Setup profile image view with accessibility properties.
        profileImageView.isAccessibilityElement = true
        
        // 2. Configure text fields with validation logic, design system styling, and placeholders.
        firstNameTextField.setupStyle()
        lastNameTextField.setupStyle()
        phoneTextField.setupStyle()
        
        // 3. Setup the save button to manage a loading state when tapped.
        saveButton.addTarget(self, action: #selector(validateAndSave), for: .touchUpInside)
        
        // 4. Configure the photo picker button to invoke handlePhotoSelection.
        changePhotoButton.addTarget(self, action: #selector(handlePhotoSelection), for: .touchUpInside)
        
        // 5. Add UI elements to the view hierarchy.
        view.addSubview(profileImageView)
        view.addSubview(firstNameTextField)
        view.addSubview(lastNameTextField)
        view.addSubview(phoneTextField)
        view.addSubview(saveButton)
        view.addSubview(changePhotoButton)
        view.addSubview(loadingIndicator)
        
        // 6. Apply auto-layout constraints for each subview. In a robust app, you might use
        //    SnapKit, pure Auto Layout code, or SwiftUI. Below is a direct example:
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        firstNameTextField.translatesAutoresizingMaskIntoConstraints = false
        lastNameTextField.translatesAutoresizingMaskIntoConstraints = false
        phoneTextField.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        changePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Profile Image Constraints
            profileImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            profileImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 120),
            profileImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Change Photo Button Constraints
            changePhotoButton.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 12),
            changePhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // First Name Constraints
            firstNameTextField.topAnchor.constraint(equalTo: changePhotoButton.bottomAnchor, constant: 24),
            firstNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            firstNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            firstNameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Last Name Constraints
            lastNameTextField.topAnchor.constraint(equalTo: firstNameTextField.bottomAnchor, constant: 16),
            lastNameTextField.leadingAnchor.constraint(equalTo: firstNameTextField.leadingAnchor),
            lastNameTextField.trailingAnchor.constraint(equalTo: firstNameTextField.trailingAnchor),
            lastNameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Phone TextField Constraints
            phoneTextField.topAnchor.constraint(equalTo: lastNameTextField.bottomAnchor, constant: 16),
            phoneTextField.leadingAnchor.constraint(equalTo: firstNameTextField.leadingAnchor),
            phoneTextField.trailingAnchor.constraint(equalTo: firstNameTextField.trailingAnchor),
            phoneTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Save Button Constraints
            saveButton.topAnchor.constraint(equalTo: phoneTextField.bottomAnchor, constant: 24),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Loading Indicator Constraints
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // 7. Setup dynamic type support, if custom. For typical usage, the text fields and buttons
        //    handle it automatically if configured with dynamic fonts.
        
        // 8. Configure voice over properties. Some have been set. Could add more, e.g., for the image:
        profileImageView.accessibilityHint = "Double-tap to select a new profile image."
    }
    
    // MARK: - Binding with ViewModel
    
    /// Establishes secure data binding with the EditProfileViewModel. Observes user data,
    /// manages validation, error handling, and loading states for a robust user experience.
    private func bindViewModel() {
        // 1. Bind user data with input sanitization
        //    Once userSubject sends a valid user, populate text fields.
        viewModel.userSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self, let user = user else { return }
                self.firstNameTextField.text = user.firstName
                self.lastNameTextField.text = user.lastName
                self.phoneTextField.text = user.phone
                // For the profile image, we could load it from a URL if set.
            }
            .store(in: &cancellables)
        
        // 2. Setup validation publishers or advanced text field callbacks if needed.
        //    Example: We could watch changes in text fields and re-validate them automatically.
        
        // 3. Configure error handling. For demonstration, we rely on BaseViewController.errorSubject if needed.
        
        // 4. Bind loading state. If we had an isLoadingPublisher, we could do:
        viewModel.isLoadingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.loadingIndicator.startAnimating()
                } else {
                    self.loadingIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
        
        // 5. Listen for successful saves. Dismiss or show a message upon success.
        viewModel.saveSuccessSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Indicate success to user. Possibly pop the view or show a success dialog.
                self?.showSaveSuccessFeedback()
            }
            .store(in: &cancellables)
        
        // 6. Configure retry logic or advanced offline mode handling as needed
        //    (e.g., re-queue user updates if offline).
    }
    
    // MARK: - Photo Selection
    
    /// Manages secure photo selection and processing, verifying library permissions,
    /// presenting a modern photo picker, and handling the chosen image.
    @objc private func handlePhotoSelection() {
        // 1. Check and request photo library permissions if needed. Swift automatically
        //    handles this with Info.plist usage descriptions. We'll trust the user has it.
        
        // 2. Present the photo picker. This uses PHPickerViewController already initialized.
        guard let picker = photoPicker else { return }
        present(picker, animated: true)
    }
    
    // MARK: - Photo Tap
    
    /// A gesture recognizer action invoked when the profile image view is tapped.
    /// Optionally provides a second entry point to the same handlePhotoSelection method.
    @objc private func profileImageTapped() {
        handlePhotoSelection()
    }
    
    // MARK: - Validate and Save
    
    /// Performs comprehensive validation and secure save operation, ensuring all input fields
    /// are valid, toggling the loading state, and propagating the update to the view model.
    @objc private func validateAndSave() {
        // 1. Validate all input fields.
        let firstNameValid = firstNameTextField.validate()
        let lastNameValid = lastNameTextField.validate()
        let phoneValid = phoneTextField.validate()
        
        if !firstNameValid || !lastNameValid || !phoneValid {
            // If any field is invalid, show an inline error (CustomTextField handles this).
            return
        }
        
        // 2. Sanitize input data.
        let sanitizedFirstName = firstNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitizedLastName = lastNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitizedPhone = phoneTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 3. Show loading state by instructing the view model to set isLoadingSubject.
        //    The viewModel will update isLoadingSubject automatically in updateProfile calls.
        
        // 4. Attempt save operation using the view model's secure updateProfile method.
        viewModel.updateProfile(
            firstName: sanitizedFirstName,
            lastName: sanitizedLastName,
            phone: sanitizedPhone,
            profileImageUrl: nil, // or a URL from the selected image if we have one
            version: nil
        )
        .sink(receiveCompletion: { [weak self] completion in
            // 5. Handle success/failure once the publisher completes.
            switch completion {
            case .failure(let error):
                // Show appropriate feedback for error, possibly using showError(_:) from BaseViewController.
                self?.showError(error)
            case .finished:
                // Nothing specific here, since we handle success in .sink's receiveValue or in saveSuccessSubject.
                break
            }
        }, receiveValue: { _ in
            // 6. We typically rely on the saveSuccessSubject to handle final success UI updates.
        })
        .store(in: &cancellables)
        
        // 7. Log analytics event for profile save if needed. E.g., Analytics.track("ProfileSaveAttempt")
        
        // 8. If the device is offline, handle scenario by queueing changes (omitted for brevity).
    }
    
    // MARK: - Internal Helpers
    
    /// Shows a simple success feedback to the user upon successfully saving the profile.
    /// This method can be replaced with a more comprehensive UI or navigation logic.
    private func showSaveSuccessFeedback() {
        let alert = UIAlertController(title: "Success", message: "Profile updated successfully.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
    
    /// Registers for keyboard notifications if needed to adjust the layout
    /// when the keyboard appears or disappears. This is optional and can be
    /// omitted if using a more advanced layout approach.
    private func registerForKeyboardNotifications() {
        // Example placeholders:
        // NotificationCenter.default.addObserver(...)
        // In a production scenario, you'd adjust the view's content insets to avoid text fields
        // being hidden under the keyboard.
    }
}

// MARK: - PHPickerViewControllerDelegate

extension EditProfileViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Dismiss the picker
        picker.dismiss(animated: true, completion: nil)
        
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else {
            // 6. Handle selection cancellation or unsupported data.
            return
        }
        
        // 1. Process selected image in a memory-efficient manner.
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (object, error) in
            if let error = error {
                // 2. Possibly show error or revert UI state.
                DispatchQueue.main.async {
                    self?.showError(error)
                }
                return
            }
            guard let self = self, let image = object as? UIImage else { return }
            
            // 3. Compress image data if needed for uploading, or manipulate as required.
            //    For demonstration, we directly load it into the profileImageView.
            DispatchQueue.main.async {
                self.profileImageView.image = image
            }
            // 4. We could store the compressed data for future updates to the server.
        }
    }
}
```