/**
 * Core type definitions for the API Gateway service including authentication,
 * request/response types, and shared interfaces used across the application.
 * This file implements robust, production-ready, schema-compliant code to meet
 * all specification requirements.
 */

// ----------------------------------------------------------------------------
// External Imports (with version comments)
// ----------------------------------------------------------------------------
import { Request } from 'express' // express@4.18.2
import * as jwt from 'jsonwebtoken' // jsonwebtoken@9.0.2

// ----------------------------------------------------------------------------
// Global Enumerations
// ----------------------------------------------------------------------------

/**
 * UserRole
 * This enumeration defines the possible roles for any authenticated user
 * within the application, aligning with the system's authorization model
 * to ensure role-based access control in API interactions.
 */
export enum UserRole {
  /**
   * OWNER: Represents a dog owner user role.
   */
  OWNER = 'owner',

  /**
   * WALKER: Represents a dog walker user role.
   */
  WALKER = 'walker',

  /**
   * ADMIN: Represents an administrator role with elevated privileges.
   */
  ADMIN = 'admin',
}

/**
 * AuthProvider
 * This enumeration specifies the supported authentication providers for the
 * platform, allowing for both email/password and social logins.
 */
export enum AuthProvider {
  /**
   * EMAIL: Standard email and password authentication flow.
   */
  EMAIL = 'email',

  /**
   * GOOGLE: OAuth2-based login via Google.
   */
  GOOGLE = 'google',

  /**
   * APPLE: OAuth2-based login via Apple.
   */
  APPLE = 'apple',

  /**
   * FACEBOOK: OAuth2-based login via Facebook.
   */
  FACEBOOK = 'facebook',
}

// ----------------------------------------------------------------------------
// Interface: UserPayload
// ----------------------------------------------------------------------------

/**
 * UserPayload
 * Represents the claims included in the JWT token payload, integrating with
 * the application's role-based access control and authentication flows.
 * This interface extends jwt.JwtPayload to incorporate standard JWT fields
 * if needed, while adding domain-specific user properties.
 */
export interface UserPayload extends jwt.JwtPayload {
  /**
   * Unique identifier for the user in the system.
   */
  id: string;

  /**
   * The email address associated with the user account.
   */
  email: string;

  /**
   * The current role of the user, indicating their permissions level.
   */
  role: UserRole;

  /**
   * The Date object specifying when this user account was created.
   */
  createdAt: Date;

  /**
   * The Date object specifying the last login time for this user.
   */
  lastLogin: Date;

  /**
   * Flag indicating if the user has completed the necessary verification steps.
   */
  verified: boolean;
}

// ----------------------------------------------------------------------------
// Interface: AuthenticatedRequest
// ----------------------------------------------------------------------------

/**
 * AuthenticatedRequest
 * An extended Express.js Request type that includes an authenticated user's
 * information derived from the JWT token. Use this interface in routes
 * requiring authorization, ensuring that the 'user' field is present
 * and validated.
 */
export interface AuthenticatedRequest extends Request {
  /**
   * The authenticated user's payload derived from the token.
   */
  user: UserPayload;
}

// ----------------------------------------------------------------------------
// Interface: LoginRequest
// ----------------------------------------------------------------------------

/**
 * LoginRequest
 * Defines the structure for incoming login requests, supporting both
 * traditional email/password authentication and social login providers.
 */
export interface LoginRequest {
  /**
   * The email supplied by the user during login.
   */
  email: string;

  /**
   * The password supplied by the user. Required if provider is 'email'.
   */
  password: string;

  /**
   * An enum value indicating which authentication provider is being used.
   */
  provider: AuthProvider;
}

// ----------------------------------------------------------------------------
// Interface: RegisterRequest
// ----------------------------------------------------------------------------

/**
 * RegisterRequest
 * Defines the structure for user registration, including essential
 * profile details such as email, role, and contact information. Allows
 * the client to store user preferences in an unstructured object.
 */
export interface RegisterRequest {
  /**
   * The email address for account creation.
   */
  email: string;

  /**
   * The password for account security.
   */
  password: string;

  /**
   * The role of the user, determining access levels in the application.
   */
  role: UserRole;

  /**
   * The display or real-world name for the user account.
   */
  name: string;

  /**
   * Phone number for contact or verification purposes.
   */
  phone: string;

  /**
   * URL or reference to the user's profile picture.
   */
  profilePicture: string;

  /**
   * Preferred settings for the user, represented as an unstructured object.
   */
  preferences: object;
}

// ----------------------------------------------------------------------------
// Interface: AuthResponse
// ----------------------------------------------------------------------------

/**
 * AuthResponse
 * Defines the structure for authentication responses, encapsulating both the
 * access and refresh tokens, as well as the authorized user's payload details.
 */
export interface AuthResponse {
  /**
   * The short-lived token authorizing the user to access protected resources.
   */
  accessToken: string;

  /**
   * The long-lived token used to refresh the session after the access token
   * expires.
   */
  refreshToken: string;

  /**
   * Detailed user information corresponding to the current session, including
   * role and verification status.
   */
  user: UserPayload;
}

// ----------------------------------------------------------------------------
// Interface: ApiError
// ----------------------------------------------------------------------------

/**
 * ApiError
 * A standardized error response structure for the API, ensuring consistent
 * error details presentation. Includes debugging data such as stack traces
 * and error codes to facilitate rapid troubleshooting.
 */
export interface ApiError {
  /**
   * Numeric code representing the particular error scenario (e.g., 400, 401).
   */
  code: number;

  /**
   * Human-readable message describing the cause of the error.
   */
  message: string;

  /**
   * Optional object containing additional metadata or contextual information
   * relevant to the error.
   */
  details: object;

  /**
   * Stack trace or debugging information (should be omitted in production
   * environments).
   */
  stack: string;

  /**
   * Timestamp indicating when the error occurred, aiding in log correlation.
   */
  timestamp: Date;
}