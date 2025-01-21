/**
 * Core application metadata constants. These values represent high-level
 * configuration details used throughout the web application and must be
 * kept up to date to accurately reflect the platform’s version and purpose.
 */
export const APP_CONFIG = {
  /**
   * The current version of the Dog Walking Platform web application.
   * Update this value whenever a new release is deployed.
   */
  APP_VERSION: '1.0.0',

  /**
   * The official name of the dog walking platform, used for branding
   * and display purposes across the web application.
   */
  APP_NAME: 'Dog Walking Platform',

  /**
   * A short description summarizing the main functionality provided
   * by the dog walking platform for owners and walkers.
   */
  APP_DESCRIPTION: 'Mobile application connecting owners with walkers',
} as const;

/**
 * Comprehensive UI design system constants, grouped to ensure
 * consistency across the entire web application interface.
 */
export const UI_CONSTANTS = {
  /**
   * Defines the primary color tokens used throughout the UI layer.
   * Includes standardized color swatches for brand consistency.
   */
  COLORS: {
    /**
     * Represents the primary brand color (blue) used for
     * actionable UI elements like buttons, links, and highlights.
     */
    PRIMARY: '#2196F3',

    /**
     * Represents the secondary brand color (green) often used for
     * confirmations, success messages, or secondary accents.
     */
    SECONDARY: '#4CAF50',

    /**
     * Represents the color used for error states, alerts, or
     * any unfavorable feedback in the UI.
     */
    ERROR: '#F44336',

    /**
     * Default background color for panels, pages, or components
     * that require a bright, clean look.
     */
    BACKGROUND_DEFAULT: '#FFFFFF',

    /**
     * Alternate background color, often used to differentiate
     * sections or containers within the layout.
     */
    BACKGROUND_ALTERNATE: '#F5F5F5',

    /**
     * Primary text color typically used for high-contrast text
     * over light backgrounds.
     */
    TEXT_PRIMARY: '#212121',

    /**
     * Secondary text color suitable for subtext or descriptive
     * messages appearing on lighter backgrounds.
     */
    TEXT_SECONDARY: '#757575',
  },

  /**
   * Simple typography tokens leveraging consistent text styles
   * across application components. Detailed typography constants
   * are available in TYPOGRAPHY_CONSTANTS for advanced usage.
   */
  TYPOGRAPHY: {
    /**
     * Text style for large headings or significant labels.
     */
    HEADING1: {
      fontSize: 32,
      lineHeight: 1.5,
      fontWeight: 700,
    },
    /**
     * Text style for sub-headings or medium emphasis titles.
     */
    HEADING2: {
      fontSize: 24,
      lineHeight: 1.5,
      fontWeight: 600,
    },
    /**
     * Body text style for standard paragraphs and descriptions.
     */
    BODY: {
      fontSize: 16,
      lineHeight: 1.5,
      fontWeight: 400,
    },
    /**
     * Smaller text style for hints, microcopy, or less
     * prominent text within components.
     */
    CAPTION: {
      fontSize: 14,
      lineHeight: 1.5,
      fontWeight: 400,
    },
  },

  /**
   * Provides consistent spacing values used for margins, paddings,
   * and layout gaps throughout the application.
   */
  SPACING: {
    /**
     * Small spacing unit, often used for tight layouts or
     * minimal spacing requirements.
     */
    XS: 4,

    /**
     * Base spacing unit aligned with the standard design
     * system guideline of 8px increments.
     */
    SM: 8,

    /**
     * Medium spacing unit, commonly used for moderate separation
     * between UI sections or components.
     */
    MD: 16,

    /**
     * Larger spacing unit, often used for bigger sections,
     * container boundaries, or extensive padding around UI blocks.
     */
    LG: 24,

    /**
     * Extra-large spacing unit for significant separation or
     * creating spacious layouts between major interface sections.
     */
    XL: 32,
  },

  /**
   * Elevation levels simulating material-style shadows or depth
   * used to provide hierarchy in the UI. Values are in dp.
   */
  ELEVATION: {
    /**
     * Minor depth typically for cards or small panels.
     */
    CARD: 2,

    /**
     * Slightly higher depth for navigation bars or sticky headers.
     */
    NAVIGATION: 4,

    /**
     * Additional depth used for floating action buttons or
     * UI elements that require attention.
     */
    FLOATING: 6,

    /**
     * Highest depth for modals, dialogs, or overlays that sit
     * above most UI elements.
     */
    MODAL: 8,
  },

  /**
   * Collection of icon references that map to textual or graphical
   * representations. These icons provide consistent symbolic cues
   * throughout the application.
   */
  ICONS: {
    USER: '[@]',
    DASHBOARD: '[#]',
    PAYMENT: '[$]',
    HELP: '[?]',
    ALERT: '[!]',
    ADD: '[+]',
    CLOSE: '[x]',
    UPLOAD: '[^]',
    SETTINGS: '[=]',
    FAVORITE: '[*]',
  },

  /**
   * High-level definitions for frequently reused components.
   * Each component entry typically outlines dimension, padding,
   * or style defaults for straightforward reuse.
   */
  COMPONENTS: {
    /**
     * Alert component specifications, including typical layout
     * structure, title sizing, and close button styling.
     */
    ALERT: {
      width: 400,
      minHeight: 120,
      padding: 16,
      titleFontSize: 16,
      bodyFontSize: 14,
      closeIcon: '[x]',
    },
    /**
     * Search component with default input field dimensions,
     * icons, and optional filter toggles.
     */
    SEARCH: {
      width: 300,
      height: 40,
      placeholderColor: '#757575',
      iconLeft: '[?]',
    },
    /**
     * Profile card specifications containing layout guidelines,
     * recommended spacing, and text styling for user or walker info.
     */
    PROFILE_CARD: {
      width: 280,
      height: 100,
      padding: 16,
      avatarSize: 48,
      nameFontSize: 16,
      subtitleFontSize: 14,
    },
    /**
     * Common list item or tile used for representing walk sessions,
     * schedules, or other horizontally displayed data.
     */
    LIST_ITEM: {
      height: 60,
      paddingHorizontal: 16,
      paddingVertical: 8,
      separatorColor: '#E0E0E0',
    },
    /**
     * Common button definition with consistent default spacing,
     * height, and font style. Extended or variant styles could
     * inherit from this base configuration.
     */
    BUTTON: {
      height: 44,
      paddingHorizontal: 16,
      borderRadius: 6,
      fontSize: 16,
      fontWeight: 500,
      defaultColor: '#2196F3',
    },
  },
} as const;

/**
 * Responsive design breakpoints and layout behavior definitions
 * for mobile, tablet, and desktop form factors. These constants
 * drive adaptive UI changes throughout the entire application.
 */
export const BREAKPOINTS = {
  /**
   * Threshold for small mobile devices, typically up to 375px wide.
   * The UI may adjust by reducing visible content or stacking elements.
   */
  MOBILE_SMALL: 375,

  /**
   * Threshold for standard mobile devices, typically up to 428px wide.
   * Elements are arranged in a single column with a bottom navigation.
   */
  MOBILE: 428,

  /**
   * Threshold for tablet-sized screens, typically up to 768px wide.
   * The layout often transitions to a dual-column view or side nav.
   */
  TABLET: 768,

  /**
   * Threshold for desktop and larger screens, typically from 1024px
   * onward, providing multi-column layouts and extended navigation.
   */
  DESKTOP: 1024,

  /**
   * Associates each breakpoint with typical layout behaviors,
   * such as column count, navigation positioning, or content scaling.
   */
  LAYOUT_BEHAVIOR: {
    MOBILE_SMALL: {
      columns: 1,
      navigation: 'bottom',
      scale: 0.9,
    },
    MOBILE: {
      columns: 1,
      navigation: 'bottom',
      scale: 1.0,
    },
    TABLET: {
      columns: 2,
      navigation: 'side',
      scale: 1.0,
    },
    DESKTOP: {
      columns: 3,
      navigation: 'expanded side',
      scale: 1.0,
    },
  },
} as const;

/**
 * Theme color constants intended for system-level theming. Includes
 * both light and dark variants enabling dynamic theming support.
 */
export const THEME_CONSTANTS = {
  /**
   * Global primary color token used for brand identification
   * and primary accent elements across the UI.
   */
  PRIMARY_COLOR: '#2196F3',

  /**
   * Global secondary color token, commonly used for success
   * states or complementary accenting in components.
   */
  SECONDARY_COLOR: '#4CAF50',

  /**
   * Color token used for indicating error states, warnings,
   * and other negative feedback in the interface.
   */
  ERROR_COLOR: '#F44336',

  /**
   * Base background color typically used for major surfaces
   * in the light theme variant.
   */
  BACKGROUND_COLOR: '#FFFFFF',

  /**
   * Default text color providing sufficient contrast on
   * light backgrounds.
   */
  TEXT_COLOR: '#212121',

  /**
   * The light theme object, representing the background,
   * text, and other UI element overrides for daylight usage.
   */
  LIGHT_THEME: {
    background: '#FFFFFF',
    text: '#212121',
    surface: '#F5F5F5',
    shadow: 'rgba(0,0,0,0.1)',
  },

  /**
   * The dark theme object, representing a darker color scheme
   * for low-light environments or user preference.
   */
  DARK_THEME: {
    background: '#212121',
    text: '#FFFFFF',
    surface: '#333333',
    shadow: 'rgba(0,0,0,0.6)',
  },
} as const;

/**
 * An extensive typography configuration containing all critical text
 * attributes leveraged across application components, ensuring
 * consistent font families, sizes, weights, and spacing.
 */
export const TYPOGRAPHY_CONSTANTS = {
  /**
   * References to commonly used font families across iOS and
   * Android platforms.
   */
  FONT_FAMILY: {
    ios: 'SF Pro',
    android: 'Roboto',
  },

  /**
   * Predefined font sizes aligned with the design system scale,
   * covering various text elements like headings, body, and captions.
   */
  FONT_SIZE: {
    XS: 12,
    SM: 14,
    MD: 16,
    LG: 20,
    XL: 24,
    XXL: 32,
  },

  /**
   * Common line-height values that maintain consistent text
   * readability across different font sizes and layouts.
   */
  LINE_HEIGHT: {
    NORMAL: 1.5,
    DOUBLE: 2.0,
  },

  /**
   * Standardized font weights for headings, subheadings,
   * and body text, ensuring a cohesive typographic hierarchy.
   */
  FONT_WEIGHT: {
    REGULAR: 400,
    MEDIUM: 500,
    BOLD: 700,
  },

  /**
   * Letter-spacing values for fine-tuning text readability
   * and adjusting for specific languages or design preferences.
   */
  LETTER_SPACING: {
    NONE: 0,
    NARROW: -0.5,
    WIDE: 1,
  },
} as const;

/**
 * Comprehensive spacing and layout system constants, essential
 * for margin, padding, and structured design application.
 */
export const SPACING_CONSTANTS = {
  /**
   * Base spacing unit, typically an 8-pixel increment
   * used to maintain consistent vertical and horizontal spacing.
   */
  BASE_UNIT: 8,

  /**
   * Standardized margin sizes used universally throughout
   * the interface for external spacing around compartments.
   */
  MARGIN: {
    SMALL: 8,
    MEDIUM: 16,
    LARGE: 24,
  },

  /**
   * Standardized padding sizes used within components to ensure
   * balanced internal spacing and clear visual hierarchy.
   */
  PADDING: {
    SMALL: 8,
    MEDIUM: 16,
    LARGE: 24,
  },

  /**
   * Grid-related settings, defining the number of columns and
   * gutter spacing for systematic alignment of interface elements.
   */
  GRID: {
    COLUMNS: 4,
    GUTTER: 4,
  },

  /**
   * Additional layout-specific values, referencing typical
   * container or component dimensions for consistent approach
   * to spacing across the application’s design.
   */
  LAYOUT: {
    CARD_SPACING: 16,
    SECTION_SPACING: 24,
    SCREEN_HORIZONTAL_PADDING: 16,
    SCREEN_VERTICAL_PADDING: 16,
  },
} as const;