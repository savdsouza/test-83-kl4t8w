import React, { useEffect, useCallback, useMemo } from 'react'; // ^18.0.0
import classNames from 'classnames'; // ^2.3.2
import useRateLimit from '@security/rate-limit'; // ^1.2.0

////////////////////////////////////////////////////////////////////////////////
// Internal Imports - Ensuring we respect usage from the provided specification
////////////////////////////////////////////////////////////////////////////////
import { Input } from '../common/Input'; // Secure and accessible form input component
import {
  User,
  UserRole,
  WalkerProfile,
  // The specification mentions SecurityPreferences in the "members_used"
  // but no direct usage is described beyond it being part of the User type.
  // We'll include it for completeness if needed.
  SecurityPreferences
} from '../../types/user.types';
import {
  userProfileSchema,
  walkerProfileSchema,
  validateUserProfile,
  sanitizeInput
} from '../../validation/user.validation';
import {
  useForm
} from '../../hooks/useForm';

////////////////////////////////////////////////////////////////////////////////
// Additional Types from JSON Spec (SecurityLevel, ValidationMode, etc.)
////////////////////////////////////////////////////////////////////////////////

/**
 * Represents different security clearance levels that might guide
 * how strictly the form processes, encrypts, or persists data.
 */
export enum SecurityLevel {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
}

/**
 * Represents various validation approaches, dictating how lenient
 * or strict the form should be when encountering borderline input.
 */
export enum ValidationMode {
  LENIENT = 'LENIENT',
  STRICT = 'STRICT',
}

////////////////////////////////////////////////////////////////////////////////
// UserFormProps Interface
// As defined by JSON specification: includes user, walkerProfile, onSubmit,
// isLoading, maxAttempts, securityLevel, validationMode
////////////////////////////////////////////////////////////////////////////////
export interface UserFormProps {
  /**
   * Represents the existing user data for edit scenarios or null for creation.
   */
  user: User | null;

  /**
   * Represents the existing walker profile data for edit scenarios or null if
   * the user is not a walker.
   */
  walkerProfile: WalkerProfile | null;

  /**
   * Callback invoked when the form is successfully submitted with validated
   * user and optional walker profile data.
   */
  onSubmit: (user: User, walkerProfile?: WalkerProfile) => Promise<void>;

  /**
   * Indicates if the form is in a loading state, disabling certain interactions
   * and showing progress indicators where applicable.
   */
  isLoading: boolean;

  /**
   * Maximum allowed submission attempts within a defined window, used for
   * rate-limiting logic to mitigate brute-force or malicious form submissions.
   */
  maxAttempts: number;

  /**
   * Dictates what level of security constraints or data handling measures
   * are applied throughout the form processing.
   */
  securityLevel: SecurityLevel;

  /**
   * Specifies whether the form should be extremely strict about borderline
   * validation checks or allow a more lenient approach.
   */
  validationMode: ValidationMode;
}

////////////////////////////////////////////////////////////////////////////////
// getInitialValues Function
// Securely prepares and sanitizes initial form values
////////////////////////////////////////////////////////////////////////////////
/**
 * Safely merges user and walker profile data (if available) into a structure
 * suitable for initializing the form. Applies sanitization and security
 * measures based on the provided securityLevel. Validates final data structure
 * before returning.
 */
export function getInitialValues(
  user: User | null,
  walkerProfile: WalkerProfile | null,
  securityLevel: SecurityLevel
): Record<string, any> {
  //////////////////////////////////////////////////////////////////////////////
  // Step 1: Sanitize incoming user data
  // We remove suspicious code, trim spaces, and mitigate injection attempts.
  // If there's no user data, we start with an empty structure to fill out.
  //////////////////////////////////////////////////////////////////////////////
  const sanitizedUser = user
    ? {
        id: sanitizeInput(user.id),
        email: sanitizeInput(user.email),
        role: user.role,
        // Basic demonstration for partial usage of security preferences if needed:
        securityPreferences: user.securityPreferences || {},
        // The rest of user fields can be inserted as needed:
        firstName: sanitizeInput((user as any).firstName || ''),
        lastName: sanitizeInput((user as any).lastName || ''),
        phone: sanitizeInput((user as any).phone || '')
      }
    : {
        id: '',
        email: '',
        role: UserRole.OWNER,
        securityPreferences: {},
        firstName: '',
        lastName: '',
        phone: ''
      };

  //////////////////////////////////////////////////////////////////////////////
  // Step 2: Apply security level filters
  // (A mock demonstration: at higher security levels, we could mask certain fields
  // or re-check more validations.)
  //////////////////////////////////////////////////////////////////////////////
  if (securityLevel === SecurityLevel.HIGH) {
    // For demonstration, we might mask the phone if no explicit permission:
    if (sanitizedUser.phone && sanitizedUser.phone.length > 0) {
      // Example partial obfuscation
      sanitizedUser.phone = sanitizedUser.phone.replace(/\d/g, '*');
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // Step 3: Merge user data with defaults
  // Provide fallback fields or default placeholders if missing.
  //////////////////////////////////////////////////////////////////////////////
  const mergedUserData = {
    ...sanitizedUser,
    // Additional default flag or placeholder data
    isActive: (user && (user as any).isActive) || false,
    isVerified: (user && user.isVerified) || false
  };

  //////////////////////////////////////////////////////////////////////////////
  // Step 4: Add sanitized walker profile data (if any)
  // If the user is a walker, we incorporate relevant fields.
  //////////////////////////////////////////////////////////////////////////////
  let walkerData = {};
  if (walkerProfile) {
    walkerData = {
      userId: sanitizeInput(walkerProfile.userId),
      rating: walkerProfile.rating,
      totalWalks: walkerProfile.totalWalks,
      isAvailable: walkerProfile.isAvailable,
      hourlyRate: walkerProfile.hourlyRate,
      serviceArea: (walkerProfile.serviceArea || []).map((area) => sanitizeInput(area)),
      backgroundCheckStatus: walkerProfile.backgroundCheckStatus,
      bio: sanitizeInput(walkerProfile.bio),
      certifications: (walkerProfile.certifications || []).map((cert) => sanitizeInput(cert))
    };
  }

  //////////////////////////////////////////////////////////////////////////////
  // Step 5: Validate combined data
  // We run a brief structural validation using userProfileSchema or walkerProfileSchema
  // in a try-catch to ensure no fundamental issues exist before returning.
  //////////////////////////////////////////////////////////////////////////////
  try {
    // Common user validation
    const userCheck = userProfileSchema.parse(mergedUserData);
    if (walkerProfile) {
      // If we do have walker data, parse that separately
      walkerProfileSchema.parse(walkerData);
    }
    // If success, we store them back
    mergedUserData.id = userCheck.id;
    // (In a real scenario, we'd store more validated fields if needed.)
  } catch (e) {
    // For demonstration, we do not throw. In production we might raise an error
    // or handle it, but here we simply log.
    // eslint-disable-next-line no-console
    console.error('Error validating initial form values:', e);
  }

  //////////////////////////////////////////////////////////////////////////////
  // Step 6: Return secured form values
  // Final structure combining both user & walker data in a single object.
  //////////////////////////////////////////////////////////////////////////////
  return {
    // All user fields
    ...mergedUserData,
    // All walker fields
    ...walkerData
  };
}

////////////////////////////////////////////////////////////////////////////////
// UserForm Component
// Renders a secure form for creating or editing user profiles with
// comprehensive validation
////////////////////////////////////////////////////////////////////////////////
export const UserForm: React.FC<UserFormProps> = (props) => {
  //////////////////////////////////////////////////////////////////////////////
  // Step 1: Initialize form with sanitized user data
  // We transform incoming props (user, walkerProfile) into a suitable
  // dictionary for use in our form state.
  //////////////////////////////////////////////////////////////////////////////
  const initialSanitizedValues = useMemo(
    () => getInitialValues(props.user, props.walkerProfile, props.securityLevel),
    [props.user, props.walkerProfile, props.securityLevel]
  );

  //////////////////////////////////////////////////////////////////////////////
  // Step 2: Set up enhanced form validation using useForm hook
  // We rely on a flexible schema. For demonstration, we default to userProfileSchema.
  // We'll cross-validate the data on submission for walkerProfile if needed.
  //////////////////////////////////////////////////////////////////////////////
  const {
    values,
    errors,
    handleSubmit,
    setFieldValue
  } = useForm(undefined, initialSanitizedValues, async () => {}, {
    debounceDelay: 300,
    validateOnChange: props.validationMode === ValidationMode.STRICT,
    validateOnBlur: true
  });

  //////////////////////////////////////////////////////////////////////////////
  // Step 3: Configure rate limiting for form submissions
  // We rely on the maxAttempts prop to define how many times within
  // a certain window the user can attempt to submit.
  //////////////////////////////////////////////////////////////////////////////
  const { isRateLimited, attempt, resetRateLimit } = useRateLimit({
    maxAttempts: props.maxAttempts,
    timeframeMs: 60000 // 1-minute window, adjustable as needed
  });

  //////////////////////////////////////////////////////////////////////////////
  // Step 4: Handle conditional rendering of role-specific fields
  // We'll show additional walker-only fields if the "role" is "WALKER."
  //////////////////////////////////////////////////////////////////////////////
  const isWalker = useMemo(() => {
    return values.role === UserRole.WALKER;
  }, [values.role]);

  //////////////////////////////////////////////////////////////////////////////
  // Step 5: Implement real-time input sanitization
  // The "Input" component internally calls sanitizeInput, but we can also sanitize
  // right before we apply setFieldValue. For brevity, we rely on Input for the main.
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // Step 6 & 7: Validate form data with security checks & Process/Encrypt data
  // We'll do deeper checks on submission with validateUserProfile + walkerProfileSchema,
  // and perform a placeholder "encryption" step for sensitive fields.
  //////////////////////////////////////////////////////////////////////////////
  const internalHandleSubmit = useCallback(async (e: React.FormEvent) => {
    e.preventDefault();

    if (isRateLimited) {
      // We can handle a special error flow or simply return
      // eslint-disable-next-line no-console
      console.error('Submit blocked by rate limiting');
      return;
    }

    attempt(); // increment attempt count

    // Basic user-level validation
    const userResult = await validateUserProfile({
      ...values
    });
    if (!userResult.success) {
      // eslint-disable-next-line no-console
      console.error('Security-related user validation errors:', userResult.errors);
      return;
    }

    // If role is walker, validate walker profile data
    if (isWalker) {
      try {
        walkerProfileSchema.parse({
          userId: values.userId,
          rating: values.rating,
          totalWalks: values.totalWalks,
          isAvailable: values.isAvailable,
          hourlyRate: values.hourlyRate,
          serviceArea: values.serviceArea,
          backgroundCheckStatus: values.backgroundCheckStatus,
          bio: values.bio,
          certifications: values.certifications,
          availability: values.availability
        });
      } catch (werr: any) {
        // eslint-disable-next-line no-console
        console.error('Walker validation error:', werr);
        return;
      }
    }

    // "Process and encrypt" any sensitive fields. In production this would be
    // replaced with a robust encryption library or secure API call.
    // For demonstration, we simply do a naive transformation.
    const finalEmail = `enc(${values.email})`;

    // Construct final user object
    const finalUser: User = {
      // Casting or using partial merges for demonstration
      id: values.id,
      email: finalEmail,
      role: values.role,
      securityPreferences: values.securityPreferences || {},
      isVerified: (props.user && props.user.isVerified) || false,
      isActive: (props.user && (props.user as any).isActive) || false,
      lastLoginAt: (props.user && props.user.lastLoginAt) || new Date(),
      createdAt: (props.user && props.user.createdAt) || new Date(),
      updatedAt: new Date()
    } as User;

    // Construct final walker profile if relevant
    let finalWalkerProfile: WalkerProfile | undefined;
    if (isWalker) {
      finalWalkerProfile = {
        userId: finalUser.id,
        rating: values.rating ?? 0,
        totalWalks: values.totalWalks ?? 0,
        isAvailable: values.isAvailable ?? false,
        hourlyRate: values.hourlyRate ?? 15,
        serviceArea: Array.isArray(values.serviceArea) ? values.serviceArea : [],
        backgroundCheckStatus: values.backgroundCheckStatus,
        bio: values.bio ?? '',
        certifications: Array.isArray(values.certifications) ? values.certifications : [],
        availability: Array.isArray(values.availability) ? values.availability : []
      };
    }

    //////////////////////////////////////////////////////////////////////////////
    // Step 8: Submit validated form data
    // Invoke the consumer's onSubmit callback with the final objects
    //////////////////////////////////////////////////////////////////////////////
    try {
      await props.onSubmit(finalUser, finalWalkerProfile);
      resetRateLimit(); // reset attempts on successful submission
    } catch (submissionError) {
      //////////////////////////////////////////////////////////////////////////////
      // Step 9: Handle and log security-related errors
      //////////////////////////////////////////////////////////////////////////////
      // eslint-disable-next-line no-console
      console.error('Error during form submission:', submissionError);
    }
  }, [
    attempt,
    isRateLimited,
    isWalker,
    props,
    resetRateLimit,
    values
  ]);

  //////////////////////////////////////////////////////////////////////////////
  // Step 10: Manage loading and error states
  // We'll disable the form if isLoading or if we hit rate-limits
  //////////////////////////////////////////////////////////////////////////////
  const formDisabled = props.isLoading || isRateLimited;

  //////////////////////////////////////////////////////////////////////////////
  // Step 11: Implement accessibility features
  // We add appropriate aria-labels, roles, etc. in the JSX structure below.
  //////////////////////////////////////////////////////////////////////////////
  return (
    <form
      onSubmit={internalHandleSubmit}
      className={classNames('user-form')}
      aria-label="User Profile Form"
    >
      {/* Basic Section for User Core Fields */}
      <div className="form-section" aria-labelledby="userCoreSection">
        <h2 id="userCoreSection">User Core Information</h2>
        <div className="form-row">
          <Input
            label="User ID"
            name="id"
            value={values.id}
            onChange={(e) => setFieldValue('id', e.target.value)}
            disabled={formDisabled}
            error={errors.id}
            required
          />
        </div>
        <div className="form-row">
          <Input
            label="Email"
            name="email"
            type="email"
            value={values.email}
            onChange={(e) => setFieldValue('email', e.target.value)}
            disabled={formDisabled}
            error={errors.email}
            required
          />
        </div>
        <div className="form-row">
          <Input
            label="Role"
            name="role"
            value={values.role}
            onChange={(e) => setFieldValue('role', e.target.value)}
            disabled={formDisabled}
            error={errors.role}
            required
          />
        </div>
      </div>

      {/* Conditionally Render Walker Fields */}
      {isWalker && (
        <div className="form-section" aria-labelledby="walkerProfileSection">
          <h2 id="walkerProfileSection">Walker Profile</h2>
          <div className="form-row">
            <Input
              label="Hourly Rate"
              name="hourlyRate"
              type="number"
              value={values.hourlyRate || ''}
              onChange={(e) => setFieldValue('hourlyRate', e.target.value)}
              disabled={formDisabled}
              error={errors.hourlyRate}
              required
            />
          </div>
          <div className="form-row">
            <Input
              label="Bio"
              name="bio"
              value={values.bio || ''}
              onChange={(e) => setFieldValue('bio', e.target.value)}
              disabled={formDisabled}
              error={errors.bio}
            />
          </div>
          <div className="form-row">
            <Input
              label="Service Area (comma-separated)"
              name="serviceArea"
              value={
                Array.isArray(values.serviceArea)
                  ? values.serviceArea.join(', ')
                  : ''
              }
              onChange={(e) =>
                setFieldValue(
                  'serviceArea',
                  e.target.value.split(',').map((v: string) => v.trim())
                )
              }
              disabled={formDisabled}
              error={errors.serviceArea}
            />
          </div>
        </div>
      )}

      <div className="form-actions">
        <button
          type="submit"
          disabled={formDisabled}
          className={classNames({
            'security-indicator': props.securityLevel === SecurityLevel.HIGH
          })}
        >
          {props.isLoading ? 'Processing...' : 'Submit'}
        </button>
        {isRateLimited && (
          <span className="error-message" role="alert">
            Submission temporarily blocked. Please wait before retrying.
          </span>
        )}
      </div>

      {/* Additional validation feedback or error listing */}
      {Object.keys(errors).length > 0 && (
        <div className="validation-feedback" role="alert">
          <p>Some fields have errors or require attention:</p>
          <ul>
            {Object.entries(errors).map(([field, message]) => (
              <li key={field}>{`${field}: ${message}`}</li>
            ))}
          </ul>
        </div>
      )}
    </form>
  );
};

////////////////////////////////////////////////////////////////////////////////
// Default Props for UserForm
// Setting typical defaults to ensure robust usage
////////////////////////////////////////////////////////////////////////////////
UserForm.defaultProps = {
  isLoading: false,
  maxAttempts: 5,
  securityLevel: SecurityLevel.HIGH,
  validationMode: ValidationMode.STRICT,
};

////////////////////////////////////////////////////////////////////////////////
// Exporting the UserForm as requested
////////////////////////////////////////////////////////////////////////////////
export default UserForm;