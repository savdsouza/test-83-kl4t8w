import React, {
  useState,
  useRef,
  useCallback,
  FormEvent,
  ChangeEvent,
} from 'react' // ^18.0.0
import { useNavigate } from 'react-router-dom' // ^6.0.0
import ReCAPTCHA from 'react-google-recaptcha' // ^3.1.0

/**
 * Import of AuthService with named methods that handle password reset logic
 * and rate limiting checks. These methods must be implemented within the
 * AuthService class (see src/web/src/services/auth.service.ts).
 */
import {
  AuthService,
  requestPasswordReset,
  checkRateLimit,
} from '../../services/auth.service'

/**
 * Enhanced form hook for real-time validation. We specifically use:
 *  - values       => tracks form values
 *  - errors       => tracks form errors
 *  - handleSubmit => intercepts onSubmit to run validations
 *  - validateField=> manually triggers validation on a single field
 */
import { useForm } from '../../hooks/useForm'

////////////////////////////////////////////////////////////////////////////////
// ForgotPasswordFormData
// -----------------------------------------------------------------------------
// Type definition for the data fields that this Forgot Password form collects.
// It includes an email field and a captchaToken (obtained from ReCAPTCHA).
////////////////////////////////////////////////////////////////////////////////
interface ForgotPasswordFormData {
  email: string
  captchaToken: string
}

////////////////////////////////////////////////////////////////////////////////
// ForgotPassword Component
// -----------------------------------------------------------------------------
// A React Function Component implementing a secure password reset flow
// with rate limiting, audit logging, and enhanced validation. Users
// enter their email and pass a CAPTCHA check before requesting a reset.
////////////////////////////////////////////////////////////////////////////////
const ForgotPassword: React.FC = () => {
  //--------------------------------------------------------------------------
  // Local State Definitions
  //--------------------------------------------------------------------------
  // loading     => Tracks whether a password reset request is in progress
  // error       => Stores any error messages that occur during the submission flow
  // success     => Indicates if the password reset request succeeded
  // rateLimited => Tracks if the user has been flagged as over the rate limit
  // attempts    => Tracks the number of password reset attempts for audit/logging
  //--------------------------------------------------------------------------
  const [loading, setLoading] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<boolean>(false)
  const [rateLimited, setRateLimited] = useState<boolean>(false)
  const [attempts, setAttempts] = useState<number>(0)

  //--------------------------------------------------------------------------
  // Navigation Hook
  //--------------------------------------------------------------------------
  // We use the useNavigate hook from react-router-dom to programmatically
  // navigate the user to the login page upon a successful password reset.
  //--------------------------------------------------------------------------
  const navigate = useNavigate()

  //--------------------------------------------------------------------------
  // ReCAPTCHA Reference
  //--------------------------------------------------------------------------
  // A reference to the ReCAPTCHA component, enabling us to reset or read
  // the captcha token when needed.
  //--------------------------------------------------------------------------
  const recaptchaRef = useRef<ReCAPTCHA>(null)

  //--------------------------------------------------------------------------
  // useForm Hook Integration
  //--------------------------------------------------------------------------
  // For this forgot password flow, we only need an email field (and implicitly
  // a captcha token). We define initialValues accordingly. We also destructure
  // only the subset of methods / state we need from the useForm hook.
  //--------------------------------------------------------------------------
  const {
    values,
    errors,
    handleSubmit: formSubmit,
    validateField,
    setFieldValue,
  } = useForm(
    undefined, // We can rely on a default or a specialized schema if desired
    { email: '', captchaToken: '' },
    async () => {
      // This onSubmit is unused here because we handle submission with handleSubmit below
    },
    {
      validateOnChange: true,
      validateOnBlur: true,
    }
  )

  //--------------------------------------------------------------------------
  // AuthService Instance
  //--------------------------------------------------------------------------
  // An instance of our AuthService class, providing dedicated methods for
  // password reset and rate-limiting checks. In a real environment, you
  // might inject this or use a singleton pattern for the service.
  //--------------------------------------------------------------------------
  const authService = new AuthService(null as any)

  //--------------------------------------------------------------------------
  // handleEmailChange
  //--------------------------------------------------------------------------
  // Implements the 4-step approach described in the specification:
  //  1) Update email value in form state
  //  2) Debounce validation check (automatically done by useForm + useDebounce)
  //  3) Validate email format
  //  4) Update error state if needed
  //--------------------------------------------------------------------------
  const handleEmailChange = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      // 1) Update email value in the form state
      const updatedEmail = e.target.value
      setFieldValue('email', updatedEmail)

      // 2) Debounce happens automatically within useForm, so we rely on that to avoid
      //    immediate heavy validations. Nevertheless, we can force a field-level check:
      validateField('email')

      // 3) If the email fails advanced validation, the useForm will store the error
      //    in the 'errors' object. We can read or handle it if needed:
      //    e.g., if (errors.email) { setError(...) }
    },
    [setFieldValue, validateField]
  )

  //--------------------------------------------------------------------------
  // handleSubmit
  //--------------------------------------------------------------------------
  // We define a specialized submission flow that corresponds to the 8 steps
  // specified in the JSON specification:
  //  1. Prevent default form submission
  //  2. Validate CAPTCHA response
  //  3. Check rate limiting status
  //  4. Validate email format using AUTH_VALIDATION constants (via validateField)
  //  5. Call AuthService.requestPasswordReset with the user's email
  //  6. Show success message with i18n support (placeholder here)
  //  7. Navigate to login page after a delay
  //  8. Handle and log any errors with appropriate user feedback
  //--------------------------------------------------------------------------
  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    // 1) Prevent default form submission behavior
    event.preventDefault()

    try {
      setLoading(true)
      setError(null)
      setRateLimited(false)

      // 2) Validate CAPTCHA response
      const captchaValue = recaptchaRef.current?.getValue() || ''
      if (!captchaValue) {
        setError('Please complete the ReCAPTCHA challenge.')
        setLoading(false)
        return
      }
      setFieldValue('captchaToken', captchaValue)

      // 3) Check rate limiting status
      const limitCheck = await checkRateLimit('password-reset', values.email)
      if (limitCheck.rateLimited) {
        setRateLimited(true)
        setError('Too many attempts. Please try again later.')
        setLoading(false)
        return
      }

      // 4) Validate email format explicitly
      await validateField('email')
      if (errors.email) {
        setLoading(false)
        setError(errors.email)
        return
      }

      // 5) Call AuthService.requestPasswordReset with email
      //    (Simulating the ephemeral request method from the service)
      await requestPasswordReset(values.email, captchaValue)

      // 6) Show success message
      setSuccess(true)

      // 7) Navigate to login page after a short delay
      setTimeout(() => {
        navigate('/login')
      }, 2000)
    } catch (err: any) {
      // 8) Handle and log errors with user-friendly feedback
      setError(
        err?.message || 'An unexpected error occurred. Please try again later.'
      )
    } finally {
      setAttempts((prev) => prev + 1)
      setLoading(false)
      // Optionally reset ReCAPTCHA if another attempt is needed
      recaptchaRef.current?.reset()
    }
  }

  //--------------------------------------------------------------------------
  // JSX Return
  //--------------------------------------------------------------------------
  // Presents a form where the user can enter email, fulfill captcha requirements,
  // and submit a request. Displays loading states, errors, and success messages.
  //--------------------------------------------------------------------------
  return (
    <div style={{ maxWidth: '420px', margin: '0 auto' }}>
      <h1>Forgot Password</h1>
      {/* Conditionally render an error if it exists */}
      {error && (
        <div style={{ color: 'red', marginBottom: '1rem' }}>
          {error}
        </div>
      )}

      {/* Conditionally render a success message */}
      {success && (
        <div style={{ color: 'green', marginBottom: '1rem' }}>
          Password reset request successful! Please check your email.
        </div>
      )}

      {/* Conditionally render a rate-limit message if flagged */}
      {rateLimited && (
        <div style={{ color: 'orange', marginBottom: '1rem' }}>
          You have exceeded the number of password reset attempts. Please try again later.
        </div>
      )}

      {/* The main password reset form */}
      <form onSubmit={handleSubmit}>
        <label htmlFor="email" style={{ display: 'block', marginBottom: '0.5rem' }}>
          Enter your email address:
        </label>
        <input
          id="email"
          name="email"
          type="email"
          value={values.email}
          onChange={handleEmailChange}
          style={{ width: '100%', marginBottom: '1rem' }}
          placeholder="example@domain.com"
        />

        <ReCAPTCHA
          ref={recaptchaRef}
          sitekey="YOUR_RECAPTCHA_SITE_KEY"
          style={{ marginBottom: '1rem' }}
        />

        <button
          type="submit"
          disabled={loading}
          style={{ width: '100%', padding: '0.75rem' }}
        >
          {loading ? 'Requesting...' : 'Request Password Reset'}
        </button>
      </form>

      {/* Logging number of attempts for debugging or auditing */}
      <p style={{ marginTop: '1rem', fontSize: '0.9rem', color: '#666' }}>
        Attempts: {attempts}
      </p>
    </div>
  )
}

export default ForgotPassword