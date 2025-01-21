/**
 * -----------------------------------------------------------------------------
 * Avatar Component
 * -----------------------------------------------------------------------------
 * Description:
 *  A reusable avatar component that displays user profile images with fallback
 *  initials. Supports different sizes, loading states, accessibility features,
 *  and comprehensive error handling with an ErrorBoundary. Leverages responsive
 *  image loading and ensures graceful handling of missing or invalid image URLs.
 *
 * Requirements Addressed:
 *  1) User Management (Scope → Core Features → User Management)
 *     - Displays user profile images as part of owner/walker profiles with
 *       fallback to initials when the image is unavailable or fails to load.
 *  2) Component Library (UI/UX Design → 6.3 Component Specifications)
 *     - Implements a reusable avatar component following design system guidelines
 *       with support for different sizes and states.
 * -----------------------------------------------------------------------------
 */

//
// External Dependencies
//
// NOTE: React version ^18.0.0
import React, { FC, useState, SyntheticEvent } from 'react';
// NOTE: classnames version ^2.3.0
import classNames from 'classnames';
// NOTE: react-error-boundary version ^4.0.0
import { ErrorBoundary } from 'react-error-boundary';

//
// Internal Dependencies
//
import { User } from '../../types/user.types';

/**
 * -----------------------------------------------------------------------------
 * Interface: AvatarProps
 * -----------------------------------------------------------------------------
 * Comprehensive set of props for the Avatar component, supporting:
 *  - Optional user data to determine image, first/last name.
 *  - Size variants ('small', 'medium', 'large') for consistent UI scaling.
 *  - Optional click handler for interactive use cases.
 *  - Loading state for skeleton or spinner placeholders.
 *  - Alt text for improved accessibility (screen readers, etc.).
 *  - className for custom styling or overrides.
 */
export interface AvatarProps {
  /**
   * The user object containing avatarUrl, firstName, and lastName.
   * May be undefined if user data is not yet available.
   */
  user?: User;

  /**
   * The size variant controlling the avatar's dimensions and styling.
   */
  size: 'small' | 'medium' | 'large';

  /**
   * Optional additional CSS class names for custom styling.
   */
  className: string;

  /**
   * Optional callback function to handle user interactions (click/tap).
   */
  onClick?: () => void;

  /**
   * Flag indicating whether the avatar is in a loading state.
   * Useful when user data is being fetched or updated.
   */
  loading: boolean;

  /**
   * The textual alternative for screen readers, essential for accessibility.
   */
  alt: string;
}

/**
 * -----------------------------------------------------------------------------
 * getInitials
 * -----------------------------------------------------------------------------
 * Extracts and formats initials from a given user's first and last name.
 * Steps:
 *  1. Safely extract the first character from firstName if it exists.
 *  2. Safely extract the first character from lastName if it exists.
 *  3. Concatenate the extracted characters.
 *  4. Convert the result to uppercase.
 *  5. Return the combined initials or an empty string if no valid characters.
 *
 * @param firstName - The user's first name string
 * @param lastName  - The user's last name string
 * @returns Combined uppercase initials from both names
 */
export function getInitials(firstName: string, lastName: string): string {
  // Guard clauses to handle empty strings
  const firstInitial: string = firstName?.charAt(0) || '';
  const lastInitial: string = lastName?.charAt(0) || '';
  const combined = `${firstInitial}${lastInitial}`.toUpperCase();
  return combined.trim();
}

/**
 * -----------------------------------------------------------------------------
 * getSizeClass
 * -----------------------------------------------------------------------------
 * Determines the appropriate CSS class string based on the avatar size variant.
 * Steps:
 *  1. Map the size to specific pixel dimensions, like height/width.
 *  2. Include size-specific border radius or shape styling as needed.
 *  3. Add size-specific font sizes for cases where we display initials.
 *  4. Return the combined class name string for consistent theming.
 *
 * @param size - A string variant specifying 'small', 'medium', or 'large'
 * @returns A string containing one or more CSS classes
 */
export function getSizeClass(size: 'small' | 'medium' | 'large'): string {
  switch (size) {
    case 'small':
      return 'w-8 h-8 text-sm';
    case 'medium':
      return 'w-12 h-12 text-base';
    case 'large':
      return 'w-16 h-16 text-lg';
    default:
      return '';
  }
}

/**
 * -----------------------------------------------------------------------------
 * Avatar Component
 * -----------------------------------------------------------------------------
 * Production-ready React Functional Component that displays a user's avatar
 * with full error handling, fallback initials, and optional loading skeleton.
 *
 * Key Functionalities:
 *  1. Loading State:
 *     - If loading is true, a skeleton or loader is shown, preventing random
 *       user data from showing prematurely.
 *  2. Image Rendering:
 *     - If the user has a valid avatarUrl and the image loads successfully,
 *       display the image with alt text for accessibility.
 *  3. Fallback Text:
 *     - If the image fails to load or is missing, fallback to user initials
 *       as derived by the getInitials() helper.
 *  4. Error Boundary:
 *     - Wraps the image component in a react-error-boundary <ErrorBoundary>
 *       to gracefully degrade in case of any unexpected issues.
 *  5. Size and ClassName:
 *     - Dynamically applies sizing (small/medium/large) and any additional
 *       class names for theming or layout.
 *  6. onClick:
 *     - Optionally handles user interaction for clickable avatars.
 *
 * Example Usage:
 *  <Avatar
 *    user={{ firstName: "John", lastName: "Doe", avatarUrl: "...", ... }}
 *    size="medium"
 *    className="rounded-full shadow-md"
 *    loading={false}
 *    alt="User profile picture"
 *    onClick={() => console.log("Avatar clicked")}
 *  />
 */
export const Avatar: FC<AvatarProps> = ({
  user,
  size,
  className,
  onClick,
  loading,
  alt,
}) => {
  // Local state to track if the image has errored out
  const [imageError, setImageError] = useState<boolean>(false);

  // Early return if loading is active → show a loader/skeleton
  if (loading) {
    return (
      <div
        className={classNames(
          'inline-flex items-center justify-center bg-gray-200 animate-pulse text-transparent select-none',
          getSizeClass(size),
          className
        )}
      >
        {/* This skeleton area remains text-transparent to look like a placeholder */}
        Loading...
      </div>
    );
  }

  // If user is not provided or if the user has no meaningful info, show fallback
  const hasUserData = user && (user.firstName || user.lastName);
  const fallbackText = hasUserData
    ? getInitials(user?.firstName || '', user?.lastName || '')
    : '';

  // Decide whether to display the image or fallback initials
  const shouldShowImage = user?.avatarUrl && !imageError;

  /**
   * Error boundary fallback component for image failures. If triggered,
   * we show the same fallback initials UI.
   */
  const errorFallback = () => {
    return (
      <div
        className={classNames(
          'inline-flex items-center justify-center bg-gray-300 text-white uppercase font-bold select-none',
          getSizeClass(size),
          className
        )}
        onClick={onClick}
        aria-label={`${alt} - image load failed, showing initials`}
      >
        {fallbackText || '??'}
      </div>
    );
  };

  /**
   * onError handler for the <img> element to set the imageError state.
   */
  const handleImageError = (event: SyntheticEvent<HTMLImageElement>) => {
    // Mark that we encountered an error in loading this image
    setImageError(true);
    // Throwing an error to invoke the react-error-boundary fallback
    throw new Error('Avatar image failed to load.');
  };

  return (
    <ErrorBoundary FallbackComponent={errorFallback}>
      {shouldShowImage ? (
        <img
          src={user?.avatarUrl}
          alt={alt}
          onClick={onClick}
          onError={handleImageError}
          className={classNames(
            'object-cover select-none',
            'inline-block',
            getSizeClass(size),
            className
          )}
        />
      ) : (
        /**
         * If the image is not displayed, fall back to initials.
         */
        <div
          className={classNames(
            'inline-flex items-center justify-center bg-blue-500 text-white uppercase font-semibold select-none',
            getSizeClass(size),
            className
          )}
          onClick={onClick}
          aria-label={`${alt} - no image available, showing initials`}
        >
          {fallbackText || '??'}
        </div>
      )}
    </ErrorBoundary>
  );
};