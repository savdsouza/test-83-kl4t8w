import UIKit // iOS 13.0+ (UI framework for advanced interface components)
import Foundation // iOS 13.0+ (Core iOS framework for essential types)

// MARK: - Internal Import
// Referencing ColorPalette from AppConstants (Core/Constants/AppConstants.swift)
 // Note: In a real project, ensure the following import matches your module setup.
 // e.g., import DogWalking or an equivalent framework/module exposing AppConstants.
 
/**
 Extends UIColor to provide the DogWalking application's color palette,
 theme support, and utilities for color initialization and manipulation.
 This extension references the design system's primary, secondary, and
 error colors, as well as background and text variants, enabling
 consistent usage throughout the iOS application.
 */
public extension UIColor {
    
    // MARK: - Semantic App Colors

    /// The primary brand color (#2196F3) from the design system.
    /// Generally used for main interactive elements such as buttons.
    static var primary: UIColor {
        // Direct mapping to the ColorPalette's primary color.
        return ColorPalette.PRIMARY
    }

    /// The secondary brand color (#4CAF50), serving as an accent or
    /// complementary highlight in the application's UI elements.
    static var secondary: UIColor {
        // Direct mapping to the ColorPalette's secondary color.
        return ColorPalette.SECONDARY
    }

    /// The error color (#F44336) used to highlight critical states,
    /// validation failures, and alerts in the user interface.
    static var error: UIColor {
        // Direct mapping to the ColorPalette's error color.
        return ColorPalette.ERROR
    }

    /**
     The background color for standard interface layers.
     This implementation supports dynamic theming, which adjusts the color
     automatically for Light and Dark modes (iOS 13+). On older systems, it
     defaults to the light-mode background color.
     */
    static var background: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection -> UIColor in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    // Optionally use background["secondary"] for dark mode.
                    // Fallback to darkGray if unavailable.
                    return ColorPalette.BACKGROUND["secondary"] ?? .darkGray
                default:
                    return ColorPalette.BACKGROUND["primary"] ?? .white
                }
            }
        } else {
            return ColorPalette.BACKGROUND["primary"] ?? .white
        }
    }

    /**
     The primary text color (#212121) from the design system, usually
     used for prominent text. This property also supports dynamic theming.
     On platforms older than iOS 13, it defaults to the design system's text.
     */
    static var textPrimary: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection -> UIColor in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    // If preferred for dark mode, adjust as needed.
                    return .white
                default:
                    return ColorPalette.TEXT["primary"] ?? .black
                }
            }
        } else {
            return ColorPalette.TEXT["primary"] ?? .black
        }
    }

    /**
     The secondary text color (#757575) from the design system, often
     used for less prominent text or placeholder text. Also supports
     dynamic theming for Light and Dark modes.
     */
    static var textSecondary: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traitCollection -> UIColor in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    // If preferred for dark mode, adjust as needed.
                    return .lightGray
                default:
                    return ColorPalette.TEXT["secondary"] ?? .darkGray
                }
            }
        } else {
            return ColorPalette.TEXT["secondary"] ?? .darkGray
        }
    }

    // MARK: - Color Creation and Conversion

    /**
     Initializes a UIColor from a hex string with an optional alpha value.
     Supports both 6-digit (RGB) and 8-digit (RGBA) hex formats.
     
     Steps:
     1. Validate hex string format (6 or 8 characters).
     2. Remove '#' prefix if present.
     3. Convert hex string to an integer using radix 16.
     4. If 6 characters, extract R, G, B and apply the provided alpha.
        If 8 characters, parse R, G, B, A from the hex.
     5. Create and return the UIColor using the extracted components.
     
     - Parameters:
       - hex: The hexadecimal color string (with or without '#').
       - alpha: A CGFloat representing the alpha (transparency) of the color.
                Ignored if the provided hex is in 8-digit format.
     - Returns: An initialized UIColor instance if parsing is successful,
                otherwise a fully transparent color as a fallback.
     */
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Remove '#' if present.
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        // Validate length (must be 6 or 8).
        guard hexString.count == 6 || hexString.count == 8 else {
            self.init(white: 0.0, alpha: 0.0)
            return
        }
        
        // Convert to an integer.
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        // Parse and initialize.
        if hexString.count == 6 {
            // RGB only, apply the provided alpha parameter.
            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: alpha)
        } else {
            // 8-digit format includes alpha components from the hex string.
            let r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgbValue & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        }
    }

    /**
     Converts the UIColor instance into a hexadecimal string representation.
     If the alpha component is strictly less than 1.0, the returned
     string will include the alpha channel as an 8-digit RGBA format.
     
     Steps:
     1. Extract RGBA components using `cgColor`.
     2. Convert each component to a two-digit hexadecimal value.
     3. If alpha < 1.0, append an additional two-digit hex for alpha.
     4. Assemble and return the final string prefixed with '#'.
     
     - Returns: A string representing the hex value of the color, including
                alpha if not fully opaque. Fallbacks to "#000000" if components
                are unavailable.
     */
    func toHex() -> String {
        guard let components = self.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        // Extract RGBA, defaulting alpha to 1.0 if missing.
        let r = components[0]
        let g = components[1]
        let b = components[2]
        let a = (components.count >= 4) ? components[3] : 1.0
        
        let rgb: Int = (Int)(r * 255) << 16
                     | (Int)(g * 255) << 8
                     | (Int)(b * 255) << 0
        
        // Include alpha if it's less than 1.0.
        if a < 1.0 {
            let alphaInt = Int(a * 255)
            return String(format: "#%06X%02X", rgb, alphaInt)
        } else {
            return String(format: "#%06X", rgb)
        }
    }

    // MARK: - Color Manipulation

    /**
     Produces a lighter version of the current color by increasing the brightness
     while preserving the hue and saturation. The `percentage` parameter dictates
     how strongly to lighten, ranging from 0.0 (no change) to potentially >1.0 (much lighter).
     
     Steps:
     1. Convert color to HSB color space using `getHue`.
     2. Extract hue, saturation, brightness, and alpha components.
     3. Increase brightness by `(1.0 - brightness) * percentage`.
     4. Clamp brightness to a maximum of 1.0.
     5. Return a new UIColor instance with the adjusted brightness value.
     
     - Parameter percentage: A CGFloat representing how much to lighten the color.
     - Returns: A new UIColor that is lighter than the original.
     */
    func lighter(_ percentage: CGFloat) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            // If unable to retrieve HSB, return self.
            return self
        }
        
        let adjustment = (1.0 - b) * percentage
        b = min(b + adjustment, 1.0)
        
        return UIColor(hue: h, saturation: s, brightness: b, alpha: a)
    }

    /**
     Produces a darker version of the current color by decreasing the brightness
     while preserving the hue and saturation. The `percentage` parameter dictates
     how strongly to darken, ranging from 0.0 (no change) to potentially >1.0 (much darker).
     
     Steps:
     1. Convert color to HSB color space using `getHue`.
     2. Extract hue, saturation, brightness, and alpha components.
     3. Decrease brightness by `brightness * percentage`.
     4. Clamp brightness to a minimum of 0.0.
     5. Return a new UIColor instance with the adjusted brightness value.
     
     - Parameter percentage: A CGFloat representing how much to darken the color.
     - Returns: A new UIColor that is darker than the original.
     */
    func darker(_ percentage: CGFloat) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            // If unable to retrieve HSB, return self.
            return self
        }
        
        let adjustment = b * percentage
        b = max(b - adjustment, 0.0)
        
        return UIColor(hue: h, saturation: s, brightness: b, alpha: a)
    }
}