// react ^18.0.0
import React, {
  useState,
  useEffect,
  useCallback,
  ForwardRefRenderFunction,
  forwardRef,
  ChangeEvent,
  FocusEvent
} from 'react';

// classnames ^2.3.2
import classNames from 'classnames';

// Internal imports for component state management and utilities
import { LoadingState } from '../../types/common.types';
import { sanitizeInput } from '../../utils/validation.utils';
import useDebounce from '../../hooks/useDebounce';

/**
 * Represents the result of a validation process,
 * indicating whether the input is valid and the
 * corresponding error message if any.
 */
interface ValidationResult {
  /** Flag indicating if the input passes all validation checks. */
  isValid: boolean;
  /** Detailed error message providing feedback on validation failures. */
  errorMessage?: string;
}

/**
 * TextAreaProps
 *
 * Defines all properties accepted by the reusable TextArea component.
 * This interface ensures consistent usage and integration within the
 * application, including support for custom validation, accessibility,
 * and enhanced security.
 */
export interface TextAreaProps {
  /**
   * The current value of the textarea.
   */
  value: string;

  /**
   * Event handler called when the textarea value changes,
   * receiving the sanitized string as an argument.
   */
  onChange: (value: string) => void;

  /**
   * Callback triggered when the textarea loses focus,
   * allowing consumers to perform additional actions.
   */
  onBlur?: () => void;

  /**
   * Placeholder text displayed inside the textarea when it is empty.
   */
  placeholder?: string;

  /**
   * Disables the textarea when true, preventing user interaction.
   */
  disabled?: boolean;

  /**
   * An external error message to display if provided by the parent
   * or higher-level validation process.
   */
  error?: string;

  /**
   * Marks the textarea as required, prompting validation rules
   * to ensure a non-empty value.
   */
  required?: boolean;

  /**
   * The number of visible text lines for the textarea.
   */
  rows?: number;

  /**
   * The maximum allowable length for the textarea value,
   * preventing input beyond the specified character count.
   */
  maxLength?: number;

  /**
   * Optional CSS class name for additional styling or customization.
   */
  className?: string;

  /**
   * An optional asynchronous validator function. If provided,
   * it will be used to perform advanced checks on the value
   * and return a ValidationResult.
   */
  validator?: (value: string) => Promise<ValidationResult>;

  /**
   * Accessible label used by screen readers to identify
   * the purpose of this textarea.
   */
  ariaLabel?: string;
}

/**
 * validateInput
 *
 * Validates the provided string value against the configured rules:
 * 1) Checks if field is required and the value is empty.
 * 2) Checks for exceeding the maxLength constraint if specified.
 * 3) Invokes an optional custom validator if provided.
 * 4) Returns a ValidationResult containing the outcome.
 *
 * @param value The string value to validate.
 * @param required If true, ensures value is non-empty.
 * @param maxLength The maximum number of characters allowed, if any.
 * @param validator An optional asynchronous validation function.
 * @returns A promise resolving to a ValidationResult indicating validity and an error message if invalid.
 */
async function validateInput(
  value: string,
  required?: boolean,
  maxLength?: number,
  validator?: (val: string) => Promise<ValidationResult>
): Promise<ValidationResult> {
  // Step 1: Check for required field if specified
  if (required && !value.trim()) {
    return {
      isValid: false,
      errorMessage: 'This field is required.'
    };
  }

  // Step 2: Validate against maxLength constraint if provided
  if (typeof maxLength === 'number' && value.length > maxLength) {
    return {
      isValid: false,
      errorMessage: `This field cannot exceed ${maxLength} characters.`
    };
  }

  // Step 3: Run custom validation if provided
  if (validator) {
    try {
      const customResult = await validator(value);
      if (!customResult.isValid) {
        return customResult;
      }
    } catch {
      return {
        isValid: false,
        errorMessage: 'Validation process encountered an error.'
      };
    }
  }

  // Step 4: If all checks pass, return an affirmative validation result
  return {
    isValid: true
  };
}

/**
 * TextArea
 *
 * A reusable, multi-line text input component that integrates:
 * - Sanitization of user input to mitigate XSS or injection attacks.
 * - Debounced custom validation to reduce performance overhead.
 * - Accessibility features through ARIA labeling.
 * - Enterprise-grade error handling and loading state integration.
 */
const TextAreaRenderFn: ForwardRefRenderFunction<HTMLTextAreaElement, TextAreaProps> = (
  {
    value,
    onChange,
    onBlur,
    placeholder = '',
    disabled = false,
    error = '',
    required = false,
    rows = 3,
    maxLength,
    className,
    validator,
    ariaLabel,
  },
  ref
) => {
  /**
   * Internal component states
   * loadingState: tracks the current loading or error status from an enterprise perspective.
   * internalError: stores any locally computed error messages (e.g., from internal or custom validation).
   * internalValue: maintains a local representation of the textarea value to decouple external changes.
   */
  const [loadingState, setLoadingState] = useState<LoadingState>(LoadingState.IDLE);
  const [internalError, setInternalError] = useState<string>(error);
  const [internalValue, setInternalValue] = useState<string>(value);

  /**
   * Debounced value that triggers custom validation if provided.
   * Minimizes frequent validation calls as the user types.
   */
  const debouncedValue = useDebounce(internalValue, 300);

  /**
   * Sync the local error state with the external error prop whenever
   * the parent updates it, ensuring consistent user-facing messaging.
   */
  useEffect(() => {
    setInternalError(error);
  }, [error]);

  /**
   * Sync the local value state with the external value prop whenever
   * a new value is passed down from the parent component or store.
   */
  useEffect(() => {
    setInternalValue(value);
  }, [value]);

  /**
   * Whenever the debounced value changes, and if a custom validator
   * is provided, run the validation logic to keep the user feedback
   * timely but not overly reactive to every keystroke.
   */
  useEffect(() => {
    const performValidation = async () => {
      if (validator) {
        setLoadingState(LoadingState.LOADING);
        try {
          const debouncedValidation = await validator(debouncedValue);
          if (debouncedValidation.isValid) {
            setLoadingState(LoadingState.IDLE);
            setInternalError('');
          } else {
            setLoadingState(LoadingState.ERROR);
            setInternalError(debouncedValidation.errorMessage || 'Invalid input');
          }
        } catch {
          setLoadingState(LoadingState.ERROR);
          setInternalError('An unexpected validation error occurred.');
        }
      }
    };

    performValidation();
  }, [debouncedValue, validator]);

  /**
   * handleChange
   *
   * Responds to user input in the textarea:
   * 1) Prevents any default event behavior that might interfere.
   * 2) Sanitizes input to eliminate potential XSS or injection.
   * 3) Enforces maxLength if specified by slicing unwanted characters.
   * 4) Updates the internal state with the sanitized value.
   * 5) Invokes the parent onChange handler with the sanitized value.
   * 6) Debounced validation occurs automatically in useEffect.
   */
  const handleChange = useCallback(
    (event: ChangeEvent<HTMLTextAreaElement>): void => {
      event.preventDefault();

      // Step 2: Sanitize input
      let newValue = sanitizeInput(event.target.value);

      // Step 3: Enforce maxLength if applicable
      if (typeof maxLength === 'number' && newValue.length > maxLength) {
        newValue = newValue.substring(0, maxLength);
      }

      // Step 4: Update state for local usage or further debounced validation
      setInternalValue(newValue);

      // Step 5: Trigger parent-level change with sanitized value
      onChange(newValue);
    },
    [onChange, maxLength]
  );

  /**
   * handleBlur
   *
   * Handles focus departure by performing comprehensive checks:
   * 1) Validates using the local rules and optional custom validator.
   * 2) Updates error state based on the validation outcome.
   * 3) Invokes the optional onBlur callback from props.
   * 4) Sets the component's loading state to either IDLE or ERROR.
   */
  const handleBlur = useCallback(
    async (event: FocusEvent<HTMLTextAreaElement>): Promise<void> => {
      // Run the full validation suite on current internalValue
      const validationRes = await validateInput(
        internalValue,
        required,
        maxLength,
        validator
      );

      if (!validationRes.isValid) {
        setInternalError(validationRes.errorMessage || 'Invalid input');
        setLoadingState(LoadingState.ERROR);
      } else {
        setInternalError('');
        setLoadingState(LoadingState.IDLE);
      }

      // Call any external onBlur handler
      if (onBlur) {
        onBlur();
      }
    },
    [internalValue, onBlur, required, maxLength, validator]
  );

  /**
   * Dynamically compute the final CSS classes for this component,
   * combining any external className with an error or disabled state.
   */
  const textAreaClass = classNames('text-area-component', className, {
    'text-area-error': internalError,
    'text-area-disabled': disabled
  });

  return (
    <div className="text-area-wrapper">
      {/* Render the actual multi-line input with specified properties. */}
      <textarea
        ref={ref}
        className={textAreaClass}
        placeholder={placeholder}
        disabled={disabled}
        required={required}
        rows={rows}
        aria-label={ariaLabel}
        value={internalValue}
        onChange={handleChange}
        onBlur={handleBlur}
      />

      {/* If an error message is present, show it below. */}
      {internalError && (
        <p className="text-area-error-message" role="alert">
          {internalError}
        </p>
      )}

      {/* For demonstration, we could reflect current loading state if needed. */}
      {loadingState === LoadingState.ERROR && (
        <p className="text-area-loading-state" role="alert">
          Validation error detected.
        </p>
      )}
    </div>
  );
};

/**
 * ForwardRefExoticComponent wrapper enabling direct ref usage on the
 * underlying <textarea> HTML element for advanced form operations or
 * third-party library integrations.
 */
const TextArea = forwardRef(TextAreaRenderFn);

export default TextArea;