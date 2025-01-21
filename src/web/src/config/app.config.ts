/**
 * Core application configuration file that defines global settings,
 * environment variables, feature flags, and application metadata
 * for the Dog Walking Platform web client. This file implements
 * enhanced security features, PKCE support, and biometric
 * authentication settings in alignment with the comprehensive
 * technical specifications.
 */

// dotenv@16.3.1
import 'dotenv/config';

/**
 * Imports the application metadata constants object containing
 * the official name, version, and other descriptive properties
 * of the Dog Walking Platform.
 */
import { APP_CONFIG } from '../constants/app.constants';

/**
 * Imports the core theme configuration, including typography
 * and color specifications for type-safe usage.
 */
import { theme as ThemeConfig } from './theme.config';

/**
 * Destructures the APP_NAME and APP_VERSION from the
 * application metadata constants for easier reference below.
 */
const { APP_NAME, APP_VERSION } = APP_CONFIG;

/**
 * Captures environment variables with fallback defaults
 * for local or development scenarios. Implements basic
 * boolean checks for various feature flags and advanced
 * security toggles.
 */
const NODE_ENV: string = process.env.NODE_ENV || 'development';
const API_URL: string = process.env.REACT_APP_API_URL || 'http://localhost:3000';
const ENABLE_SECURITY_FEATURES: boolean =
  process.env.REACT_APP_ENABLE_SECURITY_FEATURES === 'true';
const ENABLE_ANALYTICS: boolean =
  process.env.REACT_APP_ENABLE_ANALYTICS === 'true';
const ENABLE_PERF_MONITORING: boolean =
  process.env.REACT_APP_ENABLE_PERF_MONITORING === 'true';
const BUILD_NUMBER: string | undefined = process.env.REACT_APP_BUILD_NUMBER;
const COMMIT_HASH: string | undefined = process.env.REACT_APP_COMMIT_HASH;
const ENABLE_BIOMETRIC: boolean =
  process.env.REACT_APP_ENABLE_BIOMETRIC === 'true';
const ENABLE_MFA: boolean = process.env.REACT_APP_ENABLE_MFA === 'true';
const GOOGLE_MAPS_KEY: string | undefined = process.env.REACT_APP_GOOGLE_MAPS_KEY;
const MAP_STYLES: string | undefined = process.env.REACT_APP_MAP_STYLES;

/**
 * Comprehensive application configuration object that centralizes
 * environment, app metadata, API endpoints, authentication workflows,
 * map integration, and security constraints. All values comply with
 * the design system and security standards outlined in the technical
 * specification.
 */
export const appConfig = {
  /**
   * Environment-related flags and feature settings that determine
   * runtime behavior across various deployment scenarios (development,
   * production, staging, etc.).
   */
  env: {
    isDevelopment: NODE_ENV === 'development',
    isProduction: NODE_ENV === 'production',
    apiUrl: API_URL,
    features: {
      enableSecurity: ENABLE_SECURITY_FEATURES,
      enableAnalytics: ENABLE_ANALYTICS,
      enablePerfMonitoring: ENABLE_PERF_MONITORING,
    },
  },

  /**
   * High-level application details, including official branding,
   * versioning, theming, localization, and build metadata.
   */
  app: {
    name: APP_NAME,
    version: APP_VERSION,
    theme: ThemeConfig,
    defaultLanguage: 'en',
    supportedLanguages: ['en', 'es', 'fr'],
    defaultTimezone: 'UTC',
    buildNumber: BUILD_NUMBER,
    commitHash: COMMIT_HASH,
  },

  /**
   * Defines global API client settings like timeouts, retries,
   * concurrency limits, and endpoint URIs to maintain consistency
   * and reliability for all network requests within the web client.
   */
  api: {
    timeout: 30000,
    retryAttempts: 3,
    retryDelay: 1000,
    maxConcurrentRequests: 10,
    endpoints: {
      auth: '/api/v1/auth',
      users: '/api/v1/users',
      walks: '/api/v1/walks',
      dogs: '/api/v1/dogs',
      payments: '/api/v1/payments',
      tracking: '/api/v1/tracking',
      notifications: '/api/v1/notifications',
    },
  },

  /**
   * Contains authentication-related configurations, covering
   * secure token policies, PKCE parameters for OAuth flows,
   * biometric login toggles, and multi-factor authentication.
   */
  auth: {
    tokenKey: 'auth_token',
    tokenExpiry: 86400,
    refreshTokenKey: 'refresh_token',
    refreshTokenExpiry: 604800,
    pkce: {
      enabled: true,
      challengeMethod: 'S256',
      verifierLength: 128,
    },
    biometric: {
      enabled: ENABLE_BIOMETRIC,
      fallbackToPassword: true,
    },
    mfa: {
      enabled: ENABLE_MFA,
      methods: ['totp', 'sms'],
    },
  },

  /**
   * Configuration object for map integrations, handling default
   * location, zoom, API key references, cluster behavior, and
   * optional custom style usage. Adheres to the platform's
   * location-based features.
   */
  maps: {
    defaultCenter: {
      lat: 40.7128,
      lng: -74.0060,
    },
    defaultZoom: 12,
    apiKey: GOOGLE_MAPS_KEY,
    clustering: {
      enabled: true,
      radius: 50,
    },
    styles: MAP_STYLES,
  },

  /**
   * Enhanced security controls, including content security policies,
   * rate-limiting thresholds, and encryption details for sensitive data.
   * Aligned with regulatory requirements and best practices.
   */
  security: {
    contentSecurity: {
      enabled: true,
      reportOnly: false,
    },
    rateLimit: {
      enabled: true,
      maxRequests: 100,
      windowMs: 900000, // 15 minutes
    },
    encryption: {
      algorithm: 'aes-256-gcm',
      keyRotationInterval: 86400, // 24 hours
    },
  },
};