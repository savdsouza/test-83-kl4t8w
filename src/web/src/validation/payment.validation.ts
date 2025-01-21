/**
 * Implements comprehensive validation schemas and rules for payment-related
 * operations in the dog walking application using Zod validation library
 * with strict PCI DSS compliance.
 */

// --------------------------------------------------------------------------
// External Imports
// --------------------------------------------------------------------------
// zod version ^3.22.0
import { z } from 'zod';

// --------------------------------------------------------------------------
// Internal Imports
// --------------------------------------------------------------------------
import {
  PaymentMethod,
  CreatePaymentRequest,
  RefundRequest,
  CurrencyCode,
} from '../types/payment.types';

// --------------------------------------------------------------------------
// Global Constants
// --------------------------------------------------------------------------
/**
 * Defines a list of supported currency codes following ISO 4217.
 * These currencies must be validated strictly for PCI DSS compliance.
 */
const SUPPORTED_CURRENCIES = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'] as const;

/**
 * Minimum allowable payment amount in currency units (e.g., 1.00 USD).
 */
const MIN_PAYMENT_AMOUNT = 1;

/**
 * Maximum allowable payment amount in currency units (e.g., 1000.00 USD).
 */
const MAX_PAYMENT_AMOUNT = 1000;

/**
 * A strict regex pattern enforcing UUID v4 format:
 *  - 8 hex chars
 *  - One hyphen
 *  - 4 hex chars
 *  - One hyphen
 *  - 4 hex chars (starting with 4)
 *  - One hyphen
 *  - 4 hex chars (starting with 8-9-a-b)
 *  - One hyphen
 *  - 12 hex chars
 */
const UUID_V4_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Maximum length allowed for textual reasons, for example refund justifications.
 */
const MAX_REASON_LENGTH = 500;

// --------------------------------------------------------------------------
// Validation Utility Functions
// --------------------------------------------------------------------------

/**
 * Validates that a payment amount is within acceptable range (PCI DSS best practices)
 * and follows correct decimal precision (up to 2 decimal places).
 *
 * @param amount - The monetary amount to validate
 * @returns True if the amount is valid, false otherwise
 *
 * Steps:
 * 1. Check if amount is positive.
 * 2. Validate amount is not exceeding the maximum limit.
 * 3. Verify amount has a maximum of 2 decimal places.
 * 4. Return validation result.
 */
export function validatePaymentAmount(amount: number): boolean {
  // Step 1: Check for positivity
  const isPositive = amount > 0;

  // Step 2: Check not exceeding maximum limit
  const withinMaxLimit = amount <= MAX_PAYMENT_AMOUNT;

  // Step 3: Match up to 2 decimal places
  // Force the amount to string and test with a regex for decimal precision
  const decimalPrecisionOk = /^(0|[1-9]\d*)(\.\d{1,2})?$/.test(amount.toString());

  // Combine all checks
  return isPositive && withinMaxLimit && decimalPrecisionOk;
}

/**
 * Validates a currency code to ensure it follows ISO 4217 format
 * and is included in the application's supported currency list.
 *
 * @param currency - The currency code to validate (e.g., 'USD')
 * @returns True if the currency code is valid, false otherwise
 *
 * Steps:
 * 1. Check if currency is uppercase.
 * 2. Validate currency length is exactly three characters.
 * 3. Verify currency is in the list of supported currencies.
 * 4. Return validation result.
 */
export function validateCurrency(currency: string): boolean {
  // Step 1: Enforce uppercase
  const isUpperCase = currency === currency.toUpperCase();

  // Step 2: Check length == 3
  const lengthIsThree = currency.length === 3;

  // Step 3: Ensure currency is supported
  const isSupported = SUPPORTED_CURRENCIES.includes(currency as any);

  // Final decision
  return isUpperCase && lengthIsThree && isSupported;
}

/**
 * Validates that a string is a properly formatted UUID v4.
 *
 * @param id - The string to check for UUID v4 format
 * @returns True if the string is a valid UUID, false otherwise
 *
 * Steps:
 * 1. Check if string matches UUID v4 regex pattern.
 * 2. Validate string length is exactly 36 characters.
 * 3. Verify hyphen positions align with UUID v4 format.
 * 4. Return validation result.
 */
export function validateUUID(id: string): boolean {
  // Step 1 & 2: Regex match and length 36
  const matchesRegex = UUID_V4_REGEX.test(id);
  const hasLength36 = id.length === 36;

  // Step 3: The regex has also verified the hyphen positions, but we reconfirm logically
  // We expect the hyphens at positions 8, 13, 18, 23 for a standard UUID format
  const hyphenPositionsOk =
    id[8] === '-' && id[13] === '-' && id[18] === '-' && id[23] === '-';

  // Combine all checks
  return matchesRegex && hasLength36 && hyphenPositionsOk;
}

/**
 * Validates that a refund amount is valid in comparison to the original payment amount
 * and that it adheres to correct decimal constraints.
 *
 * @param refundAmount - The refund amount requested
 * @param originalAmount - The original total amount of the payment
 * @returns True if the refund amount is valid, false otherwise
 *
 * Steps:
 * 1. Check if refund amount is positive.
 * 2. Validate refund amount does not exceed the original amount.
 * 3. Verify refund amount has a maximum of 2 decimal places.
 * 4. Return validation result.
 */
export function validateRefundAmount(
  refundAmount: number,
  originalAmount: number,
): boolean {
  // Step 1: Must be positive
  const isPositive = refundAmount > 0;

  // Step 2: Must not exceed original
  const withinOriginal = refundAmount <= originalAmount;

  // Step 3: Check decimal format
  const decimalPrecisionOk = /^(0|[1-9]\d*)(\.\d{1,2})?$/.test(
    refundAmount.toString(),
  );

  // Final
  return isPositive && withinOriginal && decimalPrecisionOk;
}

// --------------------------------------------------------------------------
// Zod Schemas for Payment Operations
// --------------------------------------------------------------------------

/**
 * createPaymentSchema
 * A Zod schema for validating payment creation requests with strict rules.
 * This schema ensures that all required fields conform to PCI DSS compliance.
 */
export const createPaymentSchema = z
  .object({
    /**
     * Must be a valid UUID v4 for identifying the targeted walk/booking.
     */
    walkId: z
      .string()
      .regex(
        UUID_V4_REGEX,
        'Invalid walkId format; must be a valid UUID v4 string.',
      )
      .refine((val) => validateUUID(val), {
        message: 'walkId must match UUID v4 standard.',
      }),

    /**
     * The monetary amount to be charged, validated against positive,
     * within-limits, and 2 decimal places constraints.
     */
    amount: z
      .number({ invalid_type_error: 'amount must be a valid number.' })
      .refine((val) => validatePaymentAmount(val), {
        message: `Amount must be > 0, <= ${MAX_PAYMENT_AMOUNT}, and have up to 2 decimals.`,
      }),

    /**
     * The currency code that must follow strict ISO 4217 and be
     * whitelisted in SUPPORTED_CURRENCIES.
     */
    currency: z
      .string()
      .refine(
        (val) => validateCurrency(val),
        'Must be an uppercase, 3-character currency code from the supported list.',
      ),

    /**
     * A valid PaymentMethod enumeration, restricted to recognized
     * payment instruments like CREDIT_CARD or DEBIT_CARD.
     */
    method: z.nativeEnum(PaymentMethod, {
      invalid_type_error: 'Invalid payment method specified.',
    }),

    /**
     * Allows storing payment credentials for future usage,
     * booleans only, defaulting to false if not specified.
     */
    setupFutureUsage: z.boolean().optional().default(false),
  })
  .strict();

/**
 * refundRequestSchema
 * A Zod schema for validating refund requests. Includes fields for
 * payment identification, reason for the refund, and refund amount.
 * Additional validations can be performed to ensure PCI DSS adherence.
 */
export const refundRequestSchema = z
  .object({
    /**
     * Must be a valid UUID v4 identifier representing the payment record
     * that is being refunded.
     */
    paymentId: z
      .string()
      .regex(
        UUID_V4_REGEX,
        'Invalid paymentId format; must be a valid UUID v4 string.',
      )
      .refine((val) => validateUUID(val), {
        message: 'paymentId must match UUID v4 standard.',
      }),

    /**
     * The textual reason for requesting a refund, constrained
     * in length for security and data management.
     */
    reason: z
      .string()
      .min(1, 'A reason is required for the refund.')
      .max(
        MAX_REASON_LENGTH,
        `Refund reason cannot exceed ${MAX_REASON_LENGTH} characters.`,
      ),

    /**
     * Monetary amount to be refunded, subjected to positivity,
     * decimal precision, and potential comparison with original
     * payment amount in higher-level validation.
     */
    refundAmount: z
      .number({ invalid_type_error: 'refundAmount must be a valid number.' })
      .refine((val) => val > 0, 'Refund amount must be greater than 0.')
      .refine((val) => /^(0|[1-9]\d*)(\.\d{1,2})?$/.test(val.toString()), {
        message: 'Refund amount must have at most 2 decimal places.',
      }),
  })
  .strict();