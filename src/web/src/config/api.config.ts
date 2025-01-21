/**
 * This file configures API client settings and environment-specific configurations
 * for communicating with backend microservices, including enhanced security controls,
 * real-time features, and monitoring capabilities. It implements core retry logic,
 * circuit breaker patterns, and WebSocket options for real-time communications.
 *
 * The design follows best practices for large-scale enterprise scenarios, providing:
 * - Environment-based base URL determination with fallback and validation.
 * - HTTP headers for authentication, CSRF protection, request signature, rate limiting, and compression.
 * - Response interceptors for signature validation, compression handling, metadata processing,
 *   circuit breaker state updates, and metrics logging.
 * - A unified object export for API config, including custom request/response interceptors.
 * - A retry configuration with exponential backoff capability.
 * - A WebSocket configuration object for real-time event handling.
 */

import axios /* v1.5.0 */ from 'axios';
import CircuitBreaker /* v0.5.0 */ from 'circuit-breaker-js';
import { io /* v4.7.2 */ } from 'socket.io-client';

// Internal Named Imports
import { API_VERSION, API_ENDPOINTS } from '../constants/api.constants';

/**
 * Global constants specifying runtime behavior, security, and resilience thresholds.
 */
const API_TIMEOUT: number = 30000;
const MAX_RETRIES: number = 3;
const RETRY_DELAY: number = 1000;
const RATE_LIMIT_REQUESTS: number = 100;
const RATE_LIMIT_WINDOW: number = 60000;
const CIRCUIT_BREAKER_THRESHOLD: number = 5;
const CIRCUIT_BREAKER_TIMEOUT: number = 30000;

/**
 * Maintains a global circuit breaker instance to track error volumes
 * and open/close states for API calls.
 */
const apiCircuitBreaker = new CircuitBreaker({
  timeoutDuration: CIRCUIT_BREAKER_TIMEOUT, // Determines how long the breaker stays open.
  volumeThreshold: CIRCUIT_BREAKER_THRESHOLD, // Minimum number of requests before checking error rate.
  errorThreshold: 50, // Percentage of failures that causes the breaker to trip.
});

/**
 * Returns the environment-specific base URL for API requests.
 * Steps:
 * 1) Check current environment from the 'env' parameter.
 * 2) Return corresponding environment URL if defined.
 * 3) Default to the development URL if environment is not found.
 * 4) Validate URL format before returning.
 *
 * @param {string} env - Environment name (e.g., "development", "staging", "production").
 * @returns {string} - The base URL for the specified environment.
 */
function getBaseUrl(env: string): string {
  // Map environments to their respective base URLs
  const envBaseUrls: Record<string, string> = {
    development: 'http://localhost:3000',
    staging: 'https://staging.api.myapp.com',
    production: 'https://api.myapp.com',
  };

  // Step 1 & 2: Determine URL or default to development
  const selectedUrl: string = envBaseUrls[env] || envBaseUrls.development;

  // Step 4: Validate URL format using URL constructor
  try {
    // Throws if invalid
    new URL(selectedUrl);
  } catch {
    throw new Error(`Invalid base URL: ${selectedUrl}`);
  }

  return selectedUrl;
}

/**
 * Creates the Axios request interceptor with authentication and security headers.
 * Steps:
 * 1) Add authentication token (e.g., from storage or cookie).
 * 2) Add CSRF token header.
 * 3) Add request signature header.
 * 4) Add rate limiting headers.
 * 5) Add compression headers.
 *
 * @returns {Function} - A configured request interceptor function.
 */
function createRequestInterceptor(): (config: any) => any {
  return (config: any) => {
    // Step 1: Add authentication token if available
    // (Adjust token retrieval to match your auth storage mechanism)
    const token = sessionStorage.getItem('authToken');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }

    // Step 2: Add CSRF token (placeholder)
    config.headers['X-CSRF-Token'] = 'PLACEHOLDER-CSRF-TOKEN';

    // Step 3: Add request signature (placeholder logic)
    config.headers['X-Request-Signature'] = 'PLACEHOLDER-SIGNATURE';

    // Step 4: Add rate limiting headers
    config.headers['X-RateLimit-Requests'] = RATE_LIMIT_REQUESTS.toString();
    config.headers['X-RateLimit-Window'] = RATE_LIMIT_WINDOW.toString();

    // Step 5: Add compression headers
    config.headers['Accept-Encoding'] = 'gzip, deflate, br';

    // Before sending the request, check if circuit is open
    if (apiCircuitBreaker.isOpen()) {
      throw new Error('Circuit breaker is currently open; request cannot proceed.');
    }

    return config;
  };
}

/**
 * Creates the Axios response interceptor with error handling and monitoring.
 * Steps:
 * 1) Validate response signature.
 * 2) Handle response compression (if applicable).
 * 3) Process response metadata (e.g., custom headers).
 * 4) Update circuit breaker state (success/failure).
 * 5) Log response metrics.
 *
 * @returns {Function} - A configured response interceptor function.
 */
function createResponseInterceptor(): (response: any) => any {
  return (response: any) => {
    // Step 1: Validate response signature (placeholder check)
    const signature = response?.headers?.['x-response-signature'] || '';
    if (!signature) {
      // Response signature is missing or invalid
      apiCircuitBreaker.markFailure();
      throw new Error('Invalid or missing response signature');
    }

    // Step 2: Handle response compression
    // Axios automatically handles gzip/deflate if configured, so placeholder check
    const contentEncoding = response?.headers?.['content-encoding'];
    if (contentEncoding && /(gzip|deflate|br)/.test(contentEncoding)) {
      // Typically, Axios manages the decompression transparently. Additional checks can be done if needed.
    }

    // Step 3: Process response metadata (placeholder)
    const responseMetadata = response?.headers?.['x-response-meta'] || 'none';
    // Log or handle metadata if necessary

    // Step 4: Update circuit breaker state
    if (response.status >= 200 && response.status < 300) {
      apiCircuitBreaker.markSuccess();
    } else {
      apiCircuitBreaker.markFailure();
    }

    // Step 5: Log response metrics (placeholder logging)
    // You can integrate with your monitoring solution here
    // e.g., console.log(`Metrics for request: ${JSON.stringify(response)}`);

    return response;
  };
}

/**
 * Exports an object containing comprehensive API configurations,
 * including base URL, timeouts, headers, credential settings,
 * and custom interceptors for requests and responses.
 */
export const apiConfig = {
  /**
   * The base URL for API calls, determined by current environment
   * and appended with the globally imported API_VERSION.
   */
  baseURL: `${getBaseUrl(process.env.NODE_ENV || 'development')}/${API_VERSION}`,

  /**
   * The timeout duration (in ms) for API requests before cancellation.
   */
  timeout: API_TIMEOUT,

  /**
   * Default headers applied to all requests unless overridden.
   * Additional headers can be appended by interceptors.
   */
  headers: {
    'Content-Type': 'application/json',
  },

  /**
   * Whether cross-site Access-Control requests
   * should be made using credentials such as cookies.
   */
  withCredentials: true,

  /**
   * The custom request interceptor function which includes:
   * auth token, CSRF token, request signature,
   * rate limiting headers, and compression headers.
   */
  requestInterceptor: createRequestInterceptor(),

  /**
   * The custom response interceptor function which includes:
   * signature validation, compression handling, metadata processing,
   * circuit breaker state updates, and metrics logging.
   */
  responseInterceptor: createResponseInterceptor(),
};

/**
 * Exports a retry configuration object incorporating exponential backoff.
 * - maxRetries: the maximum retry attempts allowed
 * - retryDelay: the initial delay between retries (milliseconds)
 * - retryCondition: a function to determine if a retry is warranted
 * - backoffFactor: factor by which the delay increases after each attempt
 */
export const retryConfig = {
  /**
   * Maximum number of retry attempts allowed for each request.
   */
  maxRetries: MAX_RETRIES,

  /**
   * Initial delay (in ms) between retries.
   */
  retryDelay: RETRY_DELAY,

  /**
   * Condition to evaluate if a retry should occur.
   * Returns true if error status indicates a retriable scenario.
   */
  retryCondition: (error: any) => {
    if (!error.response) {
      // Typically a network error
      return true;
    }
    // Retry for 5xx status or rate-limited responses
    return error.response.status >= 500 || error.response.status === 429;
  },

  /**
   * Factor for exponential backoff. Delay is multiplied by this factor before each retry.
   */
  backoffFactor: 2,
};

/**
 * Exports a WebSocket configuration object for real-time features.
 * - url: the WebSocket endpoint
 * - options: any Socket.IO configuration (transports, query, etc.)
 * - reconnection: settings for automatic reconnection
 */
export const wsConfig = {
  /**
   * URL pointing to the server's real-time/WebSocket endpoint.
   * It can be environment-specific if needed.
   */
  url: `${getBaseUrl(process.env.NODE_ENV || 'development')}/socket.io`,

  /**
   * Any custom options passed directly to the Socket.IO client.
   * For instance, we specify only the 'websocket' transport.
   */
  options: {
    transports: ['websocket'],
  },

  /**
   * Manages reconnection behavior, attempts, and delays.
   */
  reconnection: {
    enabled: true,
    attempts: 5,
    delay: 2000,
  },
};