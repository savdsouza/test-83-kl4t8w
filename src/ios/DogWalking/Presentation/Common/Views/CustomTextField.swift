//
//  CustomTextField.swift
//  DogWalking
//
//  A custom UITextField subclass with enhanced styling, validation, accessibility,
//  and interaction capabilities. This file strictly follows the design system
//  specifications (typography, spacing, and color), provides secure text input handling,
//  and integrates a comprehensive error display mechanism.
//
//  Created by DogWalking Mobile Team
//  © 2023 DogWalking Inc. All rights reserved.
//

// MARK: - External Imports (UIKit iOS 13.0+)
import UIKit // iOS 13.0+

// MARK: - Internal Imports (Named)
import CoreExtensions // Placeholder module import illustration; replaced by actual import below
import CoreConstants  // Placeholder module import illustration; replaced by actual import below

// Explicit named imports from UIView+Extensions
import class DogWalking.Core.Extensions.UIView_Extensions
import func DogWalking.Core.Extensions.UIView_Extensions.addShadow
import func DogWalking.Core.Extensions.UIView_Extensions.addBorder
import func DogWalking.Core.Extensions.UIView_Extensions.roundCorners

// Explicit named imports from String+Extensions
import class DogWalking.Core.Extensions.String_Extensions
import var DogWalking.Core.Extensions.String_Extensions.isValidEmail
import var DogWalking.Core.Extensions.String_Extensions.isValidPassword
import var DogWalking.Core.Extensions.String_Extensions.trimmed
import var DogWalking.Core.Extensions.String_Extensions.containsSpecialCharacters

// Explicit named imports from AppConstants (Typography)
import enum DogWalking.Core.Constants.AppConstants.Typography
import var DogWalking.Core.Constants.AppConstants.Typography.FONT_FAMILY_PRIMARY
import var DogWalking.Core.Constants.AppConstants.Typography.FONT_SIZES
import var DogWalking.Core.Constants.AppConstants.Typography.FONT_WEIGHTS

/// Describes the various validation options available to the CustomTextField.
/// Additional cases can be added for domain-specific validation.
public enum ValidationStyle {
    case none
    case email
    case password
    /// A custom validation closure to handle specialized logic.
    case custom((String) -> Bool)
}

/// A custom UITextField subclass that implements the application's design system
/// with enhanced styling, validation, accessibility, and interaction features.
public class CustomTextField: UITextField {
    
    // MARK: - Public Properties
    
    /// The validation style determining how this text field validates its content.
    public var validationType: ValidationStyle = .none
    
    /// The border color applied in normal, non-error state.
    public var borderColor: UIColor = .lightGray
    
    /// The corner radius for the text field's layer.
    public var cornerRadius: CGFloat = 8.0
    
    /// Inset padding for the text content area.
    public var textPadding: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    
    /// Optional placeholder text to display when the field is empty.
    public var placeholderText: String? {
        didSet {
            configurePlaceholder()
        }
    }
    
    /// Indicates whether the current text content is considered valid.
    public private(set) var isValid: Bool = true
    
    /// Holds the current error message, if any.
    public private(set) var errorMessage: String?
    
    /// Tracks the dark mode state; updates styling accordingly.
    public var isDarkMode: Bool = false {
        didSet {
            applyCurrentTheme()
        }
    }
    
    /// Holds the current scaled font for dynamic text support.
    public var scaledFont: UIFont = UIFont.systemFont(ofSize: 16.0)
    
    /// A height constraint reference for dynamic UI adjustments.
    public var heightConstraint: NSLayoutConstraint = NSLayoutConstraint()
    
    // MARK: - Private UI Elements
    
    /// A label used to display validation error messages with proper contrast and accessibility.
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initializers
    
    /// Primary designated initializer that sets up the custom text field with
    /// enhanced styling and accessibility support.
    /// - Parameter frame: The frame rectangle for the text field.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        // STEP 1: Call super.init with frame (already done above).
        // STEP 2: Setup default styling with dark mode support.
        isDarkMode = (traitCollection.userInterfaceStyle == .dark)
        
        // STEP 3: Configure dynamic text padding.
        // (Implementation occurs in overridden textRect and editingRect.)
        
        // STEP 4: Apply corner radius and elevation.
        layer.cornerRadius = cornerRadius
        addShadow(radius: 2.0, opacity: 0.1, offset: 2.0, color: .black)
        
        // STEP 5: Setup placeholder attributes with proper contrast.
        configurePlaceholder()
        
        // STEP 6: Configure accessibility properties.
        accessibilityTraits = .staticText
        
        // STEP 7: Add target-action for text changes.
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        
        // STEP 8: Setup validation debouncing (basic example can be immediate or can be extended).
        // For brevity, we rely on textDidChange for validation triggers.
        
        // STEP 9: Register for theme changes (traitCollectionDidChange or NotificationCenter).
        // We'll use traitCollectionDidChange for dynamic theme updates.
        
        // STEP 10: Initialize scaled font from design system.
        updateScaledFont()
        
        // Add the error label to the view hierarchy.
        setupErrorLabel()
    }
    
    /// Convenience initializer to handle storyboard or xib usage.
    /// - Parameter aDecoder: The coder object for decoding.
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // Mirror the initialization steps from init(frame:).
        isDarkMode = (traitCollection.userInterfaceStyle == .dark)
        layer.cornerRadius = cornerRadius
        addShadow(radius: 2.0, opacity: 0.1, offset: 2.0, color: .black)
        configurePlaceholder()
        accessibilityTraits = .staticText
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        updateScaledFont()
        setupErrorLabel()
    }
    
    // MARK: - Lifecycle Overrides
    
    /// Automatically called when interface environment changes (e.g., dark or light mode).
    /// We refresh the isDarkMode property to reapply styles.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            isDarkMode = (traitCollection.userInterfaceStyle == .dark)
        }
    }
    
    // MARK: - Layout Overrides
    
    /// Provides the text area rect, applying the specified textPadding in normal display.
    /// - Parameter bounds: The current bounds of the text field.
    /// - Returns: A smaller rect inset by textPadding.
    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textPadding)
    }
    
    /// Provides the editing text area rect, applying the specified textPadding in editing mode.
    /// - Parameter bounds: The current bounds of the text field.
    /// - Returns: A smaller rect inset by textPadding.
    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textPadding)
    }
    
    // MARK: - Private Setup Methods
    
    /// Creates and lays out the errorLabel beneath the text field for displaying error messages.
    private func setupErrorLabel() {
        guard let superview = superview ?? self.superview else { return }
        superview.addSubview(errorLabel)
        
        // Constraints for positioning error label at the bottom of the text field.
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: bottomAnchor, constant: 4),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
    }
    
    /// Builds or updates the placeholder attributes with appropriate text color for the theme.
    private func configurePlaceholder() {
        let placeholderValue = placeholderText ?? ""
        let placeholderColor: UIColor = isDarkMode ? .lightGray : .darkGray
        attributedPlaceholder = NSAttributedString(
            string: placeholderValue,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: scaledFont
            ]
        )
    }
    
    /// Updates the font based on the Typography design system, applying scale transformations if needed.
    private func updateScaledFont() {
        let baseSize = FONT_SIZES["MD"] ?? 16.0
        let weight = FONT_WEIGHTS["Regular"] ?? .regular
        if let primaryFontName = FONT_FAMILY_PRIMARY.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
           let customFont = UIFont(name: primaryFontName, size: baseSize) {
            scaledFont = UIFont(descriptor: customFont.fontDescriptor, size: baseSize)
        } else {
            scaledFont = UIFont.systemFont(ofSize: baseSize, weight: weight)
        }
        font = scaledFont
    }
    
    /// Applies the current theme (dark or light) to relevant properties for consistent UI styling.
    private func applyCurrentTheme() {
        let currentBackground: UIColor = isDarkMode ? .black : .white
        backgroundColor = currentBackground
        configurePlaceholder()
        
        // Update border color for dark mode if desired.
        let adjustedBorderColor = isDarkMode ? UIColor.white.withAlphaComponent(0.25) : borderColor
        addBorder(width: 1.0, color: adjustedBorderColor)
        // If needed, refresh the error label's style if an error is present.
        if let message = errorMessage {
            showError(message)
        }
    }
    
    // MARK: - Target Actions
    
    /// Triggered whenever the text in the field changes. Can trigger validation or updates.
    @objc private func textDidChange() {
        _ = validate()
    }
    
    // MARK: - Public Methods
    
    /// Configures the visual appearance with dynamic styling support.
    /// This method can be called explicitly if the client needs to reapply styling at runtime.
    public func setupStyle() {
        // STEP 1: Apply scaled font from Typography constants.
        updateScaledFont()
        
        // STEP 2: Set dynamic border color and width.
        addBorder(width: 1.0, color: isDarkMode ? UIColor.white.withAlphaComponent(0.25) : borderColor)
        
        // STEP 3: Apply corner radius with elevation (shadow).
        layer.cornerRadius = cornerRadius
        addShadow(radius: 2.0, opacity: 0.1, offset: 2.0, color: .black)
        
        // STEP 4: Configure dynamic text color and alignment.
        textColor = isDarkMode ? .white : .black
        textAlignment = .left
        
        // STEP 5: Setup background color with dark mode support.
        applyCurrentTheme()
        
        // STEP 6: Configure accessibility traits.
        accessibilityTraits = .staticText
        
        // STEP 7: Setup input traits for keyboard.
        keyboardType = .default
        autocorrectionType = .no
        spellCheckingType = .no
        
        // STEP 8: Apply text content type if needed (e.g., .emailAddress when ValidationStyle.email).
        switch validationType {
        case .email:
            textContentType = .emailAddress
        case .password:
            textContentType = .password
            isSecureTextEntry = true
        case .custom, .none:
            textContentType = .none
        }
    }
    
    /// Validates the text field content with enhanced validation rules.
    /// - Returns: A Boolean indicating whether the content is valid.
    @discardableResult
    public func validate() -> Bool {
        // STEP 1: Get current text value with proper trimming.
        let currentText = (self.text ?? "").trimmed
        
        // STEP 2: Check validation type and requirements.
        var validated = true
        switch validationType {
        case .email:
            validated = currentText.isValidEmail
        case .password:
            validated = currentText.isValidPassword
        case .custom(let block):
            validated = block(currentText)
        case .none:
            validated = true
        }
        
        // STEP 3: Apply additional security checks or domain checks if needed.
        // (e.g., checking for special characters if required.)
        
        // STEP 4: Update isValid property with thread safety (on main thread).
        DispatchQueue.main.async {
            self.isValid = validated
        }
        
        // STEP 5: Update error state if invalid with accessibility announcement.
        if !validated {
            let message = localizedErrorMessage(for: validationType)
            showError(message)
            UIAccessibility.post(notification: .announcement, argument: message)
        } else {
            // Clear error if it was previously shown.
            clearError()
        }
        
        // STEP 6: Handle validation state transitions if needed (additional UI changes).
        
        // STEP 7: Return validation result.
        return validated
    }
    
    /// Displays the error state with accessibility support.
    /// - Parameter message: The localized error message to display.
    public func showError(_ message: String) {
        // STEP 1: Set localized error message (store it, too).
        errorMessage = message
        errorLabel.text = message
        
        // STEP 2: Apply error state styling with animation.
        UIView.animate(withDuration: 0.2) {
            // Emphasize the border for error.
            self.addBorder(width: 1.0, color: .red)
            self.backgroundColor = self.isDarkMode
                ? UIColor.red.withAlphaComponent(0.2)
                : UIColor.red.withAlphaComponent(0.1)
        }
        
        // STEP 3: Show error label with proper contrast.
        errorLabel.textColor = .red
        errorLabel.isHidden = false
        
        // STEP 4: Update border color to error state (already done above).
        
        // STEP 5: Announce error message to VoiceOver (triggered in validate).
        
        // STEP 6: Update accessibility value for the text field.
        accessibilityValue = "Error: \(message)"
        
        // STEP 7: Handle error state layout updates (fade in label or simply ensure it's visible).
        errorLabel.alpha = 0.0
        UIView.animate(withDuration: 0.3) {
            self.errorLabel.alpha = 1.0
        }
    }
    
    /// Clears the error state with proper styling and accessibility updates.
    public func clearError() {
        // STEP 1: Clear error message state.
        errorMessage = nil
        errorLabel.text = nil
        
        // STEP 2: Restore normal styling with animation.
        UIView.animate(withDuration: 0.2) {
            self.addBorder(width: 1.0, color: self.isDarkMode
                           ? UIColor.white.withAlphaComponent(0.25)
                           : self.borderColor)
            let defaultBackground: UIColor = self.isDarkMode ? .black : .white
            self.backgroundColor = defaultBackground
        }
        
        // STEP 3: Hide error label with a transition.
        UIView.animate(withDuration: 0.3) {
            self.errorLabel.alpha = 0.0
        } completion: { _ in
            self.errorLabel.isHidden = true
        }
        
        // STEP 4: Reset border color with theme awareness (handled in the animation above).
        
        // STEP 5: Update accessibility state.
        accessibilityValue = nil
        
        // STEP 6: Handle layout updates if needed (e.g., constraint changes).
        
        // STEP 7: Reset validation state (since error is cleared, assume normal).
        DispatchQueue.main.async {
            self.isValid = true
        }
    }
    
    // MARK: - Helper Methods
    
    /// Provides a localized error message for a given validation style.
    /// - Parameter style: The validation style to derive a message for.
    /// - Returns: A user-readable localized string describing the error.
    private func localizedErrorMessage(for style: ValidationStyle) -> String {
        switch style {
        case .email:
            return "Please enter a valid email address."
        case .password:
            return "Password must be at least 12 characters, including letters, digits, and special characters."
        case .custom(_):
            return "Invalid input."
        case .none:
            return "Invalid input."
        }
    }
}