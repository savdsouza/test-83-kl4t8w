import * as dotenv from 'dotenv'; // v16.3.1

dotenv.config();

/**
 * Comprehensive authentication and security configuration
 * for the Dog Walking Auth Service.
 *
 * This configuration includes:
 * 1) JWT settings for both access and refresh tokens with RS256.
 * 2) Strict password policy requirements including Argon2id hashing.
 * 3) OAuth 2.0 configurations (Google, Apple, Facebook) with PKCE.
 * 4) Multi-factor authentication settings (TOTP, SMS, Email).
 * 5) Biometric authentication options.
 * 6) Additional security settings such as rate limiting and lockout.
 */

/**
 * Exported authConfig object containing all security-related settings.
 * The structure below implements the specifications provided in the
 * technical design documentation, ensuring compliance with enterprise
 * security standards.
 */
export const authConfig = {
  /**
   * JWT configuration for both access and refresh tokens.
   * Uses RS256 signing, strict issuer/audience controls,
   * and rotation settings for refresh tokens.
   */
  jwt: {
    accessToken: {
      expiresIn: '15m',
      algorithm: 'RS256',
      issuer: 'dog-walking-auth-service',
      audience: 'dog-walking-api',
      clockTolerance: 30,
      jwtid: true,
    },
    refreshToken: {
      expiresIn: '7d',
      algorithm: 'RS256',
      issuer: 'dog-walking-auth-service',
      audience: 'dog-walking-api',
      jwtid: true,
      rotationEnabled: true,
      rotationWindow: '2d',
    },
    keyManagement: {
      privateKeyPath: process.env.JWT_PRIVATE_KEY_PATH || '',
      publicKeyPath: process.env.JWT_PUBLIC_KEY_PATH || '',
      keyRotationInterval: '30d',
    },
  },

  /**
   * Password policy configuration, enforcing strong requirements
   * and Argon2id hashing for enhanced security.
   */
  password: {
    minLength: 12,
    requireUppercase: true,
    requireLowercase: true,
    requireNumbers: true,
    requireSpecialChars: true,
    hashingAlgorithm: 'Argon2id',
    hashingConfig: {
      memoryCost: 65536,
      timeCost: 3,
      parallelism: 4,
    },
    saltLength: 32,
    preventReuse: true,
    lastPasswordsToCheck: 5,
  },

  /**
   * OAuth 2.0 configurations for multiple providers,
   * including PKCE and optional state parameters for security.
   */
  oauth: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID || '',
      clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
      callbackUrl: process.env.GOOGLE_CALLBACK_URL || '',
      scopes: ['profile', 'email'],
      pkce: true,
      state: true,
    },
    apple: {
      clientId: process.env.APPLE_CLIENT_ID || '',
      teamId: process.env.APPLE_TEAM_ID || '',
      keyId: process.env.APPLE_KEY_ID || '',
      privateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH || '',
      callbackUrl: process.env.APPLE_CALLBACK_URL || '',
      scopes: ['name', 'email'],
      pkce: true,
    },
    facebook: {
      clientId: process.env.FACEBOOK_CLIENT_ID || '',
      clientSecret: process.env.FACEBOOK_CLIENT_SECRET || '',
      callbackUrl: process.env.FACEBOOK_CALLBACK_URL || '',
      scopes: ['email', 'public_profile'],
      profileFields: ['id', 'email', 'name'],
      state: true,
    },
  },

  /**
   * Multi-factor authentication configuration supporting
   * TOTP, SMS-based, and email-based verification.
   */
  mfa: {
    totp: {
      issuer: 'DogWalking',
      algorithm: 'SHA256',
      digits: 6,
      period: 30,
      window: 1,
      backupCodes: {
        count: 10,
        length: 10,
      },
    },
    sms: {
      codeLength: 6,
      expiresIn: '5m',
      rateLimit: '3/15m',
      provider: process.env.SMS_PROVIDER || '',
      retryLimit: 3,
      cooldownPeriod: '1h',
    },
    email: {
      codeLength: 6,
      expiresIn: '15m',
      rateLimit: '3/15m',
      retryLimit: 3,
      cooldownPeriod: '1h',
      template: 'mfa-verification',
    },
  },

  /**
   * Biometric authentication settings for mobile devices,
   * allowing up to five devices per user and periodic revalidation.
   */
  biometric: {
    enabled: true,
    allowedTypes: ['touchid', 'faceid', 'fingerprint'],
    maxDevices: 5,
    challengeTimeout: '30s',
    revalidateInterval: '14d',
  },

  /**
   * Additional security controls, including rate limiting,
   * account lockout rules, and secure HTTP headers.
   */
  security: {
    rateLimiting: {
      login: '5/5m',
      passwordReset: '3/1h',
      accountCreation: '3/24h',
    },
    lockout: {
      maxAttempts: 5,
      duration: '30m',
      incrementalDelay: true,
    },
    headers: {
      hsts: true,
      xssProtection: true,
      noSniff: true,
      frameOptions: 'DENY',
    },
  },
};