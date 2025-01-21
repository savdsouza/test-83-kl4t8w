//
//  WalkerCell.swift
//  DogWalking
//
//  A thread-safe and accessible table view cell displaying walker information
//  with optimized performance and memory management. This cell leverages the
//  enterprise-grade BaseTableViewCell for consistent styling and container
//  handling, and it integrates with the Walker domain model and RatingView for
//  displaying all required information.
//
//  Imports:
//    - UIKit (iOS 13.0+)
//    - BaseTableViewCell from Core/Base/BaseTableViewCell
//    - Walker from Domain/Models/Walker
//    - RatingView from Presentation/Common/Views/RatingView
//
//  The WalkerCell addresses:
//    1. User Interface Design for standardized elements (profile, rating, etc.).
//    2. Core Features: Displaying walker profiles, verification status (if needed),
//       booking capabilities via book button, and more.
//    3. Accessibility Support: Enhanced VoiceOver, dynamic type, and labeled elements.
//    4. Performance Requirements: Efficient layer management, reuse, and memory optimization.
//

import UIKit // UIKit (iOS 13.0+)
import Foundation

// MARK: - Internal Imports (Named)
import Core_Base_BaseTableViewCell // Mapped import: "src/ios/DogWalking/Core/Base/BaseTableViewCell.swift"
import Domain_Models_Walker        // Mapped import: "src/ios/DogWalking/Domain/Models/Walker.swift"
import Presentation_Common_Views_RatingView // Mapped import: "src/ios/DogWalking/Presentation/Common/Views/RatingView.swift"

// MARK: - ImageCache Placeholder (Optional/Stub)
// For demonstration, a basic cache. Replace or integrate with a real cache implementation.
public class ImageCache {
    public static let shared = ImageCache()
    private let session = URLSession(configuration: .default)
    
    // Simple in-memory cache
    private var cache: NSCache<NSURL, UIImage> = NSCache()
    
    // Simulated image load
    @discardableResult
    public func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        if let cachedImg = cache.object(forKey: url as NSURL) {
            completion(cachedImg)
            return nil
        }
        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            if let data = data, let image = UIImage(data: data) {
                self.cache.setObject(image, forKey: url as NSURL)
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        task.resume()
        return task
    }
}

// MARK: - WalkerCell Class Definition
@MainActor
public class WalkerCell: BaseTableViewCell {

    // MARK: - Properties

    /// Image view to display the walker's profile picture or avatar.
    public let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// Label to display the walker's name or other identifying text.
    public let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        return label
    }()

    /// Label to display the walker's service area or location coverage info.
    public let serviceAreaLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        return label
    }()

    /// Rating view to display average rating for the walker in a star-based UI.
    public let ratingView: RatingView = {
        let view = RatingView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEnabled = false
        view.accessibilityLabel = "Rating"
        return view
    }()

    /// Label to display the walker's hourly rate, e.g., "$25/hr".
    public let rateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        label.textColor = .label
        return label
    }()

    /// Button to initiate a booking flow or user action for this walker.
    public let bookButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Book", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.accessibilityHint = "Double tap to book a walk"
        return button
    }()

    /// A small indicator to reflect the walker's availability state (green if available, red if not).
    public let availabilityIndicator: UIView = {
        let indicator = UIView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.layer.cornerRadius = 6.0
        indicator.layer.masksToBounds = true
        return indicator
    }()

    /// The optional walker model reference used to configure this cell.
    public private(set) var walker: Walker?

    /// A placeholder for storing any constraints if needed; used for batch activation or updates.
    private var constraintsCache: [NSLayoutConstraint] = []

    /// A dedicated image cache reference used to load and store images, if required.
    public var imageCache: ImageCache?

    /// A URL session task to handle image fetching for profile pictures, allowing cancellation on reuse.
    private var imageTask: URLSessionDataTask?

    /// Custom accessibility identifier for UI Automation or UI tests.
    /// Exposed as requested by the specification for test usage or external reference.
    public override var accessibilityIdentifier: String? {
        get { return super.accessibilityIdentifier }
        set { super.accessibilityIdentifier = newValue }
    }

    // MARK: - Initializer

    /**
     Initializes the walker cell with the required style, reuse identifier, and configures
     UI elements for performance and accessibility.

     Steps:
     1. Call super.init with style and reuseIdentifier
     2. Setup UI components with layer optimization
     3. Configure auto layout constraints with batch activation
     4. Setup accessibility identifiers and labels
     5. Configure gesture recognizers with proper hit testing
     6. Initialize image cache
     7. Apply default styling with performance considerations
     */
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // Step 2: We can call setupUI here to place and configure subviews.
        setupContainerView() // from BaseTableViewCell for consistent styling
        setupUI()

        // Step 5: (Gesture recognizers) - Example placeholder; not specifically required but available.
        // We can add a target for the bookButton or custom gesture as needed.
        bookButton.addTarget(self, action: #selector(didTapBookButton), for: .touchUpInside)

        // Step 6: Initialize image cache (could be a shared instance or new).
        self.imageCache = ImageCache.shared

        // Step 7: Additional styling if needed.
        // e.g. contentView.backgroundColor = .systemBackground
    }

    /**
     Required initializer for decoding from a storyboard or nib. Not used in our scenario.
     */
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for WalkerCell.")
    }

    // MARK: - Setup UI

    /**
     Sets up all UI components with optimized layer properties and accessibility.

     Steps:
     1. Configure profile image view with layer optimization
     2. Setup name label with dynamic type support
     3. Configure rating view with accessibility
     4. Setup rate label with proper number formatting
     5. Configure book button with proper states
     6. Setup availability indicator with color contrast
     7. Add components to container with proper z-index
     8. Activate constraints in batch for performance
     9. Configure VoiceOver grouping and order
     */
    private func setupUI() {

        // Step 1: Profile Image View (already partially configured)
        profileImageView.layer.shouldRasterize = true
        profileImageView.layer.rasterizationScale = UIScreen.main.scale

        // Step 2: Name Label (already partially configured with dynamic type)
        nameLabel.lineBreakMode = .byTruncatingTail

        // Step 3: Rating View (already partially configured, disabled for user input)
        ratingView.isEnabled = false
        ratingView.accessibilityLabel = "Walker rating"

        // Step 4: Rate Label - localized currency formatting will happen later in configure(...)
        rateLabel.text = "$0.00/hr"

        // Step 5: Book Button with states (basic example)
        bookButton.isEnabled = true

        // Step 6: Availability Indicator: default color to .gray, updated later
        availabilityIndicator.backgroundColor = .gray

        // Step 7: Add subviews to containerView (BaseTableViewCell property)
        containerView.addSubview(profileImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(serviceAreaLabel)
        containerView.addSubview(ratingView)
        containerView.addSubview(rateLabel)
        containerView.addSubview(bookButton)
        containerView.addSubview(availabilityIndicator)

        // Step 8: Activate constraints in batch for performance
        // Clear old constraints just in case
        NSLayoutConstraint.deactivate(constraintsCache)
        constraintsCache.removeAll()

        // Profile Image Constraints
        constraintsCache.append(contentsOf: [
            profileImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            profileImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            profileImageView.widthAnchor.constraint(equalToConstant: 60),
            profileImageView.heightAnchor.constraint(equalToConstant: 60),
        ])

        // Name Label Constraints
        constraintsCache.append(contentsOf: [
            nameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8)
        ])

        // Service Area Label Constraints
        constraintsCache.append(contentsOf: [
            serviceAreaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            serviceAreaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            serviceAreaLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8)
        ])

        // Rating View Constraints
        constraintsCache.append(contentsOf: [
            ratingView.topAnchor.constraint(equalTo: serviceAreaLabel.bottomAnchor, constant: 4),
            ratingView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            ratingView.widthAnchor.constraint(equalToConstant: 100),
            ratingView.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Rate Label Constraints
        constraintsCache.append(contentsOf: [
            rateLabel.centerYAnchor.constraint(equalTo: ratingView.centerYAnchor),
            rateLabel.leadingAnchor.constraint(equalTo: ratingView.trailingAnchor, constant: 8),
            rateLabel.trailingAnchor.constraint(lessThanOrEqualTo: bookButton.leadingAnchor, constant: -8)
        ])

        // Book Button Constraints
        constraintsCache.append(contentsOf: [
            bookButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            bookButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            bookButton.widthAnchor.constraint(equalToConstant: 80),
            bookButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Availability Indicator Constraints
        constraintsCache.append(contentsOf: [
            availabilityIndicator.topAnchor.constraint(greaterThanOrEqualTo: ratingView.bottomAnchor, constant: 8),
            availabilityIndicator.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            availabilityIndicator.widthAnchor.constraint(equalToConstant: 12),
            availabilityIndicator.heightAnchor.constraint(equalToConstant: 12),
            availabilityIndicator.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])

        NSLayoutConstraint.activate(constraintsCache)

        // Step 9: Configure VoiceOver grouping & order
        isAccessibilityElement = false
        containerView.isAccessibilityElement = true
        containerView.accessibilityTraits = .none
        containerView.accessibilityLabel = "Walker Info Cell"
    }

    // MARK: - Configuration

    /**
     Thread-safe configuration of the cell with walker data.

     Steps:
     1. Set walker property with thread safety
     2. Update profile image with caching
     3. Configure name label with proper truncation
     4. Update service area with proper formatting
     5. Set rating with accessibility label
     6. Update rate label with localized currency
     7. Configure availability with proper states
     8. Update accessibility elements
     9. Handle error states gracefully
     */
    public func configure(with walker: Walker) {
        // Step 1: Assign the walker property
        self.walker = walker

        // Cancel any pending image tasks
        imageTask?.cancel()
        imageTask = nil

        // Step 2: Update profile image from walker.profileImageURL if available
        if let url = walker.profileImageURL {
            imageTask = imageCache?.loadImage(from: url) { [weak self] image in
                guard let strongSelf = self else { return }
                strongSelf.profileImageView.image = image ?? UIImage(systemName: "person.circle")
            }
        } else {
            profileImageView.image = UIImage(systemName: "person.circle")
        }

        // Step 3: Configure name label with truncation & fallback
        let fullName = "\(walker.firstName) \(walker.lastName)".trimmingCharacters(in: .whitespaces)
        nameLabel.text = fullName.isEmpty ? "No Name" : fullName

        // Step 4: Update service area label with fallback
        serviceAreaLabel.text = walker.serviceArea.isEmpty ? "Unknown Area" : walker.serviceArea

        // Step 5: Set ratingView rating with possible accessibility mention
        ratingView.updateRating(CGFloat(walker.rating), animated: false)
        ratingView.accessibilityLabel = "Walker rating: \(walker.rating) out of 5"

        // Step 6: Update rate label as localized currency. For demonstration, assume USD.
        let rateValue = walker.hourlyRate
        let rateString = String(format: "$%.2f/hr", rateValue)
        rateLabel.text = rateString

        // Step 7: Configure availability indicator color
        // If walker.isAvailable is true => green, else => red
        availabilityIndicator.backgroundColor = walker.isAvailable ? .systemGreen : .systemRed

        // Step 8: Update accessibility elements
        containerView.accessibilityValue =
            "Name: \(nameLabel.text ?? ""), " +
            "Area: \(serviceAreaLabel.text ?? ""), " +
            "Rate: \(rateString), " +
            (walker.isAvailable ? "Available" : "Not Available")

        // Optionally incorporate verificationStatus
        // e.g., if walker.verificationStatus indicates verified or not.
        // This example: we do not have an explicit UI element for it,
        // but we can mention it in the accessibilityValue or do a badge.
        // containerView.accessibilityValue += ", Verification: \(walker.verificationStatus.rawValue)"

        // Step 9: Handle any potential error states gracefully (placeholder).
        // e.g., if an image fails to load above, we have a fallback system icon in place.
    }

    // MARK: - Prepare For Reuse

    /**
     Resets cell state with proper memory management.

     Steps:
     1. Call super.prepareForReuse()
     2. Cancel any pending image loads
     3. Clear image cache if needed
     4. Reset all labels and views
     5. Clear walker reference
     6. Reset accessibility state
     7. Prepare layers for reuse
     */
    public override func prepareForReuse() {
        super.prepareForReuse()

        // Step 2: Cancel any pending image loads
        imageTask?.cancel()
        imageTask = nil

        // Step 3 (Optional): If needed, clear from the local image cache if relevant.
        // For demonstration, we do not forcibly remove it from the cache, as that might
        // hamper performance. The memory cache will handle it.

        // Step 4: Reset textual content, images, etc.
        profileImageView.image = UIImage(systemName: "person.circle")
        nameLabel.text = nil
        serviceAreaLabel.text = nil
        rateLabel.text = nil
        ratingView.updateRating(0.0, animated: false)

        // Step 5: Clear walker reference
        walker = nil

        // Step 6: Reset accessibility
        containerView.accessibilityValue = nil

        // Step 7: Re-prepare layers if needed
        availabilityIndicator.backgroundColor = .gray
    }

    // MARK: - Actions

    /// Example action for the book button. Adjust as needed for real usage.
    @objc private func didTapBookButton() {
        // Implementation: Possibly invoke a delegate or closure to handle booking logic
        // e.g.: delegate?.didTapBookWalker(walker)
    }
}