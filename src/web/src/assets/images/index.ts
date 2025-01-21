/**
 * Central index file for exporting all image assets used throughout the web application.
 * Provides type-safe imports for logos, icons, backgrounds, and other visual assets required by various UI components.
 * Implements strict TypeScript typing and organized categorization of all visual assets.
 */

// =============================================================================
// External Imports (Third-party Libraries)
// =============================================================================
// TypeScript version ^5.0.0
import type {} from 'typescript';

// =============================================================================
// Global Constants
// =============================================================================

/**
 * Global base path for all images placed under the web application's assets directory.
 * This is used in conjunction with the getImageUrl() helper function to ensure
 * that all asset references remain consistent across the project.
 */
export const IMAGE_BASE_PATH: string = '/assets/images';

// =============================================================================
// Supported File Extensions
// =============================================================================

/**
 * Comprehensive list of supported file extensions for the image assets.
 * This list is used by the getImageUrl() function to validate
 * that the provided image name has an allowed extension.
 */
const SUPPORTED_EXTENSIONS: string[] = [
  '.png',
  '.jpg',
  '.jpeg',
  '.svg',
  '.gif',
  '.webp',
];

// =============================================================================
// Helper Function: getImageUrl
// =============================================================================

/**
 * Type-safe helper function to generate a full image URL path with proper error
 * handling and path validation. Ensures images are retrieved from the central
 * IMAGE_BASE_PATH location.
 *
 * Steps to generate the URL:
 * 1) Validate input imageName for proper format.
 * 2) Combine IMAGE_BASE_PATH with the sanitized imageName.
 * 3) Verify the file extension is supported before proceeding.
 * 4) Return the complete URL string with correct path joining.
 *
 * @param imageName The name of the image file, such as "logo/app-logo.png".
 * @returns Full image URL path (e.g., "/assets/images/logo/app-logo.png").
 */
export function getImageUrl(imageName: string): string {
  // Step 1: Validate the imageName for correctness.
  if (!imageName || typeof imageName !== 'string') {
    throw new Error('Invalid image name provided. Must be a non-empty string.');
  }

  // Trim potential leading/trailing whitespace and remove leading slashes to standardize paths.
  const sanitizedName = imageName.trim().replace(/^\/+/, '');

  // Step 2: Prepare a lowercase copy for extension checks, but preserve sanitizedName for the final URL.
  const lowerCaseName = sanitizedName.toLowerCase();

  // Step 3: Verify a supported file extension is present.
  const hasValidExtension = SUPPORTED_EXTENSIONS.some((ext) =>
    lowerCaseName.endsWith(ext)
  );

  if (!hasValidExtension) {
    throw new Error(
      `Unsupported file extension for image "${imageName}". Allowed extensions are: ${SUPPORTED_EXTENSIONS.join(
        ', '
      )}.`
    );
  }

  // Step 4: Return the combined path.
  return `${IMAGE_BASE_PATH}/${sanitizedName}`;
}

// =============================================================================
// Type Definitions for Exported Image Objects
// =============================================================================

/**
 * Logo Images Interface
 * Represents the distinct application logo variants made available under /assets/images/logo.
 */
interface LogoImages {
  appLogo: string;
  appLogoSmall: string;
  appLogoWhite: string;
}

/**
 * Auth Images Interface
 * Represents the assortment of images utilized in authentication-related screens.
 */
interface AuthImages {
  loginBackground: string;
  registrationBackground: string;
  socialAuthIcons: Record<string, string>;
  verificationSuccess: string;
}

/**
 * Profile Images Interface
 * Represents user profile-related images, covering avatars, verification badges, and rating icons.
 */
interface ProfileImages {
  defaultAvatar: string;
  defaultDogAvatar: string;
  verifiedBadge: string;
  ratingStars: Record<number, string>;
}

/**
 * Illustration Images Interface
 * Represents a set of illustrations or vector graphics used for empty states,
 * notifications, error pages, and other situational UI components.
 */
interface IllustrationImages {
  emptyState: string;
  errorState: string;
  successState: string;
  loadingState: string;
  noResults: string;
}

/**
 * Background Images Interface
 * Represents the various background assets for different sections, pages, or themed layers.
 */
interface BackgroundImages {
  homeBackground: string;
  walkBackground: string;
  profileBackground: string;
  patternLight: string;
  patternDark: string;
}

// =============================================================================
// Exported Image Objects
// =============================================================================

/**
 * Application logo variants for different contexts and backgrounds.
 * These typically reside under "/assets/images/logo".
 */
export const logoImages: LogoImages = {
  /**
   * The primary brand logo for the application, recommended for header usage.
   */
  appLogo: getImageUrl('logo/app-logo.png'),

  /**
   * A smaller version of the main logo, used in confined spaces like mobile navbars or side menus.
   */
  appLogoSmall: getImageUrl('logo/app-logo-small.png'),

  /**
   * A white or light-themed version of the logo, used for dark backgrounds.
   */
  appLogoWhite: getImageUrl('logo/app-logo-white.png'),
};

/**
 * Authentication-related images including backgrounds, social login icons, and status illustrations.
 * These typically reside under "/assets/images/auth".
 */
export const authImages: AuthImages = {
  /**
   * Background image used on the login screen for owners and walkers.
   */
  loginBackground: getImageUrl('auth/login-bg.png'),

  /**
   * Background used on the registration or sign-up screen.
   */
  registrationBackground: getImageUrl('auth/registration-bg.png'),

  /**
   * Record of social authentication icons (Google, Facebook, Apple, etc.) for brand consistency.
   */
  socialAuthIcons: {
    google: getImageUrl('auth/social/google.png'),
    facebook: getImageUrl('auth/social/facebook.png'),
    apple: getImageUrl('auth/social/apple.png'),
  },

  /**
   * An image shown on successful email or identity verification steps.
   */
  verificationSuccess: getImageUrl('auth/verification-success.png'),
};

/**
 * Profile-related images including avatars, verification badges, and rating stars.
 * These typically reside under "/assets/images/profile".
 */
export const profileImages: ProfileImages = {
  /**
   * The default user avatar displayed when a user has not uploaded a personal profile image.
   */
  defaultAvatar: getImageUrl('profile/default-avatar.png'),

  /**
   * The default avatar for a dog profile when no custom dog photo is provided.
   */
  defaultDogAvatar: getImageUrl('profile/default-dog-avatar.png'),

  /**
   * A badge graphic used to indicate that a walker or user is verified (e.g., background check completed).
   */
  verifiedBadge: getImageUrl('profile/verified-badge.png'),

  /**
   * A record of rating star images with keys from 1 to 5 rating levels.
   */
  ratingStars: {
    1: getImageUrl('profile/rating-stars-1.png'),
    2: getImageUrl('profile/rating-stars-2.png'),
    3: getImageUrl('profile/rating-stars-3.png'),
    4: getImageUrl('profile/rating-stars-4.png'),
    5: getImageUrl('profile/rating-stars-5.png'),
  },
};

/**
 * Illustration assets covering empty states, errors, successes, loading states, and no-results scenarios.
 * These are typically found under "/assets/images/illustrations".
 */
export const illustrationImages: IllustrationImages = {
  /**
   * A graphic for indicating that there is currently no content to display or data to show.
   */
  emptyState: getImageUrl('illustrations/empty-state.png'),

  /**
   * A graphic displayed when an error has occurred, providing a more engaging error UI.
   */
  errorState: getImageUrl('illustrations/error-state.png'),

  /**
   * A success image displayed after certain completion events or successful flows.
   */
  successState: getImageUrl('illustrations/success-state.png'),

  /**
   * An image or animation shown to the user during data loading phases.
   */
  loadingState: getImageUrl('illustrations/loading-state.png'),

  /**
   * A graphic used when a search or query yields zero matching results.
   */
  noResults: getImageUrl('illustrations/no-results.png'),
};

/**
 * Background images and patterns used across various sections of the application.
 * Files typically reside under "/assets/images/backgrounds".
 */
export const backgroundImages: BackgroundImages = {
  /**
   * The primary home screen background, often used behind main content sections.
   */
  homeBackground: getImageUrl('backgrounds/home-bg.png'),

  /**
   * Background used on walk-related screens, such as active walks or walk history views.
   */
  walkBackground: getImageUrl('backgrounds/walk-bg.png'),

  /**
   * Background used on user profile or settings pages.
   */
  profileBackground: getImageUrl('backgrounds/profile-bg.png'),

  /**
   * A light pattern that can be used for subtle texture in bright-themed areas.
   */
  patternLight: getImageUrl('backgrounds/pattern-light.png'),

  /**
   * A darker pattern used for night-mode or dark-themed sections.
   */
  patternDark: getImageUrl('backgrounds/pattern-dark.png'),
};