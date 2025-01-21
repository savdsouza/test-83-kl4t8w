/* 
  Provides comprehensive validation schemas and functions for dog-related data validation
  using Zod (^3.22.4), ensuring data integrity, type safety, and enhanced security
  for dog profiles and sensitive medical information. This module implements:

  1) dogProfileSchema - A Zod schema enforcing strict constraints on dog profile data.
  2) medicalInfoSchema - A Zod schema enforcing strict constraints on sensitive medical data.
  3) validateDogProfile(dogData) - A function that validates complete dog profile data
     and returns a detailed result containing success status or error information.
  4) validateMedicalInfo(medicalInfo) - A function that validates and sanitizes
     the medical information object, returning success status or error information.

  The validation covers:
   - Basic field constraints (name, breed, birthDate, weight)
   - Maximum lengths (allergies, medications, conditions)
   - Regex checks for vet contact
   - Specialized date validation using validateDate from ../utils/validation.utils
   - Detailed error messages to assist debugging and audit logs

  Global constants referenced in this schema include:
   - DOG_NAME_MIN_LENGTH, DOG_NAME_MAX_LENGTH
   - DOG_WEIGHT_MIN, DOG_WEIGHT_MAX
   - SPECIAL_INSTRUCTIONS_MAX_LENGTH
   - MAX_ALLERGIES, MAX_MEDICATIONS, MAX_CONDITIONS
   - VET_CONTACT_PATTERN

  Logging statements are inserted to track each validation attempt for auditing.
*/

/* -------------------------------------------------------------------------
   1) Imports & Global Constants
   ------------------------------------------------------------------------- */

// Third-party schema validation library (Zod) version ^3.22.4
import { z } from 'zod'; // ^3.22.4

// Internal imports for specialized types and utilities
import { DogSize } from '../types/dog.types';
import { validateDate } from '../utils/validation.utils';

// The following constants are extracted from the global specs:
const DOG_NAME_MIN_LENGTH = 2;
const DOG_NAME_MAX_LENGTH = 50;
const DOG_WEIGHT_MIN = 1;
const DOG_WEIGHT_MAX = 200;
const SPECIAL_INSTRUCTIONS_MAX_LENGTH = 500;
const MAX_ALLERGIES = 20;
const MAX_MEDICATIONS = 15;
const MAX_CONDITIONS = 10;
const VET_CONTACT_PATTERN = '^[+]?[(]?[0-9]{3}[)]?[-\\s.]?[0-9]{3}[-\\s.]?[0-9]{4}$';

/* -------------------------------------------------------------------------
   2) Medical Information Schema (medicalInfoSchema)
   ------------------------------------------------------------------------- 
   This schema enforces strict validation on dog medical data, including:
   - Limited arrays for allergies, medications, and conditions
   - Structured fields for medications and conditions
   - Regex-enforced vet contact details
   - Security context for potential logging or handling
*/

export const medicalInfoSchema = z.object({
  allergies: z
    .array(z.string().max(200, { message: 'Allergy description is too long.' }))
    .max(MAX_ALLERGIES, {
      message: `Cannot exceed ${MAX_ALLERGIES} known allergies.`,
    })
    .optional(),

  medications: z
    .array(
      z.object({
        name: z
          .string()
          .min(1, { message: 'Medication name cannot be empty.' })
          .max(200, { message: 'Medication name is too long.' }),
        dosage: z
          .string()
          .min(1, { message: 'Dosage cannot be empty.' })
          .max(200, { message: 'Dosage description is too long.' }),
        schedule: z
          .string()
          .min(1, { message: 'Medication schedule cannot be empty.' })
          .max(200, { message: 'Medication schedule is too long.' }),
      })
    )
    .max(MAX_MEDICATIONS, {
      message: `Cannot exceed ${MAX_MEDICATIONS} medications.`,
    })
    .optional(),

  conditions: z
    .array(
      z.object({
        name: z
          .string()
          .min(1, { message: 'Condition name cannot be empty.' })
          .max(200, { message: 'Condition name is too long.' }),
        severity: z
          .string()
          .min(1, { message: 'Condition severity cannot be empty.' })
          .max(50, { message: 'Condition severity is too long.' }),
        notes: z.string().max(500, { message: 'Condition notes are too long.' }).optional(),
      })
    )
    .max(MAX_CONDITIONS, {
      message: `Cannot exceed ${MAX_CONDITIONS} recorded conditions.`,
    })
    .optional(),

  vetContact: z
    .string()
    .regex(new RegExp(VET_CONTACT_PATTERN), {
      message: 'Vet contact does not match required phone format.',
    })
    .optional(),
});

/* -------------------------------------------------------------------------
   3) Dog Profile Schema (dogProfileSchema)
   ------------------------------------------------------------------------- 
   This schema enforces strict validation on the overall dog profile, covering:
   - Name, breed structure, and birthDate
   - Weight field with numeric constraints
   - Medical info referencing medicalInfoSchema
   - Array of special instructions, each capped by length
   - Uses validateDate from ../utils/validation.utils for advanced date checks
*/

export const dogProfileSchema = z.object({
  /* Dog's name constrained by min/max length. */
  name: z
    .string()
    .min(DOG_NAME_MIN_LENGTH, {
      message: `Name must be at least ${DOG_NAME_MIN_LENGTH} characters long.`,
    })
    .max(DOG_NAME_MAX_LENGTH, {
      message: `Name cannot exceed ${DOG_NAME_MAX_LENGTH} characters.`,
    }),

  /* Breed object capturing basic breed info. */
  breed: z.object({
    id: z.string().nonempty({ message: 'Breed ID is required.' }),
    name: z.string().nonempty({ message: 'Breed name is required.' }),
    size: z.nativeEnum(DogSize, { errorMap: () => ({ message: 'Invalid dog size specified.' }) }),
    characteristics: z.array(z.string().max(100)).optional(),
    exerciseNeeds: z
      .number()
      .min(1, { message: 'Exercise needs must be at least 1.' })
      .max(10, { message: 'Exercise needs cannot exceed 10.' })
      .optional(),
  }),

  /* Birth date validated with a refined check using validateDate. */
  birthDate: z
    .string()
    .superRefine((val, ctx) => {
      const valid = validateDate(val);
      if (!valid) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Invalid birth date format or out of acceptable range.',
        });
      }
    }),

  /* Medical info using the dedicated medicalInfoSchema. */
  medicalInfo: medicalInfoSchema.optional(),

  /* Current weight with min/max numeric constraints. */
  weight: z
    .number()
    .min(DOG_WEIGHT_MIN, {
      message: `Weight must be at least ${DOG_WEIGHT_MIN}.`,
    })
    .max(DOG_WEIGHT_MAX, {
      message: `Weight cannot exceed ${DOG_WEIGHT_MAX}.`,
    })
    .optional(),

  /* Array of special instructions, each string up to SPECIAL_INSTRUCTIONS_MAX_LENGTH. */
  specialInstructions: z
    .array(
      z
        .string()
        .max(SPECIAL_INSTRUCTIONS_MAX_LENGTH, {
          message: `Instruction cannot exceed ${SPECIAL_INSTRUCTIONS_MAX_LENGTH} characters.`,
        })
    )
    .optional(),
});

/* -------------------------------------------------------------------------
   4) validateDogProfile Function
   ------------------------------------------------------------------------- 
   Steps (per requirements):
    1) Validate required fields (name, breed, birthDate).
    2) Validate medical information if provided.
    3) Validate special instructions if provided.
    4) Log validation attempt for audit.
    5) Return validation result with detailed error messages if any.
*/

import type { ValidationError } from '../types/api.types';

interface ValidationResult {
  success: boolean;
  errors: ValidationError[];
}

export function validateDogProfile(dogData: unknown): ValidationResult {
  // Step 4: Log validation attempt for audit
  console.log('[AUDIT] Validating dog profile data...');

  // Perform schema parsing
  const parseResult = dogProfileSchema.safeParse(dogData);

  // Build result object
  if (parseResult.success) {
    return {
      success: true,
      errors: [],
    };
  }

  // Transform Zod issues into ValidationError structures
  const issues = parseResult.error.issues.map<ValidationError>((issue) => ({
    field: issue.path.join('.'),
    message: issue.message,
    details: { code: issue.code },
  }));

  // Return aggregated errors
  return {
    success: false,
    errors: issues,
  };
}

/* -------------------------------------------------------------------------
   5) validateMedicalInfo Function
   ------------------------------------------------------------------------- 
   Steps (per requirements):
    1) Validate allergies array with size limits.
    2) Validate medications array with dosage info.
    3) Validate conditions array with severity levels.
    4) Validate vet contact format.
    5) Log medical data validation for audit.
    6) Return validation result with security context (detailed errors).
*/

export function validateMedicalInfo(medicalInfo: unknown): ValidationResult {
  // Step 5: Log validation attempt for audit
  console.log('[AUDIT] Validating medical info data...');

  // Perform schema parsing
  const parseResult = medicalInfoSchema.safeParse(medicalInfo);

  // Build result object
  if (parseResult.success) {
    return {
      success: true,
      errors: [],
    };
  }

  // Transform Zod issues into ValidationError structures
  const issues = parseResult.error.issues.map<ValidationError>((issue) => ({
    field: issue.path.join('.'),
    message: issue.message,
    details: { code: issue.code },
  }));

  return {
    success: false,
    errors: issues,
  };
}