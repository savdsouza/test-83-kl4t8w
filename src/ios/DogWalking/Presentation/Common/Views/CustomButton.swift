//
//  CustomButton.swift
//
//  A custom UIButton subclass implementing the app's design system specifications
//  for edge-aligned, responsive, and accessible buttons. This component accounts
//  for interactive states, loading/spinner states, animations, and dynamic color
//  adjustments.
//
//  Imports:
//  - UIKit (iOS 13.0+)
//  - Internal extensions for UIView (shadow, corner rounding) and UIColor (primary, secondary, etc.)
//
//  Production-Ready, Enterprise-Grade Implementation
//

import UIKit // iOS 13.0+ (Core iOS UI framework)
import CoreGraphics
import Foundation

// Internal Imports (as specified)
import DogWalking.Core.Extensions.UIView_Extensions // for addShadow, roundCorners
import DogWalking.Core.Extensions.UIColor_Extensions // for .primary, .secondary, plus color manipulation

/// Represents predefined button styles that conform to the design system.
/// Each style can specify a recommended corner radius, background color,
/// text color, shadow application, and any other relevant traits.
public enum ButtonStyle {
    case primary
    case secondary
    case outline
    case custom(backgroundColor: UIColor, textColor: UIColor, hasShadow: Bool, cornerRadius: CGFloat)
    
    /// Retrieves the recommended background color for the style.
    /// Defaults to the design system's primary or secondary brand colors
    /// while allowing custom configurations.
    func backgroundColor() -> UIColor {
        switch self {
        case .primary:
            return .primary
        case .secondary:
            return .secondary
        case .outline:
            // Typically, an outline style might use clear background
            // so the border can stand out.
            return .clear
        case .custom(let bgColor, _, _, _):
            return bgColor
        }
    }
    
    /// Retrieves the recommended text color for the style.
    func textColor() -> UIColor {
        switch self {
        case .primary, .secondary:
            return .white
        case .outline:
            // For an outline style, we might use primary text color.
            return .primary
        case .custom(_, let txtColor, _, _):
            return txtColor
        }
    }
    
    /// Indicates whether a shadow should be applied to the style.
    func hasShadow() -> Bool {
        switch self {
        case .primary, .secondary:
            return true
        case .outline:
            return false
        case .custom(_, _, let shadow, _):
            return shadow
        }
    }
    
    /// Retrieves a recommended corner radius for the style.
    func cornerRadius() -> CGFloat {
        switch self {
        case .primary, .secondary:
            // Example default for brand styles
            return 8.0
        case .outline:
            return 8.0
        case .custom(_, _, _, let radius):
            return radius
        }
    }
}

/// A custom UIButton subclass implementing the app's design system with support
/// for multiple styles, loading states, animations, and accessibility.
public class CustomButton: UIButton {
    
    // MARK: - Public Properties
    
    /// The style of the button, dictating color, typography, etc.
    public var style: ButtonStyle
    
    /// The corner radius used for the button. Usually derived from the style,
    /// but exposed publicly if further customization is needed after initialization.
    public var cornerRadius: CGFloat
    
    /// A boolean flag indicating whether the button is in a loading state.
    /// Access this property to get or set the current loading state programmatically.
    public private(set) var isLoading: Bool = false
    
    // MARK: - Internal/Private Properties
    
    /// An activity indicator for displaying a loading or busy state.
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    /// A haptic feedback generator to provide tactile feedback on button interactions.
    private let feedbackGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        return generator
    }()
    
    /// Stores the button's original transform to restore after touch animations.
    private var originalTransform: CATransform3D = CATransform3DIdentity
    
    /// Override to ensure this element is recognized as a button for accessibility.
    public override var isAccessibilityElement: Bool {
        get { return super.isAccessibilityElement }
        set { super.isAccessibilityElement = newValue }
    }
    
    // MARK: - Initializers
    
    /// Initializes the button with a specific style and configures initial appearance.
    /// - Parameter style: The ButtonStyle to be applied to the button's UI.
    public init(style: ButtonStyle) {
        self.style = style
        self.cornerRadius = style.cornerRadius()
        super.init(frame: .zero)
        
        // 1. Configure initial appearance.
        setupAppearance()
        
        // 2. Add the loading indicator and its constraints.
        addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // 3. Initialize feedback generator.
        feedbackGenerator.prepare()
        
        // 4. Configure accessibility properties.
        isAccessibilityElement = true
        accessibilityTraits = .button
        
        // 5. Add touch event handlers for user interaction states.
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
        addTarget(self, action: #selector(touchUp), for: .touchCancel)
        addTarget(self, action: #selector(touchUp), for: .touchDragExit)
        
        // 6. Store the original transform for animation reference.
        originalTransform = layer.transform
    }
    
    /// Required initializer for subclasses of UIButton when using storyboards or nibs.
    /// Not implemented here as we rely on programmatic UI layout.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Appearance
    
    /// Configures the button's visual appearance based on style and current theme.
    @objc private func setupAppearance() {
        // Apply corner radius from style or custom override
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false
        
        // Background color for the normal state
        backgroundColor = style.backgroundColor()
        
        // Title label font. Using the design system's default MD size as an example.
        let fontSize = Typography.FONT_SIZES["MD"] ?? 16.0
        if let fontWeight = Typography.FONT_WEIGHTS["Semibold"] {
            titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        } else {
            titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        }
        setTitleColor(style.textColor(), for: .normal)
        
        // Content insets for proper spacing (8pt vertical, 16pt horizontal as an example).
        contentEdgeInsets = UIEdgeInsets(
            top: 8.0,
            left: 16.0,
            bottom: 8.0,
            right: 16.0
        )
        
        // Enable Dynamic Type scaling for accessibility
        titleLabel?.adjustsFontForContentSizeCategory = true
        
        // Apply shadow if the style indicates it
        if style.hasShadow() {
            // Example usage: add a subtle shadow
            addShadow(radius: 2.0,
                      opacity: 0.3,
                      offset: 2.0,
                      color: .black)
        } else {
            layer.shadowOpacity = 0.0
        }
    }
    
    // MARK: - Loading State
    
    /// Shows or hides the loading state with smooth animations, updating the
    /// button's interactivity, title, and visual feedback accordingly.
    /// - Parameter loading: A Bool flag to indicate the desired loading state.
    public func setLoading(_ loading: Bool) {
        isLoading = loading
        
        // Smoothly animate changes
        UIView.animate(withDuration: 0.2, animations: {
            // Fade out the title if loading
            self.titleLabel?.alpha = loading ? 0.0 : 1.0
        })
        
        // Manage loading indicator visibility
        if loading {
            loadingIndicator.startAnimating()
            isUserInteractionEnabled = false
            accessibilityValue = "Loading"
        } else {
            loadingIndicator.stopAnimating()
            isUserInteractionEnabled = true
            accessibilityValue = nil
        }
    }
    
    // MARK: - Touch Handlers
    
    /// Handles the touch down interaction with animations and haptic feedback.
    @objc private func touchDown() {
        // Animate scale down to 0.95
        UIView.animate(withDuration: 0.1, animations: {
            self.layer.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
            // Darken the background color slightly
            self.backgroundColor = self.style.backgroundColor().darker(0.1)
        })
        
        // Trigger haptic feedback
        feedbackGenerator.impactOccurred()
        
        // Update accessibility to indicate pressed state
        accessibilityValue = "Pressed"
    }
    
    /// Handles the touch up interaction to restore the original state.
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2, animations: {
            // Restore original transform
            self.layer.transform = self.originalTransform
            // Reset background color
            self.backgroundColor = self.style.backgroundColor()
        }, completion: { _ in
            // Cleanup or further actions if needed
        })
        
        // Clear out the pressed accessibility value
        accessibilityValue = nil
    }
}