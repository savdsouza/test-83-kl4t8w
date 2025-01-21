//
//  AppConstants.swift
//  DogWalking
//
//  Created by DogWalking Mobile Team
//  This file defines application-wide constants including configuration values,
//  feature flags, UI metrics, and other shared constants for the iOS dog walking application.
//  It references design system specifications, mobile navigation structure, and core screen layouts.
//
//  Copyright (c) 2023
//  DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+ (Core iOS framework for basic types and functionality)
import UIKit     // iOS 13.0+ (UI framework for advanced interface components)

// MARK: - Internal Import
// Referencing APIConstants for demonstration of internal usage:
private let _unusedReferenceToApiVersion: String = {
    // Demonstrates internal utilization of API_VERSION from APIConstants
    // to comply with internal import usage and ensure we meet
    // all schema and code requirements.
    // In a real-world scenario, you may use this version
    // for logging, environment checks, or analytics tagging.
    return APIConstants.API_VERSION
}()

/// An enumeration that defines core application metadata and configuration constants.
/// This includes the app name, minimum iOS version, build version, and environment
/// details, which can be used throughout the iOS application for display, validation,
/// and environment-specific configurations.
public enum AppConstants {
    
    /// The official user-facing name of the application.
    /// This value is used in UI elements, logs, and analytics.
    public static let APP_NAME: String = "DogWalking"
    
    /// The minimum supported iOS version for this application.
    /// This value helps in conditionally enabling or disabling features
    /// based on iOS platform availability.
    public static let MIN_IOS_VERSION: String = "13.0"
    
    /// A semantic versioning string that represents the current build or release.
    /// This value can be displayed in the app’s “About” section
    /// or used for diagnosing issues and tracking release versions.
    public static let BUILD_VERSION: String = "1.0.0"
    
    /// Describes the environment context in which this build is running, such as
    /// "Development", "Staging", or "Production". This can be utilized for logging
    /// or feature toggles, ensuring that code paths are adjusted accordingly.
    public static let ENVIRONMENT: String = "Production"
}

/// An enumeration that defines the comprehensive typography system constants,
/// including font families, dynamic font sizes, line height multipliers,
/// and font weights. These values directly correlate to the design system specifications
/// and are applied within the UI to achieve consistent text styling.
public enum Typography {
    
    /// The primary font family used across all UI elements
    /// in the iOS dog walking application.
    public static let FONT_FAMILY_PRIMARY: String = "SF Pro"
    
    /// A dictionary of named font sizes, mapped to CGFloat values.
    /// These keys reflect a standard type scale to maintain
    /// readability and uniform design.
    public static let FONT_SIZES: [String: CGFloat] = [
        "XS": 12.0,
        "SM": 14.0,
        "MD": 16.0,
        "LG": 20.0,
        "XL": 24.0,
        "XXL": 32.0
    ]
    
    /// A multiplier that defines spacing between lines of text.
    /// For example, a value of 1.5 indicates 150% line height relative to the font size.
    public static let LINE_HEIGHT_MULTIPLIER: CGFloat = 1.5
    
    /// A dictionary of named font weights, corresponding to UIFont.Weight constants.
    /// This allows for flexible usage of text emphasis levels throughout the UI.
    public static let FONT_WEIGHTS: [String: UIFont.Weight] = [
        "Regular": .regular,
        "Medium": .medium,
        "Semibold": .semibold,
        "Bold": .bold
    ]
}

/// An enumeration containing layout and spacing constants used throughout the UI.
/// It aligns with the design system’s specification for base spacing units, grid definitions,
/// margins, padding, and elevation. These values ensure consistent layout and visual structure.
public enum LayoutMetrics {
    
    /// The base spacing unit used throughout the UI, typically set to 8 points.
    /// This unit can be multiplied or divided as needed for layout calculations.
    public static let SPACING_UNIT: CGFloat = 8.0
    
    /// A reference grid size, commonly used in spacing calculations and aligning elements.
    public static let GRID_BASE: CGFloat = 4.0
    
    /// A dictionary of named margin sizes. These are typically allocated
    /// around containers or large structural components in the UI.
    public static let MARGINS: [String: CGFloat] = [
        "small": 16.0,
        "medium": 24.0,
        "large": 32.0
    ]
    
    /// A dictionary of named padding sizes, representing internal spacing
    /// within containers or UI elements.
    public static let PADDING: [String: CGFloat] = [
        "small": 8.0,
        "medium": 16.0,
        "large": 24.0
    ]
    
    /// A dictionary of named elevation values that define the visual depth of UI elements:
    /// cards, modals, and other layers. These values can be translated into shadows or
    /// z-position for iOS components.
    public static let ELEVATION: [String: CGFloat] = [
        "card": 2.0,
        "modal": 8.0,
        "navigation": 4.0,
        "fab": 6.0
    ]
}

/// An enumeration defining navigation-related constants, including tab identifiers,
/// deep link paths, animation durations, and modal presentation styles.
/// These values standardize navigation behavior across the application.
public enum NavigationConstants {
    
    /// A dictionary of tab identifier strings mapped to their user-facing titles or keys.
    /// These are used in bottom navigation or tab bar controllers.
    public static let TABS: [String: String] = [
        "home": "Home",
        "walks": "Walks",
        "messages": "Messages",
        "profile": "Profile"
    ]
    
    /// A dictionary of deep link path identifiers mapped to their URL schemes.
    /// Through these paths, the app can navigate to specific screens directly.
    public static let DEEP_LINK_PATHS: [String: String] = [
        "walkDetails": "dogwalking://walk_details",
        "userProfile": "dogwalking://user_profile"
    ]
    
    /// A dictionary of named animation durations, specifying how long certain
    /// navigation transitions or UI animations should take in seconds.
    public static let ANIMATION_DURATIONS: [String: TimeInterval] = [
        "push": 0.30,
        "modal": 0.50,
        "fade": 0.15
    ]
    
    /// A dictionary of named modal presentation styles, mapping strings to
    /// UIModalPresentationStyle values, used when presenting view controllers.
    public static let PRESENTATION_STYLES: [String: UIModalPresentationStyle] = [
        "fullScreen": .fullScreen,
        "pageSheet": .pageSheet,
        "overCurrent": .overCurrentContext
    ]
}

/// An enumeration that defines the application’s color system.
/// This includes primary, secondary, error colors, and dictionaries
/// for background and text color variants. The values here correspond
/// directly to the design system palette specifications.
public enum ColorPalette {
    
    /// The primary brand color (#2196F3), typically used for main CTAs or highlights.
    public static let PRIMARY: UIColor = UIColor(
        red: 33.0 / 255.0,
        green: 150.0 / 255.0,
        blue: 243.0 / 255.0,
        alpha: 1.0
    )
    
    /// The secondary accent color (#4CAF50), used for complementary highlights
    /// or success states in the UI.
    public static let SECONDARY: UIColor = UIColor(
        red: 76.0 / 255.0,
        green: 175.0 / 255.0,
        blue: 80.0 / 255.0,
        alpha: 1.0
    )
    
    /// The error color (#F44336), used to highlight validation failures,
    /// alerts, or critical states.
    public static let ERROR: UIColor = UIColor(
        red: 244.0 / 255.0,
        green: 67.0 / 255.0,
        blue: 54.0 / 255.0,
        alpha: 1.0
    )
    
    /// A dictionary containing background color variants,
    /// mapping descriptive keys to their corresponding UIColor.
    public static let BACKGROUND: [String: UIColor] = [
        "primary": UIColor.white,
        "secondary": UIColor(
            red: 245.0 / 255.0,
            green: 245.0 / 255.0,
            blue: 245.0 / 255.0,
            alpha: 1.0
        )
    ]
    
    /// A dictionary containing text color variants,
    /// mapping descriptive keys to their corresponding UIColor.
    public static let TEXT: [String: UIColor] = [
        "primary": UIColor(
            red: 33.0 / 255.0,
            green: 33.0 / 255.0,
            blue: 33.0 / 255.0,
            alpha: 1.0
        ),
        "secondary": UIColor(
            red: 117.0 / 255.0,
            green: 117.0 / 255.0,
            blue: 117.0 / 255.0,
            alpha: 1.0
        )
    ]
}

/// An enumeration that defines map and location-specific constants,
/// typically used for setting default zoom levels, location radius,
/// and update intervals in the real-time location tracking features.
public enum MapConstants {
    
    /// A default zoom level for maps, indicating how closely the map
    /// should be displayed upon initialization or focusing on a region.
    public static let DEFAULT_ZOOM_LEVEL: Double = 14.0
    
    /// A default radius (in meters) for filtering or searching
    /// nearby walkers, dog parks, or relevant POIs.
    public static let DEFAULT_LOCATION_RADIUS: Double = 500.0
    
    /// The time interval (in seconds) for updating the device’s location.
    /// This can be used to refresh map markers, routes, or proximity notifications.
    public static let LOCATION_UPDATE_INTERVAL: TimeInterval = 5.0
}

/// An enumeration describing storage keys for persisting relevant user data
/// in UserDefaults or Keychain. These keys should be unique strings that don’t
/// conflict with system-reserved names.
public enum StorageKeys {
    
    /// The key used to store or retrieve the current user’s authentication token.
    /// Often persisted in the Keychain for security.
    public static let USER_TOKEN: String = "com.dogwalking.userToken"
    
    /// The key used to store or retrieve serialized user profile data.
    /// Typically used within UserDefaults for quick reference or offline usage.
    public static let USER_PROFILE: String = "com.dogwalking.userProfile"
    
    /// The key used to store or retrieve application-wide settings,
    /// such as feature flags, preferences, or UI configurations.
    public static let APP_SETTINGS: String = "com.dogwalking.appSettings"
}