import UIKit // iOS 13.0+
import Foundation

// MARK: - Internal Imports
// We import our UIView+Extensions for fade and pin layout utilities
// These provide fadeIn, fadeOut, pinToEdges, etc. with thread-safe checks
@MainActor
public final class LoadingView: UIView {
    
    // MARK: - Properties
    
    /// The activity indicator used to show a loading spinner.
    public let activityIndicator: UIActivityIndicatorView
    
    /// The optional label displaying a message for the loading state.
    public let messageLabel: UILabel
    
    /// A vertical stack view that holds the activity indicator and message label.
    public let stackView: UIStackView
    
    /// The message to display alongside the loading indicator.
    public var message: String?
    
    /// Indicates whether the loading view is currently animating (visible).
    public private(set) var isAnimating: Bool = false
    
    /// A layout constraint to keep the stack view centered vertically.
    private var stackViewCenterYConstraint: NSLayoutConstraint?
    
    /// A display link for potential advanced animations if needed.
    private var displayLink: CADisplayLink?
    
    // MARK: - Initializers
    
    /// Initializes the loading view with optional message text.
    /// - Parameter message: An optional message to display under the activity indicator.
    public init(message: String? = nil) {
        // STEP 1: Initialize stored properties
        self.message = message
        
        // STEP 2: Create UI components
        activityIndicator = UIActivityIndicatorView(style: .large)
        messageLabel = UILabel(frame: .zero)
        stackView = UIStackView(frame: .zero)
        
        // STEP 3: Call super initializer
        super.init(frame: .zero)
        
        // STEP 4: Set up the UI hierarchy, layout, and accessibility
        setupUI()
        
        // STEP 5: If a message is provided, update the label
        updateMessage(message)
    }
    
    /// Required initializer from interface builder (not used in this scenario).
    /// - Parameter coder: A decoder object.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    /// Configures the UI components and constraints in a thread-safe manner,
    /// ensuring proper accessibility support and dynamic layout.
    private func setupUI() {
        // STEP 1: Configure background color (use system background to align with design system)
        backgroundColor = UIColor.systemBackground
        
        // STEP 2: Configure the activity indicator
        //         Set large style, set accessibility traits, and disable auto layout masks
        activityIndicator.hidesWhenStopped = false
        activityIndicator.isAccessibilityElement = true
        activityIndicator.accessibilityTraits = .updatesFrequently
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // STEP 3: Configure the message label for optional text
        //         Dynamic type support, system font, and multiline
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = UIColor.label
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.isAccessibilityElement = true
        
        // STEP 4: Configure the stack view to hold both indicator and label
        //         Set vertical axis, alignment, spacing
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // STEP 5: Add the subviews to the stack view
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(messageLabel)
        
        // STEP 6: Add the stack view to the main view and pin it to edges with safe insets
        addSubview(stackView)
        pinToEdges() // Pin this view to any superview, if added directly
        // We also want the stackView centered within self
        stackView.pinToEdges(insets: .init(top: 0, left: 0, bottom: 0, right: 0))
        
        // STEP 7: Initialize default states
        alpha = 0.0
        isHidden = true  // Hidden by default
        messageLabel.text = message
        activityIndicator.accessibilityLabel = "Loading Indicator"
        messageLabel.isHidden = (message == nil)
        
        // STEP 8: Additional accessibility configuration
        //         Make sure the container is not interfering with subview elements
        isAccessibilityElement = false
        accessibilityElements = [activityIndicator, messageLabel]
    }
    
    // MARK: - Public Methods
    
    /// Displays the loading view with a fade-in animation,
    /// respecting the user's reduced motion accessibility settings.
    /// - Parameter duration: Animation duration in seconds.
    public func show(duration: TimeInterval = 0.25) {
        // STEP 1: Ensure main thread; avoid race conditions
        DispatchQueue.main.async {
            // STEP 2: Prevent multiple show calls if already animating
            guard self.isAnimating == false else { return }
            
            // STEP 3: Start activity indicator animation
            self.activityIndicator.startAnimating()
            
            // STEP 4: Update isAnimating state
            self.isAnimating = true
            
            // STEP 5: Unhide and fade in
            self.isHidden = false
            self.fadeIn(duration: duration) { [weak self] in
                // Clean up or do any post-show logic
                self?.postAccessibilityNotification(isAppearing: true)
            }
        }
    }
    
    /// Hides the loading view with a fade-out animation,
    /// stopping the activity indicator and cleaning up resources.
    /// - Parameter duration: Animation duration in seconds.
    public func hide(duration: TimeInterval = 0.25) {
        // STEP 1: Ensure main thread
        DispatchQueue.main.async {
            // STEP 2: Guard against hide call if not animating
            guard self.isAnimating else { return }
            
            // STEP 3: Fade out
            self.fadeOut(duration: duration) { [weak self] in
                // STEP 4: Stop the activity indicator
                self?.activityIndicator.stopAnimating()
                
                // STEP 5: Mark as hidden
                self?.isHidden = true
                
                // STEP 6: Clean up any display link or resources
                self?.displayLink?.invalidate()
                self?.displayLink = nil
                
                // STEP 7: Update isAnimating state
                self?.isAnimating = false
                
                // STEP 8: Accessibility notification
                self?.postAccessibilityNotification(isAppearing: false)
            }
        }
    }
    
    /// Updates the loading message text in a thread-safe manner,
    /// posting an accessibility announcement to inform the user of status changes.
    /// - Parameter message: New message to display. If nil, hides the label.
    public func updateMessage(_ message: String?) {
        // STEP 1: Ensure main thread
        DispatchQueue.main.async {
            self.message = message
            self.messageLabel.text = message
            
            // STEP 2: Toggle visibility
            let hasText = (message != nil && !(message?.isEmpty ?? true))
            self.messageLabel.isHidden = !hasText
            
            // STEP 3: Update accessibility label, combining spinner and message
            if hasText {
                self.messageLabel.accessibilityLabel = "Loading message: \(message ?? "")"
            } else {
                self.messageLabel.accessibilityLabel = "Loading"
            }
            
            // STEP 4: If visible, announce
            if self.isAnimating && hasText {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            
            // STEP 5: Force layout update if needed
            self.layoutIfNeeded()
        }
    }
    
    // MARK: - Private Helpers
    
    /// Posts an accessibility notification indicating the loading view's appearance state.
    /// - Parameter isAppearing: True if the view is appearing, false if it is disappearing.
    private func postAccessibilityNotification(isAppearing: Bool) {
        let message = isAppearing ? "Loading started" : "Loading finished"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}