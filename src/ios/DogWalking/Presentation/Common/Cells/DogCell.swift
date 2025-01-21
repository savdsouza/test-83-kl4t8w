//
//  DogCell.swift
//  DogWalking
//
//  Custom table view cell for displaying a dog's profile in a card-based layout.
//  Implements design system guidelines, performance optimizations, and accessibility
//  best practices. Follows enterprise-grade standards for robust, scalable, and
//  production-ready code.
//

import Foundation
import UIKit // iOS 13.0+
import SDWebImage // 5.8.0

// MARK: - Internal Imports
// BaseTableViewCell from "src/ios/DogWalking/Core/Base/BaseTableViewCell.swift"
// Dog model from "src/ios/DogWalking/Domain/Models/Dog.swift"

// MARK: - DogCell Declaration

/// A custom table view cell displaying a dog's profile information in a performance-optimized
/// card layout, leveraging the BaseTableViewCell for core styling and common functionality.
/// It supports dynamic Type, accessibility, and efficient image loading via SDWebImage.
public final class DogCell: BaseTableViewCell {
    
    // MARK: - Properties (Schema-Compliant)
    
    /// Displays the dog's profile image with content mode and clipping optimized for performance.
    private let dogImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    /// Shows the dog's name with dynamic type font scaling and multi-line support.
    private let nameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()
    
    /// Shows the dog's breed with dynamic type font scaling and multi-line support.
    private let breedLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()
    
    /// Holds the dog data model. Used to populate this cell's UI elements.
    private var dog: Dog?
    
    /// Manages any ongoing asynchronous SDWebImage operation for safe cancellation on reuse.
    private var currentImageOperation: SDWebImageOperation?
    
    // MARK: - Initializer
    
    /**
     Initializes the DogCell with the required style and reuseIdentifier, performing
     the following steps:
     
     1. Calls `super.init(style: reuseIdentifier:)`
     2. Sets up all UI components with performance optimizations
     3. Configures layout constraints in a single batch
     4. Applies default styling from the design system
     5. Sets up accessibility configuration for the cell
     6. Initializes image loading system references
     
     - Parameters:
       - style: The cell style (unused custom initializer).
       - reuseIdentifier: A unique string to identify this cell type.
     */
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // STEP 2: Set up the UI components and container-based layout.
        setupUI()
        
        // STEP 6: Initialize image loading system references (where needed).
        currentImageOperation = nil
    }
    
    /**
     Required initializer for decoding from a storyboard or nib; not used here.
     Triggers a runtime error to avoid unintended usage.
     */
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for DogCell.")
    }
    
    // MARK: - UI Setup
    
    /**
     Sets up the cell's UI components and layout with performance optimizations,
     following the design system specifications for card-based layouts.
     
     Steps:
     1. Call `setupContainerView()` from the base class for shadow & styling
     2. Create and configure dogImageView with layer optimization
     3. Create and style nameLabel with Dynamic Type support
     4. Create and style breedLabel with Dynamic Type support
     5. Add components to `containerView` in a single batch
     6. Set up Auto Layout constraints with activation batching
     7. Configure accessibility labels and traits
     8. Apply any additional design system adjustments
     */
    private func setupUI() {
        // STEP 1: Configure the containerView from the base class
        setupContainerView()
        
        // STEP 5: Add subviews to containerView in a single batch
        containerView.addSubview(dogImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(breedLabel)
        
        // STEP 6: Set up constraints (vertical stack-like arrangement here)
        NSLayoutConstraint.activate([
            // dogImageView constraints
            dogImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            dogImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            dogImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            dogImageView.heightAnchor.constraint(equalToConstant: 180),
            
            // nameLabel constraints
            nameLabel.topAnchor.constraint(equalTo: dogImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // breedLabel constraints
            breedLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            breedLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            breedLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            breedLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        // STEP 7: Configure accessibility labels and traits
        dogImageView.isAccessibilityElement = false
        nameLabel.isAccessibilityElement = true
        nameLabel.accessibilityTraits = .staticText
        breedLabel.isAccessibilityElement = true
        breedLabel.accessibilityTraits = .staticText
        
        // STEP 8: Additional design system adjustments (placeholder, can be extended)
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    // MARK: - Configuration
    
    /**
     Configures the cell's UI with the given dog data, handling image loading
     efficiently and gracefully. This follows the steps:
     
     1. Store the dog reference
     2. Set name label text with accessibility consideration
     3. Set breed label text with accessibility consideration
     4. Cancel any existing image loading operation
     5. Load the profile image with SDWebImage if available
     6. Handle image loading errors gracefully
     7. Update layout if needed for dynamic size
     8. Update accessibility value
     
     - Parameter dog: The `Dog` model containing required display information.
     */
    public func configure(with dog: Dog) {
        // STEP 1: Store the dog reference
        self.dog = dog
        
        // STEP 2: Set name label text (accessibility-friendly)
        nameLabel.text = dog.name
        nameLabel.accessibilityValue = dog.name
        
        // STEP 3: Set breed label text (accessibility-friendly)
        breedLabel.text = dog.breed
        breedLabel.accessibilityValue = dog.breed
        
        // STEP 4: Cancel any existing image loading operation
        if let operation = currentImageOperation {
            operation.cancel()
            currentImageOperation = nil
        }
        
        // STEP 5: Load the profile image with SDWebImage
        if let urlString = dog.profileImageUrl,
           let validURL = URL(string: urlString), !urlString.isEmpty {
            
            // Use a placeholder image to improve perception of performance
            dogImageView.image = UIImage(named: "dogPlaceholder")
            
            currentImageOperation = dogImageView.sd_setImage(
                with: validURL,
                placeholderImage: UIImage(named: "dogPlaceholder"),
                options: .highPriority,
                completed: { [weak self] (image, error, _, _) in
                    guard let self = self else { return }
                    
                    // STEP 6: Handle loading errors gracefully
                    if error != nil {
                        // Fallback to a placeholder on error
                        self.dogImageView.image = UIImage(named: "dogPlaceholder")
                    }
                    
                    // Clear the operation reference after completion
                    self.currentImageOperation = nil
                }
            )
        } else {
            // If no valid URL, show a placeholder
            dogImageView.image = UIImage(named: "dogPlaceholder")
        }
        
        // STEP 7: Update layout if needed
        setNeedsLayout()
        
        // STEP 8: Update accessibility label for the container view
        containerView.accessibilityLabel = "Dog card for \(dog.name)"
    }
    
    // MARK: - Reuse Handling
    
    /**
     Resets the cell state when reused to ensure no stale data persists. Steps:
     
     1. Call `super.prepareForReuse()`
     2. Cancel current image loading operation safely
     3. Reset image view to a placeholder with fade-out transition
     4. Clear the name and breed labels with animation
     5. Reset the dog reference
     6. Clean up any cached data
     7. Reset accessibility configuration
     */
    public override func prepareForReuse() {
        // STEP 1: Call super
        super.prepareForReuse()
        
        // STEP 2: Cancel current image loading if any
        if let operation = currentImageOperation {
            operation.cancel()
            currentImageOperation = nil
        }
        
        // STEP 3: Reset image view with fade
        dogImageView.fadeOut(duration: 0.2) { [weak self] in
            self?.dogImageView.image = UIImage(named: "dogPlaceholder")
            self?.dogImageView.alpha = 1.0
        }
        
        // STEP 4: Clear labels with animation
        nameLabel.fadeOut(duration: 0.2) { [weak self] in
            self?.nameLabel.text = nil
            self?.nameLabel.alpha = 1.0
        }
        breedLabel.fadeOut(duration: 0.2) { [weak self] in
            self?.breedLabel.text = nil
            self?.breedLabel.alpha = 1.0
        }
        
        // STEP 5: Reset dog reference
        dog = nil
        
        // STEP 6: Clean up any extra cached data if needed (placeholder for expansions)
        
        // STEP 7: Reset accessibility
        containerView.accessibilityLabel = nil
    }
}