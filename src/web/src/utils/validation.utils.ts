/* 
  Provides comprehensive validation utilities for data security,
  input sanitization, and schema validation with enhanced security
  features and type safety. Implements functionality to address:
  1) Data Security (7.2 Data Security/7.2.1 Data Classification)
  2) Input Validation (7.3.1 Access Control/Security Protocols)

  This file uses:
  - zod (^3.22.0) for advanced, type-safe schema validation.
  - yup (^1.3.2) for legacy schema validation support.
  - dompurify (^3.0.6) for secure HTML sanitization.
  - A custom ValidationError class from ../types/common.types
    for structured error handling.
*/

/* ------------------------- Third-Party & Internal Imports ------------------------- */
// ^3.22.0 - Type-safe schema validation
import { z } from 'zod'; // ^3.22.0

// ^1.3.2 - Legacy schema validation (object, string, etc.)
import { object as yupObject, string as yupString } from 'yup'; // ^1.3.2

// ^3.0.6 - Secure HTML sanitization for XSS prevention
import DOMPurify from 'dompurify'; // ^3.0.6

// Built-in Node DNS promises for verifying MX records (no explicit version)
import { promises as dnsPromises } from 'node:dns';

// Custom validation error type for structured error handling
import { ValidationError } from '../types/common.types';

/* ------------------------- Global Constants / Regex Patterns ------------------------- */

/**
 * Regex for basic email format validation. Matches typical characters
 * allowed in addresses. For more rigorous checks, see the steps
 * in validateEmail() which also performs maximum length and MX lookups.
 */
export const EMAIL_REGEX = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;

/**
 * Regex for enforcing password complexity. Ensures at least:
 * - One uppercase letter
 * - One lowercase letter
 * - One digit
 * - One special character (@$!%*?&)
 * - Minimum of 12 characters
 */
export const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{12,}$/;

/**
 * Regex for E.164 international phone number format. Ensures a leading '+'
 * followed by up to 15 digits. Further country-specific checks may be
 * applied in validatePhoneNumber().
 */
export const PHONE_REGEX = /^\+[1-9]\d{1,14}$/;

/**
 * Maximum allowed length for sanitized input. Helps to mitigate large
 * payload attacks and ensures reasonable field sizes.
 */
export const MAX_INPUT_LENGTH = 1000;

/**
 * Default options for DOMPurify. Ensures that no HTML tags or attributes
 * are allowed by default, significantly reducing the risk of XSS attacks.
 */
export const SANITIZATION_OPTIONS = {
  ALLOWED_TAGS: [],
  ALLOWED_ATTR: [],
};

/* ------------------------------------------------------------------
   Zod and Yup Schemas for Advanced and Legacy Validation Approaches
   ------------------------------------------------------------------ */

/**
 * Zod schema for validating emails with basic structure checks.
 * Note that maximum length is enforced at 254 to align with
 * common RFC standards. Full domain checks (MX) are done separately.
 */
const zEmailSchema = z
  .string()
  .trim()
  .max(254, { message: 'Email address exceeds maximum allowed length (254).' })
  .regex(EMAIL_REGEX, { message: 'Email does not match required format.' });

/**
 * Zod schema for password complexity. This enforces the presence
 * of uppercase, lowercase, digit, and special character, and a
 * minimum length of 12 characters.
 */
const zPasswordSchema = z
  .string()
  .regex(PASSWORD_REGEX, { message: 'Password does not meet complexity requirements.' });

/**
 * Zod schema for phone numbers using E.164 standard. This checks for a leading '+'
 * followed by up to 15 digits. 
 */
const zPhoneSchema = z
  .string()
  .regex(PHONE_REGEX, { message: 'Phone number is not in E.164 format.' });

/**
 * Legacy Yup schema for emails, offering backward compatibility in case
 * older parts of the codebase or external modules rely on Yup for validation.
 */
const legacyEmailSchema = yupObject({
  email: yupString()
    .trim()
    .required('Email is required.')
    .max(254, 'Email address exceeds maximum allowed length (254).')
    .matches(EMAIL_REGEX, 'Email does not match required format.'),
});

/**
 * Legacy Yup schema for passwords, mirroring the complexity checks above.
 */
const legacyPasswordSchema = yupObject({
  password: yupString().matches(
    PASSWORD_REGEX,
    'Password does not meet complexity requirements.'
  ),
});

/**
 * Legacy Yup schema for phone numbers. 
 */
const legacyPhoneSchema = yupObject({
  phone: yupString().matches(PHONE_REGEX, 'Phone number is not in E.164 format.'),
});

/* ------------------------------------------------------------------
   Helper for Checking MX Record Existence (Asynchronous)
   ------------------------------------------------------------------ */

/**
 * Attempts to resolve MX records for a given domain using Node’s DNS.
 * If no records exist or an error occurs, returns false.
 * 
 * NOTE: This is only applicable in a Node environment. In browser-based
 * scenarios, DNS lookups are not typically available, so it may be skipped.
 */
async function hasValidMxRecord(domain: string): Promise<boolean> {
  try {
    const records = await dnsPromises.resolveMx(domain);
    if (!records || records.length === 0) {
      return false;
    }
    return true;
  } catch {
    // If DNS resolution fails, treat as invalid domain.
    return false;
  }
}

/* ------------------------------------------------------------------
   1) validateEmail - async function returning Promise<boolean>
   ------------------------------------------------------------------ */

/**
 * Validates email format using multiple layers:
 * 1) Sanitizes input to prevent injection.
 * 2) Checks if the email is empty or undefined.
 * 3) Validates against standard regex pattern (EMAIL_REGEX).
 * 4) Enforces length constraints (maximum 254 characters).
 * 5) Optionally verifies the domain has a valid MX record.
 * 6) Returns true if valid, false otherwise.
 *
 * @param email The email string to validate
 * @returns Promise<boolean> Resolves to true if valid; otherwise false
 */
export async function validateEmail(email: string): Promise<boolean> {
  // Step 1: Sanitize input to minimize potential injection
  const sanitized = sanitizeInput(email);

  // Step 2: Check if the email after sanitization is empty
  if (!sanitized) {
    return false;
  }

  // Step 3 & 4: Validate with Zod & Yup for thorough coverage
  const zodCheck = zEmailSchema.safeParse(sanitized);
  let yupCheck: boolean;
  try {
    await legacyEmailSchema.validate({ email: sanitized });
    yupCheck = true;
  } catch {
    yupCheck = false;
  }

  if (!zodCheck.success || !yupCheck) {
    return false;
  }

  // Extract domain from the email for MX lookup
  const atIndex = sanitized.lastIndexOf('@');
  if (atIndex < 0 || atIndex === sanitized.length - 1) {
    return false;
  }
  const domain = sanitized.substring(atIndex + 1);

  // Step 5: Verify domain has valid MX record (async DNS check)
  const validMx = await hasValidMxRecord(domain);
  if (!validMx) {
    return false;
  }

  // Passed all checks
  return true;
}

/* ------------------------------------------------------------------
   2) validatePassword - function returning boolean
   ------------------------------------------------------------------ */

/**
 * Validates password strength and complexity requirements:
 * 1) Checks minimum length (12).
 * 2) Verifies at least one uppercase, one lowercase, one digit, one special char.
 * 3) Checks against a basic common-password list (for demonstration).
 * 4) Ensures no excessive repeating patterns.
 * 5) Returns true if password passes all checks, false otherwise.
 *
 * @param password The raw password string to validate
 * @returns boolean True if password meets criteria; otherwise false
 */
export function validatePassword(password: string): boolean {
  // Step 1: Quick basic check with Zod & Yup
  const zodCheck = zPasswordSchema.safeParse(password);
  let yupCheck = true;
  try {
    legacyPasswordSchema.validateSync({ password });
  } catch {
    yupCheck = false;
  }
  if (!zodCheck.success || !yupCheck) {
    return false;
  }

  // Step 2 & 3: Basic dictionary check
  // (In real scenarios, a larger dictionary or external service might be used)
  const commonPasswords = [
    'password',
    '123456',
    '123456789',
    'qwerty',
    'abc123',
    'Password1!',
  ];
  const lowerCased = password.toLowerCase();
  for (const cp of commonPasswords) {
    if (lowerCased.includes(cp)) {
      return false;
    }
  }

  // Step 4: Check for repeating characters/patterns
  // Simple example: disallow more than 3 repeated characters in a row
  const repeatRegex = /(.)\1{2,}/;
  if (repeatRegex.test(password)) {
    return false;
  }

  // Passed all checks
  return true;
}

/* ------------------------------------------------------------------
   3) validatePhoneNumber - function returning boolean
   ------------------------------------------------------------------ */

/**
 * Validates a phone number using the E.164 format:
 * 1) Removes extraneous formatting (whitespaces, dashes, etc.).
 * 2) Checks if number matches E.164 regex pattern.
 * 3) (Optional) Validates country code (simple check here).
 * 4) Verifies length constraints and potential area codes (minimal).
 * 5) Returns true on valid format, false otherwise.
 *
 * @param phoneNumber The input phone number string (e.g., "+1234567890").
 * @param countryCode The expected country code (e.g., "US") - minimal usage here.
 * @returns boolean True if the phone number is valid according to E.164; false otherwise
 */
export function validatePhoneNumber(phoneNumber: string, countryCode: string): boolean {
  // Step 1: Basic sanitization of formatting - remove spaces/dashes
  const rawNumber = phoneNumber.replace(/[\s-()]/g, '');

  // Step 2: Validate with Zod & Yup
  const zodCheck = zPhoneSchema.safeParse(rawNumber);
  let yupCheck = true;
  try {
    legacyPhoneSchema.validateSync({ phone: rawNumber });
  } catch {
    yupCheck = false;
  }
  if (!zodCheck.success || !yupCheck) {
    return false;
  }

  // Step 3: Minimal country code validation (dummy check for demonstration)
  // In practice, more robust logic or a library could be employed.
  // For example, if countryCode === 'US', you might expect a certain length in rawNumber.
  if (countryCode && countryCode.length < 2) {
    // Arbitrary check to ensure at least 2 chars for country code
    return false;
  }

  // Step 4: Verify length constraints as an additional safeguard.
  // E.164 allows up to 15 digits after the '+'. Already enforced by the E.164 regex,
  // but we can do a second pass if desired. We'll skip advanced area code checks here.
  if (rawNumber.length < 7 || rawNumber.length > 16) {
    return false;
  }

  // Passed phone checks
  return true;
}

/* ------------------------------------------------------------------
   4) sanitizeInput - function returning sanitized string
   ------------------------------------------------------------------ */

/**
 * Sanitizes user input to defend against XSS and injection attacks:
 * 1) Trims whitespace from both ends.
 * 2) Removes disallowed HTML tags/attributes via DOMPurify.
 * 3) Escapes special characters if necessary.
 * 4) Applies additional user-provided sanitization options.
 * 5) Validates input length does not exceed MAX_INPUT_LENGTH.
 * 6) Scans for malicious patterns (simple demonstration).
 * 7) Returns the safely sanitized string.
 *
 * @param input The raw user input to sanitize
 * @param options Optional custom DOMPurify configuration
 * @returns string A sanitized version of the input
 */
export function sanitizeInput(input: string, options?: object): string {
  // Step 1: Trim whitespace 
  let sanitized = input.trim();

  // Step 2: Purify using DOMPurify with default minimal settings
  // combined with any provided options for more fine-grained control.
  sanitized = DOMPurify.sanitize(sanitized, {
    ...SANITIZATION_OPTIONS,
    ...(options || {}),
  });

  // Step 3: (Optional) Additional escaping of special characters—omitted by default
  // because DOMPurify already neutralizes HTML injection. If needed:
  // sanitized = sanitized.replace(/[&<>"'`=\/]/g, (char) => `\\${char}`);

  // Step 4: Enforce maximum length to mitigate large payload attacks
  if (sanitized.length > MAX_INPUT_LENGTH) {
    sanitized = sanitized.substring(0, MAX_INPUT_LENGTH);
  }

  // Step 5: Simple malicious pattern check for demonstration purposes:
  // Example: check for presence of "<script>" substring
  const maliciousPatterns = [/\<script/gi, /\<iframe/gi, /onerror\s*=/gi];
  for (const pattern of maliciousPatterns) {
    if (pattern.test(sanitized)) {
      // If suspicious content is found, we can either remove it or
      // return an empty string. Here, returning an empty string:
      sanitized = '';
      break;
    }
  }

  // Return the fully sanitized string
  return sanitized;
}