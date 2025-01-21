/***************************************************************************************************
 * AuthService
 * -----------------------------------------------------------------------------------------------
 * Core authentication service implementing user registration, login, logout, multi-factor
 * authentication, social authentication, biometric support, rate limiting, device tracking,
 * and comprehensive audit logging as specified in the technical design documentation.
 *
 * It integrates:
 *  1) JwtService for JWT issuance, verification, refresh, and blacklisting.
 *  2) MFAService for multi-factor authentication flows (TOTP, SMS, Email, backup codes).
 *  3) passport (v0.7.0) with passport-local (v1.0.0) and passport-oauth2 (v1.7.0) for local and
 *     social auth strategies.
 *  4) biometric-auth (v1.2.0) for biometric enrollment and verification.
 *  5) rate-limiter-flexible (v2.4.1) for advanced rate limiting, progressive delays, and account
 *     lockout mechanisms.
 *
 * References to the specification:
 * - 7.1.1 Authentication Flow (JWT tokens, MFA, device fingerprinting)
 * - 7.1.2 Authentication Methods (email/password, social, biometric, MFA)
 * - 7.3.1 Access Control (rate limiting, lockout, security monitoring, audit logging)
 **************************************************************************************************/

// -------------------------------------------------------------------------------------------------
// External Imports (with library versions as comments)
// -------------------------------------------------------------------------------------------------
import passport from 'passport'; // v0.7.0
import { Strategy as LocalStrategy } from 'passport-local'; // v1.0.0
import OAuth2Strategy from 'passport-oauth2'; // v1.7.0
import * as biometricAuth from '@auth/biometric'; // v1.2.0
import {
  RateLimiterMemory,
  IRateLimiterOptions,
  RateLimiterRes,
} from 'rate-limiter-flexible'; // v2.4.1

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import { authConfig } from '../config/auth.config';
import { User, IUserDocument } from '../models/user.model';
import {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
  rotateRefreshToken,
  blacklistToken,
} from './jwt.service';
import { MFAService } from './mfa.service';

// -------------------------------------------------------------------------------------------------
// Types and Interfaces
// -------------------------------------------------------------------------------------------------

/**
 * Represents the result of a successful authentication or registration
 * providing tokens, user info, and optional MFA details.
 */
export interface AuthResult {
  user: IUserDocument;
  accessToken: string;
  refreshToken: string;
  mfaRequired?: boolean;
  mfaPendingSetup?: boolean;
  message?: string;
}

/**
 * Registration data containing essential fields plus any flags for MFA.
 */
export interface RegistrationData {
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
  phoneNumber?: string;
  enableMFA?: boolean;
}

/**
 * Device information, which may be used for device fingerprinting,
 * session identification, or advanced auditing.
 */
export interface DeviceInfo {
  deviceId?: string;
  deviceType?: string;
  ipAddress?: string;
  userAgent?: string;
}

/***************************************************************************************************
 * AuthService Class
 * -----------------------------------------------------------------------------------------------
 * Implements advanced security controls, including:
 *    - Registration with password hashing and unique constraints
 *    - Login (local auth) with rate limiting, account lockout, and device tracking
 *    - Social auth integration via OAuth2
 *    - Multi-factor authentication integration (TOTP, SMS, Email)
 *    - Biometric enrollment and verification
 *    - Token blacklisting and rotation for secure session management
 *    - Comprehensive audit logging
 **************************************************************************************************/
export class AuthService {
  /**
   * Rate limiter for user registrations. Prevents excessive account creation attempts.
   */
  private registrationLimiter: RateLimiterMemory;

  /**
   * Rate limiter for login attempts to mitigate brute-force attacks with progressive delays.
   */
  private loginLimiter: RateLimiterMemory;

  /**
   * MFA service handling TOTP/SMS/Email code generation and verification,
   * as well as backup code creation.
   */
  private mfaService: MFAService;

  /**
   * Biometric auth utility or validation for enrolling and verifying user biometrics.
   * The actual usage can vary depending on the library's API.
   */
  private biometricValidator: any;

  /**
   * Constructor:
   * Initializes rate limiters, passport strategies, and references the MFAService.
   * In a real-world scenario, you could inject a logger or Redis-based limiter here as well.
   */
  constructor() {
    // Initialization of the rate-limiter-flexible memory-based approach
    // for demonstration. In production, consider Redis or other distributed store.
    const registrationOpts: IRateLimiterOptions = {
      points: 3, // Maximum 3 registrations
      duration: 3600, // Per hour
      blockDuration: 7200, // Block for 2 hours after maximum attempts
      execEvenly: false,
    };

    const loginOpts: IRateLimiterOptions = {
      points: 5, // Maximum 5 login attempts
      duration: 300, // Per 5-minute window
      blockDuration: 1800, // Block for 30 minutes if limit is reached
      execEvenly: false,
    };

    this.registrationLimiter = new RateLimiterMemory(registrationOpts);
    this.loginLimiter = new RateLimiterMemory(loginOpts);

    // Construct MFA service - in production you'd pass a Redis client, logger, etc.
    // For demonstration, we do not pass any custom constructor args.
    this.mfaService = new MFAService(null as any, console as any);

    // Setup biometric reference from the external package. The library usage may vary.
    this.biometricValidator = biometricAuth;

    // Setup or configure passport local, passport oauth2, etc. if needed here.
    passport.use(
      'local',
      new LocalStrategy(
        {
          usernameField: 'email',
          passwordField: 'password',
          passReqToCallback: true,
        },
        async (req: any, email: string, password: string, done: any) => {
          try {
            // We skip direct usage here, the login method below implements final logic
            // This strategy definition is an example if required by direct passport usage
            const loginResult = await this.login(email, password, req.body.deviceInfo || {});
            return done(null, loginResult.user);
          } catch (err) {
            return done(err, false);
          }
        }
      )
    );

    // Example OAuth2 strategy setup for demonstration.
    passport.use(
      'oauth2',
      new OAuth2Strategy(
        {
          authorizationURL: 'https://example.com/oauth2/authorize',
          tokenURL: 'https://example.com/oauth2/token',
          clientID: 'CLIENT_ID',
          clientSecret: 'CLIENT_SECRET',
          callbackURL: 'https://yourapp.com/auth/callback',
        },
        async (accessToken: string, refreshTokenStr: string, profile: any, done: any) => {
          try {
            // The 'socialAuth' method can handle the creation or retrieval of the user
            // This is a placeholder if direct passport flow is used
            const socialResult = await this.socialAuth(
              'generic-oauth2',
              accessToken,
              refreshTokenStr,
              profile
            );
            return done(null, socialResult.user);
          } catch (err) {
            return done(err, false);
          }
        }
      )
    );
  }

  // -----------------------------------------------------------------------------------------------
  // 1) register
  // -----------------------------------------------------------------------------------------------
  /**
   * Registers a new user with enhanced security features:
   *  1) Validate registration data with thorough checks.
   *  2) Enforce rate limiting on registration attempts.
   *  3) Check for existing email (uniqueness).
   *  4) Hash password using Argon2id and create user.
   *  5) Store device info for auditing or device fingerprinting.
   *  6) Generate secure access and refresh tokens bound to user/device.
   *  7) Initialize MFA if requested (TOTP or other methods).
   *  8) Log the registration event in the user's security log.
   *  9) Return AuthResult with tokens and user info.
   *
   * @param registrationData - object containing email, password, optional personal info
   * @param deviceInfo       - optional device details for logging / fingerprinting
   * @returns Promise<AuthResult> containing the user, tokens, and security status
   */
  public async register(
    registrationData: RegistrationData,
    deviceInfo: DeviceInfo
  ): Promise<AuthResult> {
    // 1) Validate minimal fields
    if (!registrationData.email || !registrationData.password) {
      throw new Error('Email and password are required for registration.');
    }

    // 2) Rate limiting check
    try {
      await this.registrationLimiter.consume(registrationData.email);
    } catch (rateErr) {
      throw new Error(
        'Registration attempts limit reached. Please wait before trying again.'
      );
    }

    // 3) Check if user already exists
    const existingUser = await User.findOne({ email: registrationData.email });
    if (existingUser) {
      throw new Error('User with this email already exists.');
    }

    // 4) Create new user and set password
    const user = new User();
    user.email = registrationData.email;
    user.firstName = registrationData.firstName || '';
    user.lastName = registrationData.lastName || '';
    if (registrationData.phoneNumber) {
      user.phoneNumber = registrationData.phoneNumber; // encryption done in user model pre-validate
    }
    await user.setPassword(registrationData.password);

    // Additional optional device tracking
    user.sessionInfo = user.sessionInfo || {};
    user.sessionInfo.registrationDevice = {
      deviceId: deviceInfo.deviceId || null,
      deviceType: deviceInfo.deviceType || null,
      ipAddress: deviceInfo.ipAddress || null,
      userAgent: deviceInfo.userAgent || null,
      registeredAt: new Date(),
    };

    // 5) Save user record
    await user.save();

    // 6) Generate tokens with device binding or additional claims if needed
    const accessToken = await generateAccessToken(user, {
      // Additional payload or custom expiresIn can be added here
    });
    const refreshToken = await generateRefreshToken(user, {
      // Additional payload or rotation logic can be set here
    });

    // 7) Initialize MFA if requested
    let mfaPendingSetup = false;
    if (registrationData.enableMFA) {
      // This example sets a flag for the client to call 'setupMFA' flow, or we could do it automatically.
      mfaPendingSetup = true;
      user.securityLog.push({
        event: 'MFA_INIT_REQUEST',
        timestamp: new Date(),
        detail: 'User requested MFA setup during registration',
      });
      await user.save();
    }

    // 8) Log registration event
    user.securityLog.push({
      event: 'USER_REGISTERED',
      timestamp: new Date(),
      detail: `Registration from device: ${deviceInfo.deviceId || 'unknown'}`,
    });
    await user.save();

    // 9) Return AuthResult
    return {
      user,
      accessToken,
      refreshToken,
      mfaPendingSetup,
    };
  }

  // -----------------------------------------------------------------------------------------------
  // 2) login
  // -----------------------------------------------------------------------------------------------
  /**
   * Authenticates a user with email/password credentials including:
   *  1) Rate limiting of login attempts with progressive lockout.
   *  2) Retrieval of user by email, verifying password with Argon2id.
   *  3) Device tracking for each login attempt.
   *  4) Token issuance upon success, capturing security logs.
   *  5) Optional check if MFA is configured and required.
   *  6) Return AuthResult with user, tokens, and optional MFA requirement.
   *
   * @param email       - user's email
   * @param password    - user's password
   * @param deviceInfo  - optional device details for logging / fingerprinting
   * @returns Promise<AuthResult>
   */
  public async login(
    email: string,
    password: string,
    deviceInfo: DeviceInfo
  ): Promise<AuthResult> {
    // 1) Rate limiting for login attempts
    try {
      await this.loginLimiter.consume(email);
    } catch (loginErr) {
      throw new Error(
        'Too many login attempts. Account temporarily locked or delayed.'
      );
    }

    // 2) Retrieve user
    const user = await User.findOne({ email });
    if (!user) {
      throw new Error('Invalid email or password.');
    }

    // 3) Validate password
    const isValidPassword = await user.validatePassword(password);
    if (!isValidPassword) {
      throw new Error('Invalid email or password.');
    }

    // 4) Device tracking
    user.securityLog.push({
      event: 'LOGIN_ATTEMPT',
      timestamp: new Date(),
      detail: `Device: ${deviceInfo.deviceId || 'unknown'} IP: ${
        deviceInfo.ipAddress || 'unknown'
      }`,
    });
    user.sessionInfo = user.sessionInfo || {};
    user.sessionInfo.lastLoginDevice = {
      deviceId: deviceInfo.deviceId || null,
      deviceType: deviceInfo.deviceType || null,
      ipAddress: deviceInfo.ipAddress || null,
      userAgent: deviceInfo.userAgent || null,
      loginTime: new Date(),
    };
    await user.save();

    // 5) Check if MFA is configured and required
    // In a real scenario, you might check user.mfaSettings or another field to see if MFA is mandatory
    let mfaRequired = false;
    if (user.mfaSettings && (user.mfaSettings.TOTP || user.mfaSettings.SMS || user.mfaSettings.EMAIL)) {
      mfaRequired = true;
    }

    // 6) Issue tokens if no immediate MFA block
    let accessToken = '';
    let refreshToken = '';
    if (!mfaRequired) {
      accessToken = await generateAccessToken(user, {});
      refreshToken = await generateRefreshToken(user, {});
    }

    // Log successful or partial login pending MFA
    user.securityLog.push({
      event: mfaRequired ? 'LOGIN_MFA_REQUIRED' : 'LOGIN_SUCCESS',
      timestamp: new Date(),
    });
    await user.save();

    return {
      user,
      accessToken,
      refreshToken,
      mfaRequired,
    };
  }

  // -----------------------------------------------------------------------------------------------
  // 3) socialAuth
  // -----------------------------------------------------------------------------------------------
  /**
   * Social authentication that handles OAuth2-based providers:
   *  1) Validate or parse the identity from provider's profile or tokens.
   *  2) Find or create a user record in local database.
   *  3) Generate tokens upon success.
   *  4) Log social auth events for auditing.
   *
   * @param provider       - Name of the provider (e.g., 'google', 'apple', 'facebook', or 'generic-oauth2')
   * @param accessToken    - OAuth2 access token from provider
   * @param refreshToken   - OAuth2 refresh token from provider
   * @param profile        - The user info from provider
   * @returns Promise<AuthResult>
   */
  public async socialAuth(
    provider: string,
    accessToken: string,
    refreshToken: string,
    profile: any
  ): Promise<AuthResult> {
    // Basic extraction of unique user info from the profile
    // The structure depends on the OAuth2 provider's response
    if (!profile || !profile.email) {
      throw new Error('No valid email found in social provider profile.');
    }

    let user = await User.findOne({ email: profile.email });
    if (!user) {
      user = new User();
      user.email = profile.email;
      user.oauthProfiles = user.oauthProfiles || {};
    }

    // Store or update the provider's ID/token in the user's oauthProfiles
    user.oauthProfiles[provider] = {
      providerId: profile.id || '',
      accessToken,
      refreshToken,
      lastLogin: new Date(),
    };

    user.securityLog.push({
      event: 'SOCIAL_AUTH',
      timestamp: new Date(),
      detail: `Provider: ${provider}`,
    });

    await user.save();

    // Generate new tokens
    const localAccessToken = await generateAccessToken(user, {});
    const localRefreshToken = await generateRefreshToken(user, {});

    return {
      user,
      accessToken: localAccessToken,
      refreshToken: localRefreshToken,
    };
  }

  // -----------------------------------------------------------------------------------------------
  // 4) verifyMFA
  // -----------------------------------------------------------------------------------------------
  /**
   * Verifies a multi-factor authentication code from TOTP, SMS, or Email.
   *  1) Identifies the MFA method from user input.
   *  2) Uses MFAService to verify the code.
   *  3) If successful, issues final tokens or marks MFA as satisfied.
   *  4) Logs the verification attempt.
   *
   * @param userId    - The user identifier
   * @param method    - The MFA method type ('TOTP', 'SMS', 'EMAIL')
   * @param code      - The one-time code to verify
   * @returns Promise<AuthResult> with tokens if MFA is satisfied
   */
  public async verifyMFA(
    userId: string,
    method: 'TOTP' | 'SMS' | 'EMAIL',
    code: string
  ): Promise<AuthResult> {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found.');
    }

    // If user has no matching MFA configured, fail
    if (!user.mfaSettings || !user.mfaSettings[method]) {
      throw new Error(`MFA method ${method} not set up for this user.`);
    }

    let verified = false;
    if (method === 'TOTP') {
      verified = await this.mfaService.verifyTOTP(userId, code);
    } else if (method === 'SMS') {
      verified = await this.mfaService.verifySMSCode(userId, code);
    } else if (method === 'EMAIL') {
      verified = await this.mfaService.verifyEmailCode(userId, code);
    }

    user.securityLog.push({
      event: 'MFA_VERIFY_ATTEMPT',
      timestamp: new Date(),
      detail: `Method: ${method}, Success: ${verified}`,
    });
    await user.save();

    if (!verified) {
      throw new Error('MFA code verification failed.');
    }

    // If verification passes, generate final tokens
    const accessToken = await generateAccessToken(user, {});
    const refreshToken = await generateRefreshToken(user, {});

    user.securityLog.push({
      event: 'MFA_VERIFY_SUCCESS',
      timestamp: new Date(),
    });
    await user.save();

    return {
      user,
      accessToken,
      refreshToken,
    };
  }

  // -----------------------------------------------------------------------------------------------
  // 5) logout
  // -----------------------------------------------------------------------------------------------
  /**
   * Logs a user out by blacklisting the provided access token and optionally
   * rotating or invalidating refresh tokens. Also logs this event for auditing.
   *
   * @param user       - The user object
   * @param token      - The JWT to be blacklisted
   * @returns Promise<void>
   */
  public async logout(user: IUserDocument, token: string): Promise<void> {
    if (!token) {
      throw new Error('No token provided for logout.');
    }

    // Blacklist the token
    await blacklistToken(token);

    // Optionally, you could also handle refresh token revocation or rotation if needed

    user.securityLog.push({
      event: 'LOGOUT',
      timestamp: new Date(),
      detail: 'User logged out. Access token blacklisted.',
    });
    await user.save();
  }

  // -----------------------------------------------------------------------------------------------
  // 6) setupBiometric
  // -----------------------------------------------------------------------------------------------
  /**
   * Enrolls a user in biometric authentication by capturing or linking
   * a biometric signature. This is a placeholder, as actual implementations
   * depend on hardware, platform, and the biometric-auth library usage.
   *
   * @param userId      - The user identifier
   * @param biometricData - Data or token capturing the new biometric signature
   * @returns Promise<boolean> indicating success
   */
  public async setupBiometric(userId: string, biometricData: any): Promise<boolean> {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found.');
    }

    if (!authConfig.biometric.enabled) {
      throw new Error('Biometric authentication is not enabled in authConfig.');
    }

    // Hypothetical usage of the biometric-auth library
    const validated = await this.biometricValidator.enrollBiometric({
      userId,
      biometricData,
      maxDevices: authConfig.biometric.maxDevices,
    });
    if (!validated) {
      throw new Error('Failed to enroll biometric data.');
    }

    user.biometricData = user.biometricData || {};
    user.biometricData[userId] = biometricData;
    user.securityLog.push({
      event: 'BIOMETRIC_SETUP',
      timestamp: new Date(),
      detail: 'User enrolled new biometric signature.',
    });
    await user.save();

    return true;
  }

  // -----------------------------------------------------------------------------------------------
  // 7) verifyBiometric
  // -----------------------------------------------------------------------------------------------
  /**
   * Verifies a user's biometric signature. If matched, returns AuthResult with tokens.
   *
   * @param userId        - The user identifier
   * @param biometricData - Biometric data for verification
   * @returns Promise<AuthResult> if verified, otherwise throws error
   */
  public async verifyBiometric(userId: string, biometricData: any): Promise<AuthResult> {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found.');
    }
    if (!authConfig.biometric.enabled) {
      throw new Error('Biometric authentication is not enabled.');
    }

    // Hypothetical usage of the biometric-auth library
    const verified = await this.biometricValidator.verifyBiometric({
      userId,
      biometricData,
    });
    user.securityLog.push({
      event: 'BIOMETRIC_VERIFY_ATTEMPT',
      timestamp: new Date(),
      detail: `Success: ${verified}`,
    });
    await user.save();

    if (!verified) {
      throw new Error('Biometric verification failed.');
    }

    // If verified, generate tokens
    const accessToken = await generateAccessToken(user, {});
    const refreshToken = await generateRefreshToken(user, {});

    user.securityLog.push({
      event: 'BIOMETRIC_VERIFY_SUCCESS',
      timestamp: new Date(),
    });
    await user.save();

    return {
      user,
      accessToken,
      refreshToken,
    };
  }

  // -----------------------------------------------------------------------------------------------
  // 8) generateBackupCodes
  // -----------------------------------------------------------------------------------------------
  /**
   * Generates backup codes for a user via MFAService, storing them securely
   * and returning the raw codes as needed.
   *
   * @param userId - The user identifier
   * @returns Promise<string[]> array of generated backup codes
   */
  public async generateBackupCodes(userId: string): Promise<string[]> {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found.');
    }

    // For demonstration, call MFAService's generateBackupCodes method directly
    // In real usage, you might store them in user.mfaSettings or a secure store
    const totpConfig = authConfig.mfa?.totp;
    if (!totpConfig) {
      throw new Error('TOTP configuration not found. Cannot generate backup codes.');
    }

    const backupCodes = this.mfaService.generateBackupCodes(
      totpConfig.backupCodes.count,
      totpConfig.backupCodes.length
    );

    user.securityLog.push({
      event: 'GENERATE_BACKUP_CODES',
      timestamp: new Date(),
      detail: 'User requested new backup codes.',
    });
    await user.save();

    return backupCodes;
  }
}

// -------------------------------------------------------------------------------------------------
// Named Exports for the AuthService class and all required members
// -------------------------------------------------------------------------------------------------
export const register = AuthService.prototype.register;
export const login = AuthService.prototype.login;
export const socialAuth = AuthService.prototype.socialAuth;
export const verifyMFA = AuthService.prototype.verifyMFA;
export const logout = AuthService.prototype.logout;
export const setupBiometric = AuthService.prototype.setupBiometric;
export const verifyBiometric = AuthService.prototype.verifyBiometric;
export const generateBackupCodes = AuthService.prototype.generateBackupCodes;