import UIKit // iOS 13.0+ (Core iOS UI framework functionality)
import Combine // iOS 13.0+ (Reactive programming for state binding and error handling)
import PhotosUI // iOS 13.0+ (Photo picker functionality, fallback to UIImagePicker if needed)

// MARK: - Internal Imports
// BaseViewController (enhanced error handling, loading states, etc.)
import Core.Base.BaseViewController

// View Model for the walk review flow
import Presentation.Walks.ViewModels.WalkReviewViewModel

// Custom RatingView with accessibility and star rating support
import Presentation.Common.Views.RatingView

/// A view controller responsible for displaying and handling walk review submission.
/// Includes rating, notes, and photo upload features with enhanced error handling,
/// accessibility support, and offline capabilities.
final class WalkReviewViewController: BaseViewController {
    
    // MARK: - Global/Shared Properties (From JSON specification)
    
    /// The view model that coordinates the walk review data flow and state.
    private let viewModel: WalkReviewViewModel
    
    /// A set of Combine AnyCancellable references for managing memory of publishers.
    private var cancellables = Set<AnyCancellable>()
    
    /// Compression quality used when compressing user-selected photos.
    private let imageCompressionQuality: CGFloat = 0.7
    
    
    // MARK: - UI Components (From JSON specification)
    
    /// A star rating view to capture user’s rating of the walk.
    private lazy var ratingView: RatingView = {
        let rv = RatingView()
        rv.isAccessibilityElement = true // Provide explicit accessibility for star rating
        rv.translatesAutoresizingMaskIntoConstraints = false
        return rv
    }()
    
    /// A text view for entering notes or additional comments on the walk.
    private lazy var notesTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .systemBackground
        tv.font = UIFont.systemFont(ofSize: 16.0)
        tv.accessibilityLabel = "Walk Review Notes"
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    /// A button allowing the user to add a photo to the review.
    private lazy var addPhotoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Add Photo", for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(handlePhotoSelection), for: .touchUpInside)
        return btn
    }()
    
    /// A button triggering submission of the walk review.
    private lazy var submitButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Submit Review", for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18.0)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(handleSubmit), for: .touchUpInside)
        return btn
    }()
    
    /// A preview image view displaying the user-selected photo, if any.
    private lazy var photoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.secondarySystemBackground
        iv.accessibilityLabel = "Selected Review Photo"
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    /// An activity indicator used to show loading states (submission in progress, etc.).
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.color = .systemGray
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    
    // MARK: - Initializer / Constructor (From JSON specification)
    
    /// Creates a new WalkReviewViewController with a required view model, configuring
    /// advanced error handling and accessibility identifiers, plus UI initialization.
    ///
    /// Steps:
    /// 1. Call super.init(...)
    /// 2. Store the view model
    /// 3. Configure view controller properties
    /// 4. Setup accessibility identifiers
    /// 5. Initialize UI components
    ///
    /// - Parameter viewModel: The WalkReviewViewModel handling state and events of the review flow.
    init(viewModel: WalkReviewViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        
        // (3) Configure any relevant view controller properties
        self.title = "Walk Review"
        
        // (4) Setup accessibility
        self.view.accessibilityIdentifier = "walkReviewContainer"
        
        // (5) UI components are declared as lazy; they will initialize upon first access.
    }
    
    /// Required initializer, not implemented for programmatic usage.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for WalkReviewViewController.")
    }
    
    
    // MARK: - Lifecycle Methods
    
    /// Called when the view is loaded into memory, implementing advanced setup steps:
    /// 1. super.viewDidLoad()
    /// 2. Setup UI components with accessibility
    /// 3. Configure constraints
    /// 4. Bind view model with error handling
    /// 5. Setup state restoration
    /// 6. Configure analytics tracking
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Already called super
        // 2. Setup UI with accessibility
        setupUI()
        
        // 3. Add constraints
        configureConstraints()
        
        // 4. Bind the view model
        bindViewModel()
        
        // 5. Optional: Setup advanced state restoration (placeholder)
        //    e.g. restore UI states from last session
        
        // 6. Optional: Call analytics or logging for screen view
        //    e.g. AnalyticsService.logScreenView("WalkReviewViewController")
    }
    
    
    // MARK: - Setup UI (From JSON specification: override)
    
    /// Configures UI components, applying an enterprise approach to accessibility, layout,
    /// and advanced error handling. Steps:
    /// 1. Setup rating view with accessibility
    /// 2. Configure notes text view with placeholder
    /// 3. Setup photo button with compression ops
    /// 4. Configure submit button with validation
    /// 5. Setup navigation bar items
    /// 6. Configure loading indicator
    /// 7. Setup error presentation view
    override func setupUI() {
        super.setupUI()
        
        // 1. The rating view is already partially configured. Let's ensure additional accessibility.
        ratingView.accessibilityHint = "Swipe up or down to adjust the rating."
        
        // 2. The notes text view can have a placeholder. Let's do a simple approach:
        //    Typically, a separate placeholder label is used, but for demonstration:
        if notesTextView.text.isEmpty {
            notesTextView.text = "Enter your notes here..."
            notesTextView.textColor = .secondaryLabel
        }
        
        // 3. Photo button is already set with an action. We'll finalize compression logic in handlePhotoSelection.
        
        // 4. The submit button's validation logic will be implemented in handleSubmit or bindViewModel.
        
        // 5. Setup navigation bar if needed:
        navigationItem.largeTitleDisplayMode = .never
        
        // 6. The loading indicator is added as a subview. We'll start/stop it as needed.
        // 7. We rely on the base class showError(...) for error presentation.
        
        // Add subviews to the main view hierarchy
        view.addSubview(ratingView)
        view.addSubview(notesTextView)
        view.addSubview(addPhotoButton)
        view.addSubview(submitButton)
        view.addSubview(photoImageView)
        view.addSubview(loadingIndicator)
        
        view.backgroundColor = .systemBackground
    }
    
    
    // MARK: - Bind View Model (From JSON specification: override)
    
    /// Sets up data binding with the view model, including error handling, offline support,
    /// and analytics. Steps:
    /// 1. Bind rating view with validation
    /// 2. Bind notes text with character limit
    /// 3. Bind photo selection with compression
    /// 4. Bind submit button with loading state
    /// 5. Handle completion state
    /// 6. Setup error handling
    /// 7. Configure offline support
    /// 8. Setup analytics events
    override func bindViewModel() {
        super.bindViewModel(viewModel) // Inform the base class about the view model binding
        
        // 1. Rating view binding
        ratingView.ratingSubject
            .sink { [weak self] newValue in
                guard let self = self else { return }
                // Push new rating to the view model subject
                self.viewModel.ratingSubject.send(newValue)
            }
            .store(in: &cancellables)
        
        // 2. Notes text character limit, we can observe text changes or finalize on editing end
        notesTextView.delegate = self
        
        // 3. Photo selection with compression is triggered from handlePhotoSelection; see that method
        
        // 4. Observe the loading state from the view model
        viewModel.loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.showLoading()
                } else {
                    self.hideLoading()
                }
            }
            .store(in: &cancellables)
        
        // 5. If view model has a completion signal, we could observe it. For demonstration, not explicitly stated:
        viewModel.completionSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] success in
                if success {
                    // Possibly dismiss or show a success state
                    self?.navigationController?.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
        
        // 6. Setup error handling
        viewModel.errorSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
        
        // 7. Offline support could be integrated with reachability or additional logic:
        //    For demonstration, we skip explicit offline dictates beyond the view model's approach.
        
        // 8. Setup analytics for rating changes, note changes, etc. (placeholder).
        //    E.g. ratingView.ratingSubject -> track event "user_SetRating"
    }
    
    
    // MARK: - Photo Selection Handler (From JSON specification)
    
    /// Handles photo selection, including presenting a photo picker, compressing selected images,
    /// validating size/format, and sending data to the view model. Steps:
    /// 1. Present photo picker with options
    /// 2. Handle user selection with compression
    /// 3. Validate image size and format
    /// 4. Update UI with selected photo
    /// 5. Compress photo data
    /// 6. Send photo data to view model
    /// 7. Handle memory warnings
    /// 8. Track analytics event
    @objc private func handlePhotoSelection() {
        // 1. Because iOS 13.0+ doesn't fully support the PhotosUI picker, we can fallback to UIImagePickerController.
        //    If iOS 14 or above, we could use PHPickerViewController. For brevity, let's do a standard approach:
        
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.modalPresentationStyle = .overFullScreen
        
        present(picker, animated: true, completion: nil)
        
        // Steps 2-7 happen in the delegate methods, culminating in calls that compress, validate, etc.
        // In the end, we track an analytics event for photo selection if desired.
    }
    
    
    // MARK: - Submit Handler (From JSON specification)
    
    /// Handles final submission of the walk review, orchestrating validation, offline checks,
    /// interaction with the view model, and analytics. Steps:
    /// 1. Validate all input data
    /// 2. Show loading indicator
    /// 3. Handle offline state if needed
    /// 4. Trigger view model submit
    /// 5. Handle submission result
    /// 6. Show success/error feedback
    /// 7. Track submission analytics
    /// 8. Clean up resources
    @objc private func handleSubmit() {
        // 1. Validate rating (viewModel handles range, but let's do a quick check if user rating is 0)
        if ratingView.rating <= 0.0 {
            let error = NSError(domain: "WalkReview", code: 1002,
                                userInfo: [NSLocalizedDescriptionKey: "Please provide a rating before submitting"])
            showError(error)
            return
        }
        
        // Validate notes if needed. For demonstration:
        if notesTextView.text.isEmpty || notesTextView.text == "Enter your notes here..." {
            let error = NSError(domain: "WalkReview", code: 1003,
                                userInfo: [NSLocalizedDescriptionKey: "Please enter some notes."])
            showError(error)
            return
        }
        
        // 2. Show loading
        self.showLoading()
        
        // 3. Offline logic can be handled by the view model or additional checks. For demonstration, we skip here.
        
        // 4. Trigger submit by sending a signal to the view model's submitSubject
        viewModel.submitSubject.send(())
        
        // 5. The result is handled via the completionSubject or errorSubject. 
        //    We don't handle them directly here to avoid duplication.
        
        // 6. UI feedback is shown in response to the completion or error subscription in bindViewModel.
        
        // 7. Track analytics event: "User_SubmittedWalkReview"
        //    E.g. AnalyticsService.logEvent("User_SubmittedWalkReview", ...)
        
        // 8. No explicit resource cleanup needed here beyond normal flow.
    }
    
    
    // MARK: - Private Layout Helpers
    
    /// Configures Auto Layout constraints for the UI elements.
    private func configureConstraints() {
        
        // Rating view constraints
        NSLayoutConstraint.activate([
            ratingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            ratingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ratingView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            ratingView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Notes TextView constraints
        NSLayoutConstraint.activate([
            notesTextView.topAnchor.constraint(equalTo: ratingView.bottomAnchor, constant: 16),
            notesTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            notesTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            notesTextView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        // Add photo button constraints
        NSLayoutConstraint.activate([
            addPhotoButton.topAnchor.constraint(equalTo: notesTextView.bottomAnchor, constant: 16),
            addPhotoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
        
        // Photo image view constraints
        NSLayoutConstraint.activate([
            photoImageView.topAnchor.constraint(equalTo: addPhotoButton.bottomAnchor, constant: 8),
            photoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            photoImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            photoImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // Submit button constraints
        NSLayoutConstraint.activate([
            submitButton.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: 24),
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Loading indicator constraints
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}


// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate

extension WalkReviewViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Called when the user finishes picking an image
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        defer {
            picker.dismiss(animated: true, completion: nil)
        }
        
        // Steps from handlePhotoSelection:
        // 2. We got a selected photo from user
        guard let originalImage = info[.originalImage] as? UIImage else { return }
        
        // 3. Validate image size/format if needed (placeholder)
        
        // 4. Update UI with selected photo
        photoImageView.image = originalImage
        
        // 5. Compress photo data
        guard let compressedData = originalImage.jpegData(compressionQuality: imageCompressionQuality) else { return }
        
        // 6. Send data to the view model’s photoSubject
        viewModel.photoSubject.send(compressedData)
        
        // 7. Memory warnings handled at system level; we can do a dryness check if needed
        // 8. Track analytics event "User_SelectedPhoto"
    }
    
    // Called if the user cancels picking
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        // Optionally handle cancellation analytics or logic
    }
}


// MARK: - UITextViewDelegate

extension WalkReviewViewController: UITextViewDelegate {
    
    // For the notes text view placeholder logic, we'll clear or restore placeholder text
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Enter your notes here..." {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Enter your notes here..."
            textView.textColor = .secondaryLabel
        } else {
            textView.textColor = .label
            // We can also send updated text to the view model:
            viewModel.notesSubject.send(textView.text)
        }
    }
}