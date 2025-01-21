/**
 * Comprehensive validation constants used across the application for input validation,
 * form validation, data integrity checks, and security compliance.
 *
 * References:
 *  - 7. SECURITY CONSIDERATIONS (7.1.2 Authentication Methods, 7.2 Data Security)
 *  - 2.3.2 API Specifications (Security Controls)
 *  - Additional relevant parts of the technical specification.
 */

/**
 * AUTH_VALIDATION
 * 
 * Enforces strict validation rules for email/password authentication
 * to ensure compliance with minimum password length (12 characters),
 * special characters, complexity requirements, and other security measures.
 */
export const AUTH_VALIDATION = {
  /**
   * Minimum length for email addresses.
   * Must align with general input validation and data integrity rules.
   */
  EMAIL_MIN_LENGTH: 5,

  /**
   * Maximum length for email addresses to prevent excessively long inputs.
   */
  EMAIL_MAX_LENGTH: 255,

  /**
   * Email pattern ensuring compliance with valid address formats.
   */
  EMAIL_PATTERN: '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$',

  /**
   * Minimum length for passwords (12 characters) to ensure robust security,
   * in line with (7.1.2 Authentication Methods).
   */
  PASSWORD_MIN_LENGTH: 12,

  /**
   * Maximum length for passwords to avoid storage overhead while maintaining complexity.
   */
  PASSWORD_MAX_LENGTH: 128,

  /**
   * Regex pattern enforcing uppercase, lowercase, numeric, and special characters
   * for strong password complexity according to security best practices.
   */
  PASSWORD_PATTERN:
    '^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{12,}$',

  /**
   * One-Time-Password length for multi-factor authentication workflows.
   */
  OTP_LENGTH: 6,

  /**
   * Number of historical passwords stored to prevent reuse.
   */
  PASSWORD_HISTORY_SIZE: 5,

  /**
   * Password expiration duration in days, promoting periodic credential updates.
   */
  PASSWORD_EXPIRY_DAYS: 90,

  /**
   * Maximum allowed login attempts before account lockout, mitigating brute-force attacks.
   */
  MAX_LOGIN_ATTEMPTS: 5,

  /**
   * Duration (in minutes) for which an account remains locked out after exceeding
   * the maximum login attempts.
   */
  LOCKOUT_DURATION_MINUTES: 30,
};

/**
 * USER_VALIDATION
 * 
 * Defines validation constraints for user profiles, phone numbers, addresses,
 * and other personal information fields to maintain data integrity and quality.
 */
export const USER_VALIDATION = {
  /**
   * Minimum length for user names (first, last, or full name).
   */
  NAME_MIN_LENGTH: 2,

  /**
   * Maximum length for user names to prevent excessively long inputs.
   */
  NAME_MAX_LENGTH: 50,

  /**
   * Regex pattern ensuring phone numbers follow E.164 format (international notation).
   */
  PHONE_PATTERN: '^\\+[1-9]\\d{1,14}$',

  /**
   * Maximum length for user bios or profile descriptions.
   */
  BIO_MAX_LENGTH: 500,

  /**
   * Minimum length for usernames (login handles).
   */
  USERNAME_MIN_LENGTH: 3,

  /**
   * Maximum length for usernames.
   */
  USERNAME_MAX_LENGTH: 30,

  /**
   * Regex pattern allowing alphanumeric characters, underscores, and dashes for usernames.
   */
  USERNAME_PATTERN: '^[a-zA-Z0-9_-]{3,30}$',

  /**
   * Maximum file size (in bytes) for profile image uploads (5 MB).
   */
  PROFILE_IMAGE_MAX_SIZE: 5242880,

  /**
   * Allowed MIME types for profile images.
   */
  ALLOWED_IMAGE_TYPES: ['image/jpeg', 'image/png'],

  /**
   * Maximum length for address fields, ensuring standard postal lengths.
   */
  ADDRESS_MAX_LENGTH: 200,

  /**
   * Maximum length for city fields.
   */
  CITY_MAX_LENGTH: 100,

  /**
   * Regex pattern for validating alphanumeric postal or ZIP codes with optional hyphens/spaces.
   */
  POSTAL_CODE_PATTERN: '^[A-Za-z0-9\\s-]{3,10}$',
};

/**
 * WALK_VALIDATION
 * 
 * Contains constants ensuring the scheduling, duration, pricing, and other
 * parameters of dog walks meet application constraints and user expectations.
 */
export const WALK_VALIDATION = {
  /**
   * Minimum duration (in minutes) allowed for a single walk.
   */
  MIN_DURATION: 15,

  /**
   * Maximum duration (in minutes) allowed for a single walk.
   */
  MAX_DURATION: 180,

  /**
   * Maximum number of dogs that can be handled in a single walk.
   */
  MAX_DOGS_PER_WALK: 3,

  /**
   * Minimum allowable price for a dog walk.
   */
  MIN_PRICE: 10,

  /**
   * Maximum allowable price for a dog walk.
   */
  MAX_PRICE: 200,

  /**
   * Maximum length for additional notes or instructions provided by the owner.
   */
  NOTES_MAX_LENGTH: 1000,

  /**
   * Minimum cancellation notice (in minutes) required before walk start time.
   */
  CANCELLATION_NOTICE_MINUTES: 60,

  /**
   * Maximum number of days into the future a walk can be booked.
   */
  MAX_FUTURE_BOOKING_DAYS: 30,

  /**
   * Minimum required break (in minutes) a walker must have between consecutive walks.
   */
  MIN_BREAK_MINUTES: 15,

  /**
   * Maximum number of walks a single walker can take in one day.
   */
  MAX_DAILY_WALKS: 8,
};

/**
 * REVIEW_VALIDATION
 * 
 * Manages the constraints around walkthrough reviews and feedback loops,
 * ensuring fairness and consistency in ratings and user comments.
 */
export const REVIEW_VALIDATION = {
  /**
   * Minimum rating allowed.
   */
  RATING_MIN: 1,

  /**
   * Maximum rating allowed.
   */
  RATING_MAX: 5,

  /**
   * Maximum length of review comments.
   */
  COMMENT_MAX_LENGTH: 500,

  /**
   * Maximum length for reporting reasons (complaints, issues, etc.).
   */
  REPORT_REASON_MAX_LENGTH: 1000,

  /**
   * Minimum percentage of walk completion required to leave a review.
   */
  MIN_WALK_COMPLETE_PERCENT: 80,

  /**
   * Time window (in hours) after a walk ends during which a user can leave a review.
   */
  REVIEW_WINDOW_HOURS: 48,
};

/**
 * LOCATION_VALIDATION
 * 
 * Contains geographic bounds, distance, and interval settings for location-based
 * operations such as geofencing, real-time tracking, and distance calculations.
 */
export const LOCATION_VALIDATION = {
  /**
   * Minimum valid latitude value.
   */
  LAT_MIN: -90,

  /**
   * Maximum valid latitude value.
   */
  LAT_MAX: 90,

  /**
   * Minimum valid longitude value.
   */
  LNG_MIN: -180,

  /**
   * Maximum valid longitude value.
   */
  LNG_MAX: 180,

  /**
   * Minimum search or geofence radius (in miles or kilometers, as context requires).
   */
  RADIUS_MIN: 0.1,

  /**
   * Maximum search or geofence radius, preventing excessive queries or data usage.
   */
  RADIUS_MAX: 50,

  /**
   * Distance threshold (in miles or kilometers) used for geofence alerts.
   */
  GEOFENCE_ALERT_DISTANCE: 0.1,

  /**
   * Interval (in seconds) at which location updates are sent to the server.
   */
  LOCATION_UPDATE_INTERVAL: 30,

  /**
   * Threshold (in seconds) after which a location is considered outdated/stale.
   */
  STALE_LOCATION_THRESHOLD: 300,
};

/**
 * PAYMENT_VALIDATION
 * 
 * Enforces PCI-compliant data validation rules for payment information,
 * including card details, CVV, and expiry patterns for secure transactions.
 */
export const PAYMENT_VALIDATION = {
  /**
   * Standard length for most card numbers (excluding certain advanced checks).
   */
  CARD_NUMBER_LENGTH: 16,

  /**
   * CVV length for most cards (3 digits, not including certain non-standard cases).
   */
  CVV_LENGTH: 3,

  /**
   * Regex for MM/YY format validation ensuring correct month-year relationships.
   */
  EXPIRY_PATTERN: '^(0[1-9]|1[0-2])\\/([0-9]{2})$',

  /**
   * Maximum length for cardholder names stored on user payment methods.
   */
  CARD_NAME_MAX_LENGTH: 100,

  /**
   * Whitelisted card types allowed within the system's payment workflow.
   */
  ALLOWED_CARD_TYPES: ['visa', 'mastercard', 'amex'],

  /**
   * Minimum balance in user wallets; negative balances are disallowed.
   */
  MIN_WALLET_BALANCE: 0,

  /**
   * Maximum wallet balance allowed before prompting for withdrawals or limiting top-ups.
   */
  MAX_WALLET_BALANCE: 1000,

  /**
   * Maximum length for transaction descriptions or memos.
   */
  TRANSACTION_DESCRIPTION_MAX: 200,
};