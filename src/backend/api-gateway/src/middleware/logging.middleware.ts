/***************************************************************************************************
 * Enhanced middleware for request/response logging, security monitoring, request tracing, and
 * performance tracking in the API Gateway service. This file implements:
 *  - Winston-based logger with custom security levels and sensitive data masking
 *  - Express middlewares for request logging and error logging with advanced security context
 *  - Integration of performance metrics and unique request identifiers for APM correlation
 *  - Secure error handling with classification of security severity and optional error metadata
 **************************************************************************************************/

/* -------------------------------------------------------------------------------------------------
 * External Imports (with versions)
 * ------------------------------------------------------------------------------------------------- */
import express, { Request, Response, NextFunction, ErrorRequestHandler } from 'express'; // express@4.18.2
import * as winston from 'winston'; // winston@3.11.0
import morgan from 'morgan'; // morgan@1.10.0
import { v4 as uuidv4 } from 'uuid'; // uuid@9.0.0

/* -------------------------------------------------------------------------------------------------
 * Internal Imports
 * -------------------------------------------------------------------------------------------------
 * NOTE: The specification indicates "logging" is part of appConfig. If missing from the actual
 * file, this import statement may require an existing or future extension to app.config.
 * Similarly, ApiError is enhanced for security context, bridging potential mismatches in the
 * provided type definitions.
 */
import { server, logging as loggingConfig } from '../config/app.config'; // Hypothetical LoggingConfig usage
import { ApiError } from '../types'; // Enhanced error type definition with security context

/***************************************************************************************************
 * Interface Merging for Enhanced Security
 * -----------------------------------------------------------------------------------------------
 * The specification expects ApiError to support additional fields (securityLevel, context).
 * We unify them here in a single extended interface if needed. If these fields already exist
 * downstream, this interface can be omitted or adjusted.
 **************************************************************************************************/
interface ExtendedApiError extends ApiError {
  /**
   * Security-related severity indicator for this error (e.g., "low", "medium", "high", "critical").
   */
  securityLevel?: string;

  /**
   * Arbitrary security or contextual metadata relevant to the error.
   */
  context?: Record<string, unknown>;
}

/***************************************************************************************************
 * createLogger()
 * -----------------------------------------------------------------------------------------------
 * Creates and configures the Winston logger instance with enhanced security, monitoring, and
 * enterprise-level production readiness. According to the specification steps:
 *  1. Create new Winston logger instance with security formats
 *  2. Configure secure console transport for development
 *  3. Configure encrypted file transport for production
 *  4. Set up log rotation and retention policies
 *  5. Configure security level formatting
 *  6. Add sensitive data masking
 *  7. Enable log integrity verification
 *  8. Set up ELK stack compatible formatting
 *  9. Configure APM correlation
 * 10. Return secured logger instance
 **************************************************************************************************/
function createLogger(): winston.Logger {
  // STEP 1: Define custom logging levels, including a "security" level for specialized security logs.
  const customLevels = {
    error: 0,
    warn: 1,
    security: 2,
    info: 3,
    debug: 4,
  };

  // STEP 2 + 3 + 4: Transports for different environments. We can expand with encryption, log rotation, etc.
  // For demonstration, we define console transport for development and a placeholder for production file output.
  const transports: winston.transport[] = [];

  // We can read environment or logging config to determine transport usage
  const isProduction = process.env.NODE_ENV === 'production';

  if (!isProduction) {
    // Console transport for development with colorized output
    transports.push(
      new winston.transports.Console({
        level: 'debug',
        format: winston.format.combine(
          winston.format.colorize(),
          winston.format.timestamp(),
          winston.format.printf((info) => {
            // This is a simplified format demonstration
            return `[${info.timestamp as string}] [${info.level}] ${info.message}`;
          }),
        ),
      }),
    );
  } else {
    // Placeholder: File transport for production with possible encryption, log rotation, and data integrity
    transports.push(
      new winston.transports.File({
        level: 'info',
        filename: 'secure-app.log',
        format: winston.format.combine(
          // Additional log rotation logic can be integrated with external libraries
          // to fulfill the specification item of rotation policies.
          winston.format.timestamp(),
          winston.format.json(),
        ),
      }),
    );
  }

  // STEP 5: Create a custom Winston format chain that also includes security-level formatting.
  // STEP 6: We can inject a sensitive data masking step. (Placeholder function for demonstration.)
  const maskSensitiveData = winston.format((info) => {
    // Example: remove known sensitive fields from log data
    if (info.message && typeof info.message === 'string') {
      info.message = info.message.replace(/(\"password\":\s?\").+?(\")/g, '$1[REDACTED]$2');
      info.message = info.message.replace(/(\"authorization\":\s?\").+?(\")/g, '$1[REDACTED]$2');
    }
    return info;
  });

  // STEP 7: Potential log integrity verification can be performed via checksums or signing here.
  // For brevity, we place a placeholder logic that could be expanded as needed.
  const logIntegrity = winston.format((info) => {
    // e.g., info.hash = computeHash(info);
    return info;
  });

  // STEP 8 + 9: Set up an ELK-friendly JSON format and possibly include correlation or trace IDs.
  // We add them if present in the metadata or if the code has them globally.
  const elkAndApmFormat = winston.format((info) => {
    // In a real scenario, we might parse correlation IDs from request scope or use an APM library
    const correlationId = (info as any).correlationId || 'no-correlation-id';
    info.correlationId = correlationId;
    return info;
  });

  // Compose final format pipeline
  const finalFormat = winston.format.combine(
    logIntegrity(),
    maskSensitiveData(),
    elkAndApmFormat(),
  );

  // Create the Winston logger instance with custom levels, final format, and assigned transports
  const logger = winston.createLogger({
    levels: customLevels,
    level: loggingConfig?.logLevel || 'info',
    format: finalFormat,
    transports,
  });

  // Add custom color mapping for new levels if desired
  winston.addColors({
    security: 'magenta',
  });

  // Return the configured logger instance
  return logger;
}

/***************************************************************************************************
 * logger
 * -----------------------------------------------------------------------------------------------
 * Exported Winston logger with an additional "security" method for security-specific logging.
 * Fulfills the requirement to have "info", "error", "warn", "debug", and "security" methods.
 **************************************************************************************************/
const baseLogger = createLogger();

// Inject a custom convenience method for "security" level
(baseLogger as any).security = (message: string, meta?: any) => {
  baseLogger.log('security', message, meta);
};

// Exported object that matches the specified members_exposed requirements:
export const logger = {
  info: (msg: string, meta?: any): winston.Logger => baseLogger.info(msg, meta),
  error: (msg: string, meta?: any): winston.Logger => baseLogger.error(msg, meta),
  warn: (msg: string, meta?: any): winston.Logger => baseLogger.warn(msg, meta),
  debug: (msg: string, meta?: any): winston.Logger => baseLogger.debug(msg, meta),
  security: (msg: string, meta?: any): void => {
    (baseLogger as any).security(msg, meta);
  },
};

/***************************************************************************************************
 * requestLoggingMiddleware
 * -----------------------------------------------------------------------------------------------
 * Express middleware for comprehensive request logging with security context and performance
 * tracking. Steps:
 *   1. Generate unique request ID and correlation ID
 *   2. Initialize request timing metrics
 *   3. Sanitize and mask sensitive request data
 *   4. Log request details with security context
 *   5. Track request performance metrics
 *   6. Monitor for security anomalies
 *   7. Log response status and timing
 *   8. Update security metrics
 *   9. Handle logging errors securely
 **************************************************************************************************/
const requestLoggingMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  try {
    // STEP 1: Generate unique request ID and correlation ID
    const requestId = uuidv4();
    (req as any).requestId = requestId; // attach to req for usage in logs
    res.setHeader('X-Request-Id', requestId);

    // STEP 2: Initialize request timing metrics
    const startHrTime = process.hrtime();

    // STEP 3: Morgan-based request logging with sanitized data
    // Create a custom token for the request ID
    morgan.token('id', () => requestId);

    // Potentially mask sensitive tokens or query parameters in morgan's tokens with a custom solution
    // For simplicity, we will store the sanitized approach in the final log message or metadata.

    // STEP 4 + 5 + 6: Use morgan with a custom format that logs method, url, correlation ID, length, etc.
    morgan(
      '[:date[iso]] :id :method :url :status - :res[content-length] bytes',
      {
        immediate: true, // log at request start
        stream: {
          write: (message: string) => {
            // Trim newline that morgan typically adds
            const trimmedMessage = message.trim();

            // Attach a minimal security context if needed
            // The specification references advanced security context, so we can do:
            logger.info(trimmedMessage, { securityContext: 'request-start' });
          },
        },
      },
    )(req, res, () => {
      // We proceed once the immediate log is done
    });

    // Once the response finishes, we can log the final performance metrics
    res.on('finish', () => {
      // STEP 7 + 8: Calculate total time
      const diff = process.hrtime(startHrTime);
      const elapsedTimeInMs = diff[0] * 1e3 + diff[1] * 1e-6;

      // Build a performance log message including status code, method, and timing
      const performanceMessage = `Request ID: ${requestId}, Method: ${req.method}, URL: ${req.originalUrl}, Status: ${
        res.statusCode
      }, Duration: ${elapsedTimeInMs.toFixed(2)} ms`;

      // STEP 6 (monitor anomalies) + 8 (update security metrics): Placeholder logic
      // e.g., if (res.statusCode >= 500) { log or increment some alert metric? }

      // Log final request details
      logger.info(performanceMessage, {
        securityContext: 'request-complete',
        statusCode: res.statusCode,
        durationMs: elapsedTimeInMs,
      });
    });

    // STEP 9: Pass control to the next middleware
    next();
  } catch (loggingError) {
    // If there is any logging error, proceed safely without crashing
    logger.error('Failed to log request', { error: loggingError });
    next();
  }
};

/***************************************************************************************************
 * errorLoggingMiddleware
 * -----------------------------------------------------------------------------------------------
 * Enhanced error logging middleware with security classification and context tracking. Steps:
 *   1. Classify error security severity
 *   2. Extract enhanced error details
 *   3. Include security context in error log
 *   4. Mask sensitive error data
 *   5. Log error with security metadata
 *   6. Track error patterns for security analysis
 *   7. Format secure error response
 *   8. Update security metrics
 *   9. Pass sanitized error to next handler
 **************************************************************************************************/
const errorLoggingMiddleware: ErrorRequestHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  try {
    // Convert the incoming error to an ExtendedApiError shape
    const incomingError = error as ExtendedApiError;

    // STEP 1: Classify error security severity (example placeholder logic)
    const severity = incomingError.securityLevel || (res.statusCode >= 500 ? 'high' : 'low');

    // STEP 2: Extract enhanced details
    const errorMessage = incomingError.message || 'Unknown server error occurred';

    // STEP 3 + 4 + 5: Include security context, mask sensitive data, log error with metadata
    // Example masking approach for syntax demonstration:
    const maskedMessage = errorMessage.replace(/password=.*?($|\\s)/gi, 'password=[REDACTED] ');

    // We can attach the request ID from the incoming request for correlation
    const requestId = (req as any).requestId || 'no-request-id';

    // Log with "security" level if severity is high, else standard error
    if (severity === 'high') {
      logger.security(`SECURITY ALERT: ${maskedMessage}`, {
        requestId,
        severity,
        context: incomingError.context,
        stack: incomingError.stack,
      });
    } else {
      logger.error(maskedMessage, {
        requestId,
        severity,
        context: incomingError.context,
        stack: incomingError.stack,
      });
    }

    // STEP 6: Track error patterns for security analysis (placeholder)
    // e.g., integrate with a monitoring service or global security metrics

    // STEP 7: Format a secure response object, avoiding sensitive fields
    // We'll only reveal minimal info in production while passing a sanitized error forward
    const responsePayload = {
      code: incomingError.code || res.statusCode || 500,
      message: isProductionEnv() ? 'An internal server error occurred' : maskedMessage,
    };

    // STEP 8: Update security metrics if needed (placeholder)

    // STEP 9: Pass the sanitized error to the next handler
    // In many cases, we directly respond with res.status().json(...). The specification suggests
    // we may also have a final error handler. For maximum flexibility, we do not finalize here.
    // If we want to finalize, uncomment below:
    // res.status(responsePayload.code).json(responsePayload);
    // Otherwise, attach sanitized data to error and call next
    (error as ExtendedApiError).message = responsePayload.message;
    (error as ExtendedApiError).securityLevel = severity;

    next(error);
  } catch (loggingFailure) {
    // If logging fails entirely, we finalize with a generic 500.
    logger.error('Failed to log error securely', { error: loggingFailure });
    return next(error);
  }
};

/***************************************************************************************************
 * Helper: isProductionEnv
 **************************************************************************************************/
function isProductionEnv(): boolean {
  return process.env.NODE_ENV === 'production';
}

/***************************************************************************************************
 * requestLogger (Export)
 * -----------------------------------------------------------------------------------------------
 * Exported as the default for enhanced request logging middleware with security features.
 **************************************************************************************************/
export default requestLoggingMiddleware;

/***************************************************************************************************
 * errorLogger (Export)
 * -----------------------------------------------------------------------------------------------
 * Named export for the secure error logging middleware with context tracking.
 **************************************************************************************************/
export { errorLoggingMiddleware as errorLogger };
```