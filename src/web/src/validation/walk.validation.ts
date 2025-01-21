/* -----------------------------------------------------------------------------------
 * walk.validation.ts
 * -----------------------------------------------------------------------------------
 * This file provides comprehensive schema definitions (using Zod ^3.22.0) and
 * specialized validation functions for all walk-related data. It covers:
 *  - Walk creation requirements (validateWalkRequest + walkRequestSchema).
 *  - Walk updates with status transitions, photo uploads, and reviews
 *    (validateWalkUpdate + walkUpdateSchema).
 *  - Real-time location updates with coordinates, timestamps, and security checks
 *    (validateLocationUpdate + locationUpdateSchema).
 *
 * Core Requirements Addressed:
 * 1) Service Execution: Strict validation for GPS data, walk status updates,
 *    real-time location checks, and photo sharing capabilities.
 * 2) Input Validation: Enforces thorough data sanitization and Zod-based schemas,
 *    guarding against malformed inputs, invalid UUIDs, out-of-range values, or
 *    unauthorized status changes.
 * 3) Data Security: Ensures location data, review text, and other potentially
 *    sensitive fields meet stringent validation rules and proper sanitization.
 *
 * All methods throw detailed Zod errors or custom errors for any validation
 * failure, empowering higher-level error-handler middleware to provide
 * structured feedback to the client.
 * -----------------------------------------------------------------------------------
 */

/* ------------------------------ External Imports ------------------------------ */
// ^3.22.0 - Zod schema validation for robust, type-safe checks
import { z } from 'zod'; // ^3.22.0

/* ------------------------------ Internal Imports ------------------------------ */
import { WalkStatus } from '../types/walk.types';
import { validateLatLng, sanitizeInput } from '../utils/validation.utils'; // Enhanced coordinate & input sanitization

/* ------------------------------------------------------------------------------
 * CONSTANTS - Derived from the requirements_addressed & specification
 * ------------------------------------------------------------------------------ */
const MIN_WALK_DURATION = 30;      // Minimum walk duration in minutes
const MAX_WALK_DURATION = 120;     // Maximum walk duration in minutes
const MAX_REVIEW_LENGTH = 1000;    // Maximum length for owner-submitted reviews
const MIN_PRICE = 10;              // Minimum allowable price
const MAX_PRICE = 200;             // Maximum allowable price
const MAX_LOCATION_AGE = 300;      // Maximum allowed age (in seconds) for location timestamps

/* ------------------------------------------------------------------------------
 * Zod Schemas - Comprehensive schemas for walk creation, updates, and location
 * ------------------------------------------------------------------------------ */

/**
 * walkRequestSchema
 * ------------------------------------------------------------------------------
 * Zod schema for validating the core data required to create a new walk.
 * Enforces:
 *  - Valid UUIDs for ownerId, walkerId, and dogId.
 *  - startTime at least 15 minutes in the future.
 *  - duration within [MIN_WALK_DURATION, MAX_WALK_DURATION].
 *  - price within [MIN_PRICE, MAX_PRICE].
 *  - Optional initial location object, if provided, will be checked
 *    separately by the validateWalkRequest function for lat/lng correctness.
 */
export const walkRequestSchema = z.object({
  ownerId: z.string().uuid({
    message: 'ownerId must be a valid UUID string.',
  }),
  walkerId: z.string().uuid({
    message: 'walkerId must be a valid UUID string.',
  }),
  dogId: z.string().uuid({
    message: 'dogId must be a valid UUID string.',
  }),
  startTime: z.coerce.date().refine(
    (date) => date.getTime() >= Date.now() + 15 * 60 * 1000,
    {
      message: 'startTime must be at least 15 minutes in the future.',
    }
  ),
  duration: z
    .number()
    .int()
    .min(MIN_WALK_DURATION, {
      message: `duration must be at least ${MIN_WALK_DURATION} minutes.`,
    })
    .max(MAX_WALK_DURATION, {
      message: `duration cannot exceed ${MAX_WALK_DURATION} minutes.`,
    }),
  price: z
    .number()
    .min(MIN_PRICE, {
      message: `price must be at least ${MIN_PRICE}.`,
    })
    .max(MAX_PRICE, {
      message: `price cannot exceed ${MAX_PRICE}.`,
    }),
  location: z
    .object({
      latitude: z.number({
        required_error: 'latitude is required if location is provided.',
      }),
      longitude: z.number({
        required_error: 'longitude is required if location is provided.',
      }),
    })
    .optional(),
});

/**
 * walkUpdateSchema
 * ------------------------------------------------------------------------------
 * Zod schema for validating partial fields relevant to walk updates. Enforces:
 *  - Required walkId as UUID.
 *  - Optional status as valid WalkStatus.
 *  - Optional rating in [1..5].
 *  - Optional review text up to MAX_REVIEW_LENGTH characters.
 *  - Optional startTime/endTime checks (endTime must be after startTime).
 *  - Optional photos array for photo upload data.
 */
export const walkUpdateSchema = z
  .object({
    walkId: z.string().uuid({
      message: 'walkId must be a valid UUID string.',
    }),
    status: z.nativeEnum(WalkStatus).optional(),
    startTime: z.coerce.date().optional(),
    endTime: z.coerce.date().optional(),
    rating: z
      .number()
      .int()
      .min(1, { message: 'rating must be at least 1 if provided.' })
      .max(5, { message: 'rating cannot exceed 5 if provided.' })
      .optional(),
    review: z
      .string()
      .max(MAX_REVIEW_LENGTH, {
        message: `review cannot exceed ${MAX_REVIEW_LENGTH} characters.`,
      })
      .optional(),
    photos: z
      .array(
        z.object({
          url: z
            .string()
            .url({ message: 'photo url must be a valid URL if provided.' }),
          caption: z
            .string()
            .max(200, {
              message: 'photo caption cannot exceed 200 characters.',
            })
            .optional(),
        })
      )
      .optional(),
    // Additional optional fields for extended updates can be inserted here as needed.
  })
  .superRefine((data, ctx) => {
    // Validate endTime is after startTime if both are provided
    if (data.startTime && data.endTime && data.endTime <= data.startTime) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['endTime'],
        message: 'endTime must be after startTime.',
      });
    }
  });

/**
 * locationUpdateSchema
 * ------------------------------------------------------------------------------
 * Zod schema for validating real-time location updates. Enforces:
 *  - walkId as a valid UUID.
 *  - coordinates with latitude/longitude placeholders (to be refined).
 *  - timestamp within MAX_LOCATION_AGE seconds of the current time.
 *  - Optional numeric accuracy, speed, bearing with sensible ranges.
 */
export const locationUpdateSchema = z
  .object({
    walkId: z.string().uuid({
      message: 'walkId must be a valid UUID string.',
    }),
    coordinates: z.object({
      latitude: z.number({
        required_error: 'coordinates.latitude is required.',
      }),
      longitude: z.number({
        required_error: 'coordinates.longitude is required.',
      }),
    }),
    timestamp: z.coerce.date(),
    accuracy: z.number().min(0).optional(),
    speed: z.number().min(0).optional(),
    bearing: z.number().min(0).max(360).optional(),
  })
  .refine((data) => {
    // Enforce timestamp not older than MAX_LOCATION_AGE seconds
    const nowMs = Date.now();
    const timestampMs = data.timestamp.getTime();
    const age = (nowMs - timestampMs) / 1000; // in seconds
    return age <= MAX_LOCATION_AGE;
  }, {
    message: `timestamp cannot be older than ${MAX_LOCATION_AGE} seconds.`,
    path: ['timestamp'],
  });

/* ------------------------------------------------------------------------------
 * Validation Functions - Provide advanced logic and sanitization steps
 * ------------------------------------------------------------------------------ */

/**
 * validateWalkRequest
 * ------------------------------------------------------------------------------
 * Validates walk creation request data with enhanced security checks:
 * 1) Sanitizes all input fields recursively to guard against XSS or injection.
 * 2) Uses walkRequestSchema to apply type-safe, rule-based validation of fields.
 * 3) Validates optional location coordinates with validateLatLng if present.
 * 4) Throws a detailed validation error on failure or returns validated data.
 *
 * @param walkData - The raw walk creation object from the client request.
 * @returns The strongly-typed, sanitized, and validated walk creation data.
 */
export function validateWalkRequest<T extends Record<string, any>>(walkData: T) {
  /* Step 1: Recursively sanitize all string fields in walkData.
   * We systematically apply `sanitizeInput` to every value that
   * is a string. This defends against injection or script attempts.
   */
  const sanitizedData = recursivelySanitizeFields(walkData);

  /* Step 2: Parse using the walkRequestSchema for structural
   * and rules-based validation. This ensures correct data types,
   * numeric ranges, date validations, and required fields.
   */
  const parsed = walkRequestSchema.parse(sanitizedData);

  /* Step 3: If location is provided, we perform an additional enhanced
   * validation via `validateLatLng`. This function checks numeric
   * ranges for lat/long, ensuring they're within [-90..90] / [-180..180].
   */
  if (parsed.location) {
    const { latitude, longitude } = parsed.location;
    if (!validateLatLng(latitude, longitude)) {
      throw new Error(
        'Invalid location coordinates provided. Coordinates out of allowed range.'
      );
    }
  }

  /* Step 4: Return the validated and sanitized data. If any step above failed,
   * Zod or our custom checks would have thrown an error already.
   */
  return parsed;
}

/**
 * validateWalkUpdate
 * ------------------------------------------------------------------------------
 * Validates walk update data with status transition, rating,
 * review, photo upload, and other checks.
 * 1) Sanitizes all input fields recursively.
 * 2) Uses walkUpdateSchema for partial field validations.
 * 3) Throws error if new data fails structure or rule-based checks.
 *
 * @param updateData - The raw walk update object from the request.
 * @returns The strongly-typed, sanitized, and validated walk update data.
 */
export function validateWalkUpdate<T extends Record<string, any>>(updateData: T) {
  // Sanitize all string fields first
  const sanitizedData = recursivelySanitizeFields(updateData);

  // Parse with the walkUpdateSchema
  const parsed = walkUpdateSchema.parse(sanitizedData);

  // Additional logic could be used here to check advanced
  // status transitions based on prior walk states in the DB, etc.

  return parsed;
}

/**
 * validateLocationUpdate
 * ------------------------------------------------------------------------------
 * Validates walk location update data with enhanced security:
 * 1) Sanitizes all input fields recursively.
 * 2) Uses locationUpdateSchema for structural and rule-based checks.
 * 3) Calls validateLatLng to ensure latitude/longitude are within safe bounds.
 * 4) Enforces timestamp recency, speed/bearing constraints, etc.
 *
 * @param locationData - The incoming location update payload.
 * @returns The strongly-typed, sanitized, and validated location update object.
 */
export function validateLocationUpdate<T extends Record<string, any>>(locationData: T) {
  // Sanitize all possible string fields
  const sanitizedData = recursivelySanitizeFields(locationData);

  // Parse with the locationUpdateSchema
  const parsed = locationUpdateSchema.parse(sanitizedData);

  // Validate coordinates forcibly with the custom utility
  const { latitude, longitude } = parsed.coordinates;
  if (!validateLatLng(latitude, longitude)) {
    throw new Error('Invalid coordinates: latitude/longitude out of allowed range.');
  }

  // Return final, validated data
  return parsed;
}

/* ------------------------------------------------------------------------------
 * Helper: recursivelySanitizeFields
 * ------------------------------------------------------------------------------
 * Iterates over an object or array structure and applies `sanitizeInput` on
 * every string field. Protects deeply nested strings from XSS or injection.
 */
function recursivelySanitizeFields<T>(value: T): T {
  if (typeof value === 'string') {
    // Directly sanitize strings
    return sanitizeInput(value) as unknown as T;
  } else if (Array.isArray(value)) {
    // Recursively sanitize each array element
    return value.map((item) => recursivelySanitizeFields(item)) as unknown as T;
  } else if (value !== null && typeof value === 'object') {
    // Recursively sanitize each property of an object
    const newObj: Record<string, any> = {};
    for (const [k, v] of Object.entries(value)) {
      newObj[k] = recursivelySanitizeFields(v);
    }
    return newObj as T;
  }

  // For non-string values (numbers, booleans, null, etc.), return as-is
  return value;
}