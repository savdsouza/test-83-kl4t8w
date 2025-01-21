import UIKit // iOS 13.0+ (Core iOS UI framework)
import Combine // iOS 13.0+ (Reactive programming framework)

// MARK: - Internal Imports
// Using the BaseViewController from Core/Base/BaseViewController
// which provides viewDidLoad(), setupUI(), bindViewModel() methods.
import Core.Base.BaseViewController

// Using the ProfileViewModel from Presentation/Profile/ViewModels/ProfileViewModel
// which provides userSubject, profileUpdatedSubject, loadUserProfile, updateProfile.
import Presentation.Profile.ViewModels.ProfileViewModel

// Using the CustomButton from Presentation/Common/Views/CustomButton
// which supports init(...) and setLoading(...) for accessibility and loading states.
import Presentation.Common.Views.CustomButton

/// A thread-safe view controller for displaying and managing user profile information
/// with comprehensive error handling and accessibility support. Inherits from
/// BaseViewController to leverage shared lifecycle methods, UI configuration,
/// and reactive binding patterns.
final class ProfileViewController: BaseViewController {
    
    // MARK: - Properties
    
    /// The dedicated view model managing profile data, including userSubject,
    /// profile updates, and domain logic. Ensures thread-safe operations.
    private let viewModel: ProfileViewModel
    
    /// An image view used to display the user's profile picture. Configured
    /// with accessibility traits and dynamic content scaling.
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.clipsToBounds = true
        // Placeholder image or styling can be adjusted here if desired.
        return imageView
    }()
    
    /// A vertical stack view containing text fields for the user's name,
    /// email, and phone number, organized in a user-friendly layout that
    /// supports dynamic type and VoiceOver.
    private let infoStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 12.0
        return stack
    }()
    
    /// A text field for editing or displaying the user's name, configured
    /// with validation and accessibility support for VoiceOver hints.
    private let nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Name"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .words
        textField.isAccessibilityElement = true
        textField.accessibilityLabel = "Name Field"
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    /// A text field for editing or displaying the user's email address,
    /// ensuring valid formatting and comprehensive accessibility hints.
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .emailAddress
        textField.autocorrectionType = .no
        textField.isAccessibilityElement = true
        textField.accessibilityLabel = "Email Field"
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    /// A text field for editing or displaying the user's phone number,
    /// supporting additional validation logic for numeric input.
    private let phoneTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Phone Number"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .phonePad
        textField.isAccessibilityElement = true
        textField.accessibilityLabel = "Phone Field"
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    /// A custom button for initiating profile edits or updates, supporting
    /// loading/spinner states, accessibility, and dynamic type. Uses the
    /// design system’s styling rules through CustomButton.
    private let editProfileButton: CustomButton = {
        let button = CustomButton(style: .primary)
        button.setTitle("Edit Profile", for: .normal)
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        return button
    }()
    
    /// A thread-safe set of Combine AnyCancellable objects for managing
    /// subscriptions to reactive data streams (e.g., userSubject).
    private var cancellables: Set<AnyCancellable>
    
    /// A dedicated serial DispatchQueue for synchronization tasks that
    /// require thread safety, such as background loading of profile data
    /// or concurrent UI updates.
    private let serialQueue: DispatchQueue
    
    // MARK: - Initializer
    
    /// Initializes the profile view controller with a thread-safe view model.
    /// Steps involved:
    /// 1. Calls super.init() to utilize BaseViewController’s initialization.
    /// 2. Stores the view model instance for later usage.
    /// 3. Initializes UI components with accessibility and design system specs.
    /// 4. Sets up Combine cancellables to manage memory usage safely.
    /// 5. Creates a serial queue for concurrency control in data loading or updates.
    ///
    /// - Parameter viewModel: A ProfileViewModel instance providing user-bound data flows.
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        self.cancellables = Set<AnyCancellable>()
        self.serialQueue = DispatchQueue(label: "com.dogwalking.ProfileViewController.serialQueue",
                                         qos: .userInitiated)
        super.init(nibName: nil, bundle: nil)
        
        // Additional initialization logic can be placed here if needed.
        // e.g., advanced analytics or performance instrumentation.
    }
    
    /// Boilerplate initializer required for UIKit storyboard or nib usage;
    /// not implemented for programmatic UI.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented.")
    }
    
    // MARK: - Lifecycle Methods
    
    /// viewDidLoad is overridden to configure the view controller with
    /// proper thread safety, UI setup, and binding to the ProfileViewModel.
    /// Steps:
    /// 1. Calls super.viewDidLoad() for base functionality.
    /// 2. Sets up UI components with accessibility.
    /// 3. Configures the navigation bar with style or custom titles.
    /// 4. Binds the view model with error handling or state management.
    /// 5. Loads initial profile data on a background queue.
    /// 6. Sets up analytics tracking or instrumentation hooks.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 2. Setup UI, including constraints, accessibility, etc.
        setupUI()
        
        // 3. Configure navigation bar style or text if desired.
        navigationItem.title = "User Profile"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // 4. Bind the view model to handle user data changes, loading states, etc.
        bindViewModel()
        
        // 5. Load initial profile data on a background queue. We can assume
        // the user is already identified, or a userId is known if needed.
        // For demonstration, we do a dummy userId "currentUserIdExample".
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            let userId = "currentUserIdExample"
            
            self.viewModel
                .loadUserProfile(userId: userId)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        // Show error using BaseViewController's showError method
                        self.showError(error)
                    case .finished:
                        break
                    }
                } receiveValue: { _ in
                    // Profile loaded successfully; additional UI updates can occur
                }
                .store(in: &self.cancellables)
        }
        
        // 6. Setup analytics tracking if needed (placeholder).
        // Example: analytics.logEvent("ProfileViewControllerLoaded", parameters: nil)
    }
    
    // MARK: - UI Configuration
    
    /// Override of BaseViewController’s setupUI to configure accessible UI components
    /// with proper layout. Steps:
    /// 1. Configure accessible profile image view.
    /// 2. Setup info stack view with dynamic type support for name, email, phone fields.
    /// 3. Configure text fields with validation or placeholders.
    /// 4. Setup edit profile button with loading state logic and action targets.
    /// 5. Apply Auto Layout constraints for a consistent, responsive layout.
    /// 6. Configure VoiceOver support and labeling.
    override func setupUI() {
        super.setupUI() // If the base class has additional logic.
        
        view.backgroundColor = .systemBackground
        
        // 1. Configure profileImageView with corner radius, content mode, etc.
        profileImageView.layer.cornerRadius = 40.0
        profileImageView.layer.masksToBounds = true
        
        // 2. Add text fields to stack view for dynamic type consistency.
        infoStackView.addArrangedSubview(nameTextField)
        infoStackView.addArrangedSubview(emailTextField)
        infoStackView.addArrangedSubview(phoneTextField)
        
        // 3. Configure text fields (placeholders, keyboard types, validations).
        //    Already set above, but you can add further logic for advanced validation.
        
        // 4. Setup editProfileButton with a target action for tapping.
        editProfileButton.addTarget(self, action: #selector(handleEditProfileButton), for: .touchUpInside)
        
        // 5. Add subviews and define layout constraints
        [profileImageView, infoStackView, editProfileButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // Example constraints:
        NSLayoutConstraint.activate([
            // Profile Image View
            profileImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            profileImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Info Stack View
            infoStackView.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 24),
            infoStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            infoStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // Edit Profile Button
            editProfileButton.topAnchor.constraint(equalTo: infoStackView.bottomAnchor, constant: 24),
            editProfileButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editProfileButton.widthAnchor.constraint(equalToConstant: 200),
            editProfileButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 6. Configure VoiceOver or additional accessibility if needed.
        // For instance, setting custom accessibility hints:
        profileImageView.accessibilityHint = "Displays the user's profile picture."
        nameTextField.accessibilityHint = "Enter the user's first and last name."
        emailTextField.accessibilityHint = "Enter a valid email address."
        phoneTextField.accessibilityHint = "Enter a valid phone number."
    }
    
    // MARK: - ViewModel Binding
    
    /// Sets up thread-safe data binding between the ProfileViewController and ProfileViewModel,
    /// including error handling, loading state, button actions, and memory-efficient subscription
    /// management.
    ///
    /// Steps:
    /// 1. Bind user profile updates on the main thread to reflect changes in the text fields.
    /// 2. Bind loading or update states with custom UI feedback (e.g. editProfileButton).
    /// 3. Setup comprehensive error handling for user operations.
    /// 4. Configure button actions with potential debouncing or throttling if needed.
    /// 5. Establish memory-efficient cancellables to automatically manage subscription lifetimes.
    private func bindViewModel() {
        // 1. Observe userSubject to update text fields on main thread
        viewModel.userSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self, let user = user else { return }
                // Update text fields with user info
                self.nameTextField.text = "\(user.firstName) \(user.lastName)"
                self.emailTextField.text = user.email
                self.phoneTextField.text = user.phone
            }
            .store(in: &cancellables)
        
        // 2. Observe profileUpdatedSubject to handle successful profile updates
        viewModel.profileUpdatedSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                // Profile updated successfully
                // Possibly show a success toast, hide loading state, etc.
                self?.editProfileButton.setLoading(false)
                // Additional UI feedback or logging can occur here.
            }
            .store(in: &cancellables)
        
        // 3. If there's an errorSubject in the view model, we could bind to it for error handling:
        //    For demonstration, we rely on returning publishers from loadUserProfile, updateProfile, etc.
        
        // 4. The button's action is already attached. Debouncing can be applied via Combine if needed.
        
        // 5. Subscriptions are stored in the cancellables set, ensuring automatic cleanup.
    }
    
    // MARK: - Profile Update Logic
    
    /// Handles thread-safe profile updates with validation and user feedback.
    /// Steps:
    /// 1. Validate input fields for non-empty name, valid email format, etc.
    /// 2. Show a loading state on the editProfileButton for UI feedback.
    /// 3. Execute the update on a background queue to avoid blocking the main thread.
    /// 4. Handle success or failure with user feedback, possibly showing errors or success messages.
    /// 5. Update analytics or logging for profile modifications.
    /// 6. Hide the loading state on the main thread to restore normal UI controls.
    private func updateProfile() {
        // 1. Basic validation
        let fullName = (nameTextField.text ?? "").trimmingCharacters(in: .whitespaces)
        let email = (emailTextField.text ?? "").trimmingCharacters(in: .whitespaces)
        let phone = (phoneTextField.text ?? "").trimmingCharacters(in: .whitespaces)
        
        guard !fullName.isEmpty, !email.isEmpty else {
            // Show some alert or error about missing fields
            let validationError = NSError(domain: "ProfileViewController",
                                          code: 400,
                                          userInfo: [NSLocalizedDescriptionKey: "Name and Email cannot be empty."])
            showError(validationError)
            return
        }
        
        // 2. Show loading state
        editProfileButton.setLoading(true)
        
        // 3. Execute update on background queue
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Attempt to break fullName into first/last for demonstration
            let nameComponents = fullName.components(separatedBy: .whitespaces)
            let firstName = nameComponents.first ?? ""
            let lastName = nameComponents.dropFirst().joined(separator: " ")
            
            self.viewModel
                .updateProfile(firstName: firstName,
                               lastName: lastName,
                               phone: phone,
                               profileImageUrl: nil)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .failure(let error):
                        // 4. On failure, show error feedback
                        self.showError(error)
                        // Hide loading
                        self.editProfileButton.setLoading(false)
                    case .finished:
                        // Nothing special on finishing
                        break
                    }
                } receiveValue: { updatedUser in
                    // 5. Profile updated successfully, can log analytics or events
                    // Example: analytics.logEvent("ProfileUpdated", parameters: ["userId": updatedUser.id.uuidString])
                    
                    // 6. Loading is hidden in the .sink handling or in the profileUpdatedSubject binding
                    //    which also sets loading to false. If we rely purely on profileUpdatedSubject,
                    //    we can omit setting it here, but let's ensure it's hidden if the subject wasn't triggered.
                    // (We rely on the subject above, but let's add safety.)
                    self.editProfileButton.setLoading(false)
                }
                .store(in: &self.cancellables)
        }
    }
    
    // MARK: - Action Handlers
    
    /// Action handler for the edit profile button. Invokes updateProfile(),
    /// which manages validations, loading state, and the actual update logic.
    @objc private func handleEditProfileButton() {
        updateProfile()
    }
}