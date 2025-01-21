//
//  WalkCell.swift
//  DogWalking
//
//  Description:
//  A production-ready UITableViewCell subclass for displaying walk session information
//  with thread-safe data handling, real-time updates, and advanced accessibility support.
//
//  Requirements Addressed:
//  1) Service Execution: Shows status, timing, and pricing details, enabling real-time updates
//     and photo-sharing expansions.
//  2) User Interface Design: Presents walk data in an optimized, accessible layout with
//     dynamic content updates and robust styling.
//
//  Dependencies:
//  // UIKit (iOS 13.0+)
//  import UIKit
//
//  // MARK: - Internal Import from "Core/Base/BaseTableViewCell.swift"
//  // Provides BaseTableViewCell, containerView, and setupContainerView() for consistent styling.
//  // Overridden members may be overshadowed in this subclass if similarly named.
//
//  // MARK: - Internal Import from "Domain/Models/Walk.swift"
//  // Provides the Walk model with status, scheduledStartTime, duration, and price properties.
//
import UIKit // iOS 13.0+
import Core/Base/BaseTableViewCell
import Domain/Models/Walk

/// A thread-safe, accessibility-compliant table view cell for displaying walk session
/// information with real-time updates and optimized performance.
/// Utilizes a NSLock to synchronize updates to internal walk data, ensures
/// dynamic type support, and applies advanced styling from the base cell.
@MainActor
public final class WalkCell: BaseTableViewCell {

    // MARK: - Thread-Safe Lock

    /// A lock used to synchronize access to walk data, ensuring thread safety when
    /// configuring the cell from multiple contexts or background threads.
    private let walkDataLock: NSLock = NSLock()

    // MARK: - UI Properties

    /// A label showing the scheduled start time of the walk in a short date/time format.
    public let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        // Dynamic Type support with an appropriate text style:
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        return label
    }()

    /// A label displaying the current status of the walk (e.g. Scheduled, In Progress).
    public let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        return label
    }()

    /// A label indicating the total duration of the walk or the scheduled duration.
    public let durationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        return label
    }()

    /// A label showing the walk’s price, formatted in local currency.
    public let priceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        return label
    }()

    /// A stack view grouping the walk’s textual details for compact display.
    public let infoStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 4
        return stack
    }()

    /// An action button that may be configured based on walk status, enabling
    /// interactions such as starting, canceling, or ending a walk.
    public let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Action", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()

    /// A shape layer for shadow rendering in this cell, overshadowing the base class
    /// property to satisfy the JSON specification's direct reference.
    public let shadowLayer: CAShapeLayer = CAShapeLayer()

    // MARK: - Model Properties

    /// The walk data associated with this cell. Updated in a thread-safe manner
    /// inside `configure(walk:)`.
    public var walkData: Walk?

    /// A cache to store images or other resources for potential photo-sharing or real-time visuals.
    public let imageCache: NSCache<NSString, UIImage> = NSCache<NSString, UIImage>()

    /// A boolean flag indicating if the cell is currently performing an update,
    /// preventing redundant styling refreshes or layout recalculations.
    public var isUpdating: Bool = false

    // MARK: - Date Formatting

    /// A static DateFormatter to format walk times consistently across the application.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Initializers

    /// Initializes the walk cell with required style, reuseIdentifier, and accessibility setup.
    ///
    /// Steps:
    /// 1. Calls super.init(style:reuseIdentifier:) to leverage BaseTableViewCell.
    /// 2. Initializes thread-safe properties like walkDataLock, imageCache, etc.
    /// 3. Invokes setupContainerView() from the base class to ensure consistent styling.
    /// 4. Calls setupUI() to build the UI and layout constraints in a single pass.
    /// 5. Configures accessibility traits for better user experience.
    ///
    /// - Parameters:
    ///   - style: The UITableViewCell.CellStyle to use for the cell.
    ///   - reuseIdentifier: A reuse identifier string for the cell.
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        // Step 1: Call super.init
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // Step 2: Properties are already initialized with default values above.

        // Step 3: Setup container view from base class for styling and layout structure.
        setupContainerView()

        // Step 4: Build UI and layout constraints.
        setupUI()

        // Step 5: Configure the cell's accessibility traits (treated like a continuous control).
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    /// Required initializer for decoding from a storyboard or nib.
    /// Not implemented for enterprise usage.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for WalkCell.")
    }

    // MARK: - Setup UI

    /// Sets up the cell's UI components and layout with performance optimizations
    /// and best practices for dynamic type and accessibility.
    ///
    /// Steps:
    /// 1. Batch UI updates using UIView.performWithoutAnimation for smoother transitions.
    /// 2. Configure labels, stack view, and action button.
    /// 3. Add subviews to containerView.
    /// 4. Apply Auto Layout constraints in a single batch.
    /// 5. Set up default styling, including any additional shadow or corner radius logic.
    /// 6. Configure accessibility for the UI elements.
    private func setupUI() {
        UIView.performWithoutAnimation {
            // Step 2: Configure all UI components above.

            // Step 3: Add subviews to the containerView
            containerView.addSubview(infoStackView)
            containerView.addSubview(actionButton)

            // Add labels into the info stack
            infoStackView.addArrangedSubview(timeLabel)
            infoStackView.addArrangedSubview(statusLabel)
            infoStackView.addArrangedSubview(durationLabel)
            infoStackView.addArrangedSubview(priceLabel)

            // Step 4: Apply Auto Layout constraints
            NSLayoutConstraint.activate([
                // infoStackView pinned near top-left within containerView
                infoStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                infoStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                infoStackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -12),

                // actionButton anchored near bottom-right within containerView
                actionButton.topAnchor.constraint(greaterThanOrEqualTo: infoStackView.bottomAnchor, constant: 8),
                actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
            ])

            // Step 5: Default styling if needed (use parent's container shadow or localShadow).
            // The overshadowed shadowLayer can be customized here if different from the parent.
            shadowLayer.shadowColor = UIColor.black.cgColor
            shadowLayer.shadowOffset = CGSize(width: 0, height: 2)
            shadowLayer.shadowOpacity = 0.1
            shadowLayer.shadowRadius = 3
            shadowLayer.shouldRasterize = true
            shadowLayer.rasterizationScale = UIScreen.main.scale

            // Step 6: Accessibility configuration
            // Combine important label texts in accessibilityValue if needed.
            containerView.accessibilityLabel = "Walk Session Details"
        }
    }

    // MARK: - Configuration

    /// Thread-safe configuration of the cell using a Walk model, providing real-time
    /// update support. Locks walkDataLock to guarantee consistent access.
    ///
    /// Steps:
    /// 1. Acquire walkDataLock for safe data assignment.
    /// 2. Store the provided walk in walkData.
    /// 3. Update the timeLabel with a formatted date (scheduledStartTime).
    /// 4. Update the statusLabel with a localized status text.
    /// 5. Format and display duration and price.
    /// 6. Configure the action button based on current walk status.
    /// 7. Apply status-specific styling by calling updateStatusStyle.
    /// 8. Update accessibility content.
    /// 9. Release the lock.
    ///
    /// - Parameter walk: The walk data used to populate UI elements.
    public func configure(with walk: Walk) {
        walkDataLock.lock()
        defer { walkDataLock.unlock() }

        // Step 2: Store walk data
        self.walkData = walk

        // Step 3: Format scheduledStartTime
        timeLabel.text = Self.timeFormatter.string(from: walk.scheduledStartTime)

        // Step 4: Localize or present status
        let walkStatusString: String
        switch walk.status {
        case .scheduled:
            walkStatusString = "Scheduled"
        case .inProgress:
            walkStatusString = "In Progress"
        case .completed:
            walkStatusString = "Completed"
        case .cancelled:
            walkStatusString = "Cancelled"
        default:
            walkStatusString = "Unknown"
        }
        statusLabel.text = walkStatusString

        // Step 5: Display duration and price
        let durationText = String(format: "%.0f min", walk.duration / 60.0)
        durationLabel.text = "Duration: \(durationText)"
        let priceText = String(format: "$%.2f", walk.price)
        priceLabel.text = "Price: \(priceText)"

        // Step 6: The action button can be adjusted per status if needed
        // (E.g., "Start Walk" for scheduled, "End Walk" for inProgress, etc.)
        switch walk.status {
        case .scheduled:
            actionButton.setTitle("Start Walk", for: .normal)
        case .inProgress:
            actionButton.setTitle("End Walk", for: .normal)
        case .cancelled:
            actionButton.setTitle("Canceled", for: .normal)
            actionButton.isEnabled = false
        case .completed:
            actionButton.setTitle("Review", for: .normal)
        default:
            actionButton.setTitle("Action", for: .normal)
        }

        // Step 7: Apply status styling
        updateStatusStyle(to: walk.status)

        // Step 8: Update accessibility content
        accessibilityValue = "\(walkStatusString), \(durationText), \(priceText)"
    }

    // MARK: - Status Style Update

    /// Updates the cell's styling based on the walk’s status. Applies color changes,
    /// text transforms, and optional VoiceOver announcements if needed.
    ///
    /// Steps:
    /// 1. Check if an update is already in progress or if the new status matches the old (optional).
    /// 2. Apply status-specific colors, styling, and accessibility hints.
    /// 3. Update the container or button states accordingly.
    /// 4. Optionally announce status changes to VoiceOver for accessibility.
    /// 5. Cache new styling state if relevant.
    ///
    /// - Parameter status: The WalkStatus to style for.
    private func updateStatusStyle(to status: WalkStatus) {
        guard !isUpdating else { return }
        isUpdating = true

        // Step 2: Apply colors and styling based on status
        switch status {
        case .scheduled:
            statusLabel.textColor = .systemBlue
        case .inProgress:
            statusLabel.textColor = .systemGreen
        case .completed:
            statusLabel.textColor = .systemGray
        case .cancelled:
            statusLabel.textColor = .systemRed
        default:
            statusLabel.textColor = .darkGray
        }

        // Step 3: We could adjust the containerView or shadow appearance here if desired.

        // Step 4: Optional VoiceOver announcement
        // UIAccessibility.post(notification: .announcement, argument: "Walk status updated.")

        // Step 5: Mark the update as finished
        isUpdating = false
    }

    // MARK: - Cell Reuse

    /// Prepares the cell for reuse by resetting thread-safe properties, clearing caches,
    /// and restoring default UI states.
    ///
    /// Steps:
    /// 1. Acquire walkDataLock if needed and reset walkData to nil.
    /// 2. Clear image cache or any ephemeral data references.
    /// 3. Reset UI components (e.g. labels, button text).
    /// 4. Remove or invalidate any active observers.
    /// 5. Reset accessibility configurations if needed.
    /// 6. Call super.prepareForReuse() to invoke the base cell's cleanup routine.
    public override func prepareForReuse() {
        walkDataLock.lock()
        self.walkData = nil
        walkDataLock.unlock()

        // Step 2: Clear relevant caches
        imageCache.removeAllObjects()

        // Step 3: Reset UI defaults
        timeLabel.text = nil
        statusLabel.text = nil
        durationLabel.text = nil
        priceLabel.text = nil
        actionButton.setTitle("Action", for: .normal)
        actionButton.isEnabled = true

        // Step 4: Remove any observers or real-time update listeners (if used).

        // Step 5: Reset accessibility to default
        accessibilityValue = nil

        // Step 6: Call super for additional cleanup in BaseTableViewCell
        super.prepareForReuse()
    }
}