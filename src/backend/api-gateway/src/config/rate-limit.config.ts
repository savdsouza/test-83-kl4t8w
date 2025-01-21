/***************************************************************************************************
 * Configuration file for API rate limiting settings.
 * This file sets up distributed rate limiting with Redis using express-rate-limit and rate-limit-redis.
 * The implementation follows the technical specification to prevent API abuse, ensure fair usage,
 * and support different rate limits for distinct user types or endpoints.
 **************************************************************************************************/

// ---------------------------
// External Imports
// ---------------------------

// express-rate-limit version 7.1.0
import rateLimit, {
  RateLimitRequestHandler,
  Options as RateLimitOptions,
  Store as RateLimitStore,
} from 'express-rate-limit';

// rate-limit-redis version 4.0.0
import RedisStore from 'rate-limit-redis';

// ioredis version 5.3.2
import Redis from 'ioredis';

// ---------------------------
// Environment Variables
// ---------------------------
// process.env.REDIS_URL: string - Redis connection URL (e.g., "redis://localhost:6379")
// process.env.NODE_ENV: string - Application environment (e.g., "development", "production")
// process.env.RATE_LIMIT_PREFIX: string - Optional prefix for rate limit keys in Redis

/***************************************************************************************************
 * createRedisStore()
 * -----------------------------------------------------------------------------------------------
 * Creates and configures a new Redis store for distributed rate limiting.
 * This function handles Redis connection, error handling, retry strategies, and store prefixing.
 **************************************************************************************************/
export function createRedisStore(): RateLimitStore {
  // ----------------------------------------------------------------------------
  // 1. Create a new ioredis client with advanced retry, reconnect, and pipeline options.
  // ----------------------------------------------------------------------------
  const redisClient = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
    // Disables offline queue so that commands fail immediately if the client is not connected.
    enableOfflineQueue: false,

    // Maximum number of retries for each command if the first attempt fails.
    maxRetriesPerRequest: 2,

    // Custom retry strategy to control how long to wait before reconnecting attempts.
    // This strategy grows linearly: 50ms, 100ms, 150ms, up to a maximum of 2000ms.
    retryStrategy: (times: number) => {
      return Math.min(times * 50, 2000);
    },

    // Reconnect on specific Redis errors (e.g., READONLY errors in cluster failover scenarios).
    reconnectOnError: (err: Error) => {
      return err.message.includes('READONLY');
    },

    // Enables automatic command pipelining for better performance under concurrency.
    enableAutoPipelining: true,

    // Maximum time in milliseconds to wait for a connection to be established.
    connectTimeout: 10000,

    // (Non-standard) Specified in the requirements—passed for potential future enhancements.
    disconnectTimeout: 2000,

    // (Non-standard) Maximum time to wait for a command—passed according to specification.
    commandTimeout: 5000,

    // Custom cluster retry strategy if connected to a Redis cluster (non-standard usage).
    clusterRetryStrategy: (times: number) => {
      return Math.min(times * 100, 3000);
    },
  });

  // ----------------------------------------------------------------------------
  // 2. Configure error handlers to log or handle Redis connection errors.
  // ----------------------------------------------------------------------------
  redisClient.on('error', (error: Error) => {
    // In production, consider more robust logging and alerting mechanisms.
    console.error('[RateLimit Redis Client Error]:', error);
  });

  // ----------------------------------------------------------------------------
  // 3. Initialize the rate-limit-redis store with the configured Redis client.
  // ----------------------------------------------------------------------------
  const store = new RedisStore({
    // The Redis client to use for storing rate limit data.
    sendCommand: (...args) => redisClient.call(...args),

    // Optional prefix for keys in Redis, allowing us to isolate rate limit data.
    prefix: process.env.RATE_LIMIT_PREFIX || 'rl:',
  });

  // ----------------------------------------------------------------------------
  // 4. Return the fully configured store to be used by express-rate-limit.
  // ----------------------------------------------------------------------------
  return store;
}

// --------------------------------------------------------------------------------------
// Create a single shared RedisStore instance to be used by all rate limiters below.
// This ensures consistent key usage and centralized distributed rate limiting.
// --------------------------------------------------------------------------------------
const redisRateLimitStore = createRedisStore();

/***************************************************************************************************
 * Rate Limiting Configurations
 * -----------------------------------------------------------------------------------------------
 * The following objects define specific rate limit rules for different endpoints or user roles.
 * Each configuration sets the base constraints such as:
 *   - windowMs  :  Time window for which the rate limit applies
 *   - max       :  Maximum number of requests allowed in the given window
 *   - keyGenerator : Function to customize the key for the limit usage
 *   - handler   :  Function that handles rate limit exceed scenario
 *   - message   :  Default response message if rate limit is exceeded
 *   - skipFailedRequests / skipSuccessfulRequests : Booleans controlling request counting logic
 *   - standardHeaders / legacyHeaders : Whether to include rate limit headers in responses
 **************************************************************************************************/

// Default Rate Limit: 100 requests per 15 minutes
const defaultRateLimit: RateLimitOptions = {
  // 15 minutes in milliseconds
  windowMs: 900000,

  // Max requests allowed in the 15-minute window
  max: 100,

  // Include standard rate limit headers in the response
  standardHeaders: true,

  // Exclude the deprecated X-RateLimit headers
  legacyHeaders: false,

  // Message to send back if the user hits the rate limit
  message: 'Too many requests, please try again later',

  // Whether to count failed requests (5xx or 4xx) towards the limit
  skipFailedRequests: false,

  // Whether to count successful requests towards the limit
  skipSuccessfulRequests: false,

  // Custom key generator to identify a user; defaulting to the request IP address
  keyGenerator: (req) => {
    return req.ip;
  },

  // Custom handler for rate limit excess
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many requests' });
  },

  // We pass in the Redis store to enable distributed rate limiting
  store: redisRateLimitStore,
};

// Authentication Rate Limit: 5 requests per 15 minutes (stricter)
const authRateLimit: RateLimitOptions = {
  windowMs: 900000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Too many authentication attempts, please try again later',

  // Count all requests, but note that skipSuccessfulRequests is overridden below
  skipFailedRequests: false,

  // Only count successful authentication requests to reduce lockouts
  skipSuccessfulRequests: true,

  // Key generator uses IP plus specific suffix to separate from other endpoints
  keyGenerator: (req) => {
    return `${req.ip}:auth`;
  },

  handler: (req, res) => {
    res.status(429).json({ error: 'Too many authentication attempts' });
  },

  store: redisRateLimitStore,
};

// Walker Rate Limit: 1000 requests per 15 minutes (higher allowance for frequent updates)
const walkerRateLimit: RateLimitOptions = {
  windowMs: 900000,
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Rate limit exceeded for walker endpoints',
  skipFailedRequests: false,
  skipSuccessfulRequests: false,

  // Key generator ties usage to the walker's user ID
  // This requires that req.user.id is set for authenticated walker routes
  keyGenerator: (req) => {
    // Safe fallback if user or user.id is undefined
    return req?.user?.id ? `${req.user.id}:walker` : req.ip;
  },

  handler: (req, res) => {
    res.status(429).json({ error: 'Walker rate limit exceeded' });
  },

  store: redisRateLimitStore,
};

// Owner Rate Limit: 100 requests per 15 minutes
const ownerRateLimit: RateLimitOptions = {
  windowMs: 900000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Rate limit exceeded for owner endpoints',
  skipFailedRequests: false,
  skipSuccessfulRequests: false,

  // Key generator ties usage to the owner's user ID
  keyGenerator: (req) => {
    // Safe fallback if user or user.id is undefined
    return req?.user?.id ? `${req.user.id}:owner` : req.ip;
  },

  handler: (req, res) => {
    res.status(429).json({ error: 'Owner rate limit exceeded' });
  },

  store: redisRateLimitStore,
};

// --------------------------------------------------------------------------------------
// Export the four rate limiters as named exports ready for application-level use.
// --------------------------------------------------------------------------------------

/***************************************************************************************************
 * defaultLimiter:
 *   - general usage across standard endpoints
 * authLimiter:
 *   - specialized usage for login, signup, and other authentication-related endpoints
 * walkerLimiter:
 *   - used by endpoints related to the walker role
 * ownerLimiter:
 *   - used by endpoints related to the owner role
 **************************************************************************************************/
export const defaultLimiter: RateLimitRequestHandler = rateLimit(defaultRateLimit);
export const authLimiter: RateLimitRequestHandler = rateLimit(authRateLimit);
export const walkerLimiter: RateLimitRequestHandler = rateLimit(walkerRateLimit);
export const ownerLimiter: RateLimitRequestHandler = rateLimit(ownerRateLimit);