import React, {
  useEffect,
  useCallback,
  useState,
  KeyboardEvent,
  FormEvent,
  FC,
} from 'react'; // ^18.0.0
import debounce from 'lodash/debounce'; // ^4.0.8

/***************************************************************************
 * Internal Imports
 ***************************************************************************/
import useForm from '../../hooks/useForm'; // Custom hook with enhanced validation workflow
import { registerSchema } from '../../validation/auth.validation'; // Registration validation schema
import { Input } from '../common/Input'; // Accessible custom Input component

/***************************************************************************
 * Types & Interfaces
 ***************************************************************************/
import { UserRole, UserData } from '../../types/auth.types'; // For user role and user data definitions
import { ApiError } from '../../types/api.types'; // For capturing and handling registration errors

/**
 * Represents an authentication error object.
 * Aligns with ApiError for advanced error reporting.
 */
export type AuthError = ApiError;

/**
 * Extended interface for the registration form's input values,
 * aligning with all essential fields required for dog walker
 * or owner account creation. Real-time validation ensures
 * compliance with security mandates.
 */
export interface RegisterFormValues {
  /** User's email address with secure format and length checks */
  email: string;
  /** Password with robust complexity, length >= 12, special chars */
  password: string;
  /** Confirmation of the chosen password to avoid typos */
  confirmPassword: string;
  /** Role selection distinguishing dog owners from walkers */
  role: UserRole;
  /** Flag indicating acceptance of terms and conditions */
  termsAccepted: boolean;
}

/**
 * Props for the RegisterForm component, specifying callbacks for
 * successful registration, error handling, and optional analytics.
 */
export interface RegisterFormProps {
  /**
   * Triggered upon successful registration, delivering
   * the newly created user data object.
   */
  onSuccess(userData: UserData): void;
  /**
   * Triggered for any registration failure, providing
   * an AuthError object capturing the specific error details.
   */
  onError(error: AuthError): void;
  /** Toggles analytics instrumentation for logging user actions */
  enableAnalytics: boolean;
}

/***************************************************************************
 * handleRegistration
 ***************************************************************************/
/**
 * Handles the asynchronous registration logic with robust
 * validation, error reporting, and final callback execution.
 * @param values The collected form data from the registration flow
 * @returns A Promise that resolves upon success or throws on error
 */
export async function handleRegistration(
  values: RegisterFormValues
): Promise<void> {
  //--------------------------------------------------------------------------
  // STEP 1: Validate form values with the enhanced schema
  //         (At this point, they are already validated via useForm & schema,
  //         but this step exemplifies final checks or business logic.)
  //--------------------------------------------------------------------------
  // Example: Additional checks could be performed here if needed.

  //--------------------------------------------------------------------------
  // STEP 2: Track submission attempt
  //--------------------------------------------------------------------------
  // (Implement analytics or logging as needed.)
  // e.g. console.log('[Analytics] Attempting registration')

  //--------------------------------------------------------------------------
  // STEP 3: Call an AuthService or API to create the new user account
  //--------------------------------------------------------------------------
  // This simulates an API call. Replace with actual service integration.
  await new Promise((resolve) => setTimeout(resolve, 800));

  //--------------------------------------------------------------------------
  // STEP 4: On success, possibly fetch or set user data. For demonstration,
  //         the user data is mocked as a simple object to be replaced
  //         with the real API response.
  //--------------------------------------------------------------------------
  // Example success path - no error thrown
  // If an error were to happen, you can throw an AuthError to propagate:
  // throw <AuthError>{ code: 'REGISTRATION_FAILED', message: 'Email in use', ... }

  //--------------------------------------------------------------------------
  // STEP 5: Process registration errors if they exist
  //         (Simulated above by the comment – in real usage, catch errors here.)
  //--------------------------------------------------------------------------

  //--------------------------------------------------------------------------
  // STEP 6: Track submission result
  //--------------------------------------------------------------------------
  // e.g. console.log('[Analytics] Registration success')

  //--------------------------------------------------------------------------
  // STEP 7: Trigger appropriate callbacks (handled by caller)
  //--------------------------------------------------------------------------
  // No direct code here; the caller reacquires control upon this promise resolving

  //--------------------------------------------------------------------------
  // STEP 8: Clear sensitive form data or proceed as needed
  //--------------------------------------------------------------------------
  // No direct code here; clearing occurs when the form resets on success
}

/***************************************************************************
 * RegisterForm Component
 ***************************************************************************/
/**
 * A secure and accessible registration form component implementing:
 * - Comprehensive validation for email, password, confirmation
 * - Role selection for owners vs. walkers
 * - Real-time validation feedback per Security & Input Validation specs
 * - Minimum password length of 12 with complexity requirements
 * - Terms acceptance for compliance
 *
 * The component integrates deeply with useForm and the registerSchema
 * to ensure robust data validation. It also provides an interface for
 * optional analytics instrumentation, capturing user behavior or
 * partial form events as needed.
 */
export const RegisterForm: FC<RegisterFormProps> = ({
  onSuccess,
  onError,
  enableAnalytics,
}) => {
  /*************************************************************************
   * STEP 1: Define initial form values
   *************************************************************************/
  const initialValues: RegisterFormValues = {
    email: '',
    password: '',
    confirmPassword: '',
    role: UserRole.OWNER, // Default to OWNER, can switch to WALKER
    termsAccepted: false,
  };

  /*************************************************************************
   * STEP 2: Integrate useForm hook with registerSchema
   *         for real-time field-level validation
   *************************************************************************/
  const {
    values,
    errors,
    touched,
    isValid,
    isDirty,
    handleChange,
    handleBlur,
    handleSubmit,
  } = useForm(
    registerSchema, // Enhanced Zod schema for registration
    initialValues,
    async (currentValues) => {
      try {
        // Attempt registration via dedicated function
        await handleRegistration(currentValues);
        // Notify the parent of success with a mock user object
        const mockedUserData: UserData = {
          id: 'mocked-id-123',
          email: currentValues.email,
          role: currentValues.role,
          firstName: 'New',
          lastName: 'User',
          phone: '',
          isVerified: false,
          mfaEnabled: false,
          verificationStatus: 'UNVERIFIED',
          lastLogin: new Date().toISOString(),
          securityFlags: {
            accountLocked: false,
            passwordResetRequired: false,
            flaggedForReview: false,
          },
        };
        onSuccess(mockedUserData);
      } catch (err: unknown) {
        // If there's a structured AuthError, cast or handle as needed
        const authErr: AuthError = !err
          ? {
              code: 'UNKNOWN_ERROR',
              message: 'An unknown error occurred.',
              details: { correlationId: '' },
              timestamp: Date.now(),
            }
          : (err as AuthError);

        // Pass error back to parent
        onError(authErr);
      }
    },
    {
      // Additional config: turn on real-time validation, etc.
      debounceDelay: 300,
      validateOnChange: true,
      validateOnBlur: true,
    }
  );

  /*************************************************************************
   * STEP 3: Initialize analytics if enabled
   *************************************************************************/
  const debouncedAnalytics = useCallback(
    debounce((fieldName: string, fieldValue: string) => {
      if (enableAnalytics) {
        // E.g. console.log(`[Analytics] Field ${fieldName} changed to: ${fieldValue}`)
      }
    }, 400),
    [enableAnalytics]
  );

  /*************************************************************************
   * STEP 4: Setup keyboard or accessibility handlers for advanced usage
   *         (e.g., detect Enter key for form submission, etc.)
   *************************************************************************/
  const handleKeyDown = (event: KeyboardEvent<HTMLFormElement>) => {
    if (event.key === 'Enter') {
      // Optionally handle Enter for immediate submission
      // Or let handleSubmit handle it if using the default form
    }
  };

  /*************************************************************************
   * STEP 5: Track field-level changes for analytics or partial state
   *************************************************************************/
  const onFieldChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    handleChange(e);
    debouncedAnalytics(e.target.name, e.target.value);
  };

  /*************************************************************************
   * STEP 6: Render the form structure with accessibility and robust features
   *************************************************************************/
  return (
    <form
      onSubmit={(e: FormEvent<HTMLFormElement>) => handleSubmit(e)}
      onKeyDown={handleKeyDown}
      noValidate
      aria-label="Registration Form"
    >
      {/* EMAIL FIELD ********************************************************/}
      <Input
        label="Email"
        name="email"
        type="email"
        value={values.email}
        onChange={onFieldChange}
        onBlur={handleBlur}
        error={touched.email ? errors.email : ''}
        aria-invalid={Boolean(touched.email && errors.email)}
        aria-describedby="email-error"
        autoComplete="email"
        required
      />

      {/* PASSWORD FIELD *****************************************************/}
      <Input
        label="Password"
        name="password"
        type="password"
        value={values.password}
        onChange={onFieldChange}
        onBlur={handleBlur}
        error={touched.password ? errors.password : ''}
        aria-invalid={Boolean(touched.password && errors.password)}
        aria-describedby="password-error"
        autoComplete="new-password"
        required
      />

      {/* CONFIRM PASSWORD FIELD *********************************************/}
      <Input
        label="Confirm Password"
        name="confirmPassword"
        type="password"
        value={values.confirmPassword}
        onChange={onFieldChange}
        onBlur={handleBlur}
        error={touched.confirmPassword ? errors.confirmPassword : ''}
        aria-invalid={Boolean(
          touched.confirmPassword && errors.confirmPassword
        )}
        aria-describedby="confirmPassword-error"
        autoComplete="new-password"
        required
      />

      {/* ROLE SELECTION *****************************************************/}
      <div className="form-group role-selection">
        <label>Account Role</label>
        <div role="radiogroup" aria-labelledby="role-selection-group">
          <label htmlFor="role-owner">
            <input
              id="role-owner"
              type="radio"
              name="role"
              value={UserRole.OWNER}
              checked={values.role === UserRole.OWNER}
              onChange={onFieldChange}
              onBlur={handleBlur}
            />
            Dog Owner
          </label>
          <label htmlFor="role-walker">
            <input
              id="role-walker"
              type="radio"
              name="role"
              value={UserRole.WALKER}
              checked={values.role === UserRole.WALKER}
              onChange={onFieldChange}
              onBlur={handleBlur}
            />
            Dog Walker
          </label>
        </div>
        {touched.role && errors.role && (
          <span id="role-error" className="input-error" role="alert">
            {errors.role}
          </span>
        )}
      </div>

      {/* TERMS ACCEPTANCE ***************************************************/}
      <div className="form-group terms-acceptance">
        <label htmlFor="termsAccepted" className="checkbox-label">
          <input
            id="termsAccepted"
            type="checkbox"
            name="termsAccepted"
            checked={values.termsAccepted}
            onChange={onFieldChange}
            onBlur={handleBlur}
            aria-invalid={Boolean(touched.termsAccepted && errors.termsAccepted)}
            aria-describedby="terms-error"
          />
          I accept the Terms &amp; Conditions
        </label>
        {touched.termsAccepted && errors.termsAccepted && (
          <span id="terms-error" className="input-error" role="alert">
            {errors.termsAccepted}
          </span>
        )}
      </div>

      {/* SUBMISSION BUTTON **************************************************/}
      <button
        type="submit"
        disabled={!isDirty || !isValid}
        className="btn-primary"
        aria-disabled={!isDirty || !isValid}
      >
        Register
      </button>
    </form>
  );
};