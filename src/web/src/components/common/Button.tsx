import React from 'react'; // react@^18.0.0
import classNames from 'classnames'; // classnames@^2.3.2
import { LoadingState } from '../../types/common.types'; // Internal import for loading state enum

/**
 * ButtonProps defines all configurable properties for the Button component,
 * including variant, size, and accessibility attributes. This interface
 * also helps maintain strong type safety across the application.
 */
export interface ButtonProps {
  /**
   * The button style variant, which determines colors,
   * background, and overall appearance (e.g., primary,
   * secondary, text) based on the design system.
   */
  variant: 'primary' | 'secondary' | 'text';

  /**
   * The size of the button (e.g., small, medium, large),
   * controlling padding, font size, and layout.
   */
  size: 'small' | 'medium' | 'large';

  /**
   * When true, the button is disabled, preventing user interaction
   * and applying disabled styles to reflect its non-interactive state.
   */
  disabled: boolean;

  /**
   * When true, the button is considered to be in a loading state,
   * disabling interaction and optionally displaying a loading indicator.
   */
  loading: boolean;

  /**
   * When true, the button will stretch to the full container width,
   * allowing for flexible responsive designs where the button
   * must span the entire available space.
   */
  fullWidth: boolean;

  /**
   * An optional string of additional class names for style overrides,
   * custom utility classes, or theme-specific changes.
   */
  className?: string;

  /**
   * The HTML button type attribute (e.g., button, submit, reset).
   * This determines whether the button triggers form submission
   * or acts as a general purpose button.
   */
  type?: 'button' | 'submit' | 'reset';

  /**
   * The optional click handler invoked when the button is pressed.
   * Receives a MouseEvent object with details about the click event.
   */
  onClick?: (event: React.MouseEvent<HTMLButtonElement>) => void;

  /**
   * Button content that can include text, icons, or other
   * React nodes for flexible composition.
   */
  children?: React.ReactNode;

  /**
   * An accessible label describing the button’s action or purpose,
   * assisting screen readers for visually impaired users.
   */
  'aria-label'?: string;

  /**
   * Identifies the element that describes the button in more detail,
   * pointing to an ID for extended context.
   */
  'aria-describedby'?: string;

  /**
   * A data-testid attribute for streamlined test automation and
   * referencing this component in various testing frameworks.
   */
  'data-testid'?: string;
}

/**
 * getButtonClasses is a utility function that composes
 * dynamic class names for the Button component based on
 * variant, size, loading/disabled states, and other props.
 *
 * Steps:
 * 1) Combine base button classes
 * 2) Add variant-specific classes
 * 3) Add size-specific classes
 * 4) Add state-specific classes (disabled, loading)
 * 5) Add full-width class if specified
 * 6) Append custom user-defined classes if provided
 *
 * @param props The complete set of ButtonProps used to
 *              determine styling and functionality.
 * @returns A combined string of class names for the button.
 */
export function getButtonClasses(props: ButtonProps): string {
  const { variant, size, disabled, loading, fullWidth, className } = props;
  const currentLoadingState = loading ? LoadingState.LOADING : LoadingState.IDLE;

  const baseClass = 'btn';
  const variantClass = `btn--${variant}`;
  const sizeClass = `btn--${size}`;

  // State classes
  const isDisabledClass = disabled ? 'btn--disabled' : null;
  const isLoadingClass = currentLoadingState === LoadingState.LOADING ? 'btn--loading' : null;

  // Full width class
  const fullWidthClass = fullWidth ? 'btn--full-width' : null;

  return classNames(
    baseClass,
    variantClass,
    sizeClass,
    isDisabledClass,
    isLoadingClass,
    fullWidthClass,
    className
  );
}

/**
 * Button is a reusable React functional component
 * that implements the design system's button specifications,
 * covering primary, secondary, and text variants, multiple sizes,
 * and disabled/loading states. It also supports accessibility
 * attributes for screen reader compatibility.
 */
export const Button: React.FC<ButtonProps> = ({
  variant,
  size,
  disabled,
  loading,
  fullWidth,
  className,
  type,
  onClick,
  children,
  'aria-label': ariaLabel,
  'aria-describedby': ariaDescribedBy,
  'data-testid': dataTestId,
}) => {
  return (
    <button
      type={type || 'button'}
      aria-label={ariaLabel}
      aria-describedby={ariaDescribedBy}
      data-testid={dataTestId}
      className={getButtonClasses({
        variant,
        size,
        disabled,
        loading,
        fullWidth,
        className,
      })}
      onClick={onClick}
      disabled={disabled || loading}
    >
      {loading ? <span className="btn__loader">Loading...</span> : children}
    </button>
  );
};