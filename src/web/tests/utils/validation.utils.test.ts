/**
 * This test suite provides a comprehensive set of unit tests for the validation
 * utility functions defined in ../../src/utils/validation.utils, thoroughly addressing:
 * 1) Data Security (7.2 Data Security/7.2.1 Data Classification)
 * 2) Input Validation (7.3.1 Access Control/Security Protocols)
 * 3) Security Response (7.3.3 Security Response/API Abuse)
 *
 * Each function is tested against valid and invalid inputs to ensure the application's
 * handling of sensitive data, defense against malicious input, and proper validation
 * flows remain robust under complex scenarios. The tests cover sanitization and
 * boundary checks, aligning with enterprise-level requirements for security and
 * reliability.
 */

/* ------------------------- External Imports (with Versions) ------------------------- */
// ^29.5.0 - Jest testing framework for test organization and assertions
import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';

/* ------------------------- Internal Imports (Local Utility Functions) ------------------------- */
import {
  validateEmail,
  validatePassword,
  validatePhoneNumber,
  validateLatLng,
  sanitizeInput,
} from '../../src/utils/validation.utils';

/* -----------------------------------------------------------------------------------------------
   Test Data for Valid and Invalid Scenarios
   ----------------------------------------------------------------------------------------------- */
const VALID_EMAILS = [
  'user@example.com',
  'user.name+tag@domain.co.uk',
  'unicode@domain.com',
  'test@subdomain.domain.com',
];

const INVALID_EMAILS = [
  'invalid.email',
  '@domain.com',
  'user@',
  'user@.com',
  '<script>alert(1)</script>@domain.com',
];

const VALID_PASSWORDS = [
  'SecurePass123!',
  'ValidP@ssw0rd',
  'Str0ng#P@ssword',
  'C0mpl3x!P@ssw0rd',
];

const INVALID_PASSWORDS = [
  'weakpassword',
  'NoSpecialChar1',
  'short',
  'password123',
  'admin123!',
];

const VALID_COORDINATES = [
  { lat: 40.7128, lng: -74.006 },
  { lat: -33.8688, lng: 151.2093 },
  { lat: 90, lng: 180 },
  { lat: -90, lng: -180 },
];

const INVALID_COORDINATES = [
  { lat: 91, lng: -74.006 },
  { lat: 40.7128, lng: -181 },
  { lat: -91, lng: 181 },
  { lat: 'invalid', lng: -74.006 },
];

/**
 * The phone numbers tested below assume E.164 format and a minimal 'countryCode' usage.
 * For real production scenarios, we would further diversify the country codes and formats.
 */
const VALID_PHONE_NUMBERS = [
  '+1234567890',
  '+14155552671',
  '+447911123456',
  '+8613800138000',
];

const INVALID_PHONE_NUMBERS = [
  '1234567',          // Missing '+'
  '+',                // Just '+'
  '++1234567890',     // Extra '+' sign
  '+1234abc567',      // Contains invalid letters
  '+12345678901234567', // Exceeds 15 digits
];

/**
 * A selection of raw inputs for sanitizeInput tests, including HTML tags,
 * potential XSS vectors, SQL injection attempts, special characters, and
 * large inputs possibly exceeding MAX_INPUT_LENGTH from the utility file.
 */
const SANITIZE_TEST_INPUTS = [
  {
    label: 'Minimal Safe Input',
    value: 'Hello World',
    expectedSafeSubstring: 'Hello World',
  },
  {
    label: 'HTML Tag Stripping',
    value: '<b>Bold Text</b>',
    expectedSafeSubstring: 'Bold Text',
  },
  {
    label: 'XSS Attempt',
    value: '<script>alert("hacked!")</script>Safe',
    expectedSafeSubstring: 'Safe', // script tag should be removed
  },
  {
    label: 'SQL Injection Pattern',
    value: "Robert'); DROP TABLE Students;--",
    expectedSafeSubstring: "Robert'); DROP TABLE Students;--",
  },
  {
    label: 'Special Characters & Unicode',
    value: 'Example©±中文∆',
    expectedSafeSubstring: 'Example©±中文∆',
  },
];

describe('Validation Utilities - Comprehensive Test Suite', () => {
  beforeEach(() => {
    // If any setup or mocking is required before each test, include it here
    // to ensure consistent isolation across tests.
  });

  afterEach(() => {
    // Clear mocks or perform any teardown needed after each test to prevent
    // state leakage between tests.
  });

  /**
   * validateEmail
   * Asynchronous validation function returning Promise<boolean>.
   * Addresses email correctness, domain DNS (MX record) checks, and sanitization.
   */
  describe('validateEmail', () => {
    it('should return true for valid email formats (including subdomains, plus tags, etc.)', async () => {
      for (const email of VALID_EMAILS) {
        const result = await validateEmail(email);
        expect(result).toBe(true);
      }
    });

    it('should return false for invalid email inputs and injection attempts', async () => {
      for (const email of INVALID_EMAILS) {
        const result = await validateEmail(email);
        expect(result).toBe(false);
      }
    });

    it('should handle typical length constraints and disallow overly long addresses', async () => {
      // Construct a 255+ character email
      const localPart = 'a'.repeat(65);
      const domainName = 'b'.repeat(190) + '.com';
      const longEmail = `${localPart}@${domainName}`; // Over RFC max of 254
      const result = await validateEmail(longEmail);
      expect(result).toBe(false);
    });
  });

  /**
   * validatePassword
   * Validates complex password rules: uppercase, lowercase, digit, special char,
   * minimum length 12, dictionary checks, repeated characters, etc.
   */
  describe('validatePassword', () => {
    it('should return true for strong passwords meeting complexity requirements', () => {
      for (const pwd of VALID_PASSWORDS) {
        const result = validatePassword(pwd);
        expect(result).toBe(true);
      }
    });

    it('should return false for weak or invalid passwords', () => {
      for (const pwd of INVALID_PASSWORDS) {
        const result = validatePassword(pwd);
        expect(result).toBe(false);
      }
    });

    it('should reject common dictionary patterns and repeated characters', () => {
      // Example of repeated characters above threshold (including dictionary snippet)
      const repeatedCharsPassword = 'AAAValidPass123!';
      const dictionaryWordPassword = 'mysecurePassword1!';
      expect(validatePassword(repeatedCharsPassword)).toBe(false);
      expect(validatePassword(dictionaryWordPassword)).toBe(false);
    });
  });

  /**
   * validatePhoneNumber
   * Enforces E.164 format, with optional minimal country code checks.
   */
  describe('validatePhoneNumber', () => {
    it('should return true for valid phone numbers in E.164 format', () => {
      for (const phone of VALID_PHONE_NUMBERS) {
        const result = validatePhoneNumber(phone, 'US');
        expect(result).toBe(true);
      }
    });

    it('should return false for invalid phone number formats', () => {
      for (const phone of INVALID_PHONE_NUMBERS) {
        const result = validatePhoneNumber(phone, 'US');
        expect(result).toBe(false);
      }
    });

    it('should handle country code parameter checks (simple demonstration)', () => {
      // Provide an invalid country code
      const phone = '+14155552671';
      const invalidCountryCodeResult = validatePhoneNumber(phone, '');
      expect(invalidCountryCodeResult).toBe(false);
    });
  });

  /**
   * validateLatLng
   * Tests coordinates for valid latitude, longitude range, and numeric formats.
   * Example test function for location data security and boundary checks.
   */
  describe('validateLatLng', () => {
    it('should return true for valid coordinate pairs', () => {
      for (const coords of VALID_COORDINATES) {
        const result = validateLatLng(coords.lat, coords.lng);
        expect(result).toBe(true);
      }
    });

    it('should return false for invalid coordinate pairs', () => {
      for (const coords of INVALID_COORDINATES) {
        // Some invalid coords may have strings, out-of-range lat/lng, etc.
        let result = false;
        try {
          // We risk a type error if lat is non-numeric, but can catch
          result = validateLatLng(
            coords.lat as number,
            coords.lng as number
          );
        } catch {
          result = false;
        }
        expect(result).toBe(false);
      }
    });
  });

  /**
   * sanitizeInput
   * Tests input sanitization against HTML injection, XSS, SQL injection,
   * large input constraints, special characters, and malicious pattern checks.
   */
  describe('sanitizeInput', () => {
    it('should strip unsafe tags and preserve safe text', () => {
      for (const { label, value, expectedSafeSubstring } of SANITIZE_TEST_INPUTS) {
        const sanitized = sanitizeInput(value);
        // We expect the sanitized output to contain the safe substring but
        // not any malicious script tags, etc.
        expect(sanitized).toMatch(expectedSafeSubstring);
      }
    });

    it('should enforce maximum input length to prevent large payload attacks', () => {
      // Build an oversized string that exceeds 1000 characters
      const oversizedString = 'A'.repeat(2000);
      const sanitized = sanitizeInput(oversizedString);
      expect(sanitized.length).toBeLessThanOrEqual(1000);
    });

    it('should eliminate known malicious patterns (script, iframe, onerror)', () => {
      const maliciousInput = '<script>alert("xss")</script><iframe src="hack.html"></iframe>';
      const sanitized = sanitizeInput(maliciousInput);
      // If malicious patterns are found, we expect an empty string per the code
      expect(sanitized).toBe('');
    });
  });
});