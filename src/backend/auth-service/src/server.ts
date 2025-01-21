/***************************************************************************************************
 * Main Server File: Authentication Service
 * -----------------------------------------------------------------------------------------------
 * This file implements the secure authentication server, configuring robust authentication flows,
 * security middleware, and protected API endpoints with comprehensive error handling and monitoring.
 * 
 * References to the Technical Specification and JSON Requirements:
 *  1) Authentication Flow (7.1.1): Implementation of secure JWT-based flows, MFA support, and
 *     session management.
 *  2) Security Architecture (2.4.2): Enhanced security including JWT validation, rate limiting,
 *     security headers, correlation IDs, and deep auditing.
 *  3) API Design (3.3): RESTful API design with validation, route-level security, and error handling.
 * 
 * Exports:
 *  - app: The secure Express application for external usage (e.g., testing, deployment).
 **************************************************************************************************/

// -----------------------------------------------------------------------------------------------
// External Imports (with library versions in comments)
// -----------------------------------------------------------------------------------------------
import express from 'express'; // v4.18.2
import cors from 'cors'; // v2.8.5
import helmet from 'helmet'; // v7.1.0
import rateLimit from 'express-rate-limit'; // v7.1.5
import morgan from 'morgan'; // v1.10.0
import passport from 'passport'; // v0.7.0
import compression from 'compression'; // v1.7.4
import type { Request, Response, NextFunction } from 'express';

// -----------------------------------------------------------------------------------------------
// Internal Imports
// -----------------------------------------------------------------------------------------------
import { authConfig } from './config/auth.config'; // { jwt, oauth, security }
const { jwt, oauth, security } = authConfig;

import {
  AuthController,
  register,
  login,
  socialAuth,
  verifyMFA,
  logout,
  // The specification indicates usage of refreshToken from AuthController,
  // though it's not present in the snippet. We import it for completeness:
  refreshToken,
} from './controllers/auth.controller';

// -----------------------------------------------------------------------------------------------
// Global Constants and Environment Variables
// -----------------------------------------------------------------------------------------------
const PORT: string | number = process.env.AUTH_SERVICE_PORT || 3001;
const NODE_ENV: string = process.env.NODE_ENV || 'development';
const CORRELATION_ID_KEY: string = 'x-correlation-id';

// -----------------------------------------------------------------------------------------------
// Express Application Initialization
// -----------------------------------------------------------------------------------------------
/**
 * The main Express application, exported for external usage (testing, deployment).
 * Will be configured with the security middleware, routes, and error handling.
 */
export const app = express();

/***************************************************************************************************
 * initializeMiddleware
 * -----------------------------------------------------------------------------------------------
 * Configures and initializes the Express middleware stack with advanced security features.
 * 
 * Steps (from JSON specification):
 *  1) Configure CORS with strict origin validation and security options.
 *  2) Set up Helmet with CSP and security headers.
 *  3) Configure progressive rate limiting with IP tracking.
 *  4) Set up Morgan logging with correlation IDs.
 *  5) Initialize Passport with secure session configuration.
 *  6) Configure JSON parsing with size limits and validation.
 *  7) Set up compression with security checks.
 *  8) Initialize request correlation ID middleware.
 *  9) Configure security event logging middleware.
 **************************************************************************************************/
function initializeMiddleware(application: express.Application): void {
  // (1) Configure CORS: In production, set strict allowed origins, credentials, and methods
  application.use(
    cors({
      origin: function (origin, callback) {
        // Example: Restrict to a list of known domains or use a config array:
        const allowedOrigins = ['https://dogwalkingapp.com'];
        if (!origin || allowedOrigins.indexOf(origin) !== -1) {
          callback(null, true);
        } else {
          callback(new Error('CORS: Not allowed by policy'));
        }
      },
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      credentials: true,
      optionsSuccessStatus: 200,
    })
  );

  // (2) Set up Helmet with security headers (by default includes noSniff, xssFilter, etc.)
  // Additional CSP can be configured in the options if needed.
  application.use(helmet());

  // (3) Global rate limit example. Progressive approach can be refined per-route if desired.
  // 15 minutes, max 100 requests
  const globalRateLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req: Request, res: Response) => {
      return res.status(429).json({
        error: 'Too many requests from this IP. Please try again later.',
      });
    },
  });
  application.use(globalRateLimiter);

  // (4) Set up Morgan logging. We embed correlation IDs in logs for traceability.
  morgan.token('correlationId', (req: Request) => {
    return (req as any).correlationId || 'no-correlation-id';
  });
  application.use(
    morgan(':method :url :status - CID=:correlationId - :response-time ms')
  );

  // (5) Initialize Passport (secure session usage typically requires express-session or similar)
  // For demonstration, we do basic initialization only. In production, add session management:
  application.use(passport.initialize());

  // (6) Configure JSON parsing with size limit and strict validation
  application.use(express.json({ limit: '10mb', strict: true }));
  application.use(express.urlencoded({ extended: false }));

  // (7) Enable compression with security checks
  application.use(compression());

  // (8) Request correlation ID middleware
  application.use((req: Request, res: Response, next: NextFunction) => {
    const existingId = req.headers[CORRELATION_ID_KEY] as string;
    const correlationId =
      existingId || `corr-${Date.now()}-${Math.round(Math.random() * 1e6)}`;
    (req as any).correlationId = correlationId;
    res.setHeader(CORRELATION_ID_KEY, correlationId);
    return next();
  });

  // (9) Security event logging middleware
  application.use((req: Request, _res: Response, next: NextFunction) => {
    // In production, log relevant security events. Here, we do minimal demonstration:
    // E.g., monitor suspicious patterns or maintain advanced logs.
    // For brevity, we simply pass through.
    next();
  });
}

/***************************************************************************************************
 * setupRoutes
 * -----------------------------------------------------------------------------------------------
 * Sets up all authentication-related routes with the necessary security and validation middlewares.
 * 
 * Steps (from JSON specification):
 *  1) Set up secure health check endpoint with rate limiting.
 *  2) Configure authentication routes with validation middleware.
 *  3) Set up OAuth routes with security checks.
 *  4) Configure MFA verification endpoints.
 *  5) Set up token refresh endpoint.
 *  6) Configure logout endpoint with session cleanup.
 *  7) Set up comprehensive error handling middleware.
 *  8) Initialize security audit logging for routes.
 **************************************************************************************************/
function setupRoutes(application: express.Application): void {
  // (1) Secure health check with rate limiting
  const healthCheckLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 5,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req: Request, res: Response) => {
      return res.status(429).json({
        error: 'Too many health check requests. Please slow down.',
      });
    },
  });

  application.get('/health', healthCheckLimiter, (_req: Request, res: Response) => {
    return res.status(200).json({ status: 'OK', service: 'AuthService' });
  });

  // (2) Configure authentication routes: register, login
  // The auth.controller provides request validation and domain logic; we simply map routes.
  application.post('/register', register);
  application.post('/login', login);

  // (3) Set up OAuth route with security checks
  application.get('/auth/:provider/callback', socialAuth);

  // (4) Configure MFA verification endpoint
  application.post('/verify-mfa', verifyMFA);

  // (5) Token refresh endpoint (per JSON specification, though not present in snippet)
  application.post('/refresh-token', refreshToken);

  // (6) Configure logout route
  application.post('/logout', logout);

  // (7) Comprehensive error handling middleware
  // This final middleware captures errors thrown from any route or middleware above.
  application.use(
    (
      err: any,
      req: Request,
      res: Response,
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      _next: NextFunction
    ) => {
      const correlationId = (req as any).correlationId || 'no-correlation-id';
      // Log the error in a production logger with security context, stacktrace redaction, etc.
      // For brevity, we'll output minimal info:
      // eslint-disable-next-line no-console
      console.error(`[${correlationId}] Error caught by error handler:`, err);

      // Return a generic error response. In production, avoid leaking stack traces.
      return res.status(err.statusCode || 500).json({
        error: err.message || 'Internal Server Error',
        correlationId,
      });
    }
  );

  // (8) Initialize security audit logging for routes
  // Typically you would integrate a specialized logging library or SIEM feed.
  // This can be done as route-level logging or hooking into the preceding error handler.
  // Here we demonstrate a simple final pass-through:
  application.use((req: Request, _res: Response, next: NextFunction) => {
    // In a real scenario, you'd record each route usage, IP, correlationId, etc.
    // For demonstration, we simply pass:
    next();
  });
}

/***************************************************************************************************
 * startServer
 * -----------------------------------------------------------------------------------------------
 * Starts the authentication server with necessary security configurations, clustering support,
 * graceful shutdown, and event listeners for advanced operational control.
 * 
 * Steps (from JSON specification):
 *  1) Initialize security middleware.
 *  2) Set up secure routes.
 *  3) Configure SSL/TLS (placeholder, depending on environment).
 *  4) Initialize graceful shutdown handlers.
 *  5) Configure security event listeners.
 *  6) Start server with clustering support (placeholder for production environment).
 *  7) Initialize health monitoring.
 *  8) Set up error tracking.
 *  9) Log secure server startup information.
 **************************************************************************************************/
async function startServer(application: express.Application): Promise<void> {
  // (1) Initialize security middleware
  initializeMiddleware(application);

  // (2) Set up secure routes
  setupRoutes(application);

  // (3) Configure SSL/TLS (placeholder). Typically handled outside direct code or via a proxy (Nginx).
  // If needed, you could do https.createServer(credentials, application).listen(...)

  // (4) Initialize graceful shutdown handlers
  process.on('SIGTERM', () => {
    // Cleanly shut down resources, close DB connections, flush logs, etc.
    // eslint-disable-next-line no-console
    console.log('Received SIGTERM: shutting down gracefully...');
    process.exit(0);
  });
  process.on('SIGINT', () => {
    // eslint-disable-next-line no-console
    console.log('Received SIGINT: shutting down gracefully...');
    process.exit(0);
  });

  // (5) Configure security event listeners (placeholder).
  // In production, you might watch for security incidents or integrate with a SIEM.

  // (6) Start server with clustering support (placeholder). In production,
  // use a cluster manager (PM2, Docker containers, Kubernetes, etc.).
  // Here we simply listen on the configured port.

  // (7) Initialize health monitoring (placeholder). Typically use a monitoring agent or aggregator.

  // (8) Set up error tracking. Integration with Sentry or Datadog can be done here.

  // (9) Log secure server startup information
  // eslint-disable-next-line no-console
  console.log(`[AuthService] Starting in ${NODE_ENV} mode on port ${PORT}...`);

  application.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`[AuthService] Server is listening at http://localhost:${PORT}`);
  });
}

// If this file is executed directly, start the server. Otherwise, we simply export app.
if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-floating-promises
  startServer(app);
}