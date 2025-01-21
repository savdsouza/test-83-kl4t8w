//
//  RatingView.swift
//
//  A reusable, accessible, and performant rating view component that displays
//  and handles star ratings for dog walking service reviews with support for
//  custom animations, VoiceOver, and dynamic type. This implementation adheres
//  to enterprise-grade standards, ensuring robust, scalable, and production-ready
//  code.
//
//  References to design requirements and system architecture are included via
//  extensive code comments.
//
//  Imports:
//    - UIKit (iOS 13.0+)
//    - Combine (iOS 13.0+)
//    - UIView+Extensions from src/ios/DogWalking/Core/Extensions/UIView+Extensions.swift
//      for addShadow(...) and roundCorners(...)
//

import UIKit // UIKit (iOS 13.0+)
import Combine // Combine (iOS 13.0+)

// MARK: - Internal Import for UIView+Extensions
// The following extension is referenced from:
// src/ios/DogWalking/Core/Extensions/UIView+Extensions.swift
// containing addShadow(...) and roundCorners(...) methods used for styling.


// MARK: - Global Constants for RatingView

/// Default star size used when laying out star image views.
private let starSize: CGFloat = 30.0

/// Maximum number of stars in the rating component.
private let maxRating: Int = 5

/// Spacing between each star icon.
private let starSpacing: CGFloat = 8.0

/// Default animation duration for rating updates.
private let defaultAnimationDuration: TimeInterval = 0.2

/// Minimum allowed rating for the component.
private let minimumRating: CGFloat = 0.0


// MARK: - RatingView Class

/// A custom UIView subclass that displays interactive star ratings with accessibility
/// support, custom animations, and haptic feedback. This component is designed for
/// dog walking service reviews and supports dynamic type, VoiceOver, and half-star
/// increments if enabled.
@IBDesignable
public class RatingView: UIView { // Exposed as 'public' for broader framework usage

    // MARK: - Public Properties (Exposed)
    
    /// The current rating value displayed by the component.
    /// Clamped between minimumRating (0.0) and maxRating (5.0 by default).
    public var rating: CGFloat = 0.0 {
        didSet {
            // Whenever the rating is set externally, update visuals without animation.
            updateRating(rating, animated: false)
        }
    }

    /// A boolean indicating whether the rating view is enabled for user interaction.
    /// If set to false, gestures are ignored.
    public var isEnabled: Bool = true {
        didSet {
            // Enable or disable gesture recognizers accordingly.
            gestureRecognizers?.forEach { $0.isEnabled = isEnabled }
        }
    }

    /// Publish-subscribe mechanism for rating changes to notify other components.
    /// Emitted values represent the new rating after updates.
    public let ratingSubject = PassthroughSubject<CGFloat, Never>()

    /// The duration for rating change animations. If a rating call is made
    /// with animated=true, this defines the timing.
    public var animationDuration: TimeInterval = defaultAnimationDuration

    /// A boolean that defines if half-star increments are supported.
    /// When true, tapping between star boundaries will produce half increments.
    public var allowsHalfStars: Bool = false

    /// The fill color for stars that are considered “filled” based on the rating.
    /// Defaults to the system’s yellow for visual clarity in rating components.
    public var starColor: UIColor = .systemYellow

    /// The color for stars that are not yet filled according to the current rating.
    /// Defaults to a light gray tone to visually contrast filled stars.
    public var emptyStarColor: UIColor = .systemGray3


    // MARK: - Internal/Private Properties

    /// A set of Combine cancellables used to store subscriptions
    /// for reacting to rating changes or other publishers.
    private var cancellables = Set<AnyCancellable>()

    /// A haptic feedback generator for providing tactile feedback on user gesture.
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// An array holding all star image views for quick updates and constraints management.
    private var starImageViews: [UIImageView] = []


    // MARK: - Initializers

    /// Initializes the rating view with required setup, including star layout,
    /// gesture recognizers, accessibility, and dynamic type support.
    /// - Parameter frame: The frame rectangle for the rating view.
    public override init(frame: CGRect) {
        super.init(frame: frame)

        // STEP 1: Initialize default property values (already set above; no additional changes needed here).

        // STEP 2: Setup star views with reuse optimization and performance-minded layer configurations.
        setupStarViews()

        // STEP 3: Configure gesture recognizers for tap and pan interactions.
        configureGestureRecognizers()

        // STEP 4: Setup Combine publishers for rating updates (currently done via ratingSubject).
        //         Additional subscriptions can be added as needed.

        // STEP 5: Configure accessibility properties for VoiceOver and dynamic type.
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        accessibilityLabel = "Rating control"

        // STEP 6: Initialize haptic feedback generator and ready it for usage.
        feedbackGenerator.prepare()

        // STEP 7: Apply default styling and shadow to the entire rating view
        //         to create a subtle elevated effect.
        addShadow(radius: 2.0, opacity: 0.2, offset: 1.0, color: .black)

        // STEP 8: Setup dynamic type support (images are scaled via contentMode).
        //         Additional dynamic type consideration is limited because images
        //         do not scale automatically like text. However, layout updates
        //         can respond to content size category changes if needed.
    }

    /// Initializes the rating view from a coder (Storyboard or XIB).
    /// - Parameter coder: The coder to load partially archived objects.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Ensure that the interface builder path has the same configuration steps:

        setupStarViews()
        configureGestureRecognizers()
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        accessibilityLabel = "Rating control"
        feedbackGenerator.prepare()
        addShadow(radius: 2.0, opacity: 0.2, offset: 1.0, color: .black)
    }


    // MARK: - Setup Star Views

    /// Creates and configures the star image views with optimization for layer rendering,
    /// applying dynamic color, corner rounding, and subtle shadows for each star.
    /// This method ensures a consistent, accessible rating display.
    private func setupStarViews() {
        // Remove any existing star image views to avoid duplication if reinitialized
        starImageViews.forEach { $0.removeFromSuperview() }
        starImageViews.removeAll()

        // Create array of UIImageViews for each star needed in the rating.
        for _ in 0..<maxRating {
            let starImageView = UIImageView()

            // STEP 1: Layer optimization for performance
            starImageView.layer.shouldRasterize = true
            starImageView.layer.rasterizationScale = UIScreen.main.scale

            // STEP 2: Configure default appearance (size, color, content mode)
            //         Use system star image for clarity.
            starImageView.image = UIImage(systemName: "star.fill")
            starImageView.contentMode = .scaleAspectFit
            starImageView.tintColor = emptyStarColor

            // STEP 3: Add shadow / corner rounding from our extension to unify styling.
            //         Round corners might be subtle for star shapes, but we show usage.
            starImageView.roundCorners(radius: 4.0, corners: .allCorners)
            starImageView.addShadow(radius: 1.0, opacity: 0.3, offset: 1.0, color: .black)

            // STEP 4: Configure accessibility for each star image view.
            //         We set them as non-accessible individually because the
            //         entire control is an adjustable element as a whole.
            starImageView.isAccessibilityElement = false

            // STEP 5: Add to hierarchy and store in local array for constraint management
            addSubview(starImageView)
            starImageViews.append(starImageView)
        }

        // STEP 6: Setup constraints for horizontal layout, distributing stars evenly with spacing.
        arrangeStarsConstraints()
    }

    /// Constrains the star image views in a horizontal row with consistent spacing.
    /// This is a helper method extracted from setupStarViews for clarity.
    private func arrangeStarsConstraints() {
        // Disable autoresizing masks for each star image
        starImageViews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        for (index, star) in starImageViews.enumerated() {
            // Width and height constraints for a consistent star size
            NSLayoutConstraint.activate([
                star.widthAnchor.constraint(equalToConstant: starSize),
                star.heightAnchor.constraint(equalToConstant: starSize),
                star.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])

            if index == 0 {
                // First star anchored to leading edge (with no spacing to left)
                NSLayoutConstraint.activate([
                    star.leadingAnchor.constraint(equalTo: leadingAnchor)
                ])
            } else {
                // Anchor current star to the previous star's trailing edge with spacing
                let previousStar = starImageViews[index - 1]
                NSLayoutConstraint.activate([
                    star.leadingAnchor.constraint(equalTo: previousStar.trailingAnchor,
                                                  constant: starSpacing)
                ])
            }

            // If last star, anchor trailing to the container's trailing with no extra spacing
            if index == starImageViews.count - 1 {
                NSLayoutConstraint.activate([
                    star.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
                ])
            }
        }
    }


    // MARK: - Update Rating

    /// Updates the visual state of stars based on the provided rating value, applying
    /// smooth animations, haptic feedback, and accessibility updates as needed.
    ///
    /// - Parameters:
    ///   - rating: The new rating value to be displayed (clamped to minimumRating...maxRating).
    ///   - animated: Whether or not the star updates should animate.
    public func updateRating(_ rating: CGFloat, animated: Bool) {
        // STEP 1: Clamp the rating value within defined bounds
        let clampedRating = min(max(rating, minimumRating), CGFloat(maxRating))
        self.rating = clampedRating

        // STEP 2: Check for reduced motion to accommodate accessibility
        let shouldAnimate = animated && !UIAccessibility.isReduceMotionEnabled

        // STEP 3: Update each star’s tinted color based on whether it is full, half, or empty
        let animationBlock = {
            for (index, starImageView) in self.starImageViews.enumerated() {
                let starIndex = CGFloat(index) + 1.0
                var systemImageName = "star"

                if self.allowsHalfStars {
                    // For half-star logic, check if rating is between starIndex - 0.5 and starIndex
                    if clampedRating >= starIndex {
                        systemImageName = "star.fill"
                    } else if clampedRating >= (starIndex - 0.5) {
                        systemImageName = "star.lefthalf.filled"
                    } else {
                        systemImageName = "star"
                    }
                } else {
                    // Standard fill logic (no half-stars)
                    systemImageName = (clampedRating >= starIndex) ? "star.fill" : "star"
                }

                starImageView.image = UIImage(systemName: systemImageName)
                starImageView.tintColor = (systemImageName == "star" ? self.emptyStarColor : self.starColor)
            }
        }

        if shouldAnimate {
            UIView.animate(withDuration: animationDuration,
                           delay: 0.0,
                           options: [.curveEaseInOut],
                           animations: animationBlock,
                           completion: nil)
            feedbackGenerator.impactOccurred(intensity: 0.6)
        } else {
            animationBlock()
        }

        // STEP 4: Emit rating change event through Combine subject
        ratingSubject.send(self.rating)

        // STEP 5: Update accessibility: reflect the new rating in VoiceOver
        accessibilityValue = "Rating \(self.rating) out of \(maxRating) stars"
    }


    // MARK: - Gesture Handling

    /// Handles both tap and pan gestures with continuous updates to the rating,
    /// converting touch locations into star rating values. Provides haptic feedback
    /// on rating changes and updates accessibility for VoiceOver users.
    ///
    /// - Parameter gesture: The gesture recognizer triggering the rating update.
    @objc private func handleGesture(_ gesture: UIGestureRecognizer) {
        guard isEnabled else { return }

        let location = gesture.location(in: self)
        let totalStarsWidth = (CGFloat(maxRating) * starSize) + (CGFloat(maxRating - 1) * starSpacing)
        let clampedX = min(max(location.x, 0), totalStarsWidth)

        // Compute raw rating from horizontal position
        let rawRating = (clampedX / totalStarsWidth) * CGFloat(maxRating)

        // If half-stars are allowed, figure out the half increments
        // otherwise just round to nearest star.
        let computedRating: CGFloat
        if allowsHalfStars {
            // Round to nearest 0.5
            let halfStarValue = (rawRating * 2.0).rounded() / 2.0
            computedRating = halfStarValue
        } else {
            // Round to nearest integer star
            computedRating = rawRating.rounded()
        }

        updateRating(computedRating, animated: true)
        feedbackGenerator.prepare() // Prepare for the next feedback
    }


    // MARK: - Gesture Recognizers Configuration

    /// Configures tap and pan gesture recognizers to handle user interactions for
    /// setting the rating. Using both recognizers allows for immediate setting on tap
    /// and continuous adjustment on pan.
    private func configureGestureRecognizers() {
        // Tap gesture recognizer to set the rating at a specific location
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)

        // Pan gesture recognizer for continuous rating changes
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        addGestureRecognizer(panGesture)
    }

    // MARK: - Accessibility Adjustments

    /// Override accessibility increment to handle rating increase when the user adjusts
    /// the control using VoiceOver. For example, flick up gesture in VoiceOver context.
    public override func accessibilityIncrement() {
        // Increase rating by 1, or by 0.5 if half-stars are enabled
        let step: CGFloat = allowsHalfStars ? 0.5 : 1.0
        let newRating = rating + step
        updateRating(newRating, animated: true)
    }

    /// Override accessibility decrement to handle rating decrease when the user adjusts
    /// the control using VoiceOver. For example, flick down gesture in VoiceOver context.
    public override func accessibilityDecrement() {
        // Decrease rating by 1, or by 0.5 if half-stars are enabled
        let step: CGFloat = allowsHalfStars ? 0.5 : 1.0
        let newRating = rating - step
        updateRating(newRating, animated: true)
    }
}