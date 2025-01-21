/**
 * This file defines and exports constants for API versioning, endpoint paths, HTTP status codes,
 * and application-specific error codes. These constants are intended to be used throughout
 * the front-end application in order to maintain consistency, reduce duplication, and
 * streamline communication with backend microservices.
 *
 * The constants defined here provide:
 *  - A single source of truth for API versioning, enabling seamless upgrades and rollbacks.
 *  - Organized endpoint paths for each microservice domain (auth, users, dogs, walks, etc.).
 *  - Common HTTP status codes used for response handling in both success and error scenarios.
 *  - Application-specific error codes that allow for granular identification and handling
 *    of unique failure modes across various microservices.
 *
 * This structure ensures scalability, maintainability, and readability of the front-end
 * codebase, promoting best practices for RESTful endpoint consumption.
 */

/**
 * Represents the current version of the API.
 * Use this constant to prepend or append version information to endpoint paths,
 * ensuring that versioning changes are straightforward and globally controlled.
 */
export const API_VERSION: string = 'v1';

/**
 * Contains the organized set of endpoint paths for each microservice domain.
 * Each domain (e.g., AUTH, USERS, DOGS, WALKS, PAYMENTS, WALKERS, TRACKING) includes
 * all relevant endpoints to keep things structured and consistent. All paths are
 * defined here to avoid scattering string literals throughout the application.
 */
export const API_ENDPOINTS = {
  /**
   * Authentication-related endpoint paths including operations for login, logout,
   * registration, token refresh, password resets, and multi-factor authentication.
   */
  AUTH: {
    LOGIN: '/auth/login',
    REGISTER: '/auth/register',
    LOGOUT: '/auth/logout',
    REFRESH_TOKEN: '/auth/refresh',
    VERIFY_EMAIL: '/auth/verify-email',
    RESET_PASSWORD: '/auth/reset-password',
    FORGOT_PASSWORD: '/auth/forgot-password',
    VERIFY_PHONE: '/auth/verify-phone',
    MFA_SETUP: '/auth/mfa/setup',
    MFA_VERIFY: '/auth/mfa/verify',
  },

  /**
   * User-related endpoint paths for profile management, updating user details,
   * changing passwords, managing preferences, and uploading/verifying identity documents.
   */
  USERS: {
    BASE: '/users',
    PROFILE: '/users/profile',
    UPDATE_PROFILE: '/users/profile/update',
    CHANGE_PASSWORD: '/users/profile/password',
    PREFERENCES: '/users/preferences',
    NOTIFICATIONS: '/users/notifications',
    DOCUMENTS: '/users/documents',
    VERIFY_IDENTITY: '/users/verify-identity',
  },

  /**
   * Dog-related endpoint paths to create, retrieve, update, or delete dog profiles,
   * as well as manage the dog's medical, vaccination, behavior information, and photos.
   */
  DOGS: {
    BASE: '/dogs',
    GET_DOG: '/dogs/{id}',
    CREATE_DOG: '/dogs',
    UPDATE_DOG: '/dogs/{id}',
    DELETE_DOG: '/dogs/{id}',
    LIST_DOGS: '/dogs/list',
    MEDICAL_INFO: '/dogs/{id}/medical',
    VACCINATION: '/dogs/{id}/vaccination',
    BEHAVIOR: '/dogs/{id}/behavior',
    PHOTOS: '/dogs/{id}/photos',
  },

  /**
   * Walk-related endpoint paths that facilitate walk creation, updates, cancellations,
   * start/end actions, listing active or historical walks, tracking data, walk photos,
   * notes, ratings, issues, and emergency notifications.
   */
  WALKS: {
    BASE: '/walks',
    GET_WALK: '/walks/{id}',
    CREATE_WALK: '/walks',
    UPDATE_WALK: '/walks/{id}',
    CANCEL_WALK: '/walks/{id}/cancel',
    START_WALK: '/walks/{id}/start',
    END_WALK: '/walks/{id}/end',
    LIST_WALKS: '/walks/list',
    ACTIVE_WALKS: '/walks/active',
    WALK_HISTORY: '/walks/history',
    WALK_TRACKING: '/walks/{id}/tracking',
    WALK_PHOTOS: '/walks/{id}/photos',
    WALK_NOTES: '/walks/{id}/notes',
    WALK_RATING: '/walks/{id}/rating',
    WALK_ISSUES: '/walks/{id}/issues',
    EMERGENCY: '/walks/{id}/emergency',
  },

  /**
   * Payment-related endpoint paths used for creating and retrieving payment information,
   * listing payment histories, adding or removing payment methods, handling refunds,
   * disputes, and invoices.
   */
  PAYMENTS: {
    BASE: '/payments',
    CREATE_PAYMENT: '/payments',
    GET_PAYMENT: '/payments/{id}',
    LIST_PAYMENTS: '/payments/list',
    PAYMENT_HISTORY: '/payments/history',
    ADD_PAYMENT_METHOD: '/payments/methods',
    DELETE_PAYMENT_METHOD: '/payments/methods/{id}',
    SET_DEFAULT_METHOD: '/payments/methods/{id}/default',
    REFUND: '/payments/{id}/refund',
    DISPUTES: '/payments/disputes',
    INVOICES: '/payments/invoices',
  },

  /**
   * Walker-related endpoints supporting retrieval and listing of walkers, as well as
   * functionalities such as checking nearby walkers, managing walker availability,
   * reviews, schedules, earnings, documents, and background checks.
   */
  WALKERS: {
    BASE: '/walkers',
    GET_WALKER: '/walkers/{id}',
    LIST_WALKERS: '/walkers/list',
    NEARBY_WALKERS: '/walkers/nearby',
    WALKER_AVAILABILITY: '/walkers/{id}/availability',
    WALKER_REVIEWS: '/walkers/{id}/reviews',
    WALKER_SCHEDULE: '/walkers/{id}/schedule',
    WALKER_STATS: '/walkers/{id}/stats',
    WALKER_EARNINGS: '/walkers/{id}/earnings',
    WALKER_DOCUMENTS: '/walkers/{id}/documents',
    BACKGROUND_CHECK: '/walkers/{id}/background-check',
  },

  /**
   * Tracking-related endpoint paths focusing on real-time tracking of ongoing walks,
   * including location updates, route retrieval, geofencing, safe zones, alerts,
   * and real-time communication channels.
   */
  TRACKING: {
    BASE: '/tracking',
    UPDATE_LOCATION: '/tracking/location',
    GET_LOCATION: '/tracking/{walkId}/location',
    GET_ROUTE: '/tracking/{walkId}/route',
    GEOFENCE: '/tracking/{walkId}/geofence',
    SAFE_ZONES: '/tracking/safe-zones',
    ALERTS: '/tracking/alerts',
    REAL_TIME: '/tracking/real-time',
  },
};

/**
 * Standardized HTTP status codes used throughout the application to
 * handle various success and error scenarios, minimizing magic numbers
 * within the codebase and centralizing references.
 */
export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  ACCEPTED: 202,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
};

/**
 * A comprehensive list of error codes that uniquely identify
 * application-specific or domain-specific error conditions. These codes
 * aid in pinpointing exact failure cases, generating standardized error
 * messages, and facilitating clear and consistent handling across
 * multiple front-end and back-end services.
 */
export const ERROR_CODES = {
  INVALID_CREDENTIALS: 'AUTH_001',
  TOKEN_EXPIRED: 'AUTH_002',
  INVALID_TOKEN: 'AUTH_003',
  MFA_REQUIRED: 'AUTH_004',
  MFA_INVALID: 'AUTH_005',
  USER_NOT_FOUND: 'USER_001',
  USER_INACTIVE: 'USER_002',
  INVALID_DOCUMENT: 'USER_003',
  DOG_NOT_FOUND: 'DOG_001',
  INVALID_DOG_INFO: 'DOG_002',
  VACCINATION_EXPIRED: 'DOG_003',
  WALK_NOT_FOUND: 'WALK_001',
  WALK_ALREADY_STARTED: 'WALK_002',
  WALK_ALREADY_ENDED: 'WALK_003',
  WALK_CANCELLATION_LATE: 'WALK_004',
  PAYMENT_FAILED: 'PAY_001',
  INSUFFICIENT_FUNDS: 'PAY_002',
  INVALID_PAYMENT_METHOD: 'PAY_003',
  REFUND_NOT_ALLOWED: 'PAY_004',
  WALKER_NOT_FOUND: 'WALKER_001',
  WALKER_UNAVAILABLE: 'WALKER_002',
  BACKGROUND_CHECK_FAILED: 'WALKER_003',
  TRACKING_ERROR: 'TRACK_001',
  GEOFENCE_VIOLATION: 'TRACK_002',
  LOCATION_UNAVAILABLE: 'TRACK_003',
};