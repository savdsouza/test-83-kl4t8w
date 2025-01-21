import React, {
  useRef,
  useState,
  useEffect,
  useCallback,
  memo
} from 'react'; // React ^18.0.0

// Importing comprehensive checkbox styling for all states.
import styles from '../../styles/components.css'; // Internal stylesheet import

/**
 * Comprehensive props interface for Checkbox component with
 * accessibility support. This interface includes all properties
 * mandated by the specification for enterprise-grade development.
 */
export interface CheckboxProps {
  /**
   * Determines if the checkbox state is controlled by a parent component.
   * When provided, this component becomes controlled, and you are responsible
   * for handling state changes via the onChange callback.
   */
  checked?: boolean;

  /**
   * Only used for uncontrolled scenarios, allowing the checkbox to
   * manage its own state initially.
   */
  defaultChecked?: boolean;

  /**
   * Callback invoked whenever the user changes the checkbox state.
   * Provides the new boolean value and the original DOM event.
   */
  onChange?: (checked: boolean, event: React.ChangeEvent<HTMLInputElement>) => void;

  /**
   * Callback invoked when the checkbox receives focus.
   */
  onFocus?: (event: React.FocusEvent<HTMLInputElement>) => void;

  /**
   * Callback invoked when the checkbox loses focus.
   */
  onBlur?: (event: React.FocusEvent<HTMLInputElement>) => void;

  /**
   * Disables the checkbox interaction, preventing user toggles
   * and applying a visual "disabled" state.
   */
  disabled?: boolean;

  /**
   * When true, sets the checkbox to an indeterminate (mixed) state.
   * The actual "checked" value remains unaffected, but the visual
   * appearance flips to an in-between style.
   */
  indeterminate?: boolean;

  /**
   * The text label associated with the checkbox for additional screen
   * reader clarity and visual context.
   */
  label?: string;

  /**
   * The name attribute to be applied to the underlying input element,
   * often used in form submissions.
   */
  name?: string;

  /**
   * The value attribute for the underlying input, typically used during
   * form submissions to represent the checkbox's value.
   */
  value?: string;

  /**
   * Custom class name(s) for advanced styling, appended to the default
   * set of enterprise design system classes.
   */
  className?: string;

  /**
   * The id attribute for the underlying input, facilitating WAI-ARIA
   * labeling and direct DOM access.
   */
  id?: string;

  /**
   * Optionally override the accessible label text read by screen readers,
   * commonly used when no visible label is present.
   */
  'aria-label'?: string;

  /**
   * Defines which element(s) this checkbox description is related to.
   * Useful for associating the checkbox with help text or error text.
   */
  'aria-describedby'?: string;

  /**
   * Explicitly sets the ARIA role for the checkbox. Defaults to 'checkbox'
   * if no value is provided.
   */
  role?: string;

  /**
   * Sets a custom tabIndex for keyboard navigation. Most often left as default,
   * but provided for advanced focus management.
   */
  tabIndex?: number;

  /**
   * Marks the checkbox as required, applying relevant aria-required
   * attributes and assisting form validation flows.
   */
  required?: boolean;

  /**
   * Flags the checkbox as invalid or erroneous, applying appropriate
   * styling and assistive attributes for screen readers.
   */
  error?: boolean;

  /**
   * The message text displayed when the checkbox is flagged with error=true,
   * assisting users with details on what needs correction.
   */
  errorMessage?: string;
}

/**
 * Custom hook to manage the checkbox reference (ref) and handle the
 * indeterminate state at the DOM level. This approach ensures that
 * the indeterminate visual is set directly on the HTMLInputElement,
 * bypassing React's default checkbox handling.
 *
 * @param indeterminate - Indicates the "mixed" state for the checkbox
 * @param checked - Reflects the current checked state, ensuring consistency
 * @returns Ref object tied to the checkbox input element
 */
export function useCheckboxRef(
  indeterminate: boolean,
  checked: boolean
): React.RefObject<HTMLInputElement> {
  // Create a ref for direct DOM access on the <input> element.
  const inputRef = useRef<HTMLInputElement>(null);

  /**
   * Whenever the indeterminate or checked values change, update
   * the underlying input's properties at the DOM level. This
   * ensures the displayed visual state matches the logical state.
   */
  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.indeterminate = indeterminate;
      inputRef.current.checked = checked;
    }
  }, [indeterminate, checked]);

  // Return the ref so it can be applied to the checkbox input.
  return inputRef;
}

/**
 * Highly accessible checkbox component with comprehensive state
 * management, keyboard interactions, and screen reader support.
 * This enterprise-grade component ensures compliance with WCAG
 * 2.1 AA standards and integrates seamlessly into form elements.
 */
export const Checkbox: React.FC<CheckboxProps> = memo((props) => {
  const {
    checked,
    defaultChecked,
    onChange,
    onFocus,
    onBlur,
    disabled = false,
    indeterminate = false,
    label,
    name,
    value,
    className,
    id,
    role,
    tabIndex,
    required = false,
    error = false,
    errorMessage,
    'aria-label': ariaLabel,
    'aria-describedby': ariaDescribedBy
  } = props;

  /**
   * Determine if the component operates in a controlled or uncontrolled mode.
   * In controlled mode, 'checked' is maintained by the parent. In uncontrolled
   * mode, we manage the local state while deferring the initial value to
   * defaultChecked.
   */
  const isControlled = typeof checked !== 'undefined';

  /**
   * Local state for uncontrolled usage. This state is only used if
   * 'checked' was not provided, meaning the parent does not control
   * the checkbox value.
   */
  const [internalChecked, setInternalChecked] = useState<boolean>(
    defaultChecked || false
  );

  /**
   * Compute the effective "isChecked" value, which is either
   * externally controlled or locally managed.
   */
  const isChecked = isControlled ? !!checked : internalChecked;

  /**
   * Acquire a specialized ref that manages the indeterminate
   * property on the DOM <input> element.
   */
  const checkboxRef = useCheckboxRef(indeterminate, isChecked);

  /**
   * Event handler fired when the user toggles the checkbox.
   * - Updates local state if uncontrolled.
   * - Calls onChange prop with the latest checked value.
   */
  const handleChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      const nextChecked = event.target.checked;

      if (!isControlled) {
        setInternalChecked(nextChecked);
      }

      onChange?.(nextChecked, event);
    },
    [isControlled, onChange]
  );

  /**
   * CSS class composition for stateful rendering:
   * - .checkbox for baseline styling
   * - .checkbox-checked if the checkbox is in a "checked" state
   * - .checkbox-indeterminate if the checkbox is in an "indeterminate" state
   * - .checkbox-disabled if the checkbox is disabled
   * - user-provided className appended for advanced styling overrides
   */
  const combinedClassNames = [
    styles.checkbox,
    isChecked ? styles['checkbox-checked'] : '',
    indeterminate ? styles['checkbox-indeterminate'] : '',
    disabled ? styles['checkbox-disabled'] : '',
    className || ''
  ]
    .filter(Boolean)
    .join(' ');

  /**
   * Render error message element conditionally, shown if
   * 'error' is true and there's an associated message.
   */
  const renderErrorMessage = useCallback(() => {
    if (!error || !errorMessage) {
      return null;
    }
    return (
      <p
        id={`${id || name}-error-message`}
        style={{ color: 'var(--color-error)', marginTop: '4px' }}
        aria-live="polite"
      >
        {errorMessage}
      </p>
    );
  }, [error, errorMessage, id, name]);

  return (
    <label
      // Use a <label> wrapper for improved accessibility:
      // Clicking the label toggles the checkbox.
      className={combinedClassNames}
      htmlFor={id}
      style={{ display: 'inline-flex', alignItems: 'center', cursor: disabled ? 'not-allowed' : 'pointer' }}
    >
      <input
        ref={checkboxRef}
        id={id}
        name={name}
        type="checkbox"
        value={value}
        disabled={disabled}
        required={required}
        // If controlled, forward "checked" to ensure consistency;
        // otherwise let local state track the value.
        checked={isControlled ? isChecked : undefined}
        defaultChecked={!isControlled ? defaultChecked : undefined}
        // Ensure role-based alignment for screen readers, defaulting to 'checkbox'.
        role={role || 'checkbox'}
        tabIndex={typeof tabIndex === 'number' ? tabIndex : 0}
        // On focus & blur callbacks for external usage.
        onFocus={onFocus}
        onBlur={onBlur}
        onChange={handleChange}
        // Mark field as invalid if error is true.
        aria-invalid={error ? 'true' : undefined}
        aria-required={required ? 'true' : undefined}
        aria-label={ariaLabel}
        aria-describedby={ariaDescribedBy}
      />
      {/* Render the provided label text to the right of the checkbox input. */}
      {label && (
        <span style={{ marginLeft: '8px' }}>
          {label}
        </span>
      )}
      {/* Show error message if error is flagged. */}
      {renderErrorMessage()}
    </label>
  );
});

Checkbox.displayName = 'Checkbox';