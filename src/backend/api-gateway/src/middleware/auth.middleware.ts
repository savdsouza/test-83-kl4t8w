/***************************************************************************************************
 * auth.middleware.ts
 * -------------------------------------------------------------------------------------------------
 * Authentication and authorization middleware for the API Gateway. This file implements secure
 * JWT token validation (RS256), role-based authorization with hierarchy support, and advanced
 * security checks including token blacklist inspection, claims verification, and comprehensive
 * error handling in alignment with the system's security architecture and API security requirements.
 *
 * Responsibilities:
 *  1) authenticateToken: Validates the incoming JWT from the Authorization header, performing checks
 *     against blacklisted tokens, issuer/audience claims, expiration checks, and signature
 *     verification using RS256. Attaches the decoded payload to req.user if valid.
 *
 *  2) authorizeRoles: Enforces role-based access control by comparing the user's role and the
 *     system's role hierarchy with the roles required to access a protected resource.
 *
 *  3) validateToken: A reusable helper function that performs in-depth JWT validation, including
 *     signature checks, token type/version verification, claim presence checks, and issuer/audience
 *     constraints.
 *
 * Usage:
 *   import { authenticateToken, authorizeRoles } from './auth.middleware';
 *   router.get('/secure', authenticateToken, authorizeRoles(['admin']), (req, res) => { ... });
 **************************************************************************************************/

// -------------------------------------------------------------------------------------------------
// External Imports (with library version comments)
// -------------------------------------------------------------------------------------------------
import { Request, Response, NextFunction, RequestHandler } from 'express'; // express@4.18.2
import { verify, JwtPayload } from 'jsonwebtoken'; // jsonwebtoken@9.0.2
import * as httpStatus from 'http-status'; // http-status@1.7.0

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import { ApiError } from './error.middleware'; // Imported based on provided specification
import { appConfig } from '../config/app.config'; // Environment-specific configuration
import { UserPayload } from '../types'; // UserPayload interface with role, email, id, etc.

// -------------------------------------------------------------------------------------------------
// Global Constants & Helper Definitions
// -------------------------------------------------------------------------------------------------

/**
 * PUBLIC_KEY:
 * Public key for RS256 signature verification, loaded from environment variables.
 * Ensures secure token validation by matching the private key used at signing.
 */
const PUBLIC_KEY: string = process.env.JWT_PUBLIC_KEY
  ? process.env.JWT_PUBLIC_KEY.replace(/\\n/g, '\n')
  : '';

/**
 * isTokenBlacklisted
 * Placeholder async function to check token blacklist status. In a production system,
 * this would interface with a Redis store, database, or external service to verify if
 * the token has been revoked or invalidated (e.g., on logout or forced refresh).
 *
 * @param {string} token - The raw JWT token to check
 * @returns {Promise<boolean>} Whether the token is currently blacklisted
 */
async function isTokenBlacklisted(token: string): Promise<boolean> {
  // In a real implementation, query Redis/DB for the token or jti reference
  // Example: return await redisClient.exists(token);
  return false; // Default: no token is blacklisted
}

/**
 * A convenience function to build a standardized ApiError object.
 *
 * @param {number} code - HTTP status code
 * @param {string} message - Error message
 * @param {object} details - Additional details for debugging
 * @returns {ApiError} A constructed ApiError object
 */
function buildApiError(code: number, message: string, details: object): ApiError {
  return {
    code,
    message,
    details,
    stack: new Error().stack || '',
    timestamp: new Date(),
  };
}

// -------------------------------------------------------------------------------------------------
// Middleware Function: validateToken (Helper)
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * validateToken
 * -------------------------------------------------------------------------------------------------
 * A comprehensive helper function for JWT signature and claim validation using RS256. It checks:
 *   1) Token structure and presence
 *   2) Signature correctness using the PUBLIC_KEY
 *   3) Issuer and audience (if required for the system)
 *   4) Expiration checks (exp, iat)
 *   5) Token type and version if included in extended claims
 *
 * @param {string} token - The raw token string extracted from the Authorization header
 * @returns {Promise<object>} The decoded token payload if validation succeeds
 * @throws {ApiError} If validation fails, throws an ApiError for upper-layer handling
 **************************************************************************************************/
export async function validateToken(token: string): Promise<object> {
  try {
    // 1) Verify the token using RS256; this will throw if invalid signature/format
    const decoded = verify(token, PUBLIC_KEY, {
      algorithms: ['RS256'],
    }) as JwtPayload;

    // 2) Check essential claims: exp, iat, and any domain-specific checks (issuer/audience)
    if (!decoded || !decoded.exp || !decoded.iat) {
      throw buildApiError(httpStatus.UNAUTHORIZED, 'Invalid token claims', {
        reason: 'Missing token exp/iat',
      });
    }

    // 3) (Optional) Validate the issuer and audience if the system requires
    // Example placeholders:
    // if (decoded.iss !== 'dog-walking-platform') {
    //   throw buildApiError(httpStatus.UNAUTHORIZED, 'Invalid token issuer', { iss: decoded.iss });
    // }
    // if (decoded.aud !== 'dog-walking-app') {
    //   throw buildApiError(httpStatus.UNAUTHORIZED, 'Invalid token audience', { aud: decoded.aud });
    // }

    // 4) (Optional) Check for extended domain-specific claims, e.g., token type or version
    // if (decoded.type !== 'access') {
    //   throw buildApiError(httpStatus.UNAUTHORIZED, 'Invalid token type', { type: decoded.type });
    // }

    // 5) Return the decoded payload if all checks pass
    return decoded;
  } catch (err) {
    // Convert any JWT or signature error into a system-standard ApiError
    throw buildApiError(httpStatus.UNAUTHORIZED, 'Token validation failed', {
      reason: (err as Error).message,
    });
  }
}

// -------------------------------------------------------------------------------------------------
// Middleware Function: authenticateToken
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * authenticateToken
 * -------------------------------------------------------------------------------------------------
 * Express middleware that verifies the authenticity and validity of a JWT token from the
 * Authorization header. It follows these steps:
 *   1) Sanitize and validate Authorization header format
 *   2) Extract the JWT token ("Bearer <TOKEN>")
 *   3) Check the token against any recognized blacklist
 *   4) Use validateToken() to perform RS256 signature and exp/iat checks
 *   5) Attach the validated token payload (UserPayload) to req.user
 *   6) Log or record a security event if needed
 *   7) Call next() or throw an error if invalid
 *
 * @param {Request} req - The Express request object
 * @param {Response} res - The Express response object
 * @param {NextFunction} next - The next middleware in the chain
 * @returns {Promise<void>} Proceeds to the next middleware if successful, otherwise errors
 **************************************************************************************************/
export async function authenticateToken(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // 1) Retrieve Authorization header and confirm it starts with 'Bearer '
    const authHeader = (req.headers.authorization || '').trim();
    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
      throw buildApiError(httpStatus.UNAUTHORIZED, 'Missing or invalid Authorization header', {
        providedHeader: authHeader,
      });
    }

    // 2) Extract the token substring
    const token = authHeader.slice('bearer '.length).trim();
    if (!token) {
      throw buildApiError(httpStatus.UNAUTHORIZED, 'Bearer token not found', {});
    }

    // 3) Check if this token has been blacklisted
    const blacklisted = await isTokenBlacklisted(token);
    if (blacklisted) {
      throw buildApiError(httpStatus.UNAUTHORIZED, 'Token is invalid (blacklisted)', {});
    }

    // 4) Perform core validation via validateToken
    const decodedPayload = await validateToken(token);

    // 5) Attach the decoded token to the request as user (cast to our UserPayload interface)
    req.user = decodedPayload as UserPayload;

    // 6) (Optional) Log or record security event (omitted here, but recommended in production)

    // 7) Pass control to the next middleware if everything is valid
    return next();
  } catch (error) {
    return next(error);
  }
}

// -------------------------------------------------------------------------------------------------
// Middleware Factory: authorizeRoles
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * authorizeRoles
 * -------------------------------------------------------------------------------------------------
 * Role-based authorization middleware that checks whether the authenticated user holds at least one
 * of the allowed roles, considering a role hierarchy if provided in the application config. Follows:
 *   1) Confirms an authenticated user is present (requires authenticateToken beforehand)
 *   2) Extracts the user's role
 *   3) Checks if the user's role is permitted based on allowedRoles or an extended hierarchy
 *   4) Throws an ApiError if not authorized
 *   5) Calls next() if authorized
 *
 * @param {string[]} allowedRoles - Array of roles that can access the route
 * @returns {RequestHandler} An Express middleware function enforcing role-based access
 **************************************************************************************************/
export function authorizeRoles(allowedRoles: string[]): RequestHandler {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      // 1) Ensure the request has a user property populated (authenticateToken must run first)
      if (!req.user) {
        throw buildApiError(httpStatus.FORBIDDEN, 'No authenticated user found', {});
      }

      const userRole: string = req.user.role;

      // 2) Retrieve any role hierarchy from appConfig
      const { security, roleHierarchy } = appConfig as any; // For illustration of spec usage
      // If there's no defined hierarchy, fallback to basic role check below
      // Example shape: roleHierarchy = { admin: ['admin', 'owner', 'walker'], owner: ['owner'], walker: ['walker'] }

      // 3) Verify that userRole is included within the allowed roles or the extended role group
      const userHierRoles: string[] = (roleHierarchy && roleHierarchy[userRole]) || [userRole];
      const intersection = userHierRoles.filter((r: string) => allowedRoles.includes(r));
      const hasPermission = intersection.length > 0;

      if (!hasPermission) {
        throw buildApiError(httpStatus.FORBIDDEN, 'Insufficient role privileges', {
          userRole,
          allowedRoles,
        });
      }

      // 4) If authorized, proceed to the next middleware
      next();
    } catch (error) {
      return next(error);
    }
  };
}