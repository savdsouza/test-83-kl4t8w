/**
 * Utility functions for validating user input and credentials in the authentication service
 * with enhanced security features and multi-factor authentication support.
 */

import { promises as dnsPromises } from 'dns'; // Node.js built-in DNS module for MX record checks
import validator from 'validator'; // v13.11.0
import { parsePhoneNumberFromString, PhoneNumber } from 'libphonenumber-js'; // v1.10.49

// Import password and MFA configs from authConfig
import { password as passwordConfig, mfa as mfaConfig } from '../config/auth.config';

/**
 * Interface defining the result structure for email validation.
 */
interface EmailValidationResult {
  isValid: boolean;
  error: string | null;
  normalizedEmail: string | null;
}

/**
 * Interface defining the result structure for password validation.
 */
interface PasswordValidationResult {
  isValid: boolean;
  strengthScore: number;
  errors: string[];
}

/**
 * Interface defining the result structure for phone number validation.
 */
interface PhoneNumberValidationResult {
  isValid: boolean;
  formattedNumber: string | null;
  carrier: string | null;
  error: string | null;
}

/**
 * Interface defining possible MFA token validation return details.
 */
interface MfaValidationResult {
  isValid: boolean;
  tokenType: string | null;
  details: string | null;
}

/**
 * A small set of known disposable email domains to reject.
 * In production, a larger or dynamic list can be maintained.
 */
const DISPOSABLE_DOMAINS = [
  '10minutemail.com',
  'temp-mail.org',
  'dispostable.com',
  'mailinator.com',
];

/**
 * Synchronously checks some very common passwords that are easily guessable.
 * In production, use a more comprehensive approach or dictionary list.
 */
const COMMON_PASSWORDS = [
  'password123',
  'qwerty123',
  '123456789',
  'iloveyou',
  'admin1234',
];

/**
 * Validates email format and checks for disposable email providers with
 * enhanced security checks, including optional MX record validation.
 *
 * Steps Implemented:
 * 1) Sanitize input email string.
 * 2) Check if email is not empty or undefined.
 * 3) Validate email format using validator.isEmail with strict mode.
 * 4) Check against an updated list of disposable email providers.
 * 5) Optionally verify that the domain has valid MX records.
 * 6) Normalize email address to lowercase.
 * 7) Return a detailed validation result object.
 *
 * @param email - The email address to validate.
 * @returns Promise resolving to an EmailValidationResult.
 */
export async function validateEmail(email: string): Promise<EmailValidationResult> {
  const result: EmailValidationResult = {
    isValid: false,
    error: null,
    normalizedEmail: null,
  };

  try {
    // 1) Sanitize input email
    const trimmedEmail = (email || '').trim();

    // 2) Check if email is not empty
    if (!trimmedEmail) {
      result.error = 'Email is empty or undefined.';
      return result;
    }

    // 3) Validate email format with strict validation
    if (!validator.isEmail(trimmedEmail, { allow_display_name: false })) {
      result.error = 'Invalid email format.';
      return result;
    }

    // 4) Check if email domain is disposable
    const domain = trimmedEmail.split('@')[1]?.toLowerCase() || '';
    if (DISPOSABLE_DOMAINS.includes(domain)) {
      result.error = 'Disposable email addresses are not allowed.';
      return result;
    }

    // 5) Verify domain has valid MX records (asynchronous check)
    try {
      const mxRecords = await dnsPromises.resolveMx(domain);
      if (!mxRecords || mxRecords.length === 0) {
        result.error = 'No valid MX records found for email domain.';
        return result;
      }
    } catch (mxError) {
      // If DNS check fails or domain not found, we return an error
      result.error = 'Unable to validate MX records for domain.';
      return result;
    }

    // 6) Normalize email
    const normalized = trimmedEmail.toLowerCase();

    // 7) Construct success result
    result.isValid = true;
    result.normalizedEmail = normalized;
    return result;
  } catch (err) {
    result.error = `Unexpected error during email validation: ${(err as Error).message}`;
    return result;
  }
}

/**
 * Enhanced password validation against strict security requirements.
 * Also performs a check against common weak passwords and calculates
 * a naive strength score based on multiple criteria.
 *
 * Steps Implemented:
 * 1) Verify password is not undefined or empty.
 * 2) Check minimum length requirement (12 characters).
 * 3) Verify uppercase letter requirement.
 * 4) Verify lowercase letter requirement.
 * 5) Verify number requirement.
 * 6) Verify special character requirement.
 * 7) Check against a small dictionary of common passwords.
 * 8) Calculate a naive password strength score.
 * 9) (Optional) Verify password history if provided.
 * 10) Return a comprehensive validation result object.
 *
 * @param password - The password string to validate.
 * @param options - Optional object containing previousPasswords (string array).
 * @returns PasswordValidationResult object with detailed feedback.
 */
export function validatePassword(
  password: string,
  options?: { previousPasswords?: string[] }
): PasswordValidationResult {
  const result: PasswordValidationResult = {
    isValid: false,
    strengthScore: 0,
    errors: [],
  };

  // 1) Check for empty or undefined
  const pwd = (password || '').trim();
  if (!pwd) {
    result.errors.push('Password is empty or undefined.');
    return result;
  }

  // 2) Enforce minimum length from config
  if (pwd.length < (passwordConfig.minLength || 12)) {
    result.errors.push(`Password must be at least ${passwordConfig.minLength} characters long.`);
  }

  // 3) Check uppercase requirement
  if (passwordConfig.requireUppercase && !/[A-Z]/.test(pwd)) {
    result.errors.push('Password must contain at least one uppercase letter.');
  }

  // 4) Check lowercase requirement
  if (passwordConfig.requireLowercase && !/[a-z]/.test(pwd)) {
    result.errors.push('Password must contain at least one lowercase letter.');
  }

  // 5) Check number requirement
  if (passwordConfig.requireNumbers && !/[0-9]/.test(pwd)) {
    result.errors.push('Password must contain at least one digit.');
  }

  // 6) Check special character requirement
  if (
    passwordConfig.requireSpecialChars &&
    !/[!@#$%^&*(),.?":{}|<>_\-~]/.test(pwd)
  ) {
    result.errors.push('Password must contain at least one special character.');
  }

  // 7) Check common passwords list
  if (COMMON_PASSWORDS.includes(pwd.toLowerCase())) {
    result.errors.push('Password is too common and easily guessable.');
  }

  // 8) Naive strength score calculation
  // For demonstration, each satisfied requirement adds points.
  let score = 0;
  if (pwd.length >= 12) score += 1;
  if (/[A-Z]/.test(pwd)) score += 1;
  if (/[a-z]/.test(pwd)) score += 1;
  if (/[0-9]/.test(pwd)) score += 1;
  if (/[!@#$%^&*(),.?":{}|<>_\-~]/.test(pwd)) score += 1;
  // Longer passwords gain extra points
  if (pwd.length >= 16) score += 1;

  result.strengthScore = score;

  // 9) Verify password history if provided
  if (
    passwordConfig.preventReuse &&
    options?.previousPasswords &&
    Array.isArray(options.previousPasswords)
  ) {
    const match = options.previousPasswords.some(
      (oldPwd) => oldPwd.trim() === pwd
    );
    if (match) {
      result.errors.push('Password cannot be the same as any recent password.');
    }
  }

  // 10) Final isValid determination
  result.isValid = result.errors.length === 0;
  return result;
}

/**
 * Validates and formats international phone numbers with enhanced region support,
 * leveraging libphonenumber-js for parsing and formatting, while optionally
 * providing carrier information if available.
 *
 * Steps Implemented:
 * 1) Sanitize input phone number.
 * 2) Parse phone number with provided country code.
 * 3) Verify number is valid for the specified region.
 * 4) Check if number is possible and valid.
 * 5) Determine carrier information if available (placeholder).
 * 6) Format number to E.164 format if valid.
 * 7) Return detailed validation result with carrier info.
 *
 * @param phoneNumber - The raw phone number as a string.
 * @param countryCode - ISO country code (e.g., 'US', 'CA').
 * @returns PhoneNumberValidationResult with isValid, formattedNumber, carrier.
 */
export function validatePhoneNumber(
  phoneNumber: string,
  countryCode: string
): PhoneNumberValidationResult {
  const result: PhoneNumberValidationResult = {
    isValid: false,
    formattedNumber: null,
    carrier: null,
    error: null,
  };

  try {
    // 1) Sanitize phone number input
    const sanitizedNumber = (phoneNumber || '').trim();
    if (!sanitizedNumber) {
      result.error = 'Phone number is empty or undefined.';
      return result;
    }

    // 2) Parse phone number with country code
    const parsedPhone: PhoneNumber | undefined = parsePhoneNumberFromString(
      sanitizedNumber,
      countryCode
    );

    // 3) Verify that the number is valid for the region
    if (!parsedPhone) {
      result.error = 'Failed to parse phone number.';
      return result;
    }

    // 4) Check if number is possible and valid
    if (!parsedPhone.isValid() || !parsedPhone.isPossible()) {
      result.error = 'Phone number is not valid or not possible.';
      return result;
    }

    // 5) Determine carrier info if available (placeholder logic)
    // libphonenumber-js does not automatically resolve carrier names,
    // but in a real production scenario, you could integrate a carrier lookup API.
    // For now, we store a placeholder or null.
    const carrierInfo = null;

    // 6) Format to E.164
    const e164 = parsedPhone.format('E.164');

    // 7) Construct success response
    result.isValid = true;
    result.formattedNumber = e164;
    result.carrier = carrierInfo;
    return result;
  } catch (err) {
    result.error = `Unexpected error during phone validation: ${(err as Error).message}`;
    return result;
  }
}

/**
 * Comprehensive MFA token validation with support for multiple authentication methods,
 * including TOTP, SMS, and Email. Leverages configuration from authConfig to enforce
 * code length, expiration, rate limiting, and additional security checks.
 *
 * Steps Implemented:
 * 1) Sanitize input token.
 * 2) Determine MFA method type (TOTP/SMS/Email).
 * 3) Verify token length based on method from mfaConfig.
 * 4) Check token format matches method requirements.
 * 5) Validate token expiration if applicable (placeholder).
 * 6) Check rate limiting constraints (placeholder).
 * 7) Verify token has not been previously used (placeholder).
 * 8) Return detailed validation result with token type and any details.
 *
 * @param token - The MFA token as a string.
 * @param method - A string indicating the MFA method type ('TOTP', 'SMS', or 'Email').
 * @param options - An optional object that could contain properties like expiration time, usage, etc.
 * @returns MfaValidationResult indicating whether the token is valid and additional info.
 */
export function validateMfaToken(
  token: string,
  method: string,
  options?: Record<string, unknown>
): MfaValidationResult {
  const result: MfaValidationResult = {
    isValid: false,
    tokenType: null,
    details: null,
  };

  // 1) Sanitize input token
  const mfaToken = (token || '').trim();
  if (!mfaToken) {
    result.details = 'MFA token is empty or undefined.';
    return result;
  }

  // 2) Identify method and corresponding config
  let expectedLength = 6; // Default fallback
  let methodLabel = method.toUpperCase();

  switch (methodLabel) {
    case 'TOTP':
      expectedLength = mfaConfig.totp.digits || 6;
      break;
    case 'SMS':
      expectedLength = mfaConfig.sms.codeLength || 6;
      break;
    case 'EMAIL':
      expectedLength = mfaConfig.email.codeLength || 6;
      break;
    default:
      result.details = 'Unsupported MFA method.';
      return result;
  }

  result.tokenType = methodLabel;

  // 3) Verify token length
  if (mfaToken.length !== expectedLength) {
    result.details = `Token length should be ${expectedLength} digits for ${methodLabel}.`;
    return result;
  }

  // 4) Check token format (numeric check as a simple approach)
  if (!/^[0-9]+$/.test(mfaToken)) {
    result.details = 'MFA token must be numeric.';
    return result;
  }

  // 5) Placeholder for token expiration validation
  // Typically, you'd check the issue time or a stored expiry from a data store.
  // For demonstration, we assume it's valid unless proven otherwise.

  // 6) Placeholder for rate limiting constraints
  // In production, track attempts per user or device, and enforce the config.

  // 7) Placeholder for checking if token was previously used
  // This typically requires a store of used tokens or session data.

  // 8) If all checks pass, token is valid
  result.isValid = true;
  return result;
}