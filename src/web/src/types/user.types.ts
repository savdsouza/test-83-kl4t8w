/**
 * ------------------------------------------------------------------------
 * Type Definitions for User-Related Data Structures
 * ------------------------------------------------------------------------
 * This file defines all user-related interfaces and enumerations, covering
 * secure data classifications and alignment with role-based security rules.
 * It encompasses core user profiles, walker-specific data, preferences, and
 * verification records.
 *
 * Data Classification and Security Considerations:
 *  - Personally Identifiable Information (PII) fields are clearly marked.
 *  - Role-based elements are enforced via enumerations such as UserRole.
 *  - Verification details follow strict compliance, ensuring data integrity.
 *
 * ------------------------------------------------------------------------
 */

/**
 * Enumeration representing user roles within the system. Used to enforce
 * role-based access control and distinguish capabilities per user type.
 *
 * Security Classification: Internal
 */
export enum UserRole {
  /**
   * Represents a dog owner seeking walking services.
   */
  OWNER = 'OWNER',

  /**
   * Represents a verified dog walker providing services.
   */
  WALKER = 'WALKER',

  /**
   * Represents an administrative user with extended privileges.
   */
  ADMIN = 'ADMIN',
}

/**
 * Enumeration describing possible statuses for user or walker verification.
 * Helps in controlling system flows based on background checks and approvals.
 *
 * Security Classification: Internal
 */
export enum VerificationStatus {
  /**
   * Indicates user/walker verification in progress.
   */
  PENDING = 'PENDING',
  /**
   * Indicates verification completed and approved.
   */
  APPROVED = 'APPROVED',
  /**
   * Indicates verification was rejected after review.
   */
  REJECTED = 'REJECTED',
  /**
   * Indicates verification has expired and may require renewal.
   */
  EXPIRED = 'EXPIRED',
}

/**
 * Enumeration specifying acceptable document types for verification.
 *
 * Security Classification: Internal
 */
export enum VerificationDocumentType {
  /**
   * Generic government-issued ID card.
   */
  ID_CARD = 'ID_CARD',
  /**
   * Passport for international identification.
   */
  PASSPORT = 'PASSPORT',
  /**
   * Driver's license for local identification.
   */
  DRIVERS_LICENSE = 'DRIVERS_LICENSE',
}

/**
 * Interface defining a single schedule entry for walker availability.
 * Typically used in arrays to represent weekly or custom time blocks.
 *
 * Security Classification: Internal
 */
export interface Schedule {
  /**
   * Day of the week, where 0 = Sunday, 1 = Monday, ... 6 = Saturday.
   */
  dayOfWeek: number;
  /**
   * Start time in HH:mm format, e.g., "09:00".
   */
  startTime: string;
  /**
   * End time in HH:mm format, e.g., "17:00".
   */
  endTime: string;
  /**
   * Optional flag indicating availability for the entire day.
   */
  isAvailableAllDay?: boolean;
}

/**
 * Interface describing user notification settings, such as push alerts.
 * This data can be used to fine-tune real-time notifications per user.
 *
 * Security Classification: Internal
 */
export interface NotificationSettings {
  /**
   * Indicates if push notifications are enabled.
   */
  pushEnabled: boolean;
  /**
   * Indicates if push notifications will include audible alerts.
   */
  pushSound: boolean;
  /**
   * Indicates if push notifications can trigger device vibration.
   */
  pushVibration: boolean;
}

/**
 * Interface describing user preferences for email-based communications.
 * Controls the types of emails the user is willing to receive.
 *
 * Security Classification: Internal
 */
export interface EmailPreferences {
  /**
   * Indicates if marketing/promotional emails are allowed.
   */
  marketing: boolean;
  /**
   * Indicates if system-generated reminders or tips are allowed.
   */
  reminders: boolean;
  /**
   * Indicates if newsletters or dog-care advisories are allowed.
   */
  newsletters: boolean;
}

/**
 * Interface describing user preferences for SMS-based communications.
 * SMS usage often covers time-sensitive or critical alerts.
 *
 * Security Classification: Internal
 */
export interface SMSPreferences {
  /**
   * Indicates if SMS alerts are allowed for critical events.
   */
  alerts: boolean;
  /**
   * Indicates if SMS reminders are allowed for upcoming events.
   */
  reminders: boolean;
}

/**
 * Interface encapsulating privacy choices made by the user, covering
 * data visibility of sensitive profile information and activity status.
 *
 * Security Classification: Internal
 */
export interface PrivacySettings {
  /**
   * Indicates if the user’s email should be visible to others.
   */
  showEmail: boolean;
  /**
   * Indicates if the user’s phone number should be visible to others.
   */
  showPhone: boolean;
  /**
   * Indicates if the user’s current or recent activity is visible.
   */
  shareActivityStatus: boolean;
}

/**
 * Interface representing core user data. This includes essential PII fields
 * as well as status flags that determine user operability within the system.
 *
 * Data Classification: Critical (PII)
 */
export interface User {
  /**
   * Unique identifier for the user entity (PII).
   */
  id: string;

  /**
   * Email address used for contact and login (PII).
   */
  email: string;

  /**
   * First name for personalization and identification (PII).
   */
  firstName: string;

  /**
   * Last name for personalization and identification (PII).
   */
  lastName: string;

  /**
   * Phone number for contact or multi-factor verification (PII).
   */
  phone: string;

  /**
   * Role assigned to the user, controlling access scope.
   */
  role: UserRole;

  /**
   * Optional link to user’s avatar or profile image.
   */
  avatarUrl?: string;

  /**
   * Flag indicating if the user has passed verification checks.
   */
  isVerified: boolean;

  /**
   * Flag indicating if the user account is currently active.
   */
  isActive: boolean;

  /**
   * Timestamp of the user’s last successful login.
   */
  lastLoginAt: Date;

  /**
   * Timestamp when the user record was created.
   */
  createdAt: Date;

  /**
   * Timestamp for the last time the user record was updated.
   */
  updatedAt: Date;
}

/**
 * Interface representing additional profile attributes for users who
 * function as dog walkers. Extended from the core user concept, focusing
 * on availability, pricing, and verification status.
 *
 * Data Classification: Internal
 */
export interface WalkerProfile {
  /**
   * References the unique user identifier for this walker (PII).
   */
  userId: string;

  /**
   * Current rating of the walker, derived from owner reviews.
   */
  rating: number;

  /**
   * Total number of completed walks by this walker for reputation metrics.
   */
  totalWalks: number;

  /**
   * Indicates real-time walker availability for immediate bookings.
   */
  isAvailable: boolean;

  /**
   * Stated hourly rate for walking services (currency in user preferences).
   */
  hourlyRate: number;

  /**
   * An array of locations or ZIP codes representing the walker’s service area.
   */
  serviceArea: string[];

  /**
   * Verification status dictating if background checks are complete.
   */
  backgroundCheckStatus: VerificationStatus;

  /**
   * A short biography or personal statement from the walker.
   */
  bio: string;

  /**
   * Any certifications relevant to dog care or training, e.g., CPR, pet handling.
   */
  certifications: string[];

  /**
   * Detailed schedule entries indicating the walker’s recurring availability.
   */
  availability: Schedule[];
}

/**
 * Interface representing a user’s preference data, including notification
 * options, language settings, privacy controls, and more. These are used to
 * tailor the UX and system notifications.
 *
 * Data Classification: Internal
 */
export interface UserPreferences {
  /**
   * Settings controlling push notifications, alerts, and vibrations.
   */
  notifications: NotificationSettings;

  /**
   * Settings controlling types of emails the user receives.
   */
  emailUpdates: EmailPreferences;

  /**
   * Settings controlling types of SMS notifications the user receives.
   */
  smsAlerts: SMSPreferences;

  /**
   * Selected language for localization.
   */
  language: string;

  /**
   * Selected timezone for scheduling and date/time display.
   */
  timezone: string;

  /**
   * Selected currency code for pricing displays (e.g., "USD", "CAD").
   */
  currency: string;

  /**
   * Privacy settings covering data visibility and sharing scope.
   */
  privacySettings: PrivacySettings;
}

/**
 * Interface wrapping all necessary fields for tracking and documenting
 * user verification. Ensures that all user-supplied documents are recorded
 * and their statuses are maintained under secure protocols.
 *
 * Security Classification: Sensitive
 */
export interface UserVerification {
  /**
   * References the unique user identifier for the applicant (PII).
   */
  userId: string;

  /**
   * Type of document submitted for verification purposes.
   */
  documentType: VerificationDocumentType;

  /**
   * Secure URL link to the stored document. Access to this must be restricted.
   */
  documentUrl: string;

  /**
   * Current status of the verification process (pending, approved, etc.).
   */
  verificationStatus: VerificationStatus;

  /**
   * Timestamp when verification was approved, if applicable.
   */
  verifiedAt: Date | null;

  /**
   * Timestamp after which verification is considered expired, if applicable.
   */
  expiresAt: Date | null;

  /**
   * Array of notes or review comments from the verification process.
   */
  verificationNotes: string[];

  /**
   * Identifier for the user/admin who executed the final verification step.
   */
  verifiedBy: string | null;
}