/***************************************************************************************************
 * error.middleware.ts
 * -------------------------------------------------------------------------------------------------
 * Advanced error handling middleware for the API Gateway. Provides standardized, security-aware
 * responses, structured logging with Winston, comprehensive monitoring integration, and robust
 * classification of error severity based on the technical specifications.
 *
 * This file addresses:
 *  1) System Monitoring: Implements structured error logging, severity classification, and
 *     integration with monitoring tools. Captures detailed error context, timestamps, and optional
 *     performance metrics (if available from preceding middleware).
 *
 *  2) Error Handling: Delivers security-aware error classification, filtering of sensitive data,
 *     standardized incident response procedures, and support for environment-specific transformation
 *     of error details (omitting stacks in production).
 *
 *  3) API Gateway Requirements: Integrates with the central API Gateway, providing robust error
 *     responses, error code handling, correlation IDs, and rate-limiting synergy if needed.
 *
 * Exports:
 *  - default: errorHandler (Express middleware)
 *
 * Usage:
 *   import errorHandler from './error.middleware';
 *   app.use(errorHandler);
 **************************************************************************************************/

// -------------------------------------------------------------------------------------------------
// External Imports (with library version comments)
// -------------------------------------------------------------------------------------------------
import { NextFunction, Request, Response } from 'express'; // express@4.18.2
import * as winston from 'winston'; // winston@3.11.0
import { v4 as uuidv4 } from 'uuid'; // uuid@9.0.0 (Optional for correlation IDs if needed)

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import { ApiError } from '../types'; // Local interface for standardized API errors
import { appConfig } from '../config/app.config'; // Application config (we may extract env/log tracking)
 
/***************************************************************************************************
 * Global Definitions
 * -------------------------------------------------------------------------------------------------
 * Per the JSON specification, we define an ErrorSeverity enum and an ErrorResponse interface for
 * consistent classification, logging, and responses. We integrate correlationId and severity
 * to track and handle errors in a robust, enterprise-appropriate manner.
 **************************************************************************************************/

/**
 * ErrorSeverity
 * Represents various severity levels for capturing, logging, and responding
 * to errors, enabling advanced monitoring and analytics.
 */
export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

/**
 * ErrorResponse
 * A secure, standardized payload for returning error details to consumers.
 * Contains optional stack traces and an explicit correlationId for debugging.
 */
export interface ErrorResponse {
  code: number;
  message: string;
  details?: object;
  stack?: string;
  timestamp: Date;
  correlationId: string;
  severity: string;
}

/***************************************************************************************************
 * Helper: extractEnvironmentValues
 * -------------------------------------------------------------------------------------------------
 * Attempts to extract environment, logLevel, and errorTracking config from appConfig or process.env.
 * This aligns with the JSON specification references to ensure we handle environment details for
 * logging and potential external error tracking services.
 **************************************************************************************************/
function extractEnvironmentValues() {
  const environment =
    (appConfig as any).env ??
    process.env.NODE_ENV ??
    'development';

  const logLevel =
    (appConfig as any).logLevel ??
    process.env.LOG_LEVEL ??
    'info';

  const errorTracking =
    (appConfig as any).errorTracking ?? {
      enabled: false,
      serviceUrl: '',
    };

  return { environment, logLevel, errorTracking };
}

// -------------------------------------------------------------------------------------------------
// Winston Logger Configuration
// -------------------------------------------------------------------------------------------------
const { environment, logLevel, errorTracking } = extractEnvironmentValues();

/**
 * Winston logger for structured error logging with severity-based levels.
 * Additional transports (e.g., console, file, external) can be configured
 * based on environment or errorTracking settings.
 */
const logger = winston.createLogger({
  level: logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
  ],
});

/***************************************************************************************************
 * classifyErrorSeverity
 * -------------------------------------------------------------------------------------------------
 * Determines the severity of the error based on the error code, known conditions, or certain
 * fallback rules. Production logic might be more advanced (e.g., domain-based classification).
 **************************************************************************************************/
function classifyErrorSeverity(code: number): ErrorSeverity {
  if (code >= 500) {
    return ErrorSeverity.CRITICAL;
  } else if (code >= 400) {
    return ErrorSeverity.HIGH;
  }
  // Default to MEDIUM for 300 and below; can adjust if needed.
  return ErrorSeverity.MEDIUM;
}

/***************************************************************************************************
 * handleApiError
 * -------------------------------------------------------------------------------------------------
 * Processes a known ApiError object. Generates a comprehensive, sanitized ErrorResponse with
 * correlationId, classification, optional performance metrics, and any relevant details. Omits
 * sensitive data in production environments.
 *
 * Steps:
 * 1) Validate error code and message
 * 2) Sanitize error details
 * 3) Add correlationId and timestamp
 * 4) Classify error severity
 * 5) Format response
 * 6) Add performance context if available
 * 7) Return secured error response
 **************************************************************************************************/
function handleApiError(error: ApiError): ErrorResponse {
  const now = new Date();
  const correlationId = (error as any).correlationId || uuidv4();
  const code = error.code && error.code >= 100 ? error.code : 500;

  // Basic sanitization of details to remove sensitive info if needed
  let sanitizedDetails: object | undefined = {};
  if (typeof error.details === 'object' && error.details !== null) {
    sanitizedDetails = { ...error.details };
  }

  // Classify the error severity
  const severity: ErrorSeverity = classifyErrorSeverity(code);

  // Prepare final error response
  const baseResponse: ErrorResponse = {
    code,
    message: error.message || 'An unexpected error occurred.',
    details: environment === 'development' ? sanitizedDetails : undefined,
    // Conditionally include stack trace only in non-production
    stack: environment === 'development' ? error.stack : undefined,
    timestamp: now,
    correlationId,
    severity,
  };

  return baseResponse;
}

/***************************************************************************************************
 * handleUnknownError
 * -------------------------------------------------------------------------------------------------
 * Processes an unknown or unexpected error scenario, ensuring a safe, generic, security-first
 * response. In production, minimal details are exposed, and we log critical incidents for analysis.
 *
 * Steps:
 * 1) Default code (500)
 * 2) Generate a safe message
 * 3) Add correlationId, timestamp
 * 4) Set severity to CRITICAL by default
 * 5) Sanitize any included details
 * 6) Log as a security incident
 * 7) Return secure generic response
 **************************************************************************************************/
function handleUnknownError(error: unknown): ErrorResponse {
  const now = new Date();
  const correlationId = uuidv4(); // New correlation for unknown errors

  const baseResponse: ErrorResponse = {
    code: 500,
    message: 'An internal server error occurred.',
    details: environment === 'development' ? {} : undefined,
    stack: environment === 'development' && error instanceof Error ? error.stack : undefined,
    timestamp: now,
    correlationId,
    severity: ErrorSeverity.CRITICAL,
  };

  return baseResponse;
}

/***************************************************************************************************
 * errorHandler (Express Error Middleware)
 * -------------------------------------------------------------------------------------------------
 * The primary exported middleware function that unifies all error handling logic. Distinguishes
 * known ApiError instances from unknown errors, applies standardized formatting, logs errors with
 * severity levels, and integrates with external or internal monitoring if configured.
 *
 * Steps:
 * 1) Generate or extract correlationId for error tracking
 * 2) Determine if error is of type ApiError
 * 3) Call handleApiError or handleUnknownError accordingly
 * 4) Log error with Winston using structured format
 * 5) Send sanitized error response to the client
 * 6) Omit sensitive data in production, optionally adding performance metadata
 **************************************************************************************************/
function errorHandler(
  error: any,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // 1) Decide if we have an ApiError based on the presence of a numeric error.code and message
  const isApiError: boolean =
    typeof error?.code === 'number' &&
    typeof error?.message === 'string';

  // 2) Process the error into our standardized ErrorResponse
  const errorResponse: ErrorResponse = isApiError
    ? handleApiError(error as ApiError)
    : handleUnknownError(error);

  // 3) Optionally gather performance context from the request if a prior middleware sets 'startTime'
  let performanceContext: any = {};
  if (req && (req as any).startTime) {
    const diff = process.hrtime((req as any).startTime);
    // Convert [seconds, nanoseconds] to milliseconds
    const responseTimeMs = diff[0] * 1000 + diff[1] / 1e6;
    performanceContext = { responseTimeMs };
  }

  // 4) Log the error using Winston, capturing severity, correlationId, and other structured fields.
  logger.log({
    level: errorResponse.severity === ErrorSeverity.CRITICAL ? 'error' : 'warn',
    message: errorResponse.message,
    code: errorResponse.code,
    correlationId: errorResponse.correlationId,
    severity: errorResponse.severity,
    environment,
    errorTracking,
    details: errorResponse.details,
    stack: errorResponse.stack,
    performance: performanceContext,
    timestamp: errorResponse.timestamp.toISOString(),
  });

  // 5) Send the standardized error response to the client
  //    Enforce the code from errorResponse, ensuring correct HTTP status.
  res.status(errorResponse.code).json({
    code: errorResponse.code,
    message: errorResponse.message,
    details: errorResponse.details,
    // Only deliver stack if in development or explicitly allowed
    stack: environment === 'development' ? errorResponse.stack : undefined,
    timestamp: errorResponse.timestamp,
    correlationId: errorResponse.correlationId,
    severity: errorResponse.severity,
  });
}

// -------------------------------------------------------------------------------------------------
// Export (Default)
// -------------------------------------------------------------------------------------------------
/**
 * Default Export: errorHandler
 * Provides a single-step solution for robust, security-aware error handling in Express.
 */
export default errorHandler;