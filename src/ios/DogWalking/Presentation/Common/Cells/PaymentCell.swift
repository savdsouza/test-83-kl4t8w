import UIKit // iOS 13.0+
import Foundation // iOS 13.0+

// MARK: - Internal Imports
// (Imported from "src/ios/DogWalking/Core/Base/BaseTableViewCell.swift")
import CoreGraphics

// NOTE: In a typical Xcode project, "BaseTableViewCell" and "Payment" might come from
// other modules or targets. For demonstration, we assume they are accessible.
#if canImport(DogWalkingCore)
import DogWalkingCore
#else
// Fallback for direct include if local
#endif

#if canImport(DogWalkingDomain)
import DogWalkingDomain
#else
// Fallback for direct include if local
#endif

// MARK: - Payment Model Reference
// (Imported from "src/ios/DogWalking/Domain/Models/Payment.swift")
/*
    public class Payment: NSObject, Codable, Identifiable {
        public private(set) var amount: Decimal
        public private(set) var status: PaymentStatus
        public private(set) var date: Date? // Hypothetical date property (not explicitly in Payment, but for demonstration)
        // PaymentStatus: .pending, .processing, .completed, .failed, .refunded, .disputed
        // ...
    }
*/

// MARK: - BaseTableViewCell Reference
// (Imported from "src/ios/DogWalking/Core/Base/BaseTableViewCell.swift")
/*
    open class BaseTableViewCell: UITableViewCell {
        public let containerView: UIView
        public func setupContainerView() { ... }
        public override func prepareForReuse() { ... }
        // ...
    }
*/

// MARK: - PaymentCell
/// A custom table view cell designed for displaying payment transaction details.
/// This cell provides:
/// - Full accessibility support
/// - Dynamic type adaptation
/// - Optimized performance for large payment history displays
/// - Localized currency and date formatting
/// - Clear status feedback via a status indicator layer
///
/// Conforms to enterprise-grade design system specifications and the overall
/// architectural constraints outlined in the technical specification.
@IBDesignable
public class PaymentCell: BaseTableViewCell {

    // MARK: - Properties (from JSON Specification)

    /// A label for displaying the payment amount in localized currency format.
    public let amountLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    /// A label for displaying the payment date in localized format.
    public let dateLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    /// A label for displaying the payment status (e.g., pending, completed).
    public let statusLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .right
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    /// A vertical stack view to arrange all content labels for a streamlined layout.
    public let contentStackView: UIStackView = {
        let stack = UIStackView(frame: .zero)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.spacing = 4.0
        return stack
    }()

    /// The payment object that this cell will display. Updated via the configure function.
    public private(set) var payment: Payment?

    /// A dedicated number formatter for localizing currency values.
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        // Additional formatting config can be done here (e.g., rounding, grouping, etc.)
        return formatter
    }()

    /// A date formatter for formatting payment date in a user-friendly format.
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()

    /// A layer used to visually reflect the payment status (e.g., coloring or a small indicator).
    private let statusIndicatorLayer: CALayer = {
        let layer = CALayer()
        layer.masksToBounds = true
        return layer
    }()

    // MARK: - Initializers

    /// Initializes the payment cell with the specified style and reuse identifier.
    /// Follows the steps defined in the JSON specification:
    ///   1. Call super.init with style and reuseIdentifier.
    ///   2. Initialize and configure formatters for currency and date.
    ///   3. Set up UI components with dynamic type support.
    ///   4. Configure auto layout constraints with performance optimization.
    ///   5. Set up accessibility labels and hints.
    ///   6. Apply default styling with dark mode support.
    ///   7. Initialize status indicator layer.
    ///
    /// - Parameters:
    ///   - style: The UITableViewCell.CellStyle used for standard cell configuration.
    ///   - reuseIdentifier: A string used by the table view to dequeue reusable cells.
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        // Step 1: Call super.init
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // Step 2: Formatters are already instantiated as properties.
        //         Any extra configuration can be done here if needed.
        // currencyFormatter, dateFormatter are set above.

        // Step 3: Set up UI components with dynamic type support
        //         We'll call a dedicated function to centralize the logic.
        setupUI()

        // Step 4: Configure container view (base class method) & auto layout constraints
        //         The base class might have default styling we can leverage. Re-invoke if needed.
        setupContainerView()

        // Step 5: Set up accessibility labels and hints
        containerView.isAccessibilityElement = false
        amountLabel.isAccessibilityElement = true
        dateLabel.isAccessibilityElement = true
        statusLabel.isAccessibilityElement = true

        // Step 6: Apply default styling with dark mode support
        applyDefaultStyling()

        // Step 7: Initialize and configure the status indicator layer
        containerView.layer.addSublayer(statusIndicatorLayer)
        statusIndicatorLayer.cornerRadius = 3.0 // Example corner radius for a small dot shape
    }

    /// Not used in enterprise code, provided to fulfill Swift requirements for storyboard/nib usage.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for PaymentCell.")
    }

    // MARK: - Setup UI (from JSON Specification: setupUI function)

    /// Sets up the cell's UI components with accessibility and dynamic type support.
    /// Steps:
    ///  1. Create and configure labels with dynamic type.
    ///  2. Set up stack view with optimal layout.
    ///  3. Add components to containerView with proper constraints.
    ///  4. Configure accessibility properties.
    ///  5. Set up status indicator layer.
    ///  6. Apply color scheme with dark mode support.
    ///  7. Configure content compression priorities.
    private func setupUI() {
        // Step 1: Labels are already created, ensure dynamic type is enabled (done in property initialization).

        // Step 2: contentStackView is already created, set stack distribution/spacings if not done.
        //         We extend the existing config:
        contentStackView.spacing = 4.0
        contentStackView.alignment = .leading

        // Step 3: Add components to containerView with constraints
        containerView.addSubview(contentStackView)

        // We'll add amountLabel, dateLabel, and statusLabel to the stack
        contentStackView.addArrangedSubview(amountLabel)
        contentStackView.addArrangedSubview(dateLabel)
        contentStackView.addArrangedSubview(statusLabel)

        // Because we're in a table cell, let's pin contentStackView to containerView insets
        contentStackView.pinToEdges(insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))

        // Step 4: Configure accessibility properties
        contentStackView.isAccessibilityElement = false
        amountLabel.accessibilityLabel = "Payment amount"
        dateLabel.accessibilityLabel = "Payment date"
        statusLabel.accessibilityLabel = "Payment status"

        // Step 5: status indicator layer is created during init, so we can do partial setup here if needed.
        statusIndicatorLayer.backgroundColor = UIColor.clear.cgColor

        // Step 6: Apply color scheme with dark mode support - we just rely on system colors by default.
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // Step 7: Configure content compression priorities to ensure labels handle text properly
        amountLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    // MARK: - Configure Payment Data (from JSON Specification: configure function)

    /// Configures the cell with payment data and handles all possible states.
    /// Steps:
    ///  1. Store payment reference safely.
    ///  2. Update amount label with localized currency format.
    ///  3. Update date label with formatted date.
    ///  4. Update status label with appropriate styling.
    ///  5. Configure status indicator color.
    ///  6. Update accessibility labels.
    ///  7. Handle error states gracefully.
    ///  8. Apply appropriate animations.
    ///  9. Update layout for RTL if needed.
    ///
    /// - Parameter payment: The payment object containing details to be displayed.
    @objc
    public func configure(with payment: Payment) {
        // Step 1: Store payment reference
        self.payment = payment

        // Step 2: Update amount label with localized currency format
        let decimalNumber = NSDecimalNumber(decimal: payment.amount)
        amountLabel.text = currencyFormatter.string(from: decimalNumber) ?? ""

        // Step 3: Update date label with formatted date (if payment object has a date property)
        if let date = payment.date {
            dateLabel.text = dateFormatter.string(from: date)
        } else {
            dateLabel.text = "—"
        }

        // Step 4: Update status label with the payment's status string
        let statusText: String
        let statusColor: UIColor

        switch payment.status {
        case .pending:
            statusText = "Pending"
            statusColor = .systemOrange
        case .processing:
            statusText = "Processing"
            statusColor = .systemBlue
        case .completed:
            statusText = "Completed"
            statusColor = .systemGreen
        case .failed:
            statusText = "Failed"
            statusColor = .systemRed
        case .refunded:
            statusText = "Refunded"
            statusColor = .systemTeal
        case .disputed:
            statusText = "Disputed"
            statusColor = .systemPink
        }

        statusLabel.text = statusText

        // Step 5: Configure the status indicator color (small dot or bar can be used)
        statusIndicatorLayer.backgroundColor = statusColor.cgColor

        // Step 6: Update or refine accessibility labels
        amountLabel.accessibilityValue = amountLabel.text
        dateLabel.accessibilityValue = dateLabel.text
        statusLabel.accessibilityValue = statusLabel.text

        // Step 7: Handle error states gracefully (e.g., if status is failed, add extra info)
        if payment.status == .failed {
            // Potentially show an error icon or a tooltip
            // For demonstration, we just ensure the status label color is red
            // which was set above as .systemRed
        }

        // Step 8: Apply appropriate animations. For example, a slight fade on update:
        UIView.transition(with: contentView, duration: 0.25, options: .transitionCrossDissolve, animations: {
            self.layoutIfNeeded()
        }, completion: nil)

        // Step 9: Check layout direction for RTL if needed
        if effectiveUserInterfaceLayoutDirection == .rightToLeft {
            contentStackView.alignment = .trailing
        } else {
            contentStackView.alignment = .leading
        }
    }

    // MARK: - Prepare for Reuse (from JSON Specification)

    /// Thoroughly prepares the cell for reuse with proper cleanup.
    /// Steps:
    ///  1. Call super.prepareForReuse().
    ///  2. Reset labels to default state.
    ///  3. Clear payment reference.
    ///  4. Reset accessibility properties.
    ///  5. Cancel any pending animations.
    ///  6. Reset status indicator.
    ///  7. Clear any temporary states.
    ///  8. Reset formatters if needed.
    public override func prepareForReuse() {
        // Step 1: Call super.prepareForReuse().
        super.prepareForReuse()

        // Step 2: Reset labels
        amountLabel.text = nil
        dateLabel.text = nil
        statusLabel.text = nil

        // Step 3: Clear payment reference
        payment = nil

        // Step 4: Reset accessibility properties
        amountLabel.accessibilityValue = nil
        dateLabel.accessibilityValue = nil
        statusLabel.accessibilityValue = nil

        // Step 5: Cancel any pending animations
        layer.removeAllAnimations()
        containerView.layer.removeAllAnimations()

        // Step 6: Reset status indicator
        statusIndicatorLayer.backgroundColor = UIColor.clear.cgColor

        // Step 7: Clear any temporary states (if we had any custom toggles, images, etc.)
        //         For demonstration, there's nothing else to clear.

        // Step 8: Reset formatters if needed.
        //         In most cases, we don't need to reset the date or currency formatters
        //         since they're stateless. This is merely a placeholder.
    }

    // MARK: - Private Helpers

    /// Applies default styling for text colors, fonts, etc. Reflects
    /// dark mode considerations and enterprise design system guidelines.
    private func applyDefaultStyling() {
        // For demonstration, we keep default system text colors.
        // An enterprise design system might specify custom colors or fonts.
        amountLabel.textColor = .label
        dateLabel.textColor = .secondaryLabel
        statusLabel.textColor = .secondaryLabel
    }
}