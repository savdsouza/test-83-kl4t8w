import React, { useEffect, useState, useCallback } from 'react'; // react@^18.2.0
import { useForm } from 'react-hook-form'; // react-hook-form@^7.0.0
import * as yup from 'yup'; // yup@^1.0.0
import { yupResolver } from '@hookform/resolvers/yup'; // Helper to integrate Yup with React Hook Form
import FingerprintJS from '@fingerprintjs/fingerprintjs'; // @fingerprintjs/fingerprintjs@^3.0.0

// Internal imports
import { useAuth } from '../../hooks/useAuth'; // Enhanced auth hook with MFA, device fingerprinting
import { Button } from '../common/Button'; // Enhanced button component with loading/disabled states
import { Input } from '../common/Input'; // Enhanced input component with validation & accessibility

// Assuming a User type is globally available or imported from a shared auth.types module
// import type { User } from '../../types/auth.types';

/**
 * Enhanced props for the LoginForm component, enabling secure login flow,
 * including multi-factor authentication, device tracking, and robust
 * callbacks for success, error handling, and MFA redirection.
 */
export interface LoginFormProps {
  /**
   * Callback invoked when the login flow completes successfully, passing the
   * authenticated user object and the device ID used to fingerprint this client.
   */
  onSuccess: (user: any, deviceId: string) => void;

  /**
   * Callback invoked when a critical or non-recoverable error occurs during
   * authentication, allowing parent components to display or handle errors.
   */
  onError: (error: string) => void;

  /**
   * Callback invoked specifically when the server indicates MFA is required.
   * The email used for login is provided to help the parent direct or store
   * relevant state for additional verification steps.
   */
  onMfaRequired: (email: string) => void;

  /**
   * Maximum allowed login attempts before the form is locked or an error
   * is thrown to the onError callback, preventing infinite or brute-force attempts.
   */
  maxAttempts: number;
}

/**
 * Enhanced form data structure capturing all fields necessary for advanced
 * security and multi-factor capabilities, including:
 *  - email, password: standard credentials
 *  - mfaToken: multi-factor token input (e.g., TOTP)
 *  - rememberDevice: boolean indicating whether to trust this device or not
 *  - deviceId: fingerprint-identifier for device tracking/analytics
 */
export interface LoginFormData {
  email: string;
  password: string;
  mfaToken: string;
  rememberDevice: boolean;
  deviceId: string;
}

/**
 * An advanced validation schema implemented via Yup, covering:
 *  - email: must be valid email format
 *  - password: required password field
 *  - mfaToken: may be optional, but we allow user to enter one if preempted
 *  - rememberDevice: boolean, no specific constraints
 *  - deviceId: assigned by device fingerprinting logic
 */
const loginSchema = yup.object().shape({
  email: yup.string().email('Invalid email format').required('Email is required'),
  password: yup.string().required('Password is required'),
  mfaToken: yup.string(), // Optional unless specifically required on a second pass
  rememberDevice: yup.boolean(),
  deviceId: yup.string().required(),
});

/**
 * The LoginForm component handles secure login, implementing:
 * 1) Email/password authentication
 * 2) Multifactor (MFA) readiness
 * 3) Device fingerprinting
 * 4) Comprehensive validation
 * 5) Attempt limiting to thwart brute force
 *
 * Steps:
 *  (A) Initialize form with enhanced validation schema.
 *  (B) Setup device fingerprinting via FingerprintJS.
 *  (C) Initialize a rate limiting counter for login attempts.
 *  (D) Use React Hook Form to control the form state and validations.
 *  (E) Manage conditional MFA flow when the server requires it.
 *  (F) Render an accessible UI with loading/error states.
 *  (G) Handle form submission with thorough security checks.
 *  (H) Provide robust error handling and success callbacks.
 */
export const LoginForm: React.FC<LoginFormProps> = ({
  onSuccess,
  onError,
  onMfaRequired,
  maxAttempts,
}) => {
  //////////////////////////////////////////////////////////////////////////////////////
  // (A) Initialize form with enhanced Yup validation, hooking it into React Hook Form
  //////////////////////////////////////////////////////////////////////////////////////
  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
    reset,
  } = useForm<LoginFormData>({
    resolver: yupResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
      mfaToken: '',
      rememberDevice: false,
      deviceId: '',
    },
  });

  //////////////////////////////////////////////////////////////////////////////////////
  // (B) Setup device fingerprinting state and load fingerprint on mount
  //////////////////////////////////////////////////////////////////////////////////////
  const [fingerprint, setFingerprint] = useState('');
  useEffect(() => {
    // Load the FingerprintJS library and retrieve a visitorId
    (async () => {
      try {
        const fp = await FingerprintJS.load();
        const result = await fp.get();
        setFingerprint(result.visitorId);
      } catch (fpError) {
        // If fingerprinting fails, we fallback to an empty string or an alternative
        setFingerprint('');
      }
    })();
  }, []);

  // Whenever fingerprint updates, we set it within the form data
  useEffect(() => {
    if (fingerprint) {
      setValue('deviceId', fingerprint);
    }
  }, [fingerprint, setValue]);

  //////////////////////////////////////////////////////////////////////////////////////
  // (C) Initialize login attempt counter for rate limiting
  //////////////////////////////////////////////////////////////////////////////////////
  const [attempts, setAttempts] = useState(0);

  //////////////////////////////////////////////////////////////////////////////////////
  // (D) Acquire necessary methods/states from our enhanced Auth Hook
  //////////////////////////////////////////////////////////////////////////////////////
  const { login, isLoading, error: authError, requiresMfa } = useAuth();

  //////////////////////////////////////////////////////////////////////////////////////
  // (E) If the server indicates MFA is required, we signal the parent
  //////////////////////////////////////////////////////////////////////////////////////
  useEffect(() => {
    // If the hook flags that MFA is needed, the parent can direct user to another UI flow
    if (requiresMfa) {
      // The user's email is presumably typed in the form data
      // Using getValues might give us the current email: we can pass it to onMfaRequired
      // But we just do the simpler approach: read current form state
      const formValues = (document.querySelector('form') as HTMLFormElement) || null;
      // If we assume the email is stored in local state, let's do a safer approach via handleSubmit
      // Instead, let's catch this in handleSubmit. This effect can remain or handle partial logic.
    }
  }, [requiresMfa]);

  //////////////////////////////////////////////////////////////////////////////////////
  // (F) Enhanced login form rendering with accessibility and loading/error states
  //////////////////////////////////////////////////////////////////////////////////////
  /**
   * handleSubmitForm is the core submission handler function that:
   *  1) Validates form data (React Hook Form + Yup)
   *  2) Checks rate limiting counters (attempts)
   *  3) Captures device fingerprint
   *  4) Sanitizes input data
   *  5) Calls login from useAuth to attempt authentication
   *  6) If MFA is indicated, notifies the parent via onMfaRequired
   *  7) If successful, notifies the parent with onSuccess
   *  8) Handles any errors, incrementing attempts and calling onError as needed
   */
  const onSubmit = useCallback(
    async (formValues: LoginFormData): Promise<void> => {
      // ---------------------------
      // 1) Validate form data => done automatically by react-hook-form + Yup
      // 2) Check rate limiting
      // ---------------------------
      if (attempts >= maxAttempts) {
        onError('You have exceeded the maximum number of login attempts. Please try again later.');
        return;
      }

      // ---------------------------
      // 3) Generate device fingerprint => we already do it in useEffect (fingerprint state).
      //    We ensure deviceId has been set in the form's values.
      // 4) Sanitize input data (Yup + hooking into form or we do minimal trimming)
      // For demonstration, we can do a quick trim on the strings:
      const sanitizedEmail = formValues.email.trim().toLowerCase();
      const sanitizedPassword = formValues.password.trim();
      const sanitizedMfaToken = formValues.mfaToken.trim();
      const deviceId = formValues.deviceId.trim();

      // ---------------------------
      // 5) Attempt authentication
      // ---------------------------
      try {
        const authResult = await login({
          // Our useAuth expects something shaped like { email, password } or an AuthRequest
          email: sanitizedEmail,
          password: sanitizedPassword,
          // We can combine additional fields if the underlying logic supports them
          mfaToken: sanitizedMfaToken,
          deviceId,
          method: 'EMAIL_PASSWORD', // Example; depends on system
        });

        // The hook might set requiresMfa after receiving server response
        // We'll check if the result or the hook states that MFA flow is needed:
        if (authResult.requiresMfa || requiresMfa) {
          onMfaRequired(sanitizedEmail);
          // We won't call onSuccess yet because the user must still complete MFA
          return;
        }

        // If no MFA required, we can proceed with success callback
        onSuccess(authResult.user, deviceId);

        // Reset attempts and form upon success
        setAttempts(0);
        reset();

      } catch (loginError: any) {
        // 6) If there's an error, we capture it, increment attempts, and call parent onError
        setAttempts(prev => prev + 1);

        // Provide the error string to the parent
        const errMsg = loginError?.message || authError || 'An unexpected error occurred.';
        onError(errMsg);
      }
    },
    [attempts, maxAttempts, authError, login, onError, onSuccess, onMfaRequired, requiresMfa, reset]
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // (G) Actual JSX forming the secure login UI, hooking into handleSubmit (React Hook Form)
  //////////////////////////////////////////////////////////////////////////////////////
  return (
    <form
      onSubmit={handleSubmit(onSubmit)}
      aria-label="Secure Login Form"
      style={{ maxWidth: '400px', margin: '0 auto' }}
    >
      {/* Email Field */}
      <div style={{ marginBottom: '1rem' }}>
        <Input
          label="Email Address"
          aria-label="Email"
          type="email"
          error={errors.email?.message}
          disabled={isLoading}
          {...register('email')}
        />
      </div>

      {/* Password Field */}
      <div style={{ marginBottom: '1rem' }}>
        <Input
          label="Password"
          aria-label="Password"
          type="password"
          error={errors.password?.message}
          disabled={isLoading}
          {...register('password')}
        />
      </div>

      {/* Optional MFA Token Field (conditionally displayed or left optional) */}
      {requiresMfa && (
        <div style={{ marginBottom: '1rem' }}>
          <Input
            label="MFA Token"
            aria-label="MFA Token"
            type="text"
            error={errors.mfaToken?.message}
            disabled={isLoading}
            {...register('mfaToken')}
          />
        </div>
      )}

      {/* Remember Device Checkbox */}
      <div style={{ marginBottom: '1rem' }}>
        <label style={{ display: 'inline-flex', alignItems: 'center' }}>
          <input
            type="checkbox"
            style={{ marginRight: '0.5rem' }}
            disabled={isLoading}
            {...register('rememberDevice')}
          />
          Remember this device
        </label>
      </div>

      {/**
       * Hidden input to store the device fingerprint (auto-filled by effect)
       * Ensures the deviceId is included in submission
       */}
      <input type="hidden" {...register('deviceId')} />

      {/* Submit Button */}
      <Button
        variant="primary"
        size="medium"
        loading={isLoading}
        disabled={isLoading}
        fullWidth={true}
        type="submit"
        data-testid="login-submit-button"
      >
        {isLoading ? 'Logging in...' : 'Login'}
      </Button>
    </form>
  );
};