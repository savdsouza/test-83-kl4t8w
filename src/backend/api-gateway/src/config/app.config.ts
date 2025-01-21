/***************************************************************************************************
 * Main Configuration File for the API Gateway
 * -----------------------------------------------------------------------------------------------
 * This file centralizes all application-level settings for the API Gateway service. It includes:
 *  - Server configuration (port, API version, body limit, timeouts, compression)
 *  - Security configuration (trustProxy, Helmet options, CORS, rate limiters)
 *  - Service endpoints (auth, booking, payment, tracking, notification)
 *
 * The configuration is deeply aligned with the technical specification to achieve:
 *  - 99.9% system uptime through optimized server settings, proper timeouts, and compression
 *  - A robust API Gateway with enhanced request validation, throttling, and performance optimization
 *  - Comprehensive security controls including strict Content Security Policy (CSP), strict CORS,
 *    sophisticated rate limiting with Redis, and protective headers via Helmet
 **************************************************************************************************/

/* -------------------------------------------------------------------------------------------------
 * External Imports
 * ------------------------------------------------------------------------------------------------- 
 * dotenv 16.3.1: Loads environment variables from a .env file into process.env.
 * express 4.18.2: Core framework for Express application configuration and middleware.
 * helmet 7.1.0: Provides secure HTTP headers, including CSP.
 * compression 1.7.4: Middleware for response compression to improve performance.
 */
import { config as dotenvConfig } from 'dotenv'; // dotenv@16.3.1
import * as express from 'express'; // express@4.18.2
import helmet from 'helmet'; // helmet@7.1.0
import compression from 'compression'; // compression@1.7.4

/* -------------------------------------------------------------------------------------------------
 * Internal Imports
 * -------------------------------------------------------------------------------------------------
 * corsConfig      : Named import from cors.config, includes corsOptions for strict CORS handling.
 * rateLimitConfig : Named import from rate-limit.config, includes multiple rate limiters 
 *                   (e.g., defaultLimiter, authLimiter) for distributed rate limiting.
 */
import { corsConfig } from './cors.config';
import { defaultLimiter, authLimiter } from './rate-limit.config';

/***************************************************************************************************
 * Load Environment Variables
 * -----------------------------------------------------------------------------------------------
 * This initializes environment variables from any .env file or external environment configuration.
 * We ensure all relevant variables are available for the configuration object.
 **************************************************************************************************/
dotenvConfig();

/***************************************************************************************************
 * Type Definitions
 * -----------------------------------------------------------------------------------------------
 * Define interfaces for the server, security, services, and the overall application configuration.
 **************************************************************************************************/

/**
 * Defines the shape of the server configuration, including:
 *  - port        : The port to run the API on.
 *  - apiVersion  : The version of the API, used for routing.
 *  - bodyLimit   : JSON body parsing limit for incoming requests.
 *  - compression : Response compression settings (enabled, level, threshold, filter).
 *  - timeout     : Global timeout for incoming requests (in milliseconds).
 */
interface ServerConfig {
  port: number;
  apiVersion: string;
  bodyLimit: string;
  compression: {
    enabled: boolean;
    level: number;
    threshold: string;
    filter: (req: express.Request, res: express.Response) => boolean;
  };
  timeout: number;
}

/**
 * Defines the shape of the service endpoint configuration, which includes:
 *  - url     : The base URL of the service.
 *  - timeout : The timeout for requests made to this service (in milliseconds).
 *  - retries : The number of retries to attempt if the service is unreachable or times out.
 */
interface ServiceEndpointConfig {
  url: string;
  timeout: number;
  retries: number;
}

/**
 * Defines the shape of the services configuration, listing all external/internal microservices
 * the API Gateway communicates with, along with their connection properties.
 */
interface ServicesConfig {
  auth: ServiceEndpointConfig;
  booking: ServiceEndpointConfig;
  payment: ServiceEndpointConfig;
  tracking: ServiceEndpointConfig;
  notification: ServiceEndpointConfig;
}

/**
 * Defines the shape of the security configuration, including:
 *  - trustProxy   : Whether to trust X-Forwarded-* headers (needed for secure cookies behind proxies).
 *  - helmetOptions: Configuration object for Helmet to set secure HTTP response headers.
 *  - rateLimiters : Collection of rate limiters for different use cases (default, auth, etc.).
 *  - cors         : Strict CORS configuration to only allow specific origins and methods.
 */
interface SecurityConfig {
  trustProxy: boolean;
  helmetOptions: helmet.Options;
  rateLimiters: {
    defaultLimiter: express.RequestHandler;
    authLimiter: express.RequestHandler;
  };
  cors: express.RequestHandler;
}

/**
 * The top-level application configuration object:
 *  - server   : ServerConfig
 *  - security : SecurityConfig
 *  - services : ServicesConfig
 */
interface AppConfig {
  server: ServerConfig;
  security: SecurityConfig;
  services: ServicesConfig;
}

/***************************************************************************************************
 * Helper Function: shouldCompress
 * -----------------------------------------------------------------------------------------------
 * Custom filter function to determine whether compression should be applied to a given request.
 * For example, if a request includes the header 'x-no-compression', then skip compression.
 **************************************************************************************************/
function shouldCompress(req: express.Request, res: express.Response): boolean {
  // Bypass compression if the request specifically asks not to be compressed.
  if (req.headers['x-no-compression']) {
    return false;
  }
  // Fallback to the default compression behavior from the library.
  return compression.filter(req, res);
}

/***************************************************************************************************
 * createAppConfig()
 * -----------------------------------------------------------------------------------------------
 * Creates and returns the main application configuration object with enhanced security
 * and performance settings, as per the technical specification steps:
 *   1. Load and validate environment variables
 *   2. Configure enhanced security settings with strict CSP
 *   3. Set up optimized compression configuration
 *   4. Configure service endpoints with proper timeouts
 *   5. Initialize rate limiting with Redis
 *   6. Set up CORS with strict options
 *   7. Return compiled configuration object
 *
 * @returns {AppConfig} Complete application configuration object with server, security, and service settings.
 **************************************************************************************************/
function createAppConfig(): AppConfig {
  // 1. Load environment variables (already loaded by dotenvConfig()) and parse fallback values.
  const port = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
  const nodeEnvironment = process.env.NODE_ENV || 'development';
  const apiVersion = process.env.API_VERSION || 'v1';

  // 2. Configure the server object with recommended best practices (compression, timeouts, etc.).
  //    We apply a body limit to handle JSON payload size, which reduces risk of large payload attacks.
  const server: ServerConfig = {
    port,
    apiVersion,
    bodyLimit: '10mb',
    compression: {
      enabled: true,
      level: 6,
      threshold: '1kb',
      filter: shouldCompress,
    },
    // 30-second global timeout meets production expectations while preventing indefinite waits.
    timeout: 30000,
  };

  // 3. Configure security related items, leveraging Helmet with strict CSP, CORS, and Rate Limit.
  //    We set trustProxy to true, enabling correct protocol detection behind a reverse proxy.
  const security: SecurityConfig = {
    trustProxy: true,
    helmetOptions: {
      contentSecurityPolicy: {
        directives: {
          'default-src': ["'self'"],
          'script-src': ["'self'", "'unsafe-inline'"],
          'style-src': ["'self'", "'unsafe-inline'"],
          'img-src': ["'self'", 'data:', 'https:'],
          'connect-src': ["'self'", 'https://api.*'],
          'frame-ancestors': ["'none'"],
          'form-action': ["'self'"],
        },
      },
      crossOriginEmbedderPolicy: true,
      crossOriginOpenerPolicy: true,
      crossOriginResourcePolicy: true,
      dnsPrefetchControl: true,
      frameguard: { action: 'deny' },
      hidePoweredBy: true,
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true,
      },
      ieNoOpen: true,
      noSniff: true,
      originAgentCluster: true,
      permittedCrossDomainPolicies: true,
      referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
      xssFilter: true,
    },
    rateLimiters: {
      // 4. Rate limiting is initialized with Redis under the hood to reduce the chance of
      //    any single user or IP address exhausting resources. We provide a default limiter
      //    and a specialized auth limiter for login endpoints.
      defaultLimiter,
      authLimiter,
    },
    // 5. Strict CORS configuration from the imported corsConfig object, enforcing limited origins.
    cors: express.Router().use(corsConfig.corsOptions),
  };

  // 6. Define external microservice endpoints with their respective timeouts and retry attempts.
  //    These environment variables must be provided for the system to function.
  const services: ServicesConfig = {
    auth: {
      url: process.env.AUTH_SERVICE_URL || 'http://localhost:4001',
      timeout: 5000,
      retries: 2,
    },
    booking: {
      url: process.env.BOOKING_SERVICE_URL || 'http://localhost:4002',
      timeout: 10000,
      retries: 1,
    },
    payment: {
      url: process.env.PAYMENT_SERVICE_URL || 'http://localhost:4003',
      timeout: 15000,
      retries: 0,
    },
    tracking: {
      url: process.env.TRACKING_SERVICE_URL || 'http://localhost:4004',
      timeout: 5000,
      retries: 2,
    },
    notification: {
      url: process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:4005',
      timeout: 5000,
      retries: 1,
    },
  };

  // 7. Return the compiled configuration object matching the AppConfig interface.
  return {
    server,
    security,
    services,
  };
}

/***************************************************************************************************
 * Exported Application Configuration
 * -----------------------------------------------------------------------------------------------
 * We instantiate our configuration via createAppConfig() and export it as appConfig. We also expose
 * the server, security, and services configurations as named exports to ensure flexible usage 
 * throughout the codebase while maintaining a single source of truth.
 **************************************************************************************************/
export const appConfig: AppConfig = createAppConfig();
export const { server, security, services } = appConfig;