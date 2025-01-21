/* ------------------------------------------------------------------
 * user.validation.ts
 * Implements comprehensive validation schemas and rules for user-related
 * data including user profiles, walker profiles, and verification data
 * using Zod schema validation with enhanced security measures, input
 * sanitization, and performance optimizations.
 *
 * ------------------------------------------------------------------
 * Required Imports and Versioned Packages
 * ------------------------------------------------------------------
 */

// ^3.22.0 - Schema validation with strict type inference and custom validation rules
import { z } from 'zod';

// Internal type imports (User, role, etc.)
import {
  UserRole,
  VerificationStatus,
  Schedule,
  WalkerProfile as WalkerProfileType,
  UserPreferences as UserPreferencesType,
  NotificationSettings,
  EmailPreferences,
  SMSPreferences,
  PrivacySettings,
} from '../types/user.types';

// Internal validation utility imports
import {
  validateEmail,
  validatePassword,
  validatePhoneNumber,
  sanitizeInput,
} from '../utils/validation.utils';

/* ------------------------------------------------------------------
 * Global Constants (from JSON specification)
 * ------------------------------------------------------------------
 */
export const MIN_PASSWORD_LENGTH = 12;
export const MIN_HOURLY_RATE = 15;
export const MAX_HOURLY_RATE = 100;
export const VALIDATION_CACHE_TTL = 300; // In seconds
export const MAX_VALIDATION_REQUESTS = 100;
export const VALIDATION_TIMEOUT = 5000; // In milliseconds

/* ------------------------------------------------------------------
 * ValidationResult<T>
 * A generic interface describing the outcome of a validation process.
 * success: boolean indicating validation success or failure
 * data: the validated and parsed structure (if any)
 * errors: an array or structure holding error details
 * ------------------------------------------------------------------
 */
interface ValidationResult<T> {
  success: boolean;
  data?: T;
  errors?: string[] | z.ZodError | unknown;
}

/* ------------------------------------------------------------------
 * 1) userProfileSchema
 * Defines a Zod schema describing the shape of a user profile based
 * on essential "User" fields. This schema focuses on structural
 * integrity of data (types, required/optional fields). Advanced
 * phone/email checks are delegated to custom validations.
 * ------------------------------------------------------------------
 */
export const userProfileSchema = z.object({
  // The unique user identifier (can be required or optional depending on usage)
  id: z
    .string()
    .min(1, { message: 'User ID cannot be empty.' })
    .transform((val) => sanitizeInput(val)),

  // The user’s email address (further validated with validateEmail in our function)
  email: z
    .string()
    .min(1, { message: 'Email field cannot be empty.' })
    .transform((val) => sanitizeInput(val)),

  // First name for personalization and identification
  firstName: z
    .string()
    .min(1, { message: 'First name cannot be empty.' })
    .max(100, { message: 'First name cannot exceed 100 characters.' })
    .transform((val) => sanitizeInput(val)),

  // Last name for personalization and identification
  lastName: z
    .string()
    .min(1, { message: 'Last name cannot be empty.' })
    .max(100, { message: 'Last name cannot exceed 100 characters.' })
    .transform((val) => sanitizeInput(val)),

  // Phone number in E.164 format (further validated with validatePhoneNumber in our function)
  phone: z
    .string()
    .min(1, { message: 'Phone field cannot be empty.' })
    .transform((val) => sanitizeInput(val)),

  // Role assigned to the user (OWNER, WALKER, ADMIN)
  role: z.nativeEnum(UserRole, { errorMap: () => ({ message: 'Invalid user role provided.' }) }),

  // Optional link to user’s avatar or profile image
  avatarUrl: z
    .string()
    .max(500, { message: 'Avatar URL length exceeds limit.' })
    .transform((val) => sanitizeInput(val))
    .optional(),

  // Flag indicating if the user has passed verification checks
  isVerified: z.boolean(),

  // Flag indicating if the user account is currently active
  isActive: z.boolean(),

  // Timestamps can be parsed from strings into Date objects
  lastLoginAt: z
    .union([z.date(), z.string().datetime()])
    .transform((val) => (val instanceof Date ? val : new Date(val))),

  createdAt: z
    .union([z.date(), z.string().datetime()])
    .transform((val) => (val instanceof Date ? val : new Date(val))),

  updatedAt: z
    .union([z.date(), z.string().datetime()])
    .transform((val) => (val instanceof Date ? val : new Date(val))),
});

/* ------------------------------------------------------------------
 * 2) walkerProfileSchema
 * Defines a Zod schema for walker-specific profile data, extending
 * some user concepts with walker-related fields such as availability,
 * rating, and background check status.
 * ------------------------------------------------------------------
 */
const scheduleSchema = z.object({
  dayOfWeek: z
    .number()
    .min(0, { message: 'dayOfWeek must be between 0 (Sunday) and 6 (Saturday).' })
    .max(6, { message: 'dayOfWeek must be between 0 (Sunday) and 6 (Saturday).' }),
  startTime: z
    .string()
    .min(1, { message: 'startTime cannot be empty.' })
    .transform((val) => sanitizeInput(val)),
  endTime: z
    .string()
    .min(1, { message: 'endTime cannot be empty.' })
    .transform((val) => sanitizeInput(val)),
  isAvailableAllDay: z.boolean().optional(),
});

export const walkerProfileSchema = z.object({
  userId: z
    .string()
    .min(1, { message: 'Walker must reference a valid userId.' })
    .transform((val) => sanitizeInput(val)),

  // Overall rating, typically aggregated from completed walks
  rating: z.number().min(0).max(5),

  // The total number of walks completed by this walker
  totalWalks: z.number().min(0),

  // A boolean indicating if the walker is currently available to take immediate jobs
  isAvailable: z.boolean(),

  // Hourly rate for walking services, bounded by MIN_HOURLY_RATE and MAX_HOURLY_RATE
  hourlyRate: z
    .number()
    .min(MIN_HOURLY_RATE, { message: `Hourly rate must be at least ${MIN_HOURLY_RATE}.` })
    .max(MAX_HOURLY_RATE, { message: `Hourly rate cannot exceed ${MAX_HOURLY_RATE}.` }),

  // The walker’s service area, could be zip codes or city references
  serviceArea: z
    .array(z.string().transform((val) => sanitizeInput(val)))
    .max(50, { message: 'No more than 50 service area entries allowed.' }),

  // Verification status to ensure background checks etc.
  backgroundCheckStatus: z.nativeEnum(VerificationStatus, {
    errorMap: () => ({ message: 'Invalid background check status provided.' }),
  }),

  // A short biography describing the walker
  bio: z
    .string()
    .max(1000, { message: 'Bio cannot exceed 1000 characters.' })
    .transform((val) => sanitizeInput(val)),

  // Any certifications or special qualifications
  certifications: z
    .array(z.string().transform((val) => sanitizeInput(val)))
    .max(20, { message: 'No more than 20 certifications allowed.' }),

  // Detailed schedule entries describing the walker’s recurring availability
  availability: z.array(scheduleSchema).max(100, { message: 'Excessive availability entries supplied.' }),
});

/* ------------------------------------------------------------------
 * 3) userPreferencesSchema
 * Defines a Zod schema for user preferences, capturing notification
 * settings, language, currency, timezone, and privacy controls. Each
 * sub-object is carefully validated to ensure correct boolean fields
 * and string usage for language/timezone/currency codes.
 * ------------------------------------------------------------------
 */
const notificationSettingsSchema = z.object({
  pushEnabled: z.boolean(),
  pushSound: z.boolean(),
  pushVibration: z.boolean(),
});

const emailPreferencesSchema = z.object({
  marketing: z.boolean(),
  reminders: z.boolean(),
  newsletters: z.boolean(),
});

const smsPreferencesSchema = z.object({
  alerts: z.boolean(),
  reminders: z.boolean(),
});

const privacySettingsSchema = z.object({
  showEmail: z.boolean(),
  showPhone: z.boolean(),
  shareActivityStatus: z.boolean(),
});

export const userPreferencesSchema = z.object({
  notifications: notificationSettingsSchema,
  emailUpdates: emailPreferencesSchema,
  smsAlerts: smsPreferencesSchema,
  language: z
    .string()
    .min(2, { message: 'Language code must have at least 2 characters.' })
    .transform((val) => sanitizeInput(val)),
  timezone: z
    .string()
    .min(1, { message: 'Timezone cannot be empty.' })
    .transform((val) => sanitizeInput(val)),
  currency: z
    .string()
    .min(1, { message: 'Currency code cannot be empty.' })
    .transform((val) => sanitizeInput(val)),
  privacySettings: privacySettingsSchema,
});

/* ------------------------------------------------------------------
 * validateUserProfile
 * Validates user profile data with multiple steps:
 *   1. Sanitize input data for XSS prevention
 *   2. Check rate limiting for validation requests
 *   3. Validate email format with enhanced security
 *   4. Validate international phone number format
 *   5. Validate required fields with strict type checking
 *   6. Validate optional fields with custom rules
 *   7. Apply validation caching if applicable
 *   8. Log validation attempt for security audit
 *   9. Return strongly typed validation result
 * ------------------------------------------------------------------
 */
export async function validateUserProfile(
  userData: unknown
): Promise<ValidationResult<z.infer<typeof userProfileSchema>>> {
  const errors: string[] = [];

  // Step 2) Check rate limiting for validation requests (placeholder)
  //  In an actual implementation, we might consult a counter in memory
  //  or Redis to see if validation attempts exceed MAX_VALIDATION_REQUESTS.

  // Step 5 & 6) Run structural validation with Zod
  const parsed = userProfileSchema.safeParse(userData);
  if (!parsed.success) {
    return {
      success: false,
      errors: parsed.error,
    };
  }

  // Extract data now that basic structural validation has passed
  const validatedProfile = parsed.data;

  // Step 3) Validate email format with enhanced security, DNS check, etc.
  const isEmailValid = await validateEmail(validatedProfile.email);
  if (!isEmailValid) {
    errors.push(`Email validation failed for: ${validatedProfile.email}`);
  }

  // Step 4) Validate phone number format with E.164 standard
  // Country code is not specified here; passing empty string as placeholder
  const isPhoneValid = validatePhoneNumber(validatedProfile.phone, '');
  if (!isPhoneValid) {
    errors.push(`Phone validation failed for: ${validatedProfile.phone}`);
  }

  // Step 7) Apply validation caching if applicable (placeholder)
  //  E.g., store the result in a cache for VALIDATION_CACHE_TTL

  // Step 8) Log validation attempt for security audit (placeholder)
  //  Typically we would record a log entry or an audit record

  // If any advanced checks failed, return them
  if (errors.length > 0) {
    return {
      success: false,
      errors,
    };
  }

  // Step 9) Return strongly typed validation result
  return {
    success: true,
    data: validatedProfile,
  };
}

/* ------------------------------------------------------------------
 * validateWalkerProfile
 * Validates walker-specific profile data with additional security
 * measures:
 *   1. Validate base user profile shape with enhanced rules
 *   2. Validate hourly rate within allowed range
 *   3. Validate service area contents
 *   4. Verify background check credentials
 *   5. Validate insurance or certification documents (placeholder)
 *   6. Apply geo-validation rules if needed (placeholder)
 *   7. Validate availability schedule
 *   8. Return comprehensive validation result
 * ------------------------------------------------------------------
 */
export async function validateWalkerProfile(
  walkerData: unknown
): Promise<ValidationResult<z.infer<typeof walkerProfileSchema>>> {
  const errors: string[] = [];

  // 1) Basic structural validation with Zod
  const parsed = walkerProfileSchema.safeParse(walkerData);
  if (!parsed.success) {
    return {
      success: false,
      errors: parsed.error,
    };
  }

  // Walker data is valid structurally
  const validatedWalker = parsed.data;

  // 2) Validate hourly rate is within configured range
  // (Already enforced by the schema, but we can add custom checks if needed)

  // 3) Validate service area contents
  // (Schema enforces string arrays, but additional checks could be done here)

  // 4) Verify background check credentials
  // (Placeholder - in real usage, we would confirm the provided
  //  backgroundCheckStatus is consistent with records in the DB)

  // 5) Validate insurance or certification documents
  // (Placeholder - we might check each certification in more detail)

  // 6) Apply geo-validation rules if needed
  // (Placeholder - not implemented in the schema, might require external service)

  // 7) Validate availability schedule
  // (Already enforced by scheduleSchema, but further logic could be applied here)

  // Return with any custom error validations
  if (errors.length > 0) {
    return {
      success: false,
      errors,
    };
  }

  // If all checks are good, finalize
  return {
    success: true,
    data: validatedWalker,
  };
}

/* ------------------------------------------------------------------
 * validateUserPreferences
 * Validates user preferences with internationalization support:
 *   1. Validate notification settings with strict boolean checks
 *   2. Validate language code (ISO) and timezone (IANA) usage
 *   3. Validate currency preferences
 *   4. Validate email and SMS subscription toggles
 *   5. Validate privacy settings for data visibility
 *   6. Return localized validation result
 * ------------------------------------------------------------------
 */
export async function validateUserPreferences(
  preferences: unknown
): Promise<ValidationResult<z.infer<typeof userPreferencesSchema>>> {
  const errors: string[] = [];

  // Structural parse with Zod
  const parsed = userPreferencesSchema.safeParse(preferences);
  if (!parsed.success) {
    return {
      success: false,
      errors: parsed.error,
    };
  }

  const validatedPreferences = parsed.data;

  // We could further check that language is within a known set of ISO codes,
  // or that timezone is known, etc. (placeholder)

  // Return final result
  if (errors.length > 0) {
    return {
      success: false,
      errors,
    };
  }

  return {
    success: true,
    data: validatedPreferences,
  };
}