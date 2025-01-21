import UIKit // iOS 13.0+
import Combine // iOS 13.0+
// Internal import for thread-safe UI styling and animation utilities with reduced motion support
// File Path: src/ios/DogWalking/Core/Extensions/UIView+Extensions.swift
import CoreExtensions

// MARK: - Typealias for Animation Completion
/// Represents the completion closure type used after animation events.
public typealias AnimationCompletion = (() -> Void)

// MARK: - Error Analytics Protocol
/// Protocol defining methods for logging errors and analytics related to ErrorView.
public protocol ErrorAnalytics {
    /// Logs an error event with given title and message.
    /// - Parameters:
    ///   - title: A localized title describing the error.
    ///   - message: A localized message containing error details.
    func logErrorEvent(title: String, message: String)
}

// MARK: - Error State Enum
/// Represents various error states that the ErrorView can display.
public enum ErrorState: Equatable {
    /// Indicates no error or a cleared state.
    case none
    /// Indicates a network-related error (e.g., connectivity issues).
    case network
    /// Indicates a server-related error (e.g., HTTP 500).
    case server
    /// Indicates an unknown or generic error.
    case unknown
}

// MARK: - ErrorView
/// An advanced error view component with accessibility support, animations,
/// and comprehensive error state management. Conforms to the application’s
/// design system for standardized error handling and recovery tracking.
@available(iOS 13.0, *)
public class ErrorView: UIView {
    
    // MARK: - Subviews
    
    /// An icon used to visually convey the error type (e.g., warning or network error).
    public let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    /// A label displaying the primary title for the error state.
    public let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        return label
    }()
    
    /// A label providing a more detailed explanation of the error to the user.
    public let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        return label
    }()
    
    /// A button allowing the user to retry or recover from the error state.
    public let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Retry", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityTraits = .button
        return button
    }()
    
    // MARK: - Properties
    
    /// An optional closure invoked when the user taps the retry button.
    public var retryAction: (() -> Void)?
    
    /// The current error state, used to update and manage the error's presentation.
    public var currentErrorState: ErrorState = .none
    
    /// A cancellable reference for managing error state subscribers or Combine pipelines.
    public var stateCancellable: AnyCancellable?
    
    /// An accessibility identifier for UI testing and assistive technologies.
    public var accessibilityIdentifier: String?
    
    // MARK: - Initializers
    
    /// Initializes the error view with enhanced setup and accessibility configuration.
    /// - Parameter frame: The frame rectangle for the view.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        // STEP 1: Call super init
        // Already done in override init
        
        // STEP 2: Setup UI components with dynamic type support
        // This includes creating subviews and setting their properties.
        setupUI()
        
        // STEP 3: Configure layout constraints with iPad adaptations
        // This is included in `setupUI()` to handle device-agnostic constraints.
        
        // STEP 4: Setup accessibility properties and actions
        // Additional configuration steps done in `setupUI()` to ensure
        // VoiceOver, hint text, and accessibility labels are appropriately set.
        
        // STEP 5: Initialize error state management
        currentErrorState = .none
        
        // STEP 6: Configure animation or motion preferences (handled in show/hide).
        // We'll check `UIAccessibility.isReduceMotionEnabled` during show/hide transitions.
        
        // STEP 7: Apply default styling with dark mode support
        // We can set background color or other styling that adapts to traitCollection changes.
        backgroundColor = .systemBackground
        
        // Full layout pass to ensure proper sizing for subviews.
        layoutIfNeeded()
    }
    
    /// Required initializer for loading from nib or storyboard.
    /// - Parameter coder: A decoder object for unarchiving the view.
    public required init?(coder: NSCoder) {
        fatalError("ErrorView does not support init(coder:). Use init(frame:) instead.")
    }
    
    // MARK: - Setup UI
    
    /// Configures UI components with comprehensive styling and accessibility.
    /// - Note: This method is called during initialization to build subviews and constraints.
    private func setupUI() {
        // STEP 1: Add and configure iconImageView with dark mode assets
        addSubview(iconImageView)
        // Example placeholder image (can be replaced with dark/light assets)
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        iconImageView.tintColor = .systemRed
        
        // STEP 2: Add and configure titleLabel with dynamic type support
        addSubview(titleLabel)
        titleLabel.textColor = .label
        
        // STEP 3: Add and configure messageLabel with dynamic type support
        addSubview(messageLabel)
        messageLabel.textColor = .secondaryLabel
        
        // STEP 4: Configure retryButton with accessibility actions
        addSubview(retryButton)
        retryButton.addTarget(self, action: #selector(handleRetryTap), for: .touchUpInside)
        retryButton.accessibilityLabel = "Retry Button"
        retryButton.accessibilityHint = "Double-tap to retry the failed action"
        
        // STEP 5: Setup Auto Layout constraints for all devices (including iPad)
        setupConstraints()
        
        // STEP 6: Configure VoiceOver properties
        isAccessibilityElement = false
        iconImageView.isAccessibilityElement = false
        titleLabel.isAccessibilityElement = true
        messageLabel.isAccessibilityElement = true
        retryButton.isAccessibilityElement = true
        
        // STEP 7: Setup reduced motion alternatives (handled in show/hide animations).
        // We'll handle fade animations conditionally based on reduced motion settings.
        
        // Optional corner rounding for consistent style
        roundCorners(radius: 12.0, corners: [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                            .layerMinXMaxYCorner, .layerMaxXMaxYCorner])
    }
    
    // MARK: - Layout Constraints
    
    /// Sets up the layout constraints for the subviews, adapting to different device sizes.
    private func setupConstraints() {
        // Icon constraints
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            iconImageView.widthAnchor.constraint(equalToConstant: 48)
        ])
        
        // Title label constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        
        // Message label constraints
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        
        // Retry button constraints
        NSLayoutConstraint.activate([
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.heightAnchor.constraint(equalToConstant: 44),
            retryButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Configure
    
    /// Configures the error view with enhanced error tracking and analytics.
    /// - Parameters:
    ///   - title: A localized title describing the error succinctly.
    ///   - message: A localized message describing the error details.
    ///   - retryAction: An optional closure to handle user-initiated retries.
    ///   - analytics: An optional analytics logger conforming to ErrorAnalytics.
    public func configure(title: String,
                          message: String,
                          retryAction: (() -> Void)?,
                          analytics: ErrorAnalytics? = nil) {
        
        // STEP 1: Update error state with new configuration
        currentErrorState = determineErrorState(from: title)
        
        // STEP 2: Set localized title and message
        titleLabel.text = title
        messageLabel.text = message
        
        // STEP 3: Configure retry action with error tracking
        self.retryAction = retryAction
        
        // STEP 4: Update accessibility labels
        titleLabel.accessibilityLabel = "Error Title: \(title)"
        messageLabel.accessibilityLabel = "Error Message: \(message)"
        
        // STEP 5: Log error occurrence for analytics
        analytics?.logErrorEvent(title: title, message: message)
        
        // STEP 6: Update UI state with new configuration
        updateIconForState(currentErrorState)
        
        // STEP 7: Prepare error recovery tracking
        // Additional tracking code or state updates can be implemented here.
    }
    
    // MARK: - Show
    
    /// Displays the error view with optimized animations and state management.
    /// - Parameter completion: An optional closure executed upon animation completion.
    public func show(completion: AnimationCompletion? = nil) {
        // STEP 1: Check reduced motion preference
        if UIAccessibility.isReduceMotionEnabled {
            // If reduced motion is enabled, skip fade animation
            alpha = 1.0
            isHidden = false
            // STEP 2: Prepare view for display with current theme
            // Already handled by setting backgroundColor, etc.
            completion?()
            // STEP 3: Update error state persistence or logs if needed
            return
        }
        
        // If reduced motion is not enabled, fade in
        alpha = 0.0
        isHidden = false
        
        // STEP 4: Prepare view for display with current theme
        // Additional code to adapt to dark mode or theme can be added here.
        
        // STEP 5: Execute fade in animation
        fadeIn(duration: 0.3) { [weak self] in
            // STEP 6: Update accessibility state
            UIAccessibility.post(notification: .screenChanged, argument: self)
            
            // STEP 7: Log view presentation analytics if required
            // e.g., analytics?.logViewPresentation()
            
            // STEP 8: Update error state persistence
            // Additional state management code can be placed here.
            
            // STEP 9: Handle animation completion
            completion?()
        }
    }
    
    // MARK: - Hide
    
    /// Hides the error view with cleanup and state reset.
    /// - Parameter completion: An optional closure executed upon animation completion.
    public func hide(completion: AnimationCompletion? = nil) {
        // STEP 1: Check reduced motion preference
        if UIAccessibility.isReduceMotionEnabled {
            alpha = 0.0
            isHidden = true
            
            // STEP 2: Clean up error state
            currentErrorState = .none
            
            // STEP 3: Reset accessibility elements
            UIAccessibility.post(notification: .screenChanged, argument: nil)
            
            // STEP 4: Remove from superview if needed
            removeFromSuperview()
            
            // STEP 5: Log view dismissal analytics
            // e.g., analytics?.logViewDismissal()
            
            // STEP 6: Execute completion handler
            completion?()
            return
        }
        
        // STEP 2: Execute fade out animation
        fadeOut(duration: 0.3) { [weak self] in
            // STEP 3: Clean up error state
            self?.currentErrorState = .none
            
            // STEP 4: Reset accessibility elements
            UIAccessibility.post(notification: .screenChanged, argument: nil)
            
            // STEP 5: Remove from superview
            self?.removeFromSuperview()
            
            // STEP 6: Log view dismissal analytics
            // e.g., analytics?.logViewDismissal()
            
            // STEP 7: Execute completion handler
            completion?()
        }
    }
    
    // MARK: - Private Helpers
    
    /// Determines the error state from a given title. (Simplistic approach)
    /// - Parameter title: A string representing the error title.
    /// - Returns: An appropriate ErrorState inferred from the title keywords.
    private func determineErrorState(from title: String) -> ErrorState {
        let lowercaseTitle = title.lowercased()
        if lowercaseTitle.contains("network") {
            return .network
        } else if lowercaseTitle.contains("server") {
            return .server
        } else {
            return .unknown
        }
    }
    
    /// Updates the icon based on the current error state.
    /// - Parameter state: The error state governing which icon to display.
    private func updateIconForState(_ state: ErrorState) {
        switch state {
        case .none:
            iconImageView.image = UIImage(systemName: "checkmark.circle")
            iconImageView.tintColor = .systemGreen
        case .network:
            iconImageView.image = UIImage(systemName: "wifi.exclamationmark")
            iconImageView.tintColor = .systemOrange
        case .server:
            iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            iconImageView.tintColor = .systemRed
        case .unknown:
            iconImageView.image = UIImage(systemName: "questionmark.circle.fill")
            iconImageView.tintColor = .systemGray
        }
    }
    
    /// Handles the tap action on the retry button.
    @objc private func handleRetryTap() {
        // Trigger the retry action if available.
        retryAction?()
    }
}