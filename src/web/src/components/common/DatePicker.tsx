import React, {
  memo, 
  ChangeEvent, 
  FocusEvent, 
  useCallback
} from 'react' // ^18.0.0

// Third-party date manipulation and validation imports (date-fns ^2.30.0)
import {
  format,
  parse,
  isValid,
  isAfter,
  isBefore,
} from 'date-fns' // ^2.30.0

// Internal form-related imports for enhanced integration;
// NOTE: Actual named exports may vary depending on the implementation of useForm.
import {
  handleChange,
  handleBlur,
  validateField,
} from '../../hooks/useForm'

/**
 * DatePickerProps
 *
 * Represents the comprehensive set of properties required to configure and control the
 * behavior of the DatePicker component. This interface strictly adheres to the specifications
 * described in the technical document for advanced validation, accessibility, and form
 * integration.
 */
export interface DatePickerProps {
  /**
   * Unique identifier/key used for form field registration. 
   * Typically maps to a data model property (e.g., "birthDate").
   */
  name: string

  /**
   * The current date value, expected to be a string formatted in an
   * ISO-like or custom format. If undefined, no date is set.
   */
  value: string | undefined

  /**
   * Callback triggered upon date change with the new date string and a boolean
   * indicating if the newly provided date is considered valid.
   */
  onChange: (date: string, isValid: boolean) => void

  /**
   * Callback triggered upon blur/focus loss, allowing external form
   * handlers to perform validations or state updates.
   */
  onBlur: (e: FocusEvent<HTMLInputElement>) => void

  /**
   * Placeholder text displayed when no date value is set.
   */
  placeholder: string

  /**
   * Disables the date picker input, preventing user interaction and
   * visually indicating an unavailable field.
   */
  disabled: boolean

  /**
   * Potential error message passed down from an external validation
   * or form library. When present, it should be displayed to the user.
   */
  error: string | undefined

  /**
   * Minimum permissible date (string), preventing selection of any date
   * prior to this value if specified.
   */
  min: string | undefined

  /**
   * Maximum permissible date (string), preventing selection of any date
   * beyond this value if specified.
   */
  max: string | undefined

  /**
   * Optional custom class name for the root container, enabling
   * advanced styling or design-system overrides.
   */
  className: string | undefined

  /**
   * Defines how the date should be presented and parsed. Examples might include:
   * 'yyyy-MM-dd', 'MM/dd/yyyy', or any valid date-fns format string.
   */
  dateFormat: string

  /**
   * Locale code (e.g., 'en-US', 'fr', 'es') used by date-fns for internationalized
   * date parsing and formatting.
   */
  locale: string

  /**
   * The ARIA label provides a textual description for screen readers,
   * improving accessibility compliance.
   */
  ariaLabel: string | undefined
}

/**
 * formatDateForInput
 *
 * Helper function to parse a date string, validate it, and reformat it according
 * to a specified date-fns format and locale. Intended for displaying user-friendly
 * text in the date picker input.
 *
 * @param dateString - The raw string representing a date.
 * @param dateFormat - The desired format, e.g., 'yyyy-MM-dd' or 'MM/dd/yyyy'.
 * @param locale - Locale code (e.g., 'en-US') for internationalization.
 * @returns A formatted date string if valid; otherwise, an empty string.
 */
export function formatDateForInput(
  dateString: string,
  dateFormat: string,
  locale: string
): string {
  try {
    // Attempt to parse the incoming string according to the specified format.
    const parsed = parse(dateString, dateFormat, new Date())
    // Ensure the parsed date is valid; if not, return an empty string.
    if (!isValid(parsed)) {
      return ''
    }
    // Return a properly formatted string if valid.
    return format(parsed, dateFormat, { locale: undefined })
  } catch {
    // Return empty string if formatting or parsing fails.
    return ''
  }
}

/**
 * validateDateConstraints
 *
 * Checks whether a given date is valid and falls within the optional
 * min/max range supplied as strings. If the date is invalid or outside
 * the permitted boundaries, returns false.
 *
 * @param date - The user-supplied date string to validate.
 * @param min  - The earliest allowable date (string), or undefined if not set.
 * @param max  - The latest allowable date (string), or undefined if not set.
 * @returns True if the date is valid and within constraints; otherwise false.
 */
export function validateDateConstraints(
  date: string,
  min: string | undefined,
  max: string | undefined
): boolean {
  // Attempt to parse the date. If invalid, immediately fail.
  const parsedDate = parse(date, "yyyy-MM-dd'T'HH:mm:ss", new Date())
  if (!isValid(parsedDate)) {
    // If the default parse fails, try a fallback approach (assuming date format mismatch).
    // This approach uses a forgiving parse with no custom format, as a last resort.
    const fallbackParsed = new Date(date)
    if (!isValid(fallbackParsed)) {
      return false
    }
    // If fallback is valid, set final reference to fallback.
    if (min) {
      const minDate = new Date(min)
      if (isValid(minDate) && isBefore(fallbackParsed, minDate)) {
        return false
      }
    }
    if (max) {
      const maxDate = new Date(max)
      if (isValid(maxDate) && isAfter(fallbackParsed, maxDate)) {
        return false
      }
    }
    return true
  }

  // If a min date is provided, verify parsedDate is not before min.
  if (min) {
    const minDate = new Date(min)
    if (isValid(minDate) && isBefore(parsedDate, minDate)) {
      return false
    }
  }

  // If a max date is provided, verify parsedDate is not after max.
  if (max) {
    const maxDate = new Date(max)
    if (isValid(maxDate) && isAfter(parsedDate, maxDate)) {
      return false
    }
  }

  // If we've passed all checks without failing, it's valid within constraints.
  return true
}

/**
 * DatePicker
 *
 * A memoized, enterprise-ready date picker component that enables the user to input
 * or select a date, incorporating advanced validation (including min/max constraints),
 * accessibility features (ARIA attributes), and strict conformance to the application's
 * design system. This component is designed for seamless integration with form systems,
 * dispatching validation feedback via props and calling external handlers on changes.
 *
 * Steps:
 *  1) Destructure incoming props to retrieve styling, value, constraints, and callbacks.
 *  2) Format the existing date value for display using the specified date format and locale.
 *  3) Implement an internal change handler to parse user input, validate it, and call the onChange prop.
 *  4) Implement an internal blur handler, invoking both local form logic (handleBlur) and the external onBlur callback.
 *  5) Render an accessible input element with properly assigned classes, placeholders, errors, and ARIA attributes.
 *  6) Display error messages conditionally when external validation fails.
 */
function BaseDatePicker(props: DatePickerProps): JSX.Element {
  const {
    name,
    value,
    onChange,
    onBlur,
    placeholder,
    disabled,
    error,
    min,
    max,
    className,
    dateFormat,
    locale,
    ariaLabel,
  } = props

  /**
   * handleInputChange
   *
   * Interprets user-typed values in the input, leveraging advanced date parsing,
   * constraint checks, and final validation. Communicates validity to the
   * parent onChange prop while delegating standard form logic (handleChange)
   * to the internal hook's function (if applicable).
   */
  const handleInputChange = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      // Invoke internal form library's standard handler for synergy.
      handleChange(e)

      const userEnteredValue = e.target.value

      // Attempt to parse and format the user-entered date with the provided dateFormat.
      const formattedIncomingDate = formatDateForInput(userEnteredValue, dateFormat, locale)

      // If the date is valid if it passes constraint checks as well.
      const isWithinConstraints = formattedIncomingDate
        ? validateDateConstraints(
            formattedIncomingDate,
            min,
            max
          )
        : false

      // Trigger external onChange with the final string and validity.
      // If the date fails constraints or parse, we pass an empty string + false.
      if (formattedIncomingDate && isWithinConstraints) {
        onChange(formattedIncomingDate, true)
      } else {
        onChange('', false)
      }
    },
    [onChange, dateFormat, locale, min, max]
  )

  /**
   * handleInputBlur
   *
   * Called when the user leaves the input field, delegating standard blur logic
   * to our form library's handleBlur and external onBlur callback. Also triggers
   * single-field validation if needed.
   */
  const handleInputBlur = useCallback(
    (e: FocusEvent<HTMLInputElement>) => {
      // Trigger the internal form library's handleBlur for synergy.
      handleBlur(e)

      // Optionally invoke single-field validation from the form library.
      // In practice, the field name may be validated here.
      validateField(name).catch(() => {
        // If there's a validation or parse error, it is typically handled in the form's state.
      })

      // Finally, call the external onBlur prop for consumers of this DatePicker.
      onBlur(e)
    },
    [onBlur, name]
  )

  /**
   * displayValue
   *
   * Derived value for the text input. When a valid date is present in props.value,
   * attempt to format it for user display. If not valid or empty, display nothing.
   */
  const displayValue = value
    ? formatDateForInput(value, dateFormat, locale)
    : ''

  return (
    <div
      className={`date-picker-component ${className ? className : ''}`}
      style={{ display: 'inline-flex', flexDirection: 'column' }}
    >
      {/* 
        Text input field where users can type or edit dates.
        The type remains "text" to allow flexible user input.
        Patterns or specialized date inputs can be used for certain browsers,
        but this approach ensures consistency across UIs and helps with 
        advanced formatting or validation logic. 
      */}
      <input
        id={name}
        name={name}
        aria-label={ariaLabel || name}
        placeholder={placeholder}
        value={displayValue}
        onChange={handleInputChange}
        onBlur={handleInputBlur}
        disabled={disabled}
        type="text"
        className={`date-picker-input ${error ? 'has-error' : ''}`}
        autoComplete="off"
      />

      {/* 
        If there's an externally provided error, we display it here.
        This ensures the component is fully design-system compliant and
        that error states are clearly visible to the user. 
      */}
      {error && (
        <span className="date-picker-error" style={{ color: '#F44336', marginTop: '4px' }}>
          {error}
        </span>
      )}
    </div>
  )
}

/**
 * Exporting the memoized version of our BaseDatePicker for performance
 * optimization in React. This ensures the component only re-renders
 * when its props change, preserving enterprise-level efficiency.
 */
export const DatePicker = memo(BaseDatePicker)

/**
 * We export these members to allow external usage if needed. This
 * fosters reusability, advanced composition, and thorough testing
 * within the application codebase.
 */
export default DatePicker