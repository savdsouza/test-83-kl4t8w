import { TimeRange } from '../types/common.types'; // Internal import for TimeRange interface
import { format, addMinutes, isValid } from 'date-fns'; // version ^2.30.0
import { zonedTimeToUtc } from 'date-fns-tz'; // version ^2.0.0

/**
 * Formats a given date and time with enhanced timezone handling and validation.
 * @param date A valid Date object to format.
 * @param formatString An optional format pattern string (default: 'yyyy-MM-dd HH:mm:ss').
 * @param timezone An optional timezone identifier, e.g. 'America/New_York'.
 * @returns A formatted date/time string in the specified timezone, appended with a timezone indicator if provided.
 * @throws {Error} If the input date is invalid or null/undefined.
 */
export function formatDateTime(
  date: Date,
  formatString?: string,
  timezone?: string
): string {
  if (!date || !isValid(date)) {
    throw new Error('Invalid date provided to formatDateTime.');
  }

  // Use a default format if none is provided
  const appliedFormat = formatString || 'yyyy-MM-dd HH:mm:ss';

  // Convert the date to UTC based on the specified timezone
  let utcDate = date;
  if (timezone) {
    utcDate = zonedTimeToUtc(date, timezone);
  }

  // Format the resulting UTC date
  let formatted = format(utcDate, appliedFormat);

  // Append timezone info if provided
  if (timezone) {
    formatted += ` [${timezone}]`;
  }

  return formatted;
}

/**
 * Formats only the time in 12-hour format with AM/PM notation and optional timezone support.
 * @param date A valid Date object whose time is to be formatted.
 * @param timezone An optional timezone identifier, e.g. 'America/Chicago'.
 * @returns A formatted time string (e.g. "03:25 PM") with an optional timezone indicator (e.g. "[America/Chicago]").
 * @throws {Error} If the input date is invalid or null/undefined.
 */
export function formatTime(date: Date, timezone?: string): string {
  if (!date || !isValid(date)) {
    throw new Error('Invalid date provided to formatTime.');
  }

  let utcDate = date;
  if (timezone) {
    utcDate = zonedTimeToUtc(date, timezone);
  }

  let formattedTime = format(utcDate, 'hh:mm a');
  if (timezone) {
    formattedTime += ` [${timezone}]`;
  }

  return formattedTime;
}

/**
 * Calculates an end time based on a start time, a required duration in minutes, and optional buffer time.
 * @param startTime The start time for the calculation.
 * @param durationMinutes Required duration in minutes (must be a positive number).
 * @param bufferMinutes Optional buffer in minutes to add on top of the required duration.
 * @returns A new Date object representing the calculated end time, including any buffer.
 * @throws {Error} If the start time is invalid, the duration is not positive, or if the result is not in the future.
 */
export function calculateEndTime(
  startTime: Date,
  durationMinutes: number,
  bufferMinutes?: number
): Date {
  if (!startTime || !isValid(startTime)) {
    throw new Error('Invalid start time for calculateEndTime.');
  }
  if (typeof durationMinutes !== 'number' || durationMinutes <= 0) {
    throw new Error(
      'Duration minutes must be a positive number for calculateEndTime.'
    );
  }

  const buffer = bufferMinutes && bufferMinutes > 0 ? bufferMinutes : 0;
  const totalDuration = durationMinutes + buffer;
  const result = addMinutes(startTime, totalDuration);

  // Validate the end time is in the future
  if (result.getTime() <= Date.now()) {
    throw new Error('Calculated end time is not in the future.');
  }

  return result;
}

/**
 * Validates a given time range, checking date validity, sequence, optional minimum duration, and future times.
 * @param timeRange An object containing a startTime and endTime.
 * @param minimumDurationMinutes Optional minimum duration in minutes that this range should satisfy.
 * @returns True if the time range is valid, false otherwise.
 */
export function isTimeRangeValid(
  timeRange: TimeRange,
  minimumDurationMinutes?: number
): boolean {
  if (
    !timeRange ||
    !timeRange.startTime ||
    !timeRange.endTime ||
    !isValid(timeRange.startTime) ||
    !isValid(timeRange.endTime)
  ) {
    return false;
  }

  const { startTime, endTime } = timeRange;
  if (endTime <= startTime) {
    return false;
  }

  if (minimumDurationMinutes && minimumDurationMinutes > 0) {
    const differenceInMs = endTime.getTime() - startTime.getTime();
    const differenceInMinutes = differenceInMs / (1000 * 60);
    if (differenceInMinutes < minimumDurationMinutes) {
      return false;
    }
  }

  // Ensure the entire range is not in the past
  const now = Date.now();
  if (startTime.getTime() < now || endTime.getTime() < now) {
    return false;
  }

  return true;
}

/**
 * Checks the availability of a given time slot against existing bookings, applying buffer time to detect overlaps.
 * @param timeSlot The time range to check for availability.
 * @param existingBookings An array of existing booked time ranges.
 * @param bufferMinutes Optional buffer to apply before and after the slot to prevent back-to-back overlaps.
 * @returns True if the time slot does not overlap any existing booking (considering buffer), false otherwise.
 */
export function isTimeSlotAvailable(
  timeSlot: TimeRange,
  existingBookings: TimeRange[],
  bufferMinutes?: number
): boolean {
  // Validate the input time slot
  if (!isTimeRangeValid(timeSlot)) {
    return false;
  }

  // Ensure existingBookings is an array
  if (!Array.isArray(existingBookings)) {
    return false;
  }

  // Safely handle buffer
  const buffer = bufferMinutes && bufferMinutes > 0 ? bufferMinutes : 0;

  // Adjust the requested slot by buffer
  const adjustedStart = addMinutes(timeSlot.startTime, -buffer);
  const adjustedEnd = addMinutes(timeSlot.endTime, buffer);

  // Check for overlaps
  for (const booking of existingBookings) {
    if (!isTimeRangeValid(booking)) {
      // If an existing booking is invalid for any reason, skip it
      continue;
    }

    // Adjust booking times by buffer too
    const bookingStart = addMinutes(booking.startTime, -buffer);
    const bookingEnd = addMinutes(booking.endTime, buffer);

    // Overlap condition: if the requested start is before booking end
    // and the booking start is before the requested end, we have an overlap.
    if (adjustedStart < bookingEnd && bookingStart < adjustedEnd) {
      return false;
    }
  }

  return true;
}