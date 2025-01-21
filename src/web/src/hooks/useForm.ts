import { useState, useEffect, useCallback, useMemo } from 'react' // ^18.0.0
import { z } from 'zod' // ^3.22.0

// Local internal import for debounced performance optimization:
import useDebounce from './useDebounce'
// Local internal import for default form validation schema (loginSchema):
import { loginSchema } from '../validation/auth.validation'

//------------------------------------------------------------------------------
// FormState Interface
//------------------------------------------------------------------------------
//
// Represents the overall state of a form, including the current field values,
// errors, whether each field has been touched, and various status indicators such
// as submission status, dirtiness, and validity.
//
// values      -> An object tracking the current values of all fields in the form.
// errors      -> An object mapping each field name to a string describing its error.
// touched     -> An object tracking whether each field has been interacted with (true) or not (false).
// isValid     -> A boolean indicating if the entire form has no validation errors.
// isDirty     -> A boolean indicating if any field in the form has been touched or modified.
// isSubmitting-> A boolean indicating if a form submission is currently in progress.
// submitCount -> Number of times the form submission has been attempted.
export interface FormState {
  values: Record<string, any>
  errors: Record<string, string>
  touched: Record<string, boolean>
  isValid: boolean
  isDirty: boolean
  isSubmitting: boolean
  submitCount: number
}

//------------------------------------------------------------------------------
// FormHandlers Interface
//------------------------------------------------------------------------------
//
// Encapsulates various handler functions for managing form behavior, such as
// updating field values, tracking blur events, triggering form submissions,
// resetting the form, and validating fields.
//
// handleChange   -> Updates form state as the user types, optionally triggering validation.
// handleBlur     -> Marks a field as touched upon losing focus, optionally triggering validation.
// handleSubmit   -> Orchestrates the form submission process, validating and calling onSubmit.
// resetForm      -> Clears or resets the entire form to its initial state.
// setFieldValue  -> Allows direct programmatic update of a field value.
// setFieldTouched-> Programmatically marks a field as touched or untouched.
// validateField  -> Performs validation against a single field, updating error states accordingly.
export interface FormHandlers {
  handleChange: (e: React.ChangeEvent<HTMLInputElement>) => void
  handleBlur: (e: React.FocusEvent<HTMLInputElement>) => void
  handleSubmit: (e: React.FormEvent<HTMLFormElement>) => Promise<void>
  resetForm: () => void
  setFieldValue: (field: string, value: any) => void
  setFieldTouched: (field: string, touched: boolean) => void
  validateField: (field: string) => Promise<void>
}

//------------------------------------------------------------------------------
// UseFormOptions Interface (Additional Options)
//------------------------------------------------------------------------------
//
// Defines optional configuration for controlling validation behavior and the
// debounce delay used for real-time validation. Extended configuration can
// be added here (e.g., validateOnBlur, validateOnChange) for more granular
// control.
interface UseFormOptions {
  /**
   * The delay in milliseconds before validating input changes.
   * Defaults to 300ms for a reasonable balance of responsiveness
   * and performance.
   */
  debounceDelay?: number

  /**
   * Whether to validate a field when the user types (onChange).
   * Defaults to true for real-time feedback.
   */
  validateOnChange?: boolean

  /**
   * Whether to validate a field when it is blurred (onBlur).
   * Defaults to true.
   */
  validateOnBlur?: boolean
}

//------------------------------------------------------------------------------
// useForm Hook
//------------------------------------------------------------------------------
//
// A custom React hook providing comprehensive form state management with support
// for schema-based validation (zod), real-time error feedback, and debounced
// validation for optimized performance.
//
// Parameters:
//  1) validationSchema:   A z.ZodSchema defining the shape and constraints of the form data.
//  2) initialValues:      An object with default initial field values for the form.
//  3) onSubmit:           A callback function invoked upon successful form submission,
//                         receiving the form values as its argument.
//  4) options:            An optional configuration object controlling debounced
//                         validation timing and validation triggers.
//
// Returns:
//  An object composed of both FormState and FormHandlers, including values, errors,
//  touched, isValid, isDirty, isSubmitting, submitCount, and handler methods for
//  handling changes, blurs, submission, and more.
//
// Detailed Steps:
//  1) Initialize form state with initial values and metadata
//  2) Set up validation schema with Zod (falling back to loginSchema if none provided)
//  3) Initialize errors and touched fields
//  4) Configure debounced validation using useDebounce
//  5) Implement real-time field validation with error tracking
//  6) Track touched fields and dirty state on interaction
//  7) Handle form submission with full validation and error prevention
//  8) Manage form reset and field value updates
//  9) Provide utility for validating a single field
// 10) Return the comprehensive form state and handlers
//
export function useForm(
  validationSchema: z.ZodSchema | undefined,
  initialValues: Record<string, any>,
  onSubmit: (values: Record<string, any>) => Promise<void> | void,
  options?: UseFormOptions
): FormState & FormHandlers {
  // 1) Initialize default options or merge user-provided options
  const {
    debounceDelay = 300,
    validateOnChange = true,
    validateOnBlur = true,
  } = options || {}

  // 2) Determine the active schema, falling back to loginSchema if none provided
  const activeSchema = validationSchema || loginSchema

  // 3) Initialize form state for values, errors, touched fields, etc.
  const [values, setValues] = useState<Record<string, any>>({ ...initialValues })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [touched, setTouched] = useState<Record<string, boolean>>({})
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false)
  const [submitCount, setSubmitCount] = useState<number>(0)

  // useDebounce to control when we trigger auto-validation for improved performance
  const debouncedValues = useDebounce<Record<string, any>>(values, debounceDelay)

  // 4) Validate the entire form, updating the 'errors' object
  //    with field-specific error messages or clearing them if valid.
  const validateForm = useCallback(async () => {
    try {
      // Attempt full parse; if successful, clear all errors
      await activeSchema.parseAsync(values)
      setErrors({})
    } catch (err: any) {
      // If parse fails, iterate over issues to produce a field-to-error map
      if (err.errors && Array.isArray(err.errors)) {
        const newErrors: Record<string, string> = {}
        err.errors.forEach((issue: any) => {
          if (issue.path && issue.path[0]) {
            const fieldName = issue.path[0].toString()
            newErrors[fieldName] = issue.message
          }
        })
        setErrors(newErrors)
      }
    }
  }, [activeSchema, values])

  // 5) Validate a single field by leveraging the entire schema parse but
  //    isolating the resulting error specific to that field.
  const validateField = useCallback(
    async (field: string) => {
      try {
        // Full parse to detect if there's an error specifically for 'field'
        await activeSchema.parseAsync(values)
        // If there's no error for that field, remove any existing message
        setErrors((prev) => {
          const updated = { ...prev }
          delete updated[field]
          return updated
        })
      } catch (err: any) {
        if (err.errors && Array.isArray(err.errors)) {
          let fieldErrorFound = false
          const newErrors = { ...errors }
          // Check each error path
          err.errors.forEach((issue: any) => {
            if (issue.path && issue.path[0] === field) {
              fieldErrorFound = true
              newErrors[field] = issue.message
            }
          })
          // If no error was found for this field, remove any existing error
          if (!fieldErrorFound) {
            delete newErrors[field]
          }
          setErrors(newErrors)
        }
      }
    },
    [activeSchema, errors, values]
  )

  // 6) Automatically validate the entire form when debouncedValues change,
  //    if 'validateOnChange' is enabled. This triggers real-time error feedback.
  useEffect(() => {
    if (validateOnChange) {
      validateForm()
    }
  }, [debouncedValues, validateOnChange, validateForm])

  // 7) Track if the user has touched any fields to determine if the form is dirty
  //    and to control the display of error feedback.
  const isDirty = useMemo(() => {
    return Object.keys(touched).some((field) => touched[field])
  }, [touched])

  // 8) Derive 'isValid' from the presence or absence of errors
  const isValid = useMemo(() => {
    return Object.keys(errors).length === 0
  }, [errors])

  // 9) Handler: handleChange - updates state for a specific field and optionally validates
  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const { name, value } = e.target

      // Update the values state with the new field value
      setValues((prev) => ({
        ...prev,
        [name]: value,
      }))

      // Mark field as touched when a user interacts for the first time
      setTouched((prev) => ({
        ...prev,
        [name]: true,
      }))

      // If validateOnChange is true, we rely on the debounced effect to do the full form validation
      // However, if immediate single-field validation is desired on each keystroke,
      // that logic can be placed here (currently using debounced approach).
    },
    []
  )

  // 10) Handler: handleBlur - marks a field as touched and optionally validates the field
  const handleBlur = useCallback(
    async (e: React.FocusEvent<HTMLInputElement>) => {
      const { name } = e.target
      // Mark field as touched
      setTouched((prev) => ({
        ...prev,
        [name]: true,
      }))
      // If validation is enabled on blur, validate the single field
      if (validateOnBlur) {
        await validateField(name)
      }
    },
    [validateOnBlur, validateField]
  )

  // 11) Handler: handleSubmit - validates the entire form upon submission,
  //     increments submitCount, and only invokes onSubmit if there's no error.
  const handleSubmit = useCallback(
    async (e: React.FormEvent<HTMLFormElement>) => {
      e.preventDefault()
      // Increase the submission count to track repeated attempts
      setSubmitCount((prev) => prev + 1)

      setIsSubmitting(true)
      await validateForm()

      // Re-check for errors after validation
      if (Object.keys(errors).length === 0) {
        await onSubmit(values)
      }
      setIsSubmitting(false)
    },
    [errors, onSubmit, validateForm, values]
  )

  // 12) Utility: resetForm - clears form state back to initial values
  const resetForm = useCallback(() => {
    setValues({ ...initialValues })
    setErrors({})
    setTouched({})
    setIsSubmitting(false)
    setSubmitCount(0)
  }, [initialValues])

  // 13) Utility: setFieldValue - programmatically update a single field
  const setFieldValue = useCallback((field: string, value: any) => {
    setValues((prev) => ({
      ...prev,
      [field]: value,
    }))
  }, [])

  // 14) Utility: setFieldTouched - programmatically mark a single field as touched/untouched
  const setFieldTouched = useCallback((field: string, touchedValue: boolean) => {
    setTouched((prev) => ({
      ...prev,
      [field]: touchedValue,
    }))
  }, [])

  // Return combined FormState & FormHandlers for comprehensive management
  return {
    // FormState
    values,
    errors,
    touched,
    isValid,
    isDirty,
    isSubmitting,
    submitCount,

    // FormHandlers
    handleChange,
    handleBlur,
    handleSubmit,
    resetForm,
    setFieldValue,
    setFieldTouched,
    validateField,
  }
}