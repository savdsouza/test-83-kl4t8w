/**
 * Comprehensive utility module providing standardized formatting functions
 * for various data types including currency, distances, phone numbers,
 * coordinates, durations, and ratings. Ensures consistency across the
 * application and supports internationalization requirements.
 */

// Internal Imports (Type Definitions)
import { Coordinates } from '../types/common.types';

// External Imports
// currency.js@^2.0.4
import currency from 'currency.js';

/**
 * Formats a number as currency with support for negative values, zero handling,
 * and different locales. Leverages both currency.js and, if requested via
 * the locale parameter, the built-in Intl.NumberFormat.
 *
 * Steps:
 * 1. Validate input amount is a valid number.
 * 2. Handle special cases (null, undefined, NaN).
 * 3. Apply locale-specific formatting if provided.
 * 4. Format negative values with proper sign.
 * 5. Handle zero values with appropriate display.
 * 6. Apply proper decimal precision (2 places).
 * 7. Add thousands separators.
 * 8. Return formatted string with currency symbol.
 *
 * @param amount The numeric value to be formatted as currency.
 * @param locale Optional BCP 47 language tag for locale-specific formatting.
 * @returns A well-formatted currency string.
 */
export function formatCurrency(amount: number, locale?: string): string {
  // 1. Validate input amount is a valid number
  if (typeof amount !== 'number' || isNaN(amount)) {
    return '';
  }

  // 2. Handle special cases: if the amount is null, undefined, or NaN, we return an empty string
  // (above condition covers NaN). For completeness, we continue to check others:
  if (amount === null || amount === undefined) {
    return '';
  }

  // 3. Apply locale-specific formatting if provided; fallback to currency.js otherwise
  if (locale) {
    try {
      // Using Intl.NumberFormat for locale-based currency formatting
      return new Intl.NumberFormat(locale, {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      }).format(amount);
    } catch {
      // If locale is invalid, fallback to currency.js logic below
    }
  }

  // 4, 5, 6, 7, 8. Format using currency.js for consistent sign, zero handling,
  // decimal precision, and thousands separators.
  return currency(amount, {
    // Setting default precision to two decimal places
    precision: 2
  }).format();
}

/**
 * Formats a distance value with support for both imperial (miles) and metric (kilometers)
 * units, applying appropriate precision rules. Assumes that the input distance is in meters;
 * converts to the chosen unit, then formats the display string accordingly.
 *
 * Steps:
 * 1. Validate input distance is a positive number.
 * 2. Determine unit system (mi or km).
 * 3. Convert from meters to the specified unit system if necessary.
 * 4. Apply precision rules based on distance magnitude.
 * 5. Format with the proper unit abbreviation.
 * 6. Handle edge cases for extremely small or large distances.
 * 7. Return formatted string with proper spacing and suffix.
 *
 * @param distance A numeric value representing distance in meters.
 * @param unit An optional string indicating the desired output unit ("mi" or "km").
 * @returns A formatted distance string with the correct unit abbreviation.
 */
export function formatDistance(distance: number, unit?: string): string {
  // 1. Validate input distance is a positive number
  if (typeof distance !== 'number' || isNaN(distance) || distance < 0) {
    return '';
  }

  // Default to "km" unless specified as "mi"
  const chosenUnit = unit && unit.toLowerCase() === 'mi' ? 'mi' : 'km';
  let convertedValue = 0;
  let suffix = '';

  // 2. Determine unit system and 3. Convert if necessary
  if (chosenUnit === 'mi') {
    convertedValue = distance / 1609.344; // 1 mile = 1609.344 meters
    suffix = ' mi';
  } else {
    convertedValue = distance / 1000; // 1 km = 1000 meters
    suffix = ' km';
  }

  // 4. Apply precision rules
  // This example sets two decimal places if under 10, then one decimal place above that.
  if (convertedValue < 1) {
    return `${convertedValue.toFixed(2)}${suffix}`;
  }
  if (convertedValue < 10) {
    return `${convertedValue.toFixed(2)}${suffix}`;
  }
  return `${convertedValue.toFixed(1)}${suffix}`;
}

/**
 * Formats a phone number string using common patterns and optional country code logic.
 * Supports standardized formatting for US numbers, plus a simple international fallback.
 *
 * Steps:
 * 1. Sanitize input by removing non-numeric characters.
 * 2. Validate length based on country code.
 * 3. Apply country-specific formatting patterns.
 * 4. Handle international prefixes if needed.
 * 5. Format local numbers according to recognized patterns.
 * 6. Add proper separators and grouping.
 * 7. Return formatted string with optional country code.
 *
 * @param phoneNumber The raw phone number string (potentially containing spaces or dashes).
 * @param countryCode The optional country code for specialized formatting (defaults to 'US').
 * @returns A standardized phone number string.
 */
export function formatPhoneNumber(phoneNumber: string, countryCode?: string): string {
  // 1. Remove non-numeric characters
  const cleaned = (phoneNumber || '').replace(/\D+/g, '');
  if (!cleaned) {
    return '';
  }

  // Default to 'US' if no countryCode is provided
  const cc = (countryCode || 'US').toUpperCase();

  // 2. Validate length and 3, 4, 5. Country-specific logic for US
  if (cc === 'US') {
    // Typical US local is 10 digits
    if (cleaned.length === 10) {
      return `(${cleaned.substr(0, 3)}) ${cleaned.substr(3, 3)}-${cleaned.substr(6)}`;
    }
    // US with leading 1 can be 11 digits
    if (cleaned.length === 11 && cleaned.startsWith('1')) {
      return `+1 (${cleaned.substr(1, 3)}) ${cleaned.substr(4, 3)}-${cleaned.substr(7)}`;
    }
  }

  // 5. Simple fallback for if we do not have a recognized pattern or non-US
  // Attempt a default international format
  if (cc && !cleaned.startsWith(cc)) {
    return `+${cc} ${cleaned}`;
  }

  // 6, 7. Return a simple numeric fallback
  return cleaned;
}

/**
 * Formats geographic coordinates into decimal or DMS (degrees, minutes, seconds)
 * notation, including cardinal directions and configurable precision.
 *
 * Steps:
 * 1. Validate the coordinate object properties.
 * 2. Check for valid latitude range (-90 to 90).
 * 3. Check for valid longitude range (-180 to 180).
 * 4. Determine output format (decimal or DMS).
 * 5. Apply specified precision.
 * 6. Add cardinal directions (N/S/E/W).
 * 7. Construct the properly formatted string.
 * 8. Return the final result.
 *
 * @param coordinates An object containing 'latitude' and 'longitude' values.
 * @param format Optional format specifier ('decimal' or 'dms'), defaults to 'decimal'.
 * @returns A string representing the formatted coordinate pair.
 */
export function formatCoordinates(coordinates: Coordinates, format?: string): string {
  const { latitude, longitude } = coordinates;

  // 1, 2, 3. Validate coordinate ranges
  if (
    typeof latitude !== 'number' ||
    typeof longitude !== 'number' ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return '';
  }

  // Default format to 'decimal' if not provided
  const chosenFormat = format || 'decimal';

  if (chosenFormat === 'dms') {
    // 4. Convert decimal degrees to DMS for both latitude and longitude
    const latDirection = latitude >= 0 ? 'N' : 'S';
    const lonDirection = longitude >= 0 ? 'E' : 'W';

    const latAbs = Math.abs(latitude);
    const latDeg = Math.floor(latAbs);
    const latMin = Math.floor((latAbs - latDeg) * 60);
    const latSec = ((latAbs - latDeg) * 60 - latMin) * 60;

    const lonAbs = Math.abs(longitude);
    const lonDeg = Math.floor(lonAbs);
    const lonMin = Math.floor((lonAbs - lonDeg) * 60);
    const lonSec = ((lonAbs - lonDeg) * 60 - lonMin) * 60;

    // 7. Construct DMS output
    return `${latDeg}°${latMin}'${latSec.toFixed(2)}" ${latDirection}, ` +
           `${lonDeg}°${lonMin}'${lonSec.toFixed(2)}" ${lonDirection}`;
  }

  // 'decimal' notation
  const latDirection = latitude >= 0 ? 'N' : 'S';
  const lonDirection = longitude >= 0 ? 'E' : 'W';

  // 5. Apply default decimal precision (6 decimal places to align with typical WGS84 usage)
  // 6, 7. Add cardinal directions
  return `${Math.abs(latitude).toFixed(6)}° ${latDirection}, ` +
         `${Math.abs(longitude).toFixed(6)}° ${lonDirection}`;
}

/**
 * Formats a time duration, expressed in total minutes, into a
 * human-readable string, supporting verbose or concise output.
 * Breaks down the input minutes into years, months, weeks, days,
 * hours, and minutes as appropriate.
 *
 * Steps:
 * 1. Validate input is a positive number.
 * 2. Calculate years/months/weeks/days/hours/minutes.
 * 3. Handle plural vs. singular forms.
 * 4. Determine appropriate unit display.
 * 5. Format according to verbose or concise preference.
 * 6. Apply localization if needed (currently stubbed for expansions).
 * 7. Combine units with proper separators.
 * 8. Return the final duration string.
 *
 * @param totalMinutes The total duration in minutes.
 * @param verbose If true, uses long-form units (e.g., "hours"); otherwise shorter forms (e.g., "h").
 * @returns A human-readable duration string.
 */
export function formatDuration(totalMinutes: number, verbose?: boolean): string {
  // 1. Validate input
  if (typeof totalMinutes !== 'number' || isNaN(totalMinutes) || totalMinutes < 0) {
    return '';
  }

  const minutesInHour = 60;
  const minutesInDay = minutesInHour * 24;
  const minutesInWeek = minutesInDay * 7;
  const minutesInMonth = minutesInDay * 30; // approximate measure
  const minutesInYear = minutesInDay * 365; // approximate measure

  let remainder = totalMinutes;
  const years = Math.floor(remainder / minutesInYear);
  remainder %= minutesInYear;

  const months = Math.floor(remainder / minutesInMonth);
  remainder %= minutesInMonth;

  const weeks = Math.floor(remainder / minutesInWeek);
  remainder %= minutesInWeek;

  const days = Math.floor(remainder / minutesInDay);
  remainder %= minutesInDay;

  const hours = Math.floor(remainder / minutesInHour);
  remainder %= minutesInHour;

  const minutes = Math.floor(remainder);

  // Helper function to handle singular/plural or short forms
  function buildSegment(value: number, singular: string, plural: string): string {
    if (value <= 0) return '';
    if (verbose) {
      return value === 1 ? `${value} ${singular}` : `${value} ${plural}`;
    }
    // For concise mode, use the first character of the singular label (e.g., "h" for "hour")
    return `${value}${singular.charAt(0)}`;
  }

  // 2, 3, 4, 5, 7. Build output segments
  const segments: string[] = [];
  const y = buildSegment(years, 'year', 'years');
  const mo = buildSegment(months, 'month', 'months');
  const w = buildSegment(weeks, 'week', 'weeks');
  const d = buildSegment(days, 'day', 'days');
  const h = buildSegment(hours, 'hour', 'hours');
  const m = buildSegment(minutes, 'minute', 'minutes');

  if (y) segments.push(y);
  if (mo) segments.push(mo);
  if (w) segments.push(w);
  if (d) segments.push(d);
  if (h) segments.push(h);
  if (m) segments.push(m);

  // If no segments were added, we're dealing with zero
  if (!segments.length) {
    return verbose ? '0 minutes' : '0m';
  }

  // 8. Return final joined string; for verbose, use spaces
  // For concise, also use spaces or some minimal delimiter
  return segments.join(' ');
}

/**
 * Formats a rating value, optionally normalizing against a maximum rating.
 * Keeps consistent decimal precision and handles edge cases for zero or
 * perfect scores.
 *
 * Steps:
 * 1. Validate rating is within valid range.
 * 2. Determine overall scale based on maxRating (default 5).
 * 3. Normalize rating if it exceeds maxRating.
 * 4. Apply consistent decimal precision.
 * 5. Handle cases when rating is an integer vs. decimal.
 * 6. Handle zero or perfect rating gracefully.
 * 7. Return the formatted rating string, e.g. "4.5/5".
 *
 * @param rating The numeric rating to be formatted.
 * @param maxRating An optional maximum rating for the scale (defaults to 5).
 * @returns A string representing the rating, e.g. "4.5/5".
 */
export function formatRating(rating: number, maxRating?: number): string {
  // 1. Validate
  if (typeof rating !== 'number' || isNaN(rating) || rating < 0) {
    return '';
  }

  // 2, 3. Determine scale and clamp if needed
  const scale = maxRating && maxRating > 0 ? maxRating : 5;
  if (rating > scale) {
    rating = scale;
  }

  // 4, 5. Apply decimal precision, removing trailing .0 if it exists
  let formattedValue = rating.toFixed(1);
  if (Number(formattedValue) === Math.floor(rating)) {
    formattedValue = String(Math.floor(rating));
  }

  // 6. Zero or perfect rating edge cases are naturally handled here,
  // but additional logic can be inserted if needed.

  // 7. Return final string
  return `${formattedValue}/${scale}`;
}

// Named Exports
export {
  formatCurrency,
  formatDistance,
  formatPhoneNumber,
  formatCoordinates,
  formatDuration,
  formatRating
};