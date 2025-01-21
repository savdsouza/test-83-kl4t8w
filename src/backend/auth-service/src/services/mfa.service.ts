/**
 * Multi-Factor Authentication (MFA) Service
 * ----------------------------------------
 * This service handles all MFA operations (TOTP, SMS, Email) with enhanced
 * security features, including encryption of secrets, rate limiting, and
 * comprehensive logging for security events.
 *
 * It implements:
 *   1) TOTP key generation and verification (otplib - v12.0.1)
 *   2) SMS code generation and verification (twilio - v4.19.0)
 *   3) Email code generation and verification (nodemailer - v6.9.7)
 *   4) Rate limiting and temporary storage using Redis (redis - v4.6.10)
 *   5) Security event logging (winston - v3.11.0)
 *   6) Encryption/Decryption for sensitive data (encryptData, decryptData)
 */

import { authConfig } from '../config/auth.config';
import { encryptData, decryptData } from '../utils/encryption.util';
import { authenticator } from 'otplib'; // v12.0.1
import * as Twilio from 'twilio'; // v4.19.0
import nodemailer from 'nodemailer'; // v6.9.7
import { createClient, RedisClientType } from 'redis'; // v4.6.10
import { Logger } from 'winston'; // v3.11.0

/**
 * The MFAService class provides methods to create and verify TOTP secrets,
 * SMS codes, and email-based codes for multi-factor authentication.
 */
export class MFAService {
  /**
   * Redis client used for storing and retrieving MFA data, rate limiting,
   * and session-based ephemeral code storage.
   */
  private redisClient: RedisClientType;

  /**
   * Winston logger for auditing security events, verification attempts,
   * and overall MFA operations.
   */
  private logger: Logger;

  /**
   * Constructor
   * -----------
   * 1. Initializes Redis client for rate limiting and code storage.
   * 2. Initializes logger for security event tracking.
   * 3. Validates existence of MFA configuration settings in authConfig.
   * 4. Sets up a cleanup routine for expired MFA entries if needed.
   *
   * @param redisClient - Pre-initialized Redis client instance
   * @param logger - Winston logger instance for security logs
   */
  public constructor(redisClient: RedisClientType, logger: Logger) {
    this.redisClient = redisClient;
    this.logger = logger;

    // Basic validation check to ensure we have the required configuration
    if (!authConfig.mfa) {
      throw new Error('MFA configuration is missing from authConfig.');
    }

    // Optional: Create a routine to clean up expired keys if needed.
    // This is left as an example placeholder:
    // setInterval(() => this.cleanupExpiredCodes(), 60 * 60 * 1000);

    this.logger.info('[MFAService] Initialized MFA service with Redis and Logger.');
  }

  /**
   * generateTOTPSecret
   * ------------------
   * Generates and stores an encrypted TOTP secret along with backup codes.
   * Returns an object containing the raw TOTP secret, a QR Code URL for
   * authenticator apps, and an array of backup codes. The secret itself is
   * stored in encrypted form in Redis; backup codes can also be stored in
   * encrypted form according to best practices.
   *
   * Steps:
   *  1. Check rate limiting for TOTP generation attempts.
   *  2. Generate a secure random TOTP secret using otplib.
   *  3. Generate backup codes based on configuration (count and length).
   *  4. Encrypt secret and backup codes using encryption.util.
   *  5. Store encrypted data in Redis with appropriate TTL if desired.
   *  6. Construct a QR code URL for common authenticator apps.
   *  7. Log TOTP setup event in Winston.
   *  8. Return the unencrypted secret, QR code URL, and backup codes.
   *
   * @param userId - Unique ID of the user requesting TOTP setup.
   * @returns Promise<object> - { secret, qrCodeUrl, backupCodes }
   */
  public async generateTOTPSecret(userId: string): Promise<{
    secret: string;
    qrCodeUrl: string;
    backupCodes: string[];
  }> {
    // 1. Check rate limiting for TOTP generation
    await this.enforceRateLimit(`mfa:totpGen:${userId}`, authConfig.mfa.totp.window);

    // 2. Generate TOTP secret
    const totpConfig = authConfig.mfa.totp;
    authenticator.options = {
      digits: totpConfig.digits,
      step: totpConfig.period,
      window: totpConfig.window,
      algorithm: totpConfig.algorithm,
    };
    const rawSecret = authenticator.generateSecret();

    // 3. Generate backup codes
    const backupCodes = this.generateBackupCodes(
      totpConfig.backupCodes.count,
      totpConfig.backupCodes.length
    );

    // 4. Encrypt secret and backup codes
    // Provide your own encryption key or source from environment
    const encryptionKey = process.env.MFA_ENCRYPTION_KEY || 'default-mfa-key';
    const encryptedSecret = encryptData(rawSecret, encryptionKey);
    const encryptedBackups = encryptData(JSON.stringify(backupCodes), encryptionKey);

    // 5. Store encrypted data in Redis (you can store these in a DB if preferred)
    const secretKeyRedis = `mfa:totp:secret:${userId}`;
    const backupKeyRedis = `mfa:totp:backup:${userId}`;
    await this.redisClient.set(secretKeyRedis, JSON.stringify(encryptedSecret));
    await this.redisClient.set(backupKeyRedis, JSON.stringify(encryptedBackups));
    // Optionally set a TTL if desired (e.g. store indefinitely or set purge policies)
    // await this.redisClient.expire(secretKeyRedis, 86400);

    // 6. Construct QR code URL (otpauth URI)
    const issuer = totpConfig.issuer || 'DogWalking';
    // Typically you'd supply a label such as 'user@example.com', but here we just use userId
    const qrCodeUrl = authenticator.keyuri(userId, issuer, rawSecret);

    // 7. Log TOTP setup
    this.logger.info(`[MFAService] User '${userId}' has initialized TOTP MFA.`);

    // 8. Return raw TOTP secret, QR code URL, and backup codes to user
    return {
      secret: rawSecret,
      qrCodeUrl,
      backupCodes,
    };
  }

  /**
   * verifyTOTP
   * ----------
   * Verifies a TOTP code submitted by the user, enforcing rate limiting
   * and logging each attempt. Uses otplib with stored, encrypted TOTP
   * secrets from Redis.
   *
   * Steps:
   *  1. Check rate limiting for TOTP verification attempts.
   *  2. Retrieve and decrypt the stored TOTP secret from Redis.
   *  3. Use otplib to verify the provided code.
   *  4. Log the verification attempt and result.
   *  5. Update rate limiting counters if needed.
   *  6. Return a boolean result indicating success or failure.
   *
   * @param userId - Unique ID of the user
   * @param code   - The TOTP code submitted for verification
   * @returns Promise<boolean> - Verification result
   */
  public async verifyTOTP(userId: string, code: string): Promise<boolean> {
    // 1. Check rate limiting for verification
    await this.enforceRateLimit(`mfa:totpVerify:${userId}`, authConfig.mfa.totp.window);

    // 2. Retrieve TOTP secret from Redis
    const encryptionKey = process.env.MFA_ENCRYPTION_KEY || 'default-mfa-key';
    const secretKeyRedis = `mfa:totp:secret:${userId}`;
    const encryptedSecretData = await this.redisClient.get(secretKeyRedis);

    if (!encryptedSecretData) {
      this.logger.warn(`[MFAService] No TOTP secret found for user '${userId}'.`);
      return false;
    }

    // Decrypt the stored secret
    let secretPlaintext: string;
    try {
      const parsedData = JSON.parse(encryptedSecretData);
      secretPlaintext = decryptData(parsedData, encryptionKey);
    } catch (err) {
      this.logger.error(`[MFAService] Error decrypting TOTP secret for user '${userId}': ${err}`);
      return false;
    }

    // 3. Verify the code with otplib
    authenticator.options = {
      digits: authConfig.mfa.totp.digits,
      step: authConfig.mfa.totp.period,
      window: authConfig.mfa.totp.window,
      algorithm: authConfig.mfa.totp.algorithm,
    };

    const verified = authenticator.verify({ token: code, secret: secretPlaintext });

    // 4. Log attempt
    this.logger.info(
      `[MFAService] TOTP verification attempt for user '${userId}'. Success: ${verified}`
    );

    // 5. (Optional) Update counters or further analytics
    // e.g., track successful vs. failed attempts

    // 6. Return verification result
    return verified;
  }

  /**
   * generateSMSCode
   * ---------------
   * Generates an SMS-based verification code (e.g., 6 digits), enforces rate
   * limiting, stores the code in Redis (encrypted or plain ephemeral), and
   * sends an SMS via Twilio. The code expires after the configured time.
   *
   * Steps:
   *  1. Enforce rate limiting for SMS code generation.
   *  2. Generate a random numeric code of configured length.
   *  3. Encrypt and store the code in Redis with a TTL.
   *  4. Send the code via Twilio SMS to the user's phone number.
   *  5. Log the event for auditing.
   *  6. Return success/failure or relevant metadata.
   *
   * @param userId - Unique ID of the user
   * @param phoneNumber - The phone number to which the SMS code is sent
   */
  public async generateSMSCode(userId: string, phoneNumber: string): Promise<boolean> {
    const { codeLength, expiresIn, rateLimit, retryLimit, cooldownPeriod } = authConfig.mfa.sms;

    // 1. Enforce rate limiting for generating SMS codes
    await this.enforceRateLimit(`mfa:smsGen:${userId}`, this.parseRateLimit(rateLimit));

    // 2. Generate a random numeric code with the configured length
    const code = this.createRandomNumericCode(codeLength);

    // 3. Encrypt and store in Redis
    const encryptionKey = process.env.MFA_ENCRYPTION_KEY || 'default-mfa-key';
    const encryptedData = encryptData(code, encryptionKey);
    const redisKey = `mfa:sms:code:${userId}`;
    await this.redisClient.set(redisKey, JSON.stringify(encryptedData), {
      EX: this.convertToSeconds(expiresIn),
    });

    // 4. Send the code via Twilio
    const smsClient = Twilio(process.env.TWILIO_SID || '', process.env.TWILIO_AUTH_TOKEN || '');
    try {
      await smsClient.messages.create({
        body: `Your verification code is: ${code}`,
        from: process.env.TWILIO_FROM_NUMBER,
        to: phoneNumber,
      });
    } catch (err) {
      this.logger.error(`[MFAService] Failed to send SMS code for user '${userId}': ${err}`);
      return false;
    }

    // 5. Log event
    this.logger.info(`[MFAService] Generated and sent SMS code for user '${userId}'.`);

    // 6. Return success
    return true;
  }

  /**
   * verifySMSCode
   * -------------
   * Verifies the SMS verification code provided by the user. Retrieves the
   * code from Redis, decrypts it, compares with user input, enforces rate
   * limiting, and logs attempts.
   *
   * Steps:
   *  1. Enforce rate limiting for SMS code verification.
   *  2. Retrieve the code from Redis and decrypt.
   *  3. Compare user input with the stored code.
   *  4. Log the verification attempt.
   *  5. Clear stored code if needed.
   *  6. Return boolean result.
   *
   * @param userId - Unique ID of the user
   * @param submittedCode - The code user submitted for verification
   * @returns Promise<boolean> - True if matches the stored code
   */
  public async verifySMSCode(userId: string, submittedCode: string): Promise<boolean> {
    const { rateLimit } = authConfig.mfa.sms;

    // 1. Enforce rate limiting for verification
    await this.enforceRateLimit(`mfa:smsVerify:${userId}`, this.parseRateLimit(rateLimit));

    // 2. Retrieve from Redis
    const encryptionKey = process.env.MFA_ENCRYPTION_KEY || 'default-mfa-key';
    const redisKey = `mfa:sms:code:${userId}`;
    const encryptedVal = await this.redisClient.get(redisKey);
    if (!encryptedVal) {
      this.logger.warn(`[MFAService] No SMS code found in Redis for user '${userId}'.`);
      return false;
    }

    let storedCode: string;
    try {
      const parsedData = JSON.parse(encryptedVal);
      storedCode = decryptData(parsedData, encryptionKey);
    } catch (err) {
      this.logger.error(`[MFAService] Failed to decrypt SMS code for user '${userId}': ${err}`);
      return false;
    }

    // 3. Compare
    const match = submittedCode === storedCode;

    // 4. Log attempt
    this.logger.info(`[MFAService] SMS code verification for user '${userId}'. Success: ${match}`);

    // 5. Clear code if we want to prevent reuse
    if (match) {
      await this.redisClient.del(redisKey);
    }

    // 6. Return result
    return match;
  }

  /**
   * generateEmailCode
   * -----------------
   * Creates a verification code for email-based MFA, enforces rate limiting,
   * encrypts and stores the code in Redis, sends an email via nodemailer.
   *
   * Steps:
   *  1. Enforce rate limiting for email code generation.
   *  2. Generate a random code of configured length.
   *  3. Encrypt and store the code in Redis with a TTL.
   *  4. Send the code via nodemailer to the user's email.
   *  5. Log the event for auditing.
   *  6. Return success/failure.
   *
   * @param userId - Unique user identifier
   * @param email  - Destination email address for verification
   */
  public async generateEmailCode(userId: string, email: string): Promise<boolean> {
    const { codeLength, expiresIn, rateLimit, retryLimit, cooldownPeriod, template } =
      authConfig.mfa.email;

    // 1. Rate limit
    await this.enforceRateLimit(`mfa:emailGen:${userId}`, this.parseRateLimit(rateLimit));

    // 2. Generate code
    const code = this.createRandomNumericCode(codeLength);

    // 3. Encrypt and store
    const encryptionKey = process.env.MFA_ENCRYPTION_KEY || 'default-mfa-key';
    const encrypted = encryptData(code, encryptionKey);
    const redisKey = `mfa:email:code:${userId}`;
    await this.redisClient.set(redisKey, JSON.stringify(encrypted), {
      EX: this.convertToSeconds(expiresIn),
    });

    // 4. Send via nodemailer
    const transporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST || '',
      port: Number(process.env.EMAIL_PORT) || 587,
      secure: false,
      auth: {
        user: process.env.EMAIL_USER || '',
        pass: process.env.EMAIL_PASS || '',
      },
    });

    try {
      await transporter.sendMail({
        from: process.env.EMAIL_FROM || '',
        to: email,
        subject: 'Your MFA Verification Code',
        text: `Your verification code is: ${code}`,
        // HTML or a template system could be used here for a more advanced email
      });
    } catch (err) {
      this.logger.error(`[MFAService] Failed to send email code to '${email}': ${err}`);
      return false;
    }

    // 5. Log event
    this.logger.info(`[MFAService] Generated and sent Email code for user '${userId}'.`);

    // 6. Return success
    return true;
  }

  /**
   * verifyEmailCode
   * ---------------
   * Fetches the stored email verification code from Redis, decrypts it,
   * compares it to the user-submitted code, and enforces verification rate
   * limiting.
   *
   * Steps:
   *  1. Enforce rate limiting for email code verification.
   *  2. Retrieve the code from Redis and decrypt.
   *  3. Compare user input with the stored code.
   *  4. Log the verification attempt.
   *  5. Clear stored code if match is successful.
   *  6. Return boolean indicating success or failure.
   *
   * @param userId - Unique user identifier
   * @param submittedCode - Code submitted by the user
   * @returns Promise<boolean>
   */
  public async verifyEmailCode(userId: string, submittedCode: string): Promise<boolean> {
    const { rateLimit } = authConfig.mfa.email;

    // 1. Enforce rate limiting
    await this.enforceRateLimit(`mfa:emailVerify:${userId}`, this.parseRateLimit(rateLimit));

    // 2. Retrieve from Redis
    const encryptionKey = process.env.MFA_ENCRYPTION_KEY || 'default-mfa-key';
    const redisKey = `mfa:email:code:${userId}`;
    const encryptedValue = await this.redisClient.get(redisKey);
    if (!encryptedValue) {
      this.logger.warn(`[MFAService] No Email code found for user '${userId}'.`);
      return false;
    }

    let storedCode: string;
    try {
      const parsedData = JSON.parse(encryptedValue);
      storedCode = decryptData(parsedData, encryptionKey);
    } catch (err) {
      this.logger.error(`[MFAService] Decryption failed for Email code of user '${userId}': ${err}`);
      return false;
    }

    // 3. Compare
    const verified = storedCode === submittedCode;

    // 4. Log event
    this.logger.info(`[MFAService] Email code verification for user '${userId}' => ${verified}`);

    // 5. Clear code if successful
    if (verified) {
      await this.redisClient.del(redisKey);
    }

    // 6. Return result
    return verified;
  }

  /**
   * generateBackupCodes
   * -------------------
   * Generates multiple random backup codes for TOTP-based MFA to be used
   * when the primary device or TOTP app is unavailable.
   *
   * @param count  - Number of backup codes to generate
   * @param length - Character length of each code
   * @returns string[] - Array of randomly generated code strings
   */
  private generateBackupCodes(count: number, length: number): string[] {
    const codes: string[] = [];
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

    for (let i = 0; i < count; i++) {
      let code = '';
      for (let j = 0; j < length; j++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      codes.push(code);
    }
    return codes;
  }

  /**
   * enforceRateLimit
   * ----------------
   * Utility to increment a counter in Redis under a specified key to ensure
   * the user doesn't exceed a configured threshold for a particular action
   * (e.g., generating or verifying TOTP too many times). If the limit is
   * exceeded, throws an error to halt the operation.
   *
   * @param key     - Redis key to track
   * @param maxUses - Maximum allowed uses in the time window
   */
  private async enforceRateLimit(key: string, maxUses: number): Promise<void> {
    // If config is 0 or negative, skip rate limiting
    if (!maxUses || maxUses <= 0) return;

    const currentVal = await this.redisClient.incr(key);
    if (currentVal === 1) {
      // If first time, set an expiry. For demonstration, set 15-min expiry.
      await this.redisClient.expire(key, 900);
    }
    if (currentVal > maxUses) {
      this.logger.warn(`[MFAService] Rate limit exceeded for key: ${key}`);
      throw new Error('Rate limit exceeded for MFA operation.');
    }
  }

  /**
   * createRandomNumericCode
   * -----------------------
   * Creates a random numeric code (e.g., 6-digit) for SMS/Email usage.
   *
   * @param length - Number of digits
   * @returns string - Random numeric code
   */
  private createRandomNumericCode(length: number): string {
    let code = '';
    for (let i = 0; i < length; i++) {
      code += Math.floor(Math.random() * 10).toString();
    }
    return code;
  }

  /**
   * parseRateLimit
   * --------------
   * Parses a rate limit string from authConfig (e.g., '3/15m') to extract
   * the maximum uses or attempts. For simplicity, we only return the max
   * uses. The time window can be partially handled with an expire call
   * (e.g., 15m).
   *
   * A more advanced approach would parse the entire '3/15m' string and
   * attempt time-based logic. Here, we simply return 3 as the max uses.
   *
   * @param rate - A string like '3/15m' from config
   * @returns number - The allowed uses in the specified window
   */
  private parseRateLimit(rate: string): number {
    // Example format: '3/15m'
    // Splitting by '/' => [ '3', '15m' ]
    if (!rate || !rate.includes('/')) {
      return 0;
    }
    const [max, _window] = rate.split('/');
    return parseInt(max, 10) || 0;
  }

  /**
   * convertToSeconds
   * ----------------
   * Converts a string like '5m' or '15m' to the number of seconds.
   *
   * @param duration - Duration string (e.g. '5m', '1h')
   * @returns number - Equivalent duration in seconds
   */
  private convertToSeconds(duration: string): number {
    // Simple logic: '5m' => 5 * 60
    // '1h' => 60 * 60
    // '15m' => 15 * 60
    // Fallback to 300 if parsing fails
    if (!duration || duration.length < 2) return 300;

    const unit = duration.slice(-1);
    const value = parseInt(duration.slice(0, -1), 10);
    if (Number.isNaN(value)) return 300;

    switch (unit) {
      case 'm':
        return value * 60;
      case 'h':
        return value * 3600;
      case 'd':
        return value * 86400;
      default:
        return 300;
    }
  }
}