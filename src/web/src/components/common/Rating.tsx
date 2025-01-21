/** 
 * A reusable Rating component that displays and optionally collects user feedback 
 * using star icons. It supports both controlled and uncontrolled usage, multiple 
 * size variants, keyboard navigation, and extensive accessibility features.
 */

 // react@^18.0.0
import React, { FC, useState, KeyboardEvent, useCallback } from 'react';

// @heroicons/react/24/solid@^2.0.0
import { StarIcon } from '@heroicons/react/24/solid';

/**
 * Imported rating-related classes from "src/web/src/styles/components.css":
 * .rating             -> Base rating container styling
 * .rating--interactive-> Styling for interactive mode
 * .rating--sm         -> Small size variant
 * .rating--md         -> Medium size variant
 * .rating--lg         -> Large size variant
 */
import '../../styles/components.css';

/**
 * RatingProps defines all options for the Rating component.
 * - value (number)            : Current rating value (1-5). For controlled usage.
 * - onChange? (function)      : Callback triggered when rating changes. Receives new rating.
 * - readOnly? (boolean)       : If true, disables interactivity and hides keyboard support.
 * - size? ('sm' | 'md' | 'lg'): Defines visual size variant of stars.
 * - className? (string)       : Additional class names for custom styling.
 * - ariaLabel? (string)       : Allows overriding default ARIA label for the rating control.
 * - disabled? (boolean)       : If true, disables pointer and keyboard events.
 */
export interface RatingProps {
  value: number;
  onChange?: (rating: number) => void;
  readOnly?: boolean;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
  ariaLabel?: string;
  disabled?: boolean;
}

/**
 * The Rating component implements a five-star rating control with both read-only
 * and interactive modes. In interactive mode, it supports mouse, touch, and full 
 * keyboard navigation. It also manages accessibility attributes for screen readers.
 */
export const Rating: FC<RatingProps> = ({
  value,
  onChange,
  readOnly = false,
  size = 'md',
  className = '',
  ariaLabel,
  disabled = false,
}) => {
  /**
   * internalRating is used to handle uncontrolled scenarios. If 'value' changes are 
   * strictly driven by an external parent, it remains a controlled component. In 
   * practice, the user can rely on 'value' + 'onChange' externally for controlled usage.
   */
  const [internalRating, setInternalRating] = useState<number>(value);

  /**
   * The effectiveRating determines the visual rating displayed. If the parent 
   * externally controls the value, that will take precedence; otherwise, we use 
   * the internalRating for display.
   */
  const effectiveRating = onChange ? value : internalRating;

  /**
   * handleRatingChange ensures all rating updates are validated, triggers onChange if 
   * provided, updates internal state if uncontrolled, and updates ARIA attributes accordingly.
   * @param newRating - The proposed new rating (1-5)
   */
  const handleRatingChange = useCallback(
    (newRating: number) => {
      // Step 1: Validate newRating is between 1 and 5
      if (newRating < 1 || newRating > 5) return;

      // Step 2: Prevent updates if component is disabled or in read-only mode
      if (disabled || readOnly) return;

      // Step 3: Update local state if the component is currently uncontrolled
      if (!onChange) {
        setInternalRating(newRating);
      }

      // Step 4: Invoke onChange callback when provided
      if (onChange) {
        onChange(newRating);
      }
      // ARIA attributes will be updated automatically by React re-render
    },
    [onChange, disabled, readOnly]
  );

  /**
   * handleKeyDown processes keyboard navigation for interactive rating selection,
   * managing arrow keys (Left/Right) for +/-1 adjustments, and Home/End for min/max rating.
   * @param event - The keyboard event containing the pressed key
   */
  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      if (readOnly || disabled) return;

      let newCalculatedRating = effectiveRating;

      switch (event.key) {
        case 'ArrowLeft':
          event.preventDefault();
          newCalculatedRating = effectiveRating - 1;
          break;
        case 'ArrowRight':
          event.preventDefault();
          newCalculatedRating = effectiveRating + 1;
          break;
        case 'Home':
          event.preventDefault();
          newCalculatedRating = 1;
          break;
        case 'End':
          event.preventDefault();
          newCalculatedRating = 5;
          break;
        default:
          return;
      }

      handleRatingChange(Math.min(Math.max(newCalculatedRating, 1), 5));
    },
    [readOnly, disabled, effectiveRating, handleRatingChange]
  );

  /**
   * Build the CSS class list dynamically to ensure we properly combine:
   * - .rating for the base container
   * - .rating--interactive if not readOnly or disabled
   * - .rating--(sm|md|lg) based on size prop
   * - any classes provided via className prop
   */
  const baseClass = 'rating';
  const sizeClass = `rating--${size}`;
  const interactiveClass = !readOnly && !disabled ? 'rating--interactive' : '';
  const containerClassList = [baseClass, sizeClass, interactiveClass, className]
    .filter(Boolean)
    .join(' ');

  /**
   * renderStar() outputs a single star icon with all relevant accessibility
   * and interaction props. The star is "filled" if index <= effectiveRating.
   */
  const renderStar = (index: number) => {
    // The star is filled if its index is less than or equal to current rating
    const isActive = index <= effectiveRating;
    const starColor = isActive ? '#fbbf24' : '#d1d5db'; // Tailwind relative colors or custom

    // For read-only or disabled states, we remove pointer interactivity
    const handleClick = () => {
      if (!readOnly && !disabled) {
        handleRatingChange(index);
      }
    };

    return (
      <button
        key={`star-${index}`}
        type="button"
        role="radio"
        aria-checked={isActive}
        aria-label={`Rate ${index} out of 5`}
        tabIndex={readOnly || disabled ? -1 : 0}
        onClick={handleClick}
        style={{
          cursor: readOnly || disabled ? 'default' : 'pointer',
          outline: 'none',
          background: 'transparent',
          border: 'none',
          padding: 0,
          display: 'inline-flex',
        }}
      >
        <StarIcon
          aria-hidden="true"
          style={{ width: '1em', height: '1em', color: starColor }}
        />
      </button>
    );
  };

  return (
    <div
      className={containerClassList}
      role="radiogroup"
      aria-label={ariaLabel || 'Rating input'}
      aria-disabled={disabled || readOnly ? 'true' : 'false'}
      onKeyDown={handleKeyDown}
      tabIndex={readOnly || disabled ? -1 : 0}
      style={{
        display: 'inline-flex',
        gap: '4px',
        alignItems: 'center',
      }}
    >
      {Array.from({ length: 5 }, (_, i) => i + 1).map((starIndex) =>
        renderStar(starIndex)
      )}
    </div>
  );
};