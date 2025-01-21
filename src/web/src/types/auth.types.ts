/**
 * Internal import of the base API response contract used
 * across the application for type-safe and standardized
 * API responses.
 */
import { ApiResponse } from './api.types';

/**
 * Strongly-typed enumeration specifying all supported
 * authentication methods, accommodating a wide array
 * of login scenarios including social logins and native
 * biometric prompts.
 */
export enum AuthMethod {
  /**
   * Represents email/password based authentication with
   * complexity requirements and secure hashing.
   */
  EMAIL_PASSWORD = 'EMAIL_PASSWORD',

  /**
   * OAuth2-based social authentication flow for Google,
   * utilizing secure tokens and user consent screens.
   */
  GOOGLE = 'GOOGLE',

  /**
   * OAuth2-based social authentication flow for Apple,
   * leveraging secure tokens and Apple’s identity APIs.
   */
  APPLE = 'APPLE',

  /**
   * OAuth2-based social authentication flow for Facebook,
   * enabling quick sign-in with user consent via Facebook’s
   * developer platform.
   */
  FACEBOOK = 'FACEBOOK',

  /**
   * Represents native biometric authentication such as
   * FaceID on iOS or fingerprint scanning on Android,
   * ensuring seamless login with device-level security.
   */
  BIOMETRIC = 'BIOMETRIC',
}

/**
 * Enumeration defining all role-based access classifications
 * recognized within the system, enabling granular authorization
 * checks and feature gating across the application.
 */
export enum UserRole {
  /**
   * Standard dog owner role, representing a customer who
   * utilizes the platform to schedule dog walks.
   */
  OWNER = 'OWNER',

  /**
   * Verified dog walker role, representing a service provider
   * who offers dog walking appointments within the platform.
   */
  WALKER = 'WALKER',

  /**
   * Administrative role with elevated privileges for
   * oversight, user management, and system maintenance.
   */
  ADMIN = 'ADMIN',
}

/**
 * Enumeration reflecting the status of a user’s verification
 * process, dictating eligibility for certain system features
 * and compliance with background checks or review procedures.
 */
export enum VerificationStatus {
  /**
   * Indicates that the user has not submitted the
   * required information or documentation for verification.
   */
  UNVERIFIED = 'UNVERIFIED',

  /**
   * Represents a state where the user’s verification
   * information is under review by the system or an admin.
   */
  PENDING = 'PENDING',

  /**
   * Informs that the user has been successfully verified
   * and may access features requiring elevated trust.
   */
  VERIFIED = 'VERIFIED',

  /**
   * Implies that a user’s submitted documentation or
   * verification request was rejected or marked invalid.
   */
  REJECTED = 'REJECTED',
}

/**
 * Interface capturing additional security-related flags or
 * indicators tied to a user’s account, aiding in advanced
 * security checks, compliance measures, and system policies.
 */
export interface SecurityFlags {
  /**
   * Specifies if the user’s account is locked due to
   * violations, security concerns, or administrative actions.
   */
  accountLocked: boolean;

  /**
   * Flags that the user must change their password before
   * continuing, typically triggered by password expiration
   * policies or security resets.
   */
  passwordResetRequired: boolean;

  /**
   * Denotes whether the user has been flagged for administrative
   * review, possibly triggered by suspicious activity or rule
   * violations.
   */
  flaggedForReview: boolean;
}

/**
 * Interface defining the structure of a login request,
 * incorporating multiple authentication schemes as well
 * as optional multi-factor and biometric capabilities.
 */
export interface LoginRequest {
  /**
   * The user’s unique email, conforming to minimum complexity
   * and validity checks (e.g., standard RFC 5322 format).
   */
  email: string;

  /**
   * The user’s password, subject to hashing, length, and complexity
   * requirements enforced by the server’s authentication layer.
   */
  password: string;

  /**
   * Specifies which authentication method is being employed,
   * facilitating dynamic handling of social, biometric, or
   * native logins.
   */
  method: AuthMethod;

  /**
   * An optional token for time-based MFA or one-time passwords,
   * enabling an extra layer of security for high-risk operations.
   */
  mfaToken?: string;

  /**
   * The unique identifier associated with the user’s device,
   * used for session tracking and security analytics.
   */
  deviceId: string;

  /**
   * An optional biometrics-derived signature, enhancing
   * user authentication for supported devices (e.g., iOS FaceID).
   */
  biometricSignature?: string;
}

/**
 * Interface representing the registration request payload
 * with fields required for account creation, including
 * acceptance of terms and role specification.
 */
export interface RegisterRequest {
  /**
   * Unique email address for account identification. Must match
   * server-enforced constraints on syntax and domain validation.
   */
  email: string;

  /**
   * The new account’s password, expected to meet or exceed the
   * application’s specified complexity measures (length, entropy, etc.).
   */
  password: string;

  /**
   * Confirmation password, which must match exactly with the primary
   * password for registration to proceed successfully.
   */
  confirmPassword: string;

  /**
   * Specifies the user’s role in the system, enabling feature
   * enablement (dog owners vs. dog walkers).
   */
  role: UserRole;

  /**
   * User’s given name, utilized for personalization and profile display.
   */
  firstName: string;

  /**
   * User’s family name, utilized for personalization and
   * identity verification.
   */
  lastName: string;

  /**
   * Phone number for contact purposes, text notifications,
   * and potential multi-factor channels (e.g., SMS-based OTP).
   */
  phone: string;

  /**
   * A boolean indicating the explicit acceptance of terms
   * and conditions before creating an account.
   */
  acceptedTerms: boolean;

  /**
   * The unique device identifier from which the registration
   * request was initiated, useful for device-based security.
   */
  deviceId: string;
}

/**
 * Interface modeling the detailed information returned upon
 * a successful authentication or refresh operation. This
 * includes tokens, user context, and session essentials.
 */
export interface AuthResponse {
  /**
   * The short-lived access token (JWT), controlling resource
   * access within the platform and binding to user identity.
   */
  accessToken: string;

  /**
   * A refresh token used to securely obtain new access tokens
   * without re-prompting the user, typically stored in a secure
   * long-term context.
   */
  refreshToken: string;

  /**
   * Comprehensive user data object, containing profile
   * and role details, verification state, and security flags.
   */
  user: UserData;

  /**
   * Flag indicating whether additional multi-factor
   * credentials are required to complete the login.
   */
  requiresMfa: boolean;

  /**
   * Numeric timestamp denoting the expiry of the current
   * access token, usually in seconds since the Unix epoch.
   */
  tokenExpiry: number;

  /**
   * Unique session identifier correlating the user’s active
   * session with any relevant server logs or active contexts.
   */
  sessionId: string;
}

/**
 * Interface defining the core structure of user data
 * returned via authentication or profile endpoints,
 * inclusive of security and verification states.
 */
export interface UserData {
  /**
   * A platform-generated UUID or user identifier, globally
   * unique across the user base.
   */
  id: string;

  /**
   * The user’s primary email address used for login and
   * communication, mapped to a verified identity.
   */
  email: string;

  /**
   * The access role for the user, influencing permissions
   * and feature sets available to them.
   */
  role: UserRole;

  /**
   * User’s first/given name for personalized greetings and
   * display within UI components.
   */
  firstName: string;

  /**
   * User’s last/family name for identification within system
   * records and communication.
   */
  lastName: string;

  /**
   * Phone number used for contact, SMS verification, or other
   * telecommunication-based interactions.
   */
  phone: string;

  /**
   * Indicates if the user has passed initial email confirmation
   * or identity checks required for basic functionality.
   */
  isVerified: boolean;

  /**
   * Denotes whether multi-factor authentication is already enabled
   * for the user, impacting future login flows and security checks.
   */
  mfaEnabled: boolean;

  /**
   * Specifies the current status of verification, encompassing
   * advanced checks such as background screenings for dog walkers.
   */
  verificationStatus: VerificationStatus;

  /**
   * The timestamp (ISO-8601 format) of the user’s most recent
   * login, aiding in activity tracking and session management.
   */
  lastLogin: string;

  /**
   * Additional security flags capturing states such as
   * account locking, required password resets, or flagged
   * incidents.
   */
  securityFlags: SecurityFlags;
}

/**
 * Interface returned upon successfully configuring multi-factor
 * authentication, furnishing the user with the necessary
 * information to finalize their MFA setup.
 */
export interface MfaSetupResponse {
  /**
   * Base64 or data URL representation of a QR code image used
   * by authenticator apps to configure TOTP-based auth.
   */
  qrCode: string;

  /**
   * The shared secret used alongside time-based algorithms
   * for generating MFA tokens.
   */
  secret: string;

  /**
   * A set of backup codes allowed if the primary
   * MFA method (e.g., authenticator app) is unavailable.
   */
  backupCodes: string[];

  /**
   * A one-time token used to finalize and confirm the MFA setup
   * process on the server side.
   */
  setupToken: string;
}

/**
 * Interface representing the internal structure of a JSON
 * Web Token (JWT) payload, containing user-relevant claim
 * data and security controls.
 */
export interface TokenPayload {
  /**
   * The unique identifier of the user, correlating to
   * the application’s user store.
   */
  userId: string;

  /**
   * The user’s role, enabling resource-level authorization
   * checks based on assigned permissions.
   */
  role: UserRole;

  /**
   * Timestamp (in seconds since the Unix epoch) at which
   * the token expires and is no longer valid.
   */
  exp: number;

  /**
   * Timestamp (in seconds since the Unix epoch) at which
   * the token was originally issued.
   */
  iat: number;

  /**
   * The active session identifier correlated with the user,
   * enabling session-level tracking or revocation.
   */
  sessionId: string;

  /**
   * Identifier for the user’s device, potentially used
   * in risk-based authentication or device-specific validations.
   */
  deviceId: string;

  /**
   * An array of custom scopes or permissions assigned
   * to the user, allowing further granularity in
   * resource access beyond typical role-based checks.
   */
  scope: string[];
}

/**
 * Creates a specialized type alias to represent any API
 * response that returns authentication details in the
 * data property, leveraging the generically-typed
 * {@link ApiResponse} interface.
 */
export type AuthApiResponse = ApiResponse<AuthResponse>;