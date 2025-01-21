/**
 * currency.util.ts
 *
 * Comprehensive utility module for secure and accurate currency operations,
 * handling conversions, formatting, and validation with support for multiple
 * currencies and precision-safe calculations. This file implements all required
 * functionalities according to the technical specifications provided.
 */

// -----------------------------------------------------------------------------
// External and Internal Imports
// -----------------------------------------------------------------------------
// NOTE: For external libraries, we add version as a comment. Example:
// import SomePackage from 'some-package'; // some-package ^1.0.0

import { currencyConfig } from '../config/payment.config';

// -----------------------------------------------------------------------------
// Global Constants
// -----------------------------------------------------------------------------

/**
 * CURRENCY_DECIMAL_PLACES
 * 
 * Specifies the number of decimal places for each supported currency, ensuring
 * proper calculations and conversions in both minor and major units. Additional
 * currency entries can be appended as the application expands to more regions.
 */
const CURRENCY_DECIMAL_PLACES: Record<string, number> = {
  USD: 2,
  EUR: 2,
  GBP: 2,
  JPY: 0,
};

/**
 * MAX_SAFE_AMOUNT
 * 
 * Ensures the upper bound for transactions, conversions, and validations to
 * avoid exceeding the safe numeric range. Any computed value above this
 * threshold triggers a RangeError.
 */
const MAX_SAFE_AMOUNT = 999999999999;

/**
 * MIN_SAFE_AMOUNT
 * 
 * Ensures the lower bound for transactions, conversions, and validations to
 * prevent underflow or unsafe negative values. Any computed value below this
 * threshold triggers a RangeError.
 */
const MIN_SAFE_AMOUNT = -999999999999;

// -----------------------------------------------------------------------------
// Local Utility Functions
// -----------------------------------------------------------------------------

/**
 * validateCurrency
 * 
 * Validates the provided currency code with comprehensive checking and
 * verbose error reporting. This function ensures currency codes conform
 * to ISO 4217 format, are supported by the application, and have a known
 * decimal places configuration.
 * 
 * @param currency - The currency code to be validated (e.g., "USD", "eur")
 * @returns boolean - True if currency is supported and valid, otherwise false
 */
export function validateCurrency(currency: string): boolean {
  // ---------------------------------------------------------------------------
  // 1) Check if currency parameter is a string type
  // ---------------------------------------------------------------------------
  if (typeof currency !== 'string') {
    return false;
  }

  // ---------------------------------------------------------------------------
  // 2) Convert currency code to uppercase for consistent validation
  // ---------------------------------------------------------------------------
  const upperCurrency = currency.toUpperCase();

  // ---------------------------------------------------------------------------
  // 3) Validate currency format using an ISO 4217 three-letter regex pattern
  // ---------------------------------------------------------------------------
  const iso4217Pattern = /^[A-Z]{3}$/;
  if (!iso4217Pattern.test(upperCurrency)) {
    return false;
  }

  // ---------------------------------------------------------------------------
  // 4) Check if this currency is in the application's supported list
  // ---------------------------------------------------------------------------
  if (!currencyConfig.supportedCurrencies.includes(upperCurrency)) {
    return false;
  }

  // ---------------------------------------------------------------------------
  // 5) Verify the currency has an associated decimal place configuration
  // ---------------------------------------------------------------------------
  if (typeof CURRENCY_DECIMAL_PLACES[upperCurrency] !== 'number') {
    return false;
  }

  return true;
}

/**
 * convertToMinorUnits
 * 
 * Converts a currency amount from major units (e.g., "10.99" USD) to minor units
 * (e.g., "1099" cents) using a precision-safe calculation method. This function
 * prevents floating point errors and ensures valid currency operations under
 * strict numeric bounds.
 * 
 * @param amount   - Numeric value representing the amount in major currency units
 * @param currency - The three-letter ISO currency code (e.g., "USD")
 * @returns number - The corresponding amount in minor units as a safe integer
 */
export function convertToMinorUnits(amount: number, currency: string): number {
  // ---------------------------------------------------------------------------
  // STEP 1: Validate input types using TypeScript type guards
  // ---------------------------------------------------------------------------
  if (typeof amount !== 'number') {
    throw new TypeError('Invalid amount type: amount must be a number.');
  }
  if (typeof currency !== 'string') {
    throw new TypeError('Invalid currency type: currency must be a string.');
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Check amount is within safe bounds (MIN_SAFE_AMOUNT to MAX_SAFE_AMOUNT)
  // ---------------------------------------------------------------------------
  if (amount < MIN_SAFE_AMOUNT || amount > MAX_SAFE_AMOUNT) {
    throw new RangeError(
      `Amount ${amount} is out of safe range [${MIN_SAFE_AMOUNT}, ${MAX_SAFE_AMOUNT}].`
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Validate currency is supported using validateCurrency
  // ---------------------------------------------------------------------------
  if (!validateCurrency(currency)) {
    throw new Error(`Currency '${currency}' is invalid or unsupported.`);
  }

  // ---------------------------------------------------------------------------
  // STEP 4: Retrieve decimal places for the currency from CURRENCY_DECIMAL_PLACES
  // ---------------------------------------------------------------------------
  const upperCurrency = currency.toUpperCase();
  const decimalPlaces = CURRENCY_DECIMAL_PLACES[upperCurrency];

  // ---------------------------------------------------------------------------
  // STEP 5: Convert amount to string to prevent floating point errors
  //         We use a sufficient decimal precision to handle rounding
  // ---------------------------------------------------------------------------
  const amountStr = amount.toFixed(decimalPlaces + 2);

  // ---------------------------------------------------------------------------
  // STEP 6: Multiply by 10^decimalPlaces using BigInt for precision
  //         We manually parse the string to safely handle decimals
  // ---------------------------------------------------------------------------
  const isNegative = amount < 0;
  const [integerPart, fractionalPart = ''] = amountStr.replace('-', '').split('.');
  let normalizedFraction = fractionalPart.padEnd(decimalPlaces, '0').slice(0, decimalPlaces);
  const combinedStr = integerPart + normalizedFraction;
  let resultBigInt = BigInt(combinedStr);

  // ---------------------------------------------------------------------------
  // STEP 7: Apply sign if negative
  // ---------------------------------------------------------------------------
  if (isNegative) {
    resultBigInt = -resultBigInt;
  }

  // ---------------------------------------------------------------------------
  // STEP 8: Ensure the resulting value is within safe numeric bounds
  // ---------------------------------------------------------------------------
  if (resultBigInt < BigInt(MIN_SAFE_AMOUNT) || resultBigInt > BigInt(MAX_SAFE_AMOUNT)) {
    throw new RangeError(
      `Converted value out of safe range [${MIN_SAFE_AMOUNT}, ${MAX_SAFE_AMOUNT}].`
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 9: Return the converted amount as a standard number (safe within bounds)
  // ---------------------------------------------------------------------------
  return Number(resultBigInt);
}

/**
 * convertToMajorUnits
 * 
 * Converts a currency amount from minor units (e.g., "1099" cents) to major units
 * (e.g., "10.99" USD). Precision handling ensures the result is always correctly
 * rounded to the configured decimal places for the target currency.
 * 
 * @param amount   - Integer value representing the amount in minor currency units
 * @param currency - The three-letter ISO currency code (e.g., "USD")
 * @returns number - The corresponding amount in major units as a floating-point number
 */
export function convertToMajorUnits(amount: number, currency: string): number {
  // ---------------------------------------------------------------------------
  // STEP 1: Validate input types using TypeScript type guards
  // ---------------------------------------------------------------------------
  if (typeof amount !== 'number') {
    throw new TypeError('Invalid amount type: amount must be a number.');
  }
  if (typeof currency !== 'string') {
    throw new TypeError('Invalid currency type: currency must be a string.');
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Check amount is within safe bounds
  // ---------------------------------------------------------------------------
  if (amount < MIN_SAFE_AMOUNT || amount > MAX_SAFE_AMOUNT) {
    throw new RangeError(
      `Amount ${amount} is out of safe range [${MIN_SAFE_AMOUNT}, ${MAX_SAFE_AMOUNT}].`
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Validate currency is supported using validateCurrency
  // ---------------------------------------------------------------------------
  if (!validateCurrency(currency)) {
    throw new Error(`Currency '${currency}' is invalid or unsupported.`);
  }

  // ---------------------------------------------------------------------------
  // STEP 4: Retrieve decimal places for the currency from CURRENCY_DECIMAL_PLACES
  // ---------------------------------------------------------------------------
  const upperCurrency = currency.toUpperCase();
  const decimalPlaces = CURRENCY_DECIMAL_PLACES[upperCurrency];

  // ---------------------------------------------------------------------------
  // STEP 5: Convert amount to a BigInt to avoid floating point errors
  // ---------------------------------------------------------------------------
  const isNegative = amount < 0;
  let amountBigInt = BigInt(Math.abs(amount));

  // ---------------------------------------------------------------------------
  // STEP 6: Divide the BigInt value by 10^decimalPlaces to shift the decimal point
  // ---------------------------------------------------------------------------
  const divisor = BigInt(Math.pow(10, decimalPlaces));
  const majorUnitsBigInt = amountBigInt / divisor;
  const remainderBigInt = amountBigInt % divisor;

  // ---------------------------------------------------------------------------
  // STEP 7: Generate a floating-point number with the remainder as decimal portion
  // ---------------------------------------------------------------------------
  const integerPart = majorUnitsBigInt.toString();
  let fractionalPart = remainderBigInt.toString().padStart(decimalPlaces, '0');

  // Combine integer and fractional parts for final numeric result
  let combinedStr = `${integerPart}.${fractionalPart}`;
  if (isNegative) {
    combinedStr = `-${combinedStr}`;
  }

  // ---------------------------------------------------------------------------
  // STEP 8: Round the result to correct decimal places using toFixed, convert back
  //         to number with parseFloat
  // ---------------------------------------------------------------------------
  const rounded = parseFloat(parseFloat(combinedStr).toFixed(decimalPlaces));

  // ---------------------------------------------------------------------------
  // STEP 9: Validate the final result is within safe bounds
  // ---------------------------------------------------------------------------
  if (rounded < MIN_SAFE_AMOUNT || rounded > MAX_SAFE_AMOUNT) {
    throw new RangeError(
      `Converted value out of safe range [${MIN_SAFE_AMOUNT}, ${MAX_SAFE_AMOUNT}].`
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 10: Return the final floating-point result
  // ---------------------------------------------------------------------------
  return rounded;
}

/**
 * formatCurrency
 * 
 * Formats a given amount and currency into a properly localized string.
 * This function decides if the provided amount is in minor or major units
 * based on magnitude, converts to major units if necessary, and then applies
 * an Intl.NumberFormat for accurate symbols and decimal placement. It also
 * allows for future expansion to handle RTL languages or advanced locale
 * customizations.
 * 
 * @param amount   - Numeric value representing the amount (in minor or major units)
 * @param currency - The three-letter ISO currency code (e.g., "USD")
 * @returns string - A formatted currency string ready for display
 */
export function formatCurrency(amount: number, currency: string): string {
  // ---------------------------------------------------------------------------
  // STEP 1: Validate input types using TypeScript type guards
  // ---------------------------------------------------------------------------
  if (typeof amount !== 'number') {
    throw new TypeError('Invalid amount type: amount must be a number.');
  }
  if (typeof currency !== 'string') {
    throw new TypeError('Invalid currency type: currency must be a string.');
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Validate currency is supported using validateCurrency
  // ---------------------------------------------------------------------------
  if (!validateCurrency(currency)) {
    throw new Error(`Currency '${currency}' is invalid or unsupported.`);
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Check if amount is likely in minor units by magnitude comparison
  //         e.g., if "amount" is large for a typical currency, we interpret
  //         it as minor units. This logic can be expanded or refined as needed.
  // ---------------------------------------------------------------------------
  const upperCurrency = currency.toUpperCase();
  const decimalPlaces = CURRENCY_DECIMAL_PLACES[upperCurrency];
  const threshold = Math.pow(10, decimalPlaces) * 1000; // Arbitrary threshold for detection

  let majorAmount = amount;
  if (Math.abs(amount) >= threshold) {
    // If above threshold, interpret as minor units and convert
    majorAmount = convertToMajorUnits(amount, upperCurrency);
  }

  // ---------------------------------------------------------------------------
  // STEP 4: Create an Intl.NumberFormat instance with currency configuration
  //         Using 'undefined' as the locale argument for broad coverage,
  //         or specifying a locale like 'en-US' for consistent formatting.
  // ---------------------------------------------------------------------------
  const formatter = new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: upperCurrency,
    // Additional configuration for advanced usage:
    // currencyDisplay: 'symbol' | 'code' | 'name'
  });

  // ---------------------------------------------------------------------------
  // STEP 5: Apply formatting, which will insert the correct currency symbol
  //         and decimal separators based on the chosen locale. In an
  //         enterprise scenario, we can detect or store user locale preferences.
  // ---------------------------------------------------------------------------
  const formattedValue = formatter.format(majorAmount);

  // ---------------------------------------------------------------------------
  // STEP 6: Handle special cases for RTL languages or advanced localization here.
  //         For demonstration, we simply assume LTR output. 
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // STEP 7: Return the final formatted string
  // ---------------------------------------------------------------------------
  return formattedValue;
}