import React, { useState, useCallback, ChangeEvent, FocusEvent } from 'react'; // react ^18.0.0
import '../../styles/variables.css';

/**
 * Interface describing the properties
 * for the RadioButton component.
 */
export interface RadioButtonProps {
  /**
   * Unique identifier for input-label association.
   */
  id: string;

  /**
   * Name of the radio button group for form submission.
   */
  name: string;

  /**
   * Value associated with this radio option.
   */
  value: string;

  /**
   * Visible label text for the radio button.
   */
  label: string;

  /**
   * Controlled checked state for fully managed usage.
   */
  checked?: boolean;

  /**
   * Uncontrolled initial checked state.
   * Only used if 'checked' is not provided.
   */
  defaultChecked?: boolean;

  /**
   * Determines whether the radio button is disabled.
   */
  disabled?: boolean;

  /**
   * Indicates if the radio button is required in a form.
   */
  required?: boolean;

  /**
   * Handler invoked when the radio button selection changes.
   * Receives the radio value and event as arguments.
   */
  onChange?: (value: string, event: React.ChangeEvent<HTMLInputElement>) => void;

  /**
   * Optional CSS class to customize styling of the container.
   */
  className?: string;

  /**
   * Accessible label for screen readers if needed.
   */
  ['aria-label']?: string;
}

/**
 * Custom hook for managing focus states on the radio button.
 * Returns a boolean indicating focused state, and dedicated
 * focus/blur handlers to manage transitions.
 */
function useRadioFocus(): {
  focused: boolean;
  handleFocus: (event: FocusEvent<HTMLInputElement>) => void;
  handleBlur: (event: FocusEvent<HTMLInputElement>) => void;
} {
  // Tracks whether the radio button is currently focused
  const [focused, setFocused] = useState(false);

  /**
   * Handles setting the focus state to true when
   * the input element gains focus.
   */
  const handleFocus = useCallback(() => {
    setFocused(true);
  }, []);

  /**
   * Handles resetting the focus state to false when
   * the input element loses focus.
   */
  const handleBlur = useCallback(() => {
    setFocused(false);
  }, []);

  return { focused, handleFocus, handleBlur };
}

/**
 * A reusable and accessible radio button component
 * that implements the design system specifications
 * with support for all interaction states, form integration,
 * and mobile optimization.
 */
export const RadioButton: React.FC<RadioButtonProps> = ({
  id,
  name,
  value,
  label,
  checked,
  defaultChecked,
  disabled,
  required,
  onChange,
  className,
  ['aria-label']: ariaLabel,
}) => {
  /**
   * Local state to manage the "checked" state
   * in uncontrolled usage scenarios.
   */
  const [internalChecked, setInternalChecked] = useState<boolean>(!!defaultChecked);

  /**
   * Determines if this component is being used in a controlled manner
   * (i.e., the 'checked' prop is provided) or uncontrolled manner.
   */
  const isControlled = typeof checked === 'boolean';

  /**
   * The current "checked" value that the component
   * will render. Derived from either controlled or uncontrolled usage.
   */
  const currentChecked = isControlled ? !!checked : internalChecked;

  // Access the focus management logic from the custom hook.
  const { focused, handleFocus, handleBlur } = useRadioFocus();

  /**
   * Handles radio button selection changes with enhanced event handling.
   * 1. Prevent default event behavior
   * 2. Extract the updated value from the event target
   * 3. Invoke the onChange callback with the extracted value
   * 4. Update internal state if this is uncontrolled usage
   * 5. Manage any additional side effects/focus states as needed
   */
  const handleChange = (event: ChangeEvent<HTMLInputElement>): void => {
    event.preventDefault();
    const newValue = event.target.value;

    if (onChange) {
      onChange(newValue, event);
    }

    // Update internal checked state if not controlled
    if (!isControlled) {
      setInternalChecked(event.target.checked);
    }
  };

  /**
   * Build a composite container class name to allow
   * external customization while maintaining default styling.
   */
  const containerClassName = [
    'rb-container',
    className || '',
    disabled ? 'rb-disabled' : '',
    focused ? 'rb-focused' : '',
  ]
    .join(' ')
    .trim();

  return (
    <>
      {/* 
        Radio container acts as the label to ensure the
        clickable area includes both the button and text.
      */}
      <label
        htmlFor={id}
        className={containerClassName}
        aria-disabled={disabled ? 'true' : undefined}
      >
        {/* 
          The radio input includes all required attributes for
          proper accessibility and form integration.
        */}
        <input
          id={id}
          name={name}
          type="radio"
          value={value}
          checked={currentChecked}
          disabled={disabled}
          required={required}
          aria-label={ariaLabel}
          onFocus={handleFocus}
          onBlur={handleBlur}
          onChange={handleChange}
          className="rb-input"
        />

        {/*
          The text label associated with the radio button.
          Screen readers will reference the label through the 'htmlFor' id.
        */}
        <span className="rb-label">
          {label}
        </span>
      </label>

      {/*
        Embedded styles block reflecting the JSON-defined
        design system attributes, pseudo-classes, and transitions.
        Uses CSS variables from variables.css to ensure consistency
        with the broader design system.
      */}
      <style>{`
        /***********************************************
         * RADIO CONTAINER STYLES
         ***********************************************/
        .rb-container {
          display: flex;
          align-items: center;
          gap: var(--spacing-sm);
          cursor: pointer;
          min-height: 44px;
          padding: var(--spacing-sm);
          user-select: none;
        }

        /* 
          This media query ensures hover effects only 
          apply on devices that support hover (e.g. desktop). 
        */
        @media (hover: hover) {
          .rb-container:not(.rb-disabled):hover {
            background-color: var(--color-hover-bg);
          }
        }

        /* 
          Disabled container will visually communicate 
          that interaction is not possible.
        */
        .rb-disabled {
          cursor: not-allowed;
        }

        .rb-focused {
          /* Potential container focus style if desired. 
             Not explicitly defined in the style spec, left 
             here for extended usage or customization. */
        }

        /***********************************************
         * RADIO INPUT STYLES
         ***********************************************/
        .rb-input {
          appearance: none;
          width: 20px;
          height: 20px;
          border: 2px solid var(--color-border);
          border-radius: 50%;
          outline: none;
          transition: var(--transition-normal);
          position: relative;
          cursor: pointer;
        }

        /* 
          Checked state styling: changes border and fill color 
          to the primary brand color. The ::after element draws 
          the inner dot. 
        */
        .rb-input:checked {
          border-color: var(--color-primary);
          background-color: var(--color-primary);
        }

        .rb-input:checked::after {
          content: "";
          position: absolute;
          width: 8px;
          height: 8px;
          background-color: #ffffff; /* White dot in the center */
          border-radius: 50%;
          left: 50%;
          top: 50%;
          transform: translate(-50%, -50%);
        }

        /* 
          Focus-visible handles the accessible outline ring 
          when navigated via keyboard. 
        */
        .rb-input:focus-visible {
          box-shadow: 0 0 0 2px var(--color-focus-ring);
        }

        /* 
          Disabled styling for the radio input, reducing 
          opacity and removing pointer actions. 
        */
        .rb-input:disabled {
          opacity: 0.5;
          cursor: not-allowed;
          background-color: var(--color-disabled-bg);
        }

        /***********************************************
         * RADIO LABEL STYLES
         ***********************************************/
        .rb-label {
          font-size: var(--font-size-md);
          color: var(--color-text);
          line-height: 1.5;
        }

        /* 
          When the container is disabled, also reflect 
          that appearance on the associated label text. 
        */
        .rb-disabled .rb-label {
          color: var(--color-text-disabled);
        }
      `}</style>
    </>
  );
};