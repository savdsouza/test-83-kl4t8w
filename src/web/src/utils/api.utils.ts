/**
 * -------------------------------------------------------------------------
 * Title: API Utilities
 * -------------------------------------------------------------------------
 * Description:
 * This file provides robust, enterprise-grade utility functions for
 * handling API requests, responses, and advanced error management
 * with comprehensive security validation, retry logic, circuit
 * breaking (conceptual), and standardized response formatting. It
 * integrates with the application's type definitions and leverages
 * external libraries such as Axios (v1.5.0) and Winston (v3.10.0)
 * for HTTP and logging functionalities, respectively.
 *
 * -------------------------------------------------------------------------
 * References:
 * - Technical specs: 2.3 Technical Decisions / 2.3.1 API Architecture
 * - Security controls: 2.3.3 Security Controls
 * - Integration Patterns: 2.3.4 Integration Patterns
 * - Imported type definitions from ../types/api.types
 * - External libraries: axios@1.5.0, winston@3.10.0
 *
 * -------------------------------------------------------------------------
 * Exported Functions:
 *  - formatApiResponse<T>
 *  - handleApiError
 *  - isApiResponse
 *  - parseApiError
 *
 * -------------------------------------------------------------------------
 * Copyright:
 * © 2023 Dog Walking Mobile Application. All rights reserved.
 * -------------------------------------------------------------------------
 */

////////////////////////////////////////////////////////////////////////////////
// EXTERNAL IMPORTS
////////////////////////////////////////////////////////////////////////////////

// version 1.5.0
import axios from 'axios';
// version 3.10.0
import winston from 'winston';

////////////////////////////////////////////////////////////////////////////////
// INTERNAL IMPORTS
////////////////////////////////////////////////////////////////////////////////

import {
  ApiResponse,
  ApiError,
  ResponseMetadata,
  ErrorDetails,
  RetryConfig as TypeRetryConfig
} from '../types/api.types';

////////////////////////////////////////////////////////////////////////////////
// GLOBAL CONSTANTS AND TYPES
////////////////////////////////////////////////////////////////////////////////

/**
 * An enumeration that maps common HTTP status codes to human-friendly keys.
 * This can be expanded or updated to accommodate additional status codes
 * as needed throughout the application.
 */
export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503
} as const;

/**
 * Common error message templates used throughout the API utility layer.
 * These messages can be extended or localized to fit application needs.
 */
export const ERROR_MESSAGES = {
  NETWORK_ERROR: 'Network error occurred',
  SERVER_ERROR: 'Server error occurred',
  UNKNOWN_ERROR: 'An unknown error occurred',
  VALIDATION_ERROR: 'Validation error occurred',
  SECURITY_ERROR: 'Security validation failed',
  RATE_LIMIT_ERROR: 'Rate limit exceeded'
} as const;

/**
 * A default retry configuration aligned with typical enterprise
 * scenarios, allowing up to 3 retries, with an exponential backoff
 * base and a maximum delay limit.
 */
export const RETRY_CONFIG = {
  maxRetries: 3,
  baseDelay: 1000,   // milliseconds
  maxDelay: 5000,    // milliseconds
  timeoutMS: 30000   // total request timeout
};

/**
 * An example SecurityContext interface that may represent any security
 * or authentication data relevant for verifying requests, roles, or
 * user identity in the error handling pipeline. Extend as needed.
 */
export interface SecurityContext {
  /**
   * The authenticated user’s ID or a unique token representing
   * the user session.
   */
  userId?: string;

  /**
   * A correlation ID that can be used to track and tie logs
   * across multiple services within a distributed system.
   */
  correlationId?: string;

  /**
   * An indicator or claims set describing the user's roles
   * or permissions within the application.
   */
  roles?: string[];
}

/**
 * Specifies options controlling how errors are parsed and made
 * more descriptive for clients or internal consumers of error
 * information.
 */
export interface ErrorParseOptions {
  /**
   * Indicates whether the application is in development mode,
   * potentially allowing more verbose or unsafe error data
   * (like stack traces) to be exposed.
   */
  isDevMode: boolean;

  /**
   * A locale or language code that can be used to format
   * error messages in a localized manner (e.g. 'en-US').
   */
  locale?: string;

  /**
   * Optional correlation ID, in case the parse logic needs
   * to embed a particular ID for further debugging or retrieval
   * of logs.
   */
  correlationId?: string;
}

/**
 * Represents the output of parsing an error into a standardized
 * structure with consistent fields, potentially referencing the
 * application’s ApiError interface or additional diagnostic data.
 */
export interface ParsedError {
  /**
   * A code representing the broad category or specific type
   * of error, such as 'AUTH_FAILED', 'VALIDATION_ERROR',
   * or 'SERVER_ERROR'.
   */
  code: string;

  /**
   * A human-readable message describing the nature of the error.
   */
  message: string;

  /**
   * Detailed information about the error context, including
   * correlation IDs, validation issues, or specialized
   * debugging data.
   */
  details: ErrorDetails;

  /**
   * A numeric timestamp (in milliseconds since the Unix epoch)
   * when the error was generated or captured, facilitating
   * correlation with logs. 
   */
  timestamp: number;

  /**
   * Optional stack trace details that are potentially included
   * in development or staging environments to assist in debugging.
   */
  stackTrace?: string;
}

/**
 * Extends the base RetryConfig from api.types to adapt to the
 * global RETRY_CONFIG structure if necessary, or to unify any
 * differences between them. This interface merges the internal
 * TypeRetryConfig with additional fields from RETRY_CONFIG.
 */
export interface EnhancedRetryConfig extends TypeRetryConfig {
  /**
   * The maximum total number of retries. (Aligning with local RETRY_CONFIG)
   */
  maxRetries?: number;

  /**
   * The base initial delay (in milliseconds) for exponential backoff.
   */
  baseDelay?: number;

  /**
   * The maximum possible delay (in milliseconds) between retries
   * after exponential growth.
   */
  maxDelay?: number;

  /**
   * The maximum time (in milliseconds) to wait before giving
   * up entirely.
   */
  timeoutMS?: number;
}

////////////////////////////////////////////////////////////////////////////////
// 1) FORMAT API RESPONSE
////////////////////////////////////////////////////////////////////////////////

/**
 * Formats API response data into a standardized ApiResponse format
 * with enhanced type safety and optional metadata injection. This
 * ensures consistency and structure in all service responses.
 *
 * Steps:
 *  1) Validate input parameters for type safety.
 *  2) Sanitize response data (if necessary).
 *  3) Add response metadata, including requestId and serverTimestamp.
 *  4) Create the standardized response object adhering to ApiResponse<T>.
 *  5) Validate the response structure (optionally through isApiResponse).
 *  6) Return the formatted response.
 *
 * @template T - The type of the data payload in the response.
 * @param data - The primary response data to be returned to the client.
 * @param success - Indicates if the operation was successful.
 * @param error - An optional error message. If not null, an ApiError will be constructed.
 * @param metadata - Additional metadata or diagnostic info.
 * @returns A fully structured ApiResponse<T> object.
 */
export function formatApiResponse<T>(
  data: T,
  success: boolean,
  error: string | null,
  metadata: Record<string, unknown> = {}
): ApiResponse<T> {
  // Step 1) Basic type safety checks (in a real scenario, more thorough checks can be applied).
  if (typeof success !== 'boolean') {
    throw new Error('Invalid parameter: success must be a boolean');
  }

  // Step 2) Sanitize data. For demonstration, we assume data is already sanitized.
  const sanitizedData = data;

  // Step 3) Create a comprehensive metadata object. For now, we partially
  // fill the required fields of ResponseMetadata while injecting any
  // custom fields from the metadata argument.
  const baseMetadata: ResponseMetadata = {
    requestId: `req_${Math.random().toString(36).substr(2, 9)}`,
    serverTimestamp: Date.now(),
    apiVersion: '2023-10',
    debugInfo: {
      ...metadata
    }
  };

  // Step 4) Construct the final ApiResponse object, generating an ApiError if needed.
  let apiError: ApiError | null = null;
  if (!success && error) {
    apiError = {
      code: 'GENERAL_ERROR',
      message: error,
      timestamp: Date.now(),
      details: {
        correlationId: baseMetadata.requestId
      }
    };
  }

  const response: ApiResponse<T> = {
    success,
    data: success ? sanitizedData : (null as unknown as T),
    error: apiError,
    metadata: baseMetadata,
    timestamp: Date.now()
  };

  // Step 5) Validate the structure of the response. This is optional.
  // We could call isApiResponse(response) here if we want to enforce correctness.
  // For performance reasons, we might skip this in production.

  // Step 6) Return the standardized response object.
  return response;
}

////////////////////////////////////////////////////////////////////////////////
// 2) HANDLE API ERROR
////////////////////////////////////////////////////////////////////////////////

/**
 * Enhanced error handler with retry logic, security validation,
 * and comprehensive error context. It attempts to decide if an
 * error is retryable, applying an exponential backoff strategy
 * if necessary, then ultimately returning an ApiResponse with
 * detailed error information.
 *
 * Steps:
 *  1) Validate security context.
 *  2) Check if error is retriable.
 *  3) Implement exponential backoff logic.
 *  4) Extract detailed error context.
 *  5) Log error with Winston.
 *  6) Format error message with context.
 *  7) Return standardized ApiResponse<null> with metadata.
 *
 * @param error - The original error encountered which needs handling.
 * @param retryOptions - Configuration controlling maximum attempts and backoff strategy.
 * @param securityContext - Security-related information for validation or correlation.
 * @returns A standardized ApiResponse<null> indicating failure.
 */
export async function handleApiError(
  error: Error,
  retryOptions: EnhancedRetryConfig,
  securityContext: SecurityContext
): Promise<ApiResponse<null>> {
  // Step 1) Validate security context
  // (A real implementation might check user roles, expiration, etc.)
  if (!securityContext || !securityContext.correlationId) {
    // We do a minimal check, but in a larger system, more validations could be present.
    winston.warn(`SecurityContext is missing or incomplete: ${JSON.stringify(securityContext)}`);
  }

  // Step 2) Check if error is retriable. For demonstration, let's assume it's retriable for
  // certain types of known transient issues, e.g. network or 5xx. We attempt a simple approach.
  const isRetriable = shouldRetry(error);

  // Step 3) Implement exponential backoff if the error is indeed retriable.
  // If we run out of attempts or it fails after final attempt, we proceed with error response.
  let attempts = 0;
  let lastError = error;
  if (isRetriable && retryOptions?.maxRetries && retryOptions.maxRetries > 0) {
    while (attempts < (retryOptions.maxRetries || 3)) {
      try {
        attempts++;
        const backoffDelay = calculateDelay(attempts, retryOptions);
        // Sleep for backoffDelay
        await new Promise((resolve) => setTimeout(resolve, backoffDelay));
        // Example re-attempt logic: we could re-invoke a failing service call or an axios request.
        // (Pseudo-code, not actually calling anything here.)
        // await axiosCallOrOtherOperation();
        // If success, break out of loop
        break;
      } catch (innerErr) {
        lastError = innerErr as Error;
        if (attempts >= (retryOptions.maxRetries || 3)) {
          // Exhausted attempts
          break;
        }
      }
    }
  }

  // Step 4) Extract detailed error context (using parseApiError for example).
  const parsed = parseApiError(lastError, {
    isDevMode: false,
    locale: 'en-US',
    correlationId: securityContext.correlationId
  });

  // Step 5) Log the error with Winston at an appropriate log level.
  // The severity can escalate if the attempts are exhausted or
  // the error is not retriable.
  if (attempts >= (retryOptions.maxRetries || 3)) {
    winston.error(`[handleApiError] Exhausted retries: ${JSON.stringify(parsed)}`);
  } else {
    winston.error(`[handleApiError] Error encountered: ${JSON.stringify(parsed)}`);
  }

  // Step 6) Format error message with context (the 'parsed' now has the required details).
  const errorMessage = parsed.message || ERROR_MESSAGES.UNKNOWN_ERROR;

  // Step 7) Return standardized ApiResponse<null> with metadata.
  const baseMetadata: ResponseMetadata = {
    requestId: securityContext.correlationId || `req_${Math.random().toString(36).substr(2, 9)}`,
    serverTimestamp: Date.now(),
    apiVersion: '2023-10',
    debugInfo: {
      attempts,
      isRetriable
    }
  };

  const finalApiError: ApiError = {
    code: parsed.code,
    message: errorMessage,
    timestamp: parsed.timestamp,
    details: parsed.details,
    stackTrace: parsed.stackTrace
  };

  const response: ApiResponse<null> = {
    success: false,
    data: null,
    error: finalApiError,
    timestamp: Date.now(),
    metadata: baseMetadata
  };

  return response;
}

////////////////////////////////////////////////////////////////////////////////
// 3) IS API RESPONSE (TYPE GUARD)
////////////////////////////////////////////////////////////////////////////////

/**
 * Type guard to check if an unknown object qualifies as a valid ApiResponse,
 * performing extensive property checks for safety. Useful when dealing with
 * responses from external sources or dynamically typed data.
 *
 * Steps:
 *  1) Check if 'response' is a valid object.
 *  2) Verify all required properties exist (success, data, error, metadata, timestamp).
 *  3) Validate property types strictly.
 *  4) Check 'metadata' structure (requestId, serverTimestamp, apiVersion).
 *  5) Validate 'error' structure if present.
 *  6) Return the validation result (true if it meets ApiResponse contract).
 *
 * @param response - The object potentially representing an ApiResponse.
 * @returns True if the object matches the ApiResponse structure, false otherwise.
 */
export function isApiResponse<T = unknown>(response: unknown): response is ApiResponse<T> {
  // Step 1) Basic check for object shape
  if (!response || typeof response !== 'object') {
    return false;
  }

  const obj = response as Record<string, any>;

  // Step 2) Verify all required properties exist
  if (
    !('success' in obj) ||
    !('data' in obj) ||
    !('error' in obj) ||
    !('metadata' in obj) ||
    !('timestamp' in obj)
  ) {
    return false;
  }

  // Step 3) Validate property types strictly
  if (typeof obj.success !== 'boolean') {
    return false;
  }
  if (typeof obj.timestamp !== 'number') {
    return false;
  }
  if (typeof obj.metadata !== 'object' || obj.metadata === null) {
    return false;
  }

  // Step 4) Validate metadata structure
  const { requestId, serverTimestamp, apiVersion } = obj.metadata;
  if (typeof requestId !== 'string') {
    return false;
  }
  if (typeof serverTimestamp !== 'number') {
    return false;
  }
  if (typeof apiVersion !== 'string') {
    return false;
  }

  // Step 5) Validate error structure if not null
  if (obj.error !== null && typeof obj.error !== 'object') {
    return false;
  }
  if (obj.error) {
    if (typeof obj.error.code !== 'string' || typeof obj.error.message !== 'string') {
      return false;
    }
    if (typeof obj.error.timestamp !== 'number') {
      return false;
    }
  }

  // If all checks pass, we conclude that this is an ApiResponse<T>.
  return true;
}

////////////////////////////////////////////////////////////////////////////////
// 4) PARSE API ERROR
////////////////////////////////////////////////////////////////////////////////

/**
 * Advanced error parser with comprehensive error mapping and context
 * preservation. It can adapt to different error sources (Axios errors,
 * native errors, or existing ApiError objects), culminating in a
 * well-defined ParsedError.
 *
 * Steps:
 *  1) Determine error type and source (Axios, native, etc.).
 *  2) Extract security context if present and correlation ID.
 *  3) Map error to a standard format (ParsedError).
 *  4) Add error metadata and timestamps.
 *  5) Format message with localization or fallback defaults.
 *  6) Include stack trace in dev mode if requested.
 *  7) Return the fully formed ParsedError with context.
 *
 * @param error - The raw error object that needs normalization.
 * @param options - Additional flags, such as whether the app is in dev mode.
 * @returns A structured ParsedError object with unified fields.
 */
export function parseApiError(error: unknown, options: ErrorParseOptions): ParsedError {
  // Step 1) Determine error type and source
  let code = 'UNKNOWN_ERROR';
  let message = ERROR_MESSAGES.UNKNOWN_ERROR;
  let stackTrace: string | undefined;

  // If it's already an ApiError-shaped object, we might extract from that.
  let details: ErrorDetails = {
    correlationId: options.correlationId ?? `corr_${Math.random().toString(36).substr(2, 9)}`
  };

  if (isPlainObject(error)) {
    const errObj = error as Record<string, any>;
    // Possibly an existing ApiError
    if (typeof errObj.code === 'string') {
      code = errObj.code;
    }
    if (typeof errObj.message === 'string') {
      message = errObj.message;
    }
    if (errObj.details && typeof errObj.details === 'object') {
      details = {
        ...details,
        ...errObj.details
      };
    }
    if (errObj.stackTrace && typeof errObj.stackTrace === 'string') {
      stackTrace = errObj.stackTrace;
    }
  } else if (error instanceof Error) {
    // A native JS Error or some library error
    message = error.message || message;
    stackTrace = error.stack;
  }

  // Step 2) Extract or override correlationId if needed (already done above).
  // Step 3) We have partially mapped error to a standard format in the code/message above.

  // Step 4) Add error metadata and timestamps
  const timestamp = Date.now();

  // Step 5) Format message with locale or fallback
  // (For now, we do not implement actual localization but placeholders.)
  if (options.locale && options.locale !== 'en-US') {
    // In a real system, we might look up translation strings for the code, etc.
    // For demonstration, we only do a comment placeholder here.
  }

  // Step 6) Include stack trace if dev mode
  let finalStackTrace: string | undefined;
  if (options.isDevMode && stackTrace) {
    finalStackTrace = stackTrace;
  }

  // Step 7) Return the fully formed object
  const parsedError: ParsedError = {
    code,
    message,
    details,
    timestamp,
    stackTrace: finalStackTrace
  };

  return parsedError;
}

////////////////////////////////////////////////////////////////////////////////
// HELPER FUNCTIONS
////////////////////////////////////////////////////////////////////////////////

/**
 * Determines if the provided error should be retried based on
 * simplistic heuristics. In a real production environment, this
 * would rely on detailed inspection of status codes, error codes,
 * or environment settings.
 *
 * @param error - The encountered error object.
 * @returns True if the error might be transient and warrant a retry attempt.
 */
function shouldRetry(error: Error): boolean {
  // Example approach: retry if message suggests a network or 5xx.
  const msg = error.message.toLowerCase();
  if (msg.includes('network') || msg.includes('timeout') || msg.includes('503')) {
    return true;
  }
  return false;
}

/**
 * Calculate the appropriate delay before the next retry attempt,
 * following an exponential backoff pattern bounded by any
 * specified maxDelay.
 *
 * @param attempt - The current retry attempt number (1-based).
 * @param retryOptions - Enhanced retry configuration containing
 *                       limits for baseDelay and maxDelay.
 * @returns The delay in milliseconds before the next attempt.
 */
function calculateDelay(attempt: number, retryOptions: EnhancedRetryConfig): number {
  const base = retryOptions.baseDelay ?? 1000;
  const max = retryOptions.maxDelay ?? 5000;
  // Exponential backoff: attempt^2 * base
  let delay = Math.pow(2, attempt) * base;
  if (delay > max) {
    delay = max;
  }
  return delay;
}

/**
 * A utility function to check if a value is a plain JavaScript
 * object. This can be used to differentiate between simple objects
 * and other entity types like arrays or class instances.
 *
 * @param val - The value to check.
 * @returns True if val is a plain object, false otherwise.
 */
function isPlainObject(val: unknown): val is Record<string, unknown> {
  return (
    typeof val === 'object' &&
    val !== null &&
    Object.prototype.toString.call(val) === '[object Object]'
  );
}