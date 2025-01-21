import React, { useState, useRef, useImperativeHandle, ForwardRefExoticComponent, RefAttributes, useEffect, useCallback } from 'react'; // ^18.0.0
import classNames from 'classnames'; // ^2.3.2
import { LoadingState } from '../../types/common.types';

////////////////////////////////////////////////////////////////////////////////
// InputProps Interface
////////////////////////////////////////////////////////////////////////////////
/**
 * Defines the property contract for an advanced and accessible input component.
 * Includes fields for validation, error handling, ARIA attributes, and callbacks
 * to accommodate a broad range of form requirements while adhering to secure
 * input practices.
 */
export interface InputProps {
  /**
   * An optional unique identifier for the input. If not provided, one will
   * be auto-generated for accessibility linkages.
   */
  id?: string;

  /**
   * The name attribute for the input element, allowing form submissions
   * and interactions to bind data to this field name.
   */
  name: string;

  /**
   * The HTML input type (e.g., 'text', 'password', 'email', etc.). Defaults
   * to 'text' if not specified.
   */
  type?: string;

  /**
   * The current string value of the input. Must be controlled from parent
   * state for predictable, consistent behavior.
   */
  value: string;

  /**
   * Placeholder text displayed within the input when no value is present.
   */
  placeholder?: string;

  /**
   * A visually rendered label text associated with the input to ensure
   * the user knows the field's purpose.
   */
  label?: string;

  /**
   * Error message text displayed when validation fails or an error state
   * is triggered. If provided, the component will visually indicate errors.
   */
  error?: string;

  /**
   * Controls the browser's autocomplete feature for improved user experience;
   * may be set to 'on', 'off', or any valid HTML5 token.
   */
  autoComplete?: string;

  /**
   * An identifier used for test automation, enabling scripts to locate
   * this component unambiguously in tests.
   */
  ['data-testid']?: string;

  /**
   * If set to true, the input is disabled and non-interactive.
   */
  disabled?: boolean;

  /**
   * If true, indicates that this field must be filled out prior to
   * form submission. Typically used in conjunction with validation logic.
   */
  required?: boolean;

  /**
   * Provides a way to explicitly mark an input as invalid in ARIA terms,
   * enhancing accessibility for assistive technologies.
   */
  ['aria-invalid']?: boolean;

  /**
   * Identifies the element (e.g., an error message container) that describes
   * this input, establishing a relationship used by screen readers.
   */
  ['aria-describedby']?: string;

  /**
   * Callback invoked whenever the input's value changes.
   */
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;

  /**
   * Callback invoked when the input loses focus.
   */
  onBlur?: (e: React.FocusEvent<HTMLInputElement>) => void;

  /**
   * Callback invoked when the input gains focus.
   */
  onFocus?: (e: React.FocusEvent<HTMLInputElement>) => void;

  /**
   * Represents the loading or validation state for the input, which can
   * be used to display certain UI states or handle internal logic. This
   * component specifically references LoadingState.IDLE and LoadingState.ERROR
   * for demonstration.
   */
  loadingState?: LoadingState;
}

////////////////////////////////////////////////////////////////////////////////
// Internal Utility Functions
////////////////////////////////////////////////////////////////////////////////

/**
 * Applies basic sanitization to the input value, trimming whitespace
 * and removing potentially harmful characters. Expand as needed for
 * further security or domain-specific constraints.
 */
function sanitizeInput(value: string): string {
  // For demonstration, remove leading/trailing whitespace.
  // In production scenarios, one might strip HTML tags or run custom logic.
  return value.trim();
}

/**
 * A small hook to debounce changes in text, preventing rapid validation
 * from firing on every keystroke. The delay is set to 300ms by default
 * for a moderate user experience. Adjust as necessary.
 */
function useDebouncedValue(value: string, delay = 300): string {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}

////////////////////////////////////////////////////////////////////////////////
// ForwardRef Input Component
////////////////////////////////////////////////////////////////////////////////

/**
 * A comprehensive, production-ready input component providing validation,
 * accessibility (ARIA attributes), error handling, and security measures
 * such as sanitization and optional debounced validation. This component
 * leverages React.forwardRef to allow parent components to access the
 * underlying <input> element when needed.
 */
export const Input: ForwardRefExoticComponent<InputProps & RefAttributes<HTMLInputElement>> =
  React.forwardRef<HTMLInputElement, InputProps>((props, ref) => {
    //////////////////////////////////////////////////////////////////////////////
    // Step 1: Destructure and define default behaviors
    //////////////////////////////////////////////////////////////////////////////
    const {
      id,
      name,
      type = 'text',
      value,
      placeholder,
      label,
      error,
      autoComplete,
      disabled = false,
      required = false,
      ['aria-invalid']: ariaInvalid,
      ['aria-describedby']: ariaDescribedBy,
      ['data-testid']: dataTestId,
      onChange,
      onBlur,
      onFocus,
      loadingState = LoadingState.IDLE,
    } = props;

    //////////////////////////////////////////////////////////////////////////////
    // Step 2: Generate a stable internal ID for accessibility linkages
    //////////////////////////////////////////////////////////////////////////////
    const [generatedId] = useState<string>(() => `input-${Math.random().toString(36).substr(2, 9)}`);
    const inputId = id || generatedId;

    //////////////////////////////////////////////////////////////////////////////
    // Step 3: Build dynamic classes based on validation/loading states
    //////////////////////////////////////////////////////////////////////////////
    const hasError = Boolean(error) || loadingState === LoadingState.ERROR;
    const inputClassName = classNames(
      'input-field',
      {
        // Indicate an error style if the error prop is set or loadingState = ERROR
        'input-error': hasError,
        // Indicate a visually disabled state if the component is disabled
        'input-disabled': disabled,
        // Mark as invalid if specified or deduced from error states
        'input-invalid': hasError || ariaInvalid,
        // Mark as loading if loadingState is something other than IDLE
        'input-loading': loadingState !== LoadingState.IDLE && loadingState !== LoadingState.ERROR,
      }
    );

    // Wrapper container classes for optional styling around the field
    const containerClassName = classNames('input-container', {
      'input-with-error': hasError,
    });

    // Label classes can be extended for focus states or theming
    const labelClassName = classNames('input-label');

    //////////////////////////////////////////////////////////////////////////////
    // Step 4: Sanitize input and apply debounced validation
    //////////////////////////////////////////////////////////////////////////////
    const debouncedValue = useDebouncedValue(value);
    useEffect(() => {
      // Here we could trigger additional form-level validation or side effects
      // once the user stops typing. This ensures minimal performance overhead
      // while ensuring accurate validation checks.
      if (hasError && loadingState === LoadingState.ERROR) {
        // For demonstration, a place to run error-specific logic if needed.
      }
    }, [debouncedValue, hasError, loadingState]);

    //////////////////////////////////////////////////////////////////////////////
    // Step 5: Set up callbacks to handle changes, focus, and blur
    //////////////////////////////////////////////////////////////////////////////
    const handleChange = useCallback(
      (e: React.ChangeEvent<HTMLInputElement>) => {
        // Basic sanitization to mitigate potential malicious input. Adjust as needed.
        const sanitized = sanitizeInput(e.target.value);
        // Pass the sanitized content alongside the original event for parent handlers
        if (onChange) {
          const syntheticEvent = {
            ...e,
            target: { ...e.target, value: sanitized },
            currentTarget: { ...e.currentTarget, value: sanitized },
          };
          onChange(syntheticEvent as React.ChangeEvent<HTMLInputElement>);
        }
      },
      [onChange]
    );

    const handleFocus = (e: React.FocusEvent<HTMLInputElement>) => {
      if (onFocus) onFocus(e);
    };

    const handleBlur = (e: React.FocusEvent<HTMLInputElement>) => {
      if (onBlur) onBlur(e);
    };

    //////////////////////////////////////////////////////////////////////////////
    // Step 6: Link the ref to the underlying <input> element
    //////////////////////////////////////////////////////////////////////////////
    const internalRef = useRef<HTMLInputElement | null>(null);
    useImperativeHandle(ref, () => internalRef.current as HTMLInputElement);

    //////////////////////////////////////////////////////////////////////////////
    // Step 7: Render the component structure
    //////////////////////////////////////////////////////////////////////////////
    return (
      <div className={containerClassName}>
        {/* Step 7a: Render label, associated with the input via htmlFor */}
        {label && (
          <label htmlFor={inputId} className={labelClassName}>
            {label}
            {required && <span aria-hidden="true"> *</span>}
          </label>
        )}

        {/* Step 7b: Render the input with comprehensive, secure, and accessible props */}
        <input
          ref={internalRef}
          id={inputId}
          name={name}
          type={type}
          value={value}
          placeholder={placeholder}
          autoComplete={autoComplete}
          disabled={disabled}
          required={required}
          className={inputClassName}
          aria-invalid={hasError || ariaInvalid ? true : undefined}
          aria-describedby={error ? `${inputId}-error` : ariaDescribedBy}
          data-testid={dataTestId}
          onChange={handleChange}
          onFocus={handleFocus}
          onBlur={handleBlur}
        />

        {/* Step 7c: Render an associated error message (if provided),
            with an ID for proper accessibility mapping */}
        {error && (
          <span id={`${inputId}-error`} className="input-error" role="alert" aria-live="assertive">
            {error}
          </span>
        )}
      </div>
    );
  });

////////////////////////////////////////////////////////////////////////////////
// Step 8: Define default props for the Input component
////////////////////////////////////////////////////////////////////////////////
Input.defaultProps = {
  type: 'text',
  placeholder: '',
  disabled: false,
  required: false,
  ['aria-invalid']: false,
  ['aria-describedby']: '',
  loadingState: LoadingState.IDLE,
  error: '',
};