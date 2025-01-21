//
//  StoryboardInstantiable.swift
//
//  Purpose:
//  1. To provide a standardized, type-safe way to instantiate view controllers
//     from storyboards in an MVVM-based iOS application.
//  2. Ensures robust error handling and logging for instant debugging feedback.
//  3. Complies with the Dog Walking Mobile Application’s architecture
//     (See Section "2. SYSTEM ARCHITECTURE/2.2.1 Core Components/Mobile Apps")
//     and supports Coordinator pattern navigation flows
//     (See Section "6. USER INTERFACE DESIGN/6.1.3 Critical User Flows").
//
//  Requirements Addressed:
//   - Mobile Apps Architecture for storyboard-based UI (MVVM).
//   - Screen Navigation flows with standardized view controller creation.
//
//  Notes on Usage and Constraints:
//   - Constrained to UIViewController subclasses to guarantee valid instantiation.
//   - This protocol depends on UIKit for storyboard-related classes and methods
//     (iOS 13.0+ as specified in the technical stack).
//   - Thread Safety: Must be invoked on the main thread to comply with UIKit.
//
//  Performance Considerations:
//   - No caching strategy: Each time instantiate() is invoked, a fresh controller
//     is created from the storyboard, ensuring minimal memory overhead.
//   - Low memory impact: Only allocated at the time of instantiation and released
//     once the view controller is no longer needed.
//
//  Debugging & Logging:
//   - Supported log/error messages specifically for:
//       storyboard_not_found, controller_not_found, type_cast_failed
//   - DEBUG builds will emit fatalError() with descriptive messages.
//   - Release builds will still use fatalError() for any critical failures
//     to prevent corrupted states, albeit with less detail.
//

import UIKit // iOS 13.0+

/// A protocol that provides a standardized way to instantiate view controllers
/// from storyboards in a type-safe manner. This protocol can only be adopted by
/// UIViewController subclasses to ensure consistent storyboard usage, correct
/// class-to-identifier mapping, and minimal risk of runtime errors.
///
/// Conforming Types:
/// ----------------
/// Any UIViewController subclass that adopts StoryboardInstantiable automatically
/// gains:
///  - A static `storyboardIdentifier` property that, by default, is set to the
///    class name (e.g., "MyViewController").
///  - A static `instantiate()` method for safely loading and casting the
///    UIViewController from the storyboard file whose name and identifier match
///    `storyboardIdentifier`.
///
/// Usage Example:
/// --------------
/// ```swift
/// final class MyViewController: UIViewController, StoryboardInstantiable {
///     // No additional code needed unless you want to override the storyboardIdentifier.
/// }
///
/// // Instantiate the controller
/// let myVC = MyViewController.instantiate()
/// ```
///
/// Error Handling:
/// --------------
/// If the storyboard file does not exist, the view controller’s identifier does
/// not match, or if the type cast fails, the application will halt execution:
///  - In DEBUG builds: a descriptive fatalError() message is shown.
///  - In RELEASE builds: a generic fatalError() message is shown.
///
/// These scenarios are considered critical errors because they reflect internal
/// misconfiguration that should be fixed during development.
public protocol StoryboardInstantiable where Self: UIViewController {
    
    /// A static property representing the identifier used to reference
    /// the view controller in the storyboard file. By default, this is the
    /// conforming class name.
    ///
    /// Returns:
    /// - A `String` containing the storyboard identifier.
    ///
    /// Example:
    /// If Self is `MyViewController.swift`, then `storyboardIdentifier`
    /// defaults to "MyViewController".
    static var storyboardIdentifier: String { get }
    
    /// Creates and returns an instance of the conforming view controller from
    /// a storyboard file. The storyboard name and storyboard identifier
    /// must match `storyboardIdentifier`. Casting to `Self` is performed,
    /// and any mismatch results in a critical runtime error with debugging
    /// output if available.
    ///
    /// Steps Performed (All on Main Thread):
    /// 1. Retrieve `storyboardIdentifier` from the type.
    /// 2. Verify the existence of the .storyboardc file in the main bundle.
    /// 3. Instantiate a `UIStoryboard` object with that name.
    /// 4. Attempt to instantiate a view controller from the storyboard using
    ///    the same identifier.
    /// 5. Cast the resulting UIViewController to `Self`.
    /// 6. If casting or storyboard retrieval fails, trigger a fatalError() with
    ///    descriptive logs in DEBUG mode and a generic message in release mode.
    ///
    /// - Returns: A `Self` instance representing the view controller with
    ///            matching storyboard settings.
    static func instantiate() -> Self
}

public extension StoryboardInstantiable {
    
    /// Default implementation of `storyboardIdentifier`. Returns the type name of the
    /// conforming UIViewController subclass, using `String(describing:)`.
    ///
    /// Example:
    /// If the conforming class is `LoginViewController`, this property will
    /// return "LoginViewController". This value must match the "Storyboard ID"
    /// in Interface Builder for the corresponding storyboard scene.
    static var storyboardIdentifier: String {
        return String(describing: self)
    }
    
    /// Default implementation of the `instantiate()` method. Handles storyboard
    /// existence checks, instantiation, type casting, and logs fatal errors
    /// with environment-specific detail upon failure.
    ///
    /// - Returns: A fully initialized instance of the conforming type
    ///            from the matching storyboard scene.
    static func instantiate() -> Self {
        
        // Obtain the 'storyboardIdentifier' that by default matches the class name.
        let identifier = storyboardIdentifier
        
        // Attempt to locate the storyboard file in the same bundle as the conforming class.
        // Checking for the compiled storyboard file (.storyboardc) ensures early detection.
        let bundle = Bundle(for: Self.self)
        guard bundle.path(forResource: identifier, ofType: "storyboardc") != nil else {
            #if DEBUG
            fatalError("Storyboard '\(identifier)' not found in main bundle. " +
                       "Ensure the file name and target membership match the class name: '\(identifier).storyboard'.")
            #else
            fatalError("An error occurred while instantiating the view controller.")
            #endif
        }
        
        // Create the UIStoryboard instance with the identified storyboard file.
        let storyboard = UIStoryboard(name: identifier, bundle: bundle)
        
        // Attempt to instantiate a view controller with the same identifier.
        // If the identifier is incorrect or not set in IB, this call can raise
        // an exception at runtime. We wrap it in a cast to handle type mismatches.
        let storyboardVC = storyboard.instantiateViewController(withIdentifier: identifier)
        
        // Cast the view controller to the expected type 'Self'.
        guard let typedVC = storyboardVC as? Self else {
            #if DEBUG
            fatalError(
                """
                Failed to cast view controller with identifier '\(identifier)' to type '\(Self.self)'.
                Possible causes:
                  - The Storyboard ID in Interface Builder is not set to '\(identifier)'.
                  - The custom class for the scene is not set to '\(Self.self)'.
                  - Type mismatch: The storyboard scene does not match this class.
                """
            )
            #else
            fatalError("An error occurred while instantiating the view controller.")
            #endif
        }
        
        // Successfully instantiated and cast. Return typed view controller.
        return typedVC
    }
}