/**
 * Routes Constants for the Dog Walking Platform Web Interface
 * 
 * This file consolidates all route paths used throughout the web application,
 * ensuring a single, centralized, and type-safe reference for navigation.
 * 
 * Addresses the following requirements based on the Technical Specifications:
 * 1. Core Screen Layouts (Section 6.2) - Defines route constants for core
 *    owner and walker screens, active walks, profiles, and dashboards.
 * 2. Authentication Flow (Section 7.1.1) - Implements route paths for login,
 *    registration, password resets, email verification, and two-factor flows.
 * 3. Navigation Structure (Section 6.1) - Supports a hierarchical navigation
 *    system for dashboards, user management, dog management, payments, walks,
 *    and settings.
 *
 * All routes are exported as constants for easy integration across components.
 * The route definitions are organized into logical groups for scalability
 * and maintainability.
 */

/* =========================================================================
 * AUTH_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Holds all route paths related to authentication and authorization.
 * INCLUDES: Login, Registration, Password Management, 2FA, etc.
 * ========================================================================= */
export const AUTH_ROUTES = {
  /** Login screen for existing users */
  LOGIN: '/auth/login',
  /** Registration screen for new users */
  REGISTER: '/auth/register',
  /** Forgot Password screen to request password reset */
  FORGOT_PASSWORD: '/auth/forgot-password',
  /** Reset Password screen to set a new password with token-based verification */
  RESET_PASSWORD: '/auth/reset-password/:token',
  /** Email Verification endpoint for completing user onboarding */
  VERIFY_EMAIL: '/auth/verify-email/:token',
  /** Two-Factor Authentication flow for additional security */
  TWO_FACTOR: '/auth/2fa',
  /** Logout endpoint to invalidate user session */
  LOGOUT: '/auth/logout',
} as const;

/* =========================================================================
 * DASHBOARD_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Holds route paths related to user dashboard areas, covering both
 * owner and walker home screens, analytics, earnings, reports, and scheduling.
 * ========================================================================= */
export const DASHBOARD_ROUTES = {
  /** Owner Home dashboard view */
  OWNER_HOME: '/dashboard/owner',
  /** Walker Home dashboard view */
  WALKER_HOME: '/dashboard/walker',
  /** Analytics overview for platform usage and metrics */
  ANALYTICS: '/dashboard/analytics',
  /** Earnings view for walker financial summaries */
  EARNINGS: '/dashboard/earnings',
  /** Reports section for administrative or advanced analytics data */
  REPORTS: '/dashboard/reports',
  /** Schedule management for owners or walkers */
  SCHEDULE: '/dashboard/schedule',
} as const;

/* =========================================================================
 * DOG_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Consolidates route paths for managing and viewing dog profiles,
 * medical info, and historical data.
 * ========================================================================= */
export const DOG_ROUTES = {
  /** Lists all dogs associated with an owner */
  LIST: '/dogs',
  /** Displays information about a specific dog */
  DETAILS: '/dogs/:id',
  /** Creation form for adding a new dog profile */
  NEW: '/dogs/new',
  /** Editing form for an existing dog profile */
  EDIT: '/dogs/:id/edit',
  /** Medical info management for a specific dog */
  MEDICAL: '/dogs/:id/medical',
  /** Historical walk details for a specific dog */
  HISTORY: '/dogs/:id/history',
} as const;

/* =========================================================================
 * WALK_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Covers route paths for handling all aspects of walks, from listing
 * and creating walks to active monitoring, reviews, and emergency handling.
 * ========================================================================= */
export const WALK_ROUTES = {
  /** Lists all walks for owner or walker, depending on role */
  LIST: '/walks',
  /** Screen for tracking an active walk session by its ID */
  ACTIVE: '/walks/active/:id',
  /** Dedicated tracking interface for real-time GPS data */
  TRACKING: '/walks/tracking/:id',
  /** Detailed view of a completed or scheduled walk */
  DETAILS: '/walks/:id',
  /** Creation flow for a new walk booking */
  NEW: '/walks/new',
  /** Editing flow for modifying an existing walk */
  EDIT: '/walks/:id/edit',
  /** Post-walk review and rating submission */
  REVIEW: '/walks/:id/review',
  /** Emergency / incident reporting during an active walk */
  EMERGENCY: '/walks/:id/emergency',
} as const;

/* =========================================================================
 * PAYMENT_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Holds route paths related to payment activities, including listing
 * and viewing transactions, adding new methods, and displaying invoices.
 * ========================================================================= */
export const PAYMENT_ROUTES = {
  /** Lists all payment transactions for a user */
  LIST: '/payments',
  /** Detailed view of a single payment transaction */
  DETAILS: '/payments/:id',
  /** Screen to initiate a new payment or add a payment method */
  NEW: '/payments/new',
  /** View and manage stored payment methods */
  METHODS: '/payments/methods',
  /** Historical payment logs for auditing and reference */
  HISTORY: '/payments/history',
  /** Invoice records and billing statements */
  INVOICES: '/payments/invoices',
} as const;

/* =========================================================================
 * USER_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Provides route paths for user profile management, verification,
 * document uploads, reviews, and availability setting.
 * ========================================================================= */
export const USER_ROUTES = {
  /** Current user's main profile interface */
  PROFILE: '/users/profile',
  /** Walker-specific profile view shared with owners */
  WALKER_PROFILE: '/users/walker-profile',
  /** Verification workflow for background checks and ID uploads */
  VERIFICATION: '/users/verification',
  /** Document upload and management section */
  DOCUMENTS: '/users/documents',
  /** Displays and manages user reviews and ratings */
  REVIEWS: '/users/reviews',
  /** Availability settings for walkers to define their schedules */
  AVAILABILITY: '/users/availability',
} as const;

/* =========================================================================
 * SETTINGS_ROUTES
 * -------------------------------------------------------------------------
 * PURPOSE: Groups all route paths for application settings such as profile
 * details, security configurations, notification preferences, and billing.
 * ========================================================================= */
export const SETTINGS_ROUTES = {
  /** Main entry point for the settings section */
  MAIN: '/settings',
  /** Personal profile adjustments */
  PROFILE: '/settings/profile',
  /** Security features like password changes or two-factor toggle */
  SECURITY: '/settings/security',
  /** Notification preference configuration */
  NOTIFICATIONS: '/settings/notifications',
  /** General user preferences within the platform */
  PREFERENCES: '/settings/preferences',
  /** Privacy-related settings including data sharing policies */
  PRIVACY: '/settings/privacy',
  /** Billing options, methods, and subscriptions */
  BILLING: '/settings/billing',
} as const;