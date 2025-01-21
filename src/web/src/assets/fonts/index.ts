import { UI_CONSTANTS } from '../../constants/app.constants';

/**
 * FONT_WEIGHTS
 * ----------------------------------------------------------------------
 * Enumeration defining standardized numeric font-weight values.
 * These values ensure consistent font-weight usage throughout
 * the web application.
 */
export enum FONT_WEIGHTS {
  /**
   * Represents a standard text weight, typically used
   * for normal paragraph text and descriptive copy.
   */
  REGULAR = 400,

  /**
   * Slightly heavier than REGULAR, often used for
   * emphasized text that requires subtle prominence.
   */
  MEDIUM = 500,

  /**
   * A semi-bold weight, commonly applied to headings
   * or subheadings that need emphasis.
   */
  SEMI_BOLD = 600,

  /**
   * Bold text weight, typically used for primary headings
   * or elements that require strong emphasis.
   */
  BOLD = 700,
}

/**
 * FONT_FAMILIES
 * ----------------------------------------------------------------------
 * Constant object defining cross-platform font families with
 * comprehensive fallback chains, ensuring consistent rendering
 * across various devices and operating systems.
 */
export const FONT_FAMILIES = {
  /**
   * PRIMARY
   * The primary marketing and branding font, leveraging
   * SF Pro Display on iOS, plus fallbacks including
   * system defaults and Roboto for non-Apple platforms.
   */
  PRIMARY: "SF Pro Display, -apple-system, BlinkMacSystemFont, Roboto, sans-serif",

  /**
   * SECONDARY
   * An alternate font family for secondary headings,
   * form elements, or less emphasized text.
   */
  SECONDARY: "Roboto, Arial, sans-serif",
} as const;

/**
 * LINE_HEIGHTS
 * ----------------------------------------------------------------------
 * Constant object providing carefully calibrated line-height
 * values. These ensure optimal text readability and spacing
 * consistency across different typographic elements.
 */
export const LINE_HEIGHTS = {
  /**
   * DEFAULT
   * Represents a balanced line height suitable for
   * most paragraph and heading text.
   */
  DEFAULT: 1.5,

  /**
   * TIGHT
   * A more condensed line height, useful for labels
   * or compact component layouts.
   */
  TIGHT: 1.25,

  /**
   * LOOSE
   * An expanded line height, conducive to content
   * that demands increased white space or higher
   * readability emphasis.
   */
  LOOSE: 1.75,
} as const;

/**
 * INTERNAL FONT SIZE MAP
 * ----------------------------------------------------------------------
 * A local mapping of textual size keys to numeric font sizes.
 * This object aligns with the standardized scale of 12, 14,
 * 16, 20, 24, and 32 pixels, empowering consistent sizing
 * across the application’s design system.
 */
const FONT_SIZE_MAP = {
  XS: 12,  //  Extra Small
  SM: 14,  //  Small / Caption
  MD: 16,  //  Medium / Body
  LG: 20,  //  Large subtitle or mid-level heading
  XL: 24,  //  Extra Large heading
  XXL: 32, //  Double Extra Large display heading
} as const;

/**
 * getFontSize
 * ----------------------------------------------------------------------
 * Retrieves the font size specified by a given size key
 * from the internal FONT_SIZE_MAP. Appends the 'px' unit
 * to the numeric value for direct usage in CSS properties.
 *
 * Steps:
 * 1. Validate the 'size' key against FONT_SIZE_MAP.
 * 2. Retrieve the corresponding numeric value.
 * 3. Append 'px' to the numeric value.
 * 4. Return the formatted string.
 *
 * @param {string} size - The size key (e.g., "SM", "MD", "XL").
 * @returns {string} - The font size with 'px' appended (e.g., "16px").
 */
export function getFontSize(size: string): string {
  const numericValue = (FONT_SIZE_MAP as Record<string, number>)[size];
  if (!numericValue) {
    throw new Error(
      `Invalid font size key: "${size}". Valid keys are: ${Object.keys(FONT_SIZE_MAP).join(', ')}`
    );
  }
  return `${numericValue}px`;
}