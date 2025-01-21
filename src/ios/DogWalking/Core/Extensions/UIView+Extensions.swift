//
//  UIView+Extensions.swift
//
//  Extension for UIView class providing optimized UI utility functions
//  for styling, layout, and animations with enhanced performance considerations
//  and accessibility support.
//
//  This implementation follows enterprise-grade standards, ensuring robust,
//  scalable, and production-ready code.
//
//  Imports:
//  // UIKit (iOS 13.0+)
//  import UIKit

// MARK: - UIView Extension for Performance and Accessibility
extension UIView {
    
    // MARK: - Adds an optimized shadow

    /// Adds an optimized shadow effect to the view with customizable parameters
    /// and cached shadow paths for improved rendering performance. This method
    /// aligns with design system specifications to ensure consistent UI styling
    /// and layout patterns.
    ///
    /// - Parameters:
    ///   - radius: The blur radius used to create the shadow's softness.
    ///   - opacity: The alpha value of the shadow from 0.0 (invisible) to 1.0.
    ///   - offset: The shadow offset, representing horizontal and vertical spread.
    ///   - color: The color of the shadow to be rendered.
    public func addShadow(radius: CGFloat,
                          opacity: CGFloat,
                          offset: CGFloat,
                          color: UIColor) {
        // STEP 1: Configure layer shadow radius with specified value
        layer.shadowRadius = radius
        
        // STEP 2: Set shadow opacity with bounds checking (0.0 to 1.0)
        let validOpacity = min(max(opacity, 0.0), 1.0)
        layer.shadowOpacity = Float(validOpacity)
        
        // STEP 3: Apply shadow offset for depth effect
        layer.shadowOffset = CGSize(width: offset, height: offset)
        
        // STEP 4: Set shadow color with proper color space conversion
        layer.shadowColor = color.cgColor
        
        // STEP 5: Calculate and cache optimal shadow path for better performance
        //         using the current bounds of the view
        let shadowRect = bounds
        layer.shadowPath = UIBezierPath(rect: shadowRect).cgPath
        
        // STEP 6: Enable rasterization for static shadows to optimize rendering
        layer.shouldRasterize = true
        
        // STEP 7: Apply shadow path optimization at screen scale
        layer.rasterizationScale = UIScreen.main.scale
    }

    // MARK: - Applies rounded corners

    /// Applies rounded corners to specified corners of the view with
    /// optimized layer updates. This supports the design system by
    /// ensuring consistent corner styling across components.
    ///
    /// - Parameters:
    ///   - radius: The corner radius to be applied.
    ///   - corners: A set of corners (e.g. [.layerMinXMinYCorner]) to round.
    public func roundCorners(radius: CGFloat,
                             corners: CACornerMask) {
        // STEP 1: Validate and set layer corner radius
        layer.cornerRadius = radius
        
        // STEP 2: Apply specified corner mask
        layer.maskedCorners = corners
        
        // STEP 3: Enable corner masking with optimization
        //         for highly performant UI rendering
        layer.masksToBounds = true
        
        // STEP 4: Update layer display properties if needed
        setNeedsDisplay()
        
        // STEP 5: Optimize rendering for specified corners
        //         by ensuring the layer is properly laid out
        layoutIfNeeded()
    }

    // MARK: - Adds a border to the view

    /// Adds a border to the view with specified width and color, optimized
    /// for layer updates. Ensures consistent styling as part of the design
    /// system framework.
    ///
    /// - Parameters:
    ///   - width: The width of the border to be drawn.
    ///   - color: The color of the border.
    public func addBorder(width: CGFloat,
                          color: UIColor) {
        // STEP 1: Validate border width value (ensure non-negative)
        let validWidth = max(width, 0.0)
        
        // STEP 2: Set layer border width
        layer.borderWidth = validWidth
        
        // STEP 3: Convert and set layer border color
        layer.borderColor = color.cgColor
        
        // STEP 4: Optimize layer rendering for border
        setNeedsLayout()
    }

    // MARK: - Fades the view in

    /// Animates the view's alpha to fade it in with accessibility
    /// considerations and configurable timing. Respects the "Reduce Motion"
    /// setting to ensure an inclusive user experience.
    ///
    /// - Parameters:
    ///   - duration: The total duration of the animation in seconds.
    ///   - completion: An optional closure to be executed when the fade completes.
    public func fadeIn(duration: TimeInterval,
                       completion: (() -> Void)? = nil) {
        // STEP 1: Check reduced motion accessibility setting
        if UIAccessibility.isReduceMotionEnabled {
            // If reduce motion is enabled, skip animation
            alpha = 1.0
            isHidden = false
            completion?()
            return
        }
        
        // STEP 2: Set initial alpha to 0 for fade effect
        alpha = 0.0
        
        // STEP 3: Ensure view is not hidden before animating
        isHidden = false
        
        // STEP 4: Configure animation timing curve
        //         Using a default linear curve or ease-in-out for standard fade
        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       options: [.curveEaseInOut],
                       animations: {
            // STEP 5: Animate alpha to 1 with specified duration
            self.alpha = 1.0
        }, completion: { _ in
            // STEP 6: Execute completion handler on main thread
            //         to ensure UI updates are safe
            DispatchQueue.main.async {
                completion?()
            }
            
            // STEP 7: Clean up animation resources if necessary
            //         (no explicit cleanup required in this example)
        })
    }

    // MARK: - Fades the view out

    /// Animates the view's alpha to fade it out with accessibility support
    /// and proper cleanup after completion.
    ///
    /// - Parameters:
    ///   - duration: The total duration of the animation in seconds.
    ///   - completion: An optional closure to be executed when the fade completes.
    public func fadeOut(duration: TimeInterval,
                        completion: (() -> Void)? = nil) {
        // STEP 1: Check reduced motion accessibility setting
        if UIAccessibility.isReduceMotionEnabled {
            // If reduce motion is enabled, skip animation
            alpha = 0.0
            isHidden = true
            completion?()
            return
        }
        
        // STEP 2: Configure animation timing curve
        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       options: [.curveEaseInOut],
                       animations: {
            // STEP 3: Animate alpha to 0 with specified duration
            self.alpha = 0.0
        }, completion: { _ in
            // STEP 4: Set view to hidden after animation
            self.isHidden = true
            
            // STEP 5: Execute completion handler on main thread
            DispatchQueue.main.async {
                completion?()
            }
            
            // STEP 6: Clean up animation resources if needed
            //         (no explicit cleanup required in this example)
        })
    }

    // MARK: - Pins the view to all edges of its superview

    /// Pins the view to all edges of its superview with optimized constraint
    /// activation and safety checks. This method ensures consistent layout
    /// handling in accordance with the application's component library.
    ///
    /// - Parameter insets: The layout insets to apply on each edge.
    public func pinToEdges(insets: UIEdgeInsets = .zero) {
        // STEP 1: Verify superview existence
        guard let superview = superview else { return }
        
        // STEP 2: Enable auto layout if needed
        translatesAutoresizingMaskIntoConstraints = false
        
        // STEP 3: Create constraints for all edges
        let topConstraint = topAnchor.constraint(equalTo: superview.topAnchor,
                                                constant: insets.top)
        let leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor,
                                                         constant: insets.left)
        let bottomConstraint = bottomAnchor.constraint(equalTo: superview.bottomAnchor,
                                                       constant: -insets.bottom)
        let trailingConstraint = trailingAnchor.constraint(equalTo: superview.trailingAnchor,
                                                           constant: -insets.right)
        
        // STEP 4: Prepare constraint activation batch
        let constraints = [topConstraint, leadingConstraint,
                           bottomConstraint, trailingConstraint]
        
        // STEP 5: Apply inset values to constraints (already embedded above)
        
        // STEP 6: Activate all constraints in single update for performance
        NSLayoutConstraint.activate(constraints)
        
        // STEP 7: Update layout if needed
        superview.layoutIfNeeded()
    }
}