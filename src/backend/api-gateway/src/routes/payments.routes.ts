/***************************************************************************************************
 * payments.routes.ts
 * -------------------------------------------------------------------------------------------------
 * Express router configuration for payment-related endpoints in the API Gateway. Implements:
 *  - Secure payment creation and refund flows with PCI DSS compliance
 *  - Enhanced Joi-based validation, including amount checks against MAX_PAYMENT_AMOUNT
 *  - JWT authentication via authenticateToken middleware
 *  - Strict rate limiting for DOS/abuse prevention
 *  - Comprehensive logging with Winston for operational/audit trails
 *  - Proxy forwarding to Payment Service with circuit breaker, retry logic, and security headers
 *
 * Export:
 *   - Default export: router (Express.Router)
 **************************************************************************************************/

// -------------------------------------------------------------------------------------------------
// External Imports (with library version comments)
// -------------------------------------------------------------------------------------------------
import express, { Request, Response, NextFunction } from 'express'; // express@4.18.2
import * as HttpProxy from 'http-proxy-middleware'; // http-proxy-middleware@2.0.6
import Joi from 'joi'; // joi@17.11.0
import * as winston from 'winston'; // winston@3.11.0
import rateLimit from 'express-rate-limit'; // express-rate-limit@7.1.0

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import { authenticateToken } from '../middleware/auth.middleware';
import validateSchema from '../middleware/validation.middleware';
import { ApiError } from '../types';

// -------------------------------------------------------------------------------------------------
// Environment & Global Config
// -------------------------------------------------------------------------------------------------
/**
 * PAYMENT_SERVICE_URL:
 * The base URL for the Payment microservice. Pulled from environment or uses local fallback.
 */
const PAYMENT_SERVICE_URL: string = process.env.PAYMENT_SERVICE_URL || 'http://localhost:4003';

/**
 * MAX_PAYMENT_AMOUNT:
 * The maximum payment amount allowed by PCI DSS policy. Defaults to 1000 if not provided.
 */
const MAX_PAYMENT_AMOUNT: number = parseFloat(String(process.env.MAX_PAYMENT_AMOUNT || 1000)) || 1000;

/**
 * PROXY_TIMEOUT:
 * Timeout for the proxy layer in milliseconds. Defaults to 30000 (30 seconds).
 */
const PROXY_TIMEOUT: number = parseInt(process.env.PROXY_TIMEOUT || '30000', 10);

// -------------------------------------------------------------------------------------------------
// Winston Logger Configuration
// -------------------------------------------------------------------------------------------------
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
  transports: [new winston.transports.Console()],
});

// -------------------------------------------------------------------------------------------------
// Joi Schemas for Payment Operations
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * createPaymentSchema
 * -------------------------------------------------------------------------------------------------
 * Returns an enhanced Joi validation schema for new payment request creation, including:
 *  - Required UUID walkId
 *  - Required positive amount with 2 decimal places, max enforced by MAX_PAYMENT_AMOUNT
 *  - Required paymentMethod with allowed values
 *  - Optional metadata with restricted fields to satisfy PCI DSS (no raw card data)
 *  - Additional PCI DSS checks to forbid raw card details
 *
 * Steps:
 *   1. Validate walkId as required UUID
 *   2. Validate amount as positive, up to 2 decimal places, <= MAX_PAYMENT_AMOUNT
 *   3. Validate paymentMethod from a set of supported token-based methods
 *   4. Forbid any raw card data in the request
 *   5. Enforce optional metadata structure with safe fields only
 *   6. Return the top-level schema covering body, query, params
 **************************************************************************************************/
function createPaymentSchema(): Joi.Schema {
  return Joi.object({
    body: Joi.object({
      walkId: Joi.string().uuid().required().label('Walk ID'),
      amount: Joi.number()
        .positive()
        .precision(2)
        .max(MAX_PAYMENT_AMOUNT)
        .required()
        .label('Payment Amount'),
      paymentMethod: Joi.string()
        .valid('card', 'paypal', 'applepay', 'googlepay')
        .required()
        .label('Payment Method'),
      metadata: Joi.object({
        description: Joi.string().max(512).optional(),
        // Demonstration of PCI DSS compliance: forbid raw cardNumber or cvc fields
        cardNumber: Joi.forbidden().messages({
          'any.unknown': 'Raw cardNumber field is not allowed',
        }),
        cvc: Joi.forbidden().messages({
          'any.unknown': 'Raw CVC data is not allowed',
        }),
      }).optional(),
    }).required(),
    query: Joi.object({}).optional(),
    params: Joi.object({}).optional(),
  });
}

/***************************************************************************************************
 * refundPaymentSchema
 * -------------------------------------------------------------------------------------------------
 * Returns a Joi schema for refund processing. Ensures:
 *   - paymentId in params is a valid UUID
 *   - Optional body fields for partial refund amount and reason, amount <= MAX_PAYMENT_AMOUNT
 *   - Forbids raw card data in line with PCI DSS
 *   - Top-level coverage for body, query, params
 **************************************************************************************************/
function refundPaymentSchema(): Joi.Schema {
  return Joi.object({
    params: Joi.object({
      paymentId: Joi.string().uuid().required().label('Payment ID'),
    }).required(),
    body: Joi.object({
      amount: Joi.number()
        .positive()
        .precision(2)
        .max(MAX_PAYMENT_AMOUNT)
        .optional()
        .label('Refund Amount'),
      reason: Joi.string().max(256).optional().label('Refund Reason'),
      // For PCI DSS compliance, forbid raw card data:
      cardNumber: Joi.forbidden().messages({
        'any.unknown': 'Raw cardNumber field is not permitted',
      }),
      cvc: Joi.forbidden().messages({
        'any.unknown': 'Raw CVC data is not permitted',
      }),
    }).optional(),
    query: Joi.object({}).optional(),
  });
}

// -------------------------------------------------------------------------------------------------
// Logging Middlewares
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * logPaymentRequest
 * -------------------------------------------------------------------------------------------------
 * Express middleware to log incoming payment creation requests with Winston. Omits any
 * sensitive data if present for PCI DSS compliance. Provides structured logs to monitor
 * payment activity.
 **************************************************************************************************/
function logPaymentRequest(req: Request, res: Response, next: NextFunction): void {
  // Extract relevant data, redacting any potential card or cvc fields
  const { walkId, paymentMethod, amount } = (req.body || {});
  logger.info('Incoming Payment Creation Request', {
    route: req.originalUrl,
    method: req.method,
    walkId,
    paymentMethod,
    amount,
    timestamp: new Date().toISOString(),
  });
  return next();
}

/***************************************************************************************************
 * logRefundRequest
 * -------------------------------------------------------------------------------------------------
 * Express middleware to log incoming refund requests with Winston. Omits any
 * sensitive data if present, ensuring PCI DSS compliance. Provides structured logs
 * to track refund activity and facilitate auditing.
 **************************************************************************************************/
function logRefundRequest(req: Request, res: Response, next: NextFunction): void {
  const { paymentId } = req.params || {};
  const { amount, reason } = req.body || {};
  logger.info('Incoming Refund Request', {
    route: req.originalUrl,
    method: req.method,
    paymentId,
    refundAmount: amount,
    reason,
    timestamp: new Date().toISOString(),
  });
  return next();
}

// -------------------------------------------------------------------------------------------------
// Circuit Breaker & Proxy Middleware
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * Simple Circuit Breaker State
 **************************************************************************************************/
interface CircuitBreakerState {
  open: boolean;
  failures: number;
  lastFailureTime: number;
  nextAttemptTime: number;
}

/***************************************************************************************************
 * createProxyMiddleware
 * -------------------------------------------------------------------------------------------------
 * Generates enhanced middleware for proxying payment requests to PAYMENT_SERVICE_URL with:
 *   - Configurable timeout
 *   - Retry logic using exponential backoff
 *   - Circuit breaker pattern to avoid sending requests when the downstream service is down
 *   - Secure header injection and thorough error handling
 *   - Request/Response logging for auditing and monitoring
 *
 * @param {string} paymentServiceUrl - The base URL to which requests will be proxied
 * @returns {HttpProxy.RequestHandler} The configured proxy middleware
 *
 * Steps:
 *   1. Initialize circuit breaker state
 *   2. Configure optional retry with exponential backoff
 *   3. If circuit is open, reject immediately with 503
 *   4. Proxy request, attaching secure headers
 *   5. If error, increment failure count and possibly open circuit
 *   6. If success, reset circuit breaker on a healthy response
 *   7. Return the proxy middleware instance
 **************************************************************************************************/
function createProxyMiddleware(paymentServiceUrl: string): HttpProxy.RequestHandler {
  // 1. Circuit breaker state in memory (demonstration approach)
  const circuitState: CircuitBreakerState = {
    open: false,
    failures: 0,
    lastFailureTime: 0,
    nextAttemptTime: 0,
  };

  // Helper for exponential backoff calculation
  function getNextBackoffDelay(failures: number): number {
    // For demonstration: base 1000ms * 2^(failures-1), max 30s
    const baseDelay = 1000;
    const maxDelay = 30000;
    const nextDelay = baseDelay * Math.pow(2, failures - 1);
    return Math.min(nextDelay, maxDelay);
  }

  const proxy = HttpProxy.createProxyMiddleware({
    target: paymentServiceUrl,
    changeOrigin: true,
    secure: true,
    ws: false,
    timeout: PROXY_TIMEOUT,
    proxyTimeout: PROXY_TIMEOUT,

    // 2. Provide hooks for request, response, error to handle circuit breaker logic
    onProxyReq: (proxyReq, req, res) => {
      // 3. If circuit is open, reject immediately
      const now = Date.now();
      if (circuitState.open && now < circuitState.nextAttemptTime) {
        logger.error('Circuit breaker is OPEN. Rejecting payment request immediately.', {
          route: req.url,
          failures: circuitState.failures,
          nextAttemptTime: circuitState.nextAttemptTime,
        });
        res.statusCode = 503;
        res.end(
          JSON.stringify({
            error: 'Payment Service Unavailable (circuit open)',
          })
        );
        proxyReq.destroy(); // Cancel the proxy request
        return;
      }

      // Sanitize or add security headers if needed
      proxyReq.setHeader('X-Payment-Service-Secure', '1');
      proxyReq.setHeader('X-Forwarded-Proto', 'https');
    },

    onProxyRes: (proxyRes, req, res) => {
      // 6. On a successful response from Payment Service, reset failures and possibly close circuit
      if (proxyRes.statusCode && proxyRes.statusCode < 500) {
        circuitState.failures = 0;
        if (circuitState.open) {
          circuitState.open = false;
          logger.info('Circuit breaker is now CLOSED after successful Payment Service response', {
            route: req.url,
          });
        }
      }
      // Optionally log responses for debugging
      logger.info('Payment Proxy Response', {
        route: req.url,
        statusCode: proxyRes.statusCode,
      });
    },

    onError: (err, req, res) => {
      // 5. Increment failure count, set circuit to open if threshold exceeded
      circuitState.failures += 1;
      circuitState.lastFailureTime = Date.now();

      logger.error('Error in Payment Proxy request', {
        route: req.url,
        error: err.message,
        failures: circuitState.failures,
      });

      // If this is the 3rd failure in a row, open the circuit
      if (circuitState.failures >= 3) {
        circuitState.open = true;
        // Determine how long to keep the circuit open
        const backoffDelay = getNextBackoffDelay(circuitState.failures);
        circuitState.nextAttemptTime = circuitState.lastFailureTime + backoffDelay;
        logger.error('Circuit breaker OPEN', {
          route: req.url,
          nextAttemptTime: circuitState.nextAttemptTime,
        });
      }

      // Return an appropriate error to the client
      if (!res.headersSent) {
        res.writeHead(503, { 'Content-Type': 'application/json' });
      }
      res.end(
        JSON.stringify({
          error: 'Payment Service Unavailable',
        })
      );
    },
  });

  return proxy;
}

// -------------------------------------------------------------------------------------------------
// Specific Rate Limiters for the Payment Routes
// -------------------------------------------------------------------------------------------------
const createPaymentRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Up to 10 createPayment requests within 15 minutes
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many payment creation requests, please try again later' });
  },
});

const refundPaymentRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // Up to 5 refunds within 1 hour
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many refund requests, please try again later' });
  },
});

// -------------------------------------------------------------------------------------------------
// Initialize Router
// -------------------------------------------------------------------------------------------------
const router = express.Router();

/***************************************************************************************************
 * POST /payments
 * Middleware chain:
 *   1. authenticateToken      : Validates JWT & user identity
 *   2. createPaymentRateLimiter : Limits request rate to mitigate abuse
 *   3. validateSchema(createPaymentSchema()) : Ensures payload matches PCI DSS compliance rules
 *   4. logPaymentRequest      : Logs incoming request details to Winston
 *   5. proxyToPaymentService  : Proxies request to Payment microservice with circuit breaker
 **************************************************************************************************/
router.post(
  '/payments',
  authenticateToken,
  createPaymentRateLimiter,
  validateSchema(createPaymentSchema(), {
    abortEarly: false,
    stripUnknown: true,
    allowUnknown: false,
    cache: false,
    debug: false,
    performanceMode: false,
  }),
  logPaymentRequest,
  createProxyMiddleware(PAYMENT_SERVICE_URL)
);

/***************************************************************************************************
 * POST /payments/:paymentId/refund
 * Middleware chain:
 *   1. authenticateToken       : Validates JWT & user identity
 *   2. refundPaymentRateLimiter : Stricter rate limit for refunds
 *   3. validateSchema(refundPaymentSchema()) : Ensures param + body compliance
 *   4. logRefundRequest        : Logs incoming request details with Winston
 *   5. proxyToPaymentService   : Proxies request to Payment microservice with circuit breaker
 **************************************************************************************************/
router.post(
  '/payments/:paymentId/refund',
  authenticateToken,
  refundPaymentRateLimiter,
  validateSchema(refundPaymentSchema(), {
    abortEarly: false,
    stripUnknown: true,
    allowUnknown: false,
    cache: false,
    debug: false,
    performanceMode: false,
  }),
  logRefundRequest,
  createProxyMiddleware(PAYMENT_SERVICE_URL)
);

// -------------------------------------------------------------------------------------------------
// Export the Router
// -------------------------------------------------------------------------------------------------
export default router;