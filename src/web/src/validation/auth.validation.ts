//////////////////////////////////////////////////////////////////////
// auth.validation.ts
//
// Implements comprehensive validation rules and schemas for all
// authentication-related requests. This includes, but is not limited
// to, login, registration, and MFA validation. Each validation
// routine leverages strict input requirements, strong password checks,
// OTP security, and device-specific checks to align with enterprise-
// grade security practices and the application's technical specification.
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
// External Imports
// - Using zod@^3.22.0 for schema creation, parsing, and error handling
//////////////////////////////////////////////////////////////////////
import { z } from 'zod'; // ^3.22.0

//////////////////////////////////////////////////////////////////////
// Internal Imports
// - AUTH_VALIDATION provides constants to enforce advanced email,
//   password, and OTP security requirements.
// - LoginRequest, RegisterRequest define structured input data
//   types for primary auth flows.
//////////////////////////////////////////////////////////////////////
import {
  AUTH_VALIDATION,
} from '../constants/validation.constants';

import {
  LoginRequest,
  RegisterRequest,
  AuthMethod,
  UserRole,
} from '../types/auth.types';

//////////////////////////////////////////////////////////////////////
// 1) LOGIN VALIDATION SCHEMA
//    This schema validates requests that contain an email, password,
//    preferred authentication method, the deviceId from which the
//    request originates, and an optional biometric signature.
//    All checks reference constants in AUTH_VALIDATION to ensure
//    compliance with minimum/maximum lengths, regex patterns, and
//    complexity requirements.
//////////////////////////////////////////////////////////////////////
export const loginSchema = z.object({
  // Email must match global email formatting and length constraints
  email: z
    .string({ required_error: 'Email is required for login.' })
    .min(
      AUTH_VALIDATION.EMAIL_MIN_LENGTH,
      `Email must be at least ${AUTH_VALIDATION.EMAIL_MIN_LENGTH} characters long.`,
    )
    .max(
      AUTH_VALIDATION.EMAIL_MAX_LENGTH,
      `Email must not exceed ${AUTH_VALIDATION.EMAIL_MAX_LENGTH} characters.`,
    )
    .regex(
      new RegExp(AUTH_VALIDATION.EMAIL_PATTERN),
      'Email must follow a valid format (e.g., user@domain.com).',
    ),

  // Password must obey robust security rules (min length 12, complexity, etc.)
  password: z
    .string({ required_error: 'Password is required for login.' })
    .min(
      AUTH_VALIDATION.PASSWORD_MIN_LENGTH,
      `Password must be at least ${AUTH_VALIDATION.PASSWORD_MIN_LENGTH} characters long.`,
    )
    .max(
      AUTH_VALIDATION.PASSWORD_MAX_LENGTH,
      `Password must not exceed ${AUTH_VALIDATION.PASSWORD_MAX_LENGTH} characters.`,
    )
    .regex(
      new RegExp(AUTH_VALIDATION.PASSWORD_PATTERN),
      'Password must include uppercase, lowercase, numeric, and special characters.',
    ),

  // AuthMethod enumerates EMAIL_PASSWORD, GOOGLE, APPLE, FACEBOOK, BIOMETRIC, etc.
  method: z.nativeEnum(AuthMethod, {
    required_error: 'Authentication method is required.',
  }),

  // Device ID used for session tracking, analysis, and potential risk scoring
  deviceId: z
    .string({ required_error: 'Device ID is required for login.' })
    .nonempty('Device ID cannot be an empty string.'),

  // Biometric signature is optional, used mainly in face/fingerprint scenarios
  biometricSignature: z.string().optional(),
});

//////////////////////////////////////////////////////////////////////
// 2) REGISTRATION VALIDATION SCHEMA
//    This schema validates new user registrations, including email,
//    password, confirmPassword, and role. Complex password checks
//    are enforced, and confirmPassword must match. The role field
//    is validated as an enum, ensuring only recognized user roles
//    are permitted.
//////////////////////////////////////////////////////////////////////
export const registerSchema = z
  .object({
    // Similar email checks as login
    email: z
      .string({ required_error: 'Email is required for registration.' })
      .min(
        AUTH_VALIDATION.EMAIL_MIN_LENGTH,
        `Email must be at least ${AUTH_VALIDATION.EMAIL_MIN_LENGTH} characters long.`,
      )
      .max(
        AUTH_VALIDATION.EMAIL_MAX_LENGTH,
        `Email must not exceed ${AUTH_VALIDATION.EMAIL_MAX_LENGTH} characters.`,
      )
      .regex(
        new RegExp(AUTH_VALIDATION.EMAIL_PATTERN),
        'Email must follow a valid format (e.g., user@domain.com).',
      ),

    // Password constraints must remain consistent with the system's robust policy
    password: z
      .string({ required_error: 'Password is required for registration.' })
      .min(
        AUTH_VALIDATION.PASSWORD_MIN_LENGTH,
        `Password must be at least ${AUTH_VALIDATION.PASSWORD_MIN_LENGTH} characters long.`,
      )
      .max(
        AUTH_VALIDATION.PASSWORD_MAX_LENGTH,
        `Password must not exceed ${AUTH_VALIDATION.PASSWORD_MAX_LENGTH} characters.`,
      )
      .regex(
        new RegExp(AUTH_VALIDATION.PASSWORD_PATTERN),
        'Password must include uppercase, lowercase, numeric, and special characters.',
      ),

    // Must match the primary password exactly
    confirmPassword: z.string({
      required_error: 'Confirm Password is required.',
    }),

    // The role must be one of the known user roles: OWNER, WALKER, ADMIN
    role: z.enum([UserRole.OWNER, UserRole.WALKER, UserRole.ADMIN], {
      required_error: 'Role is required for registration.',
    }),
  })
  .refine(
    (data) => data.password === data.confirmPassword,
    {
      path: ['confirmPassword'],
      message: 'Passwords do not match. Please verify and try again.',
    },
  );

//////////////////////////////////////////////////////////////////////
// 3) MFA TOKEN VALIDATION SCHEMA
//    This schema specifically targets OTP-based multi-factor
//    authentication. It checks the OTP length, numeric digits,
//    and prevents trivial/sequential tokens that undermine security.
//////////////////////////////////////////////////////////////////////

/**
 * Checks if a token is composed of repeated identical digits
 * or if it follows a simple ascending/descending sequence.
 * Returns true if the string is insecure (i.e., sequential/repeated).
 */
function isSequentialOrRepeated(token: string): boolean {
  // Check if all digits are the same, e.g. "000000", "111111", etc.
  if (/(.)\1{5,}/.test(token)) {
    return true;
  }

  // Define ascending and descending sequences for quick checks
  const ascending = '0123456789';
  const descending = '9876543210';

  // For 6-digit tokens, check if it appears within ascending or descending
  if (ascending.includes(token) || descending.includes(token)) {
    return true;
  }

  return false;
}

export const mfaTokenSchema = z.object({
  // "token" must match standard OTP length, numeric format, and avoid insecure patterns
  token: z
    .string({ required_error: 'MFA token is required.' })
    .length(
      AUTH_VALIDATION.OTP_LENGTH,
      `MFA token must be exactly ${AUTH_VALIDATION.OTP_LENGTH} digits long.`,
    )
    .regex(/^\d+$/, 'MFA token must contain only numeric characters.')
    .refine(
      (val) => !isSequentialOrRepeated(val),
      'MFA token cannot be composed of sequential or repeated digits.',
    ),
});

//////////////////////////////////////////////////////////////////////
// 4) VALIDATION FUNCTIONS
//    The following functions provide a boolean return indicating
//    overall success of the validation. In a production environment,
//    developers may prefer to throw specific errors or return
//    typed objects for more granular error handling.
//////////////////////////////////////////////////////////////////////

/**
 * Validates the provided login request against the loginSchema.
 * Logs any validation errors and returns a boolean indicating
 * success or failure.
 */
export function validateLoginRequest(data: LoginRequest): boolean {
  const result = loginSchema.safeParse(data);
  if (!result.success) {
    // In production, consider throwing an error or returning detailed
    // diagnostics to the caller for localized i18n messages
    // to be displayed in the client interface.
    // For now, log to console and return false.
    // eslint-disable-next-line no-console
    console.error('Login validation errors:', result.error.issues);
    return false;
  }
  return true;
}

/**
 * Validates the provided registration request data against the
 * registerSchema. In case of invalid entries, logs the corresponding
 * error details. Returns a boolean indicating validity.
 */
export function validateRegistrationRequest(data: RegisterRequest): boolean {
  const result = registerSchema.safeParse(data);
  if (!result.success) {
    // As with login, advanced handling for i18n or error codes
    // could be implemented here.
    // eslint-disable-next-line no-console
    console.error('Registration validation errors:', result.error.issues);
    return false;
  }
  return true;
}

/**
 * Validates an incoming MFA token against strict numeric,
 * length, and pattern checks. Logs issues and returns a
 * boolean illustrating whether the token is valid.
 */
export function validateMfaToken(token: string): boolean {
  const result = mfaTokenSchema.safeParse({ token });
  if (!result.success) {
    // Detailed error handling logic can be placed here.
    // eslint-disable-next-line no-console
    console.error('MFA token validation errors:', result.error.issues);
    return false;
  }
  return true;
}