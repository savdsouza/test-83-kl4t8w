/**
 * CORS Configuration Module
 * ------------------------------------------------------
 * This module defines and exports CORS (Cross-Origin Resource Sharing)
 * configuration for the API Gateway. It applies environment-specific
 * settings to enforce secure and flexible cross-origin policies,
 * aligning with the system's overall security architecture.
 */

/* External Imports */
// cors v2.8.5 - Provides type definitions and middleware for CORS configuration
import { CorsOptions } from 'cors';
// dotenv v16.3.1 - Loads environment variables from .env files
import { config as dotenvConfig } from 'dotenv';

/**
 * Load Environment Variables
 * We initialize the environment variables from the .env file or other
 * system-level configurations. This ensures we have access to all
 * necessary variables for building dynamic CORS policies.
 */
dotenvConfig();

/**
 * Extract relevant environment variables for CORS configuration.
 * NODE_ENV: Current environment (development, staging, production, etc.)
 * ALLOWED_ORIGINS: Comma-separated list of allowed origins for production.
 */
const { NODE_ENV, ALLOWED_ORIGINS } = process.env;

/**
 * Environment-Specific CORS Settings
 * ------------------------------------------------------
 * Here, we define the specific CORS properties for both development
 * and production. The 'common' object holds additional flags or
 * booleans that indicate how we want to handle more advanced or strict
 * configurations (e.g., validating each origin, disallowing wildcards).
 */
const DEV_CONFIG = {
  origin: ['http://localhost:3000', 'http://localhost:8080'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  credentials: true,
  maxAge: 86400,
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

const PROD_CONFIG = {
  // The origin array is derived by splitting the ALLOWED_ORIGINS ENV variable,
  // defaulting to an empty array if undefined.
  origin: ALLOWED_ORIGINS ? ALLOWED_ORIGINS.split(',') : [],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  credentials: true,
  maxAge: 86400,
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

const COMMON_FLAGS = {
  validateOrigin: true,  // Whether to manually validate the incoming Origin.
  allowWildcard: false,  // Whether to allow wildcard origins (we do not).
  strictPreflight: true, // Enforce strict preflight checks (no continuing).
};

/**
 * createCorsOptions()
 * ------------------------------------------------------
 * Creates and returns environment-specific CORS configuration options
 * with enhanced security measures.
 *
 * Steps:
 * 1. Determine the environment (development or production).
 * 2. Merge any applicable base configuration.
 * 3. Parse and strictly validate incoming origins if requested.
 * 4. Enforce secure defaults like limited methods and headers.
 * 5. Return the completed CORS options object.
 *
 * @returns {CorsOptions} Configured CORS options object with environment-specific settings
 */
function createCorsOptions(): CorsOptions {
  // Determine the environment and fallback to 'development' if undefined
  const environment = NODE_ENV === 'production' ? 'production' : 'development';

  // Base config for the current environment
  const envConfig = environment === 'production' ? PROD_CONFIG : DEV_CONFIG;

  // Build a final CORS options object that includes a custom 'origin' validator
  // if validateOrigin is true and allowWildcard is false.
  const corsOptions: CorsOptions = {
    // We only define origin as a callback if we want to validate each request's Origin.
    // Otherwise, we can directly supply the array contained in envConfig.origin.
    origin: COMMON_FLAGS.validateOrigin
      ? (incomingOrigin, callback): void => {
          // If no origin is present (e.g., server-to-server requests or SSR),
          // we can allow it by default, or optionally block it for stricter security.
          if (!incomingOrigin) {
            return callback(null, true);
          }

          // We allow only the explicitly listed origins from the environment config
          // if allowWildcard is false. This enforces a strict list of allowed origins.
          const allowedList = envConfig.origin as string[];
          if (allowedList.includes(incomingOrigin)) {
            return callback(null, true);
          }
          // If the origin is not in the list, block it.
          return callback(new Error('CORS: Blocked origin'), false);
        }
      : envConfig.origin,

    // HTTP methods allowed for cross-origin requests
    methods: envConfig.methods,

    // Headers that can be used during the actual request
    allowedHeaders: envConfig.allowedHeaders,

    // Headers exposed to the client
    exposedHeaders: envConfig.exposedHeaders,

    // Indicates whether the response to the request can be exposed to the
    // frontend JavaScript code when the credentials flag is true.
    credentials: envConfig.credentials,

    // Cache duration for preflight responses. A higher maxAge can reduce
    // number of preflight requests but also can lead to staleness.
    maxAge: envConfig.maxAge,

    // If true, options requests will be passed through to the next handler.
    // We set it to false to immediately return a 204 (No Content) for preflight.
    preflightContinue: COMMON_FLAGS.strictPreflight
      ? envConfig.preflightContinue
      : false,

    // The status code to use for successful OPTIONS requests
    optionsSuccessStatus: envConfig.optionsSuccessStatus,
  };

  return corsOptions;
}

/**
 * corsConfig
 * ------------------------------------------------------
 * This exported object exposes the final, ready-to-use CORS configuration
 * options through the 'corsOptions' property. It is intended to be
 * imported and applied at the API Gateway or Express-like middleware layer.
 */
export const corsConfig = {
  /**
   * corsOptions:
   * A named property that holds the result of createCorsOptions().
   * Type: CorsOptions
   */
  corsOptions: createCorsOptions(),
};
```