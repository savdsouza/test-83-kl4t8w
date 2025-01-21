/***************************************************************************************************
 * encryption.util.ts
 *
 * This utility module provides robust, enterprise-grade cryptographic functionalities for the 
 * Auth Service of the Dog Walking Platform. It implements:
 * 1) Argon2id-based secure password hashing with configurable parameters.
 * 2) AES-256-GCM encryption and decryption routines with authenticated encryption.
 * 3) A function to generate cryptographically secure encryption keys.
 *
 * All functions contain extensive error handling and best-effort memory wiping procedures for 
 * sensitive data, adhering to the highest security standards, including those specified in the
 * technical documentation under 7. SECURITY CONSIDERATIONS.
 **************************************************************************************************/

// -----------------------------------------------------------------------------------------------
// External Dependencies
// -----------------------------------------------------------------------------------------------
import argon2 from 'argon2'; // v0.31.2
import * as crypto from 'crypto'; // built-in Node.js crypto module

// -----------------------------------------------------------------------------------------------
// Internal Dependencies
// -----------------------------------------------------------------------------------------------
import { authConfig } from '../config/auth.config';

/***************************************************************************************************
 * Extract required segments from the authentication configuration. In a real-world scenario, 
 * authConfig.encryption should also be defined within the config file. If it is omitted, 
 * we gracefully fallback to default encryption settings here.
 **************************************************************************************************/
const {
  password: passwordConfig,
  encryption: encryptionConfig = {
    pbkdf2: {
      iterations: 100000,
      digest: 'sha512',
      saltLength: 16,
    },
    aes: {
      algorithm: 'aes-256-gcm',
      ivLength: 12,
      keyLength: 32,
    },
  },
} = authConfig;

// -----------------------------------------------------------------------------------------------
// Utility Functions - Password Validation
// -----------------------------------------------------------------------------------------------
/**
 * validatePasswordPolicy
 * Validates the given password against the configured password policy. 
 * Throws an error if the password does not meet the requirements.
 *
 * @param plainPassword - The plain-text password to validate.
 */
function validatePasswordPolicy(plainPassword: string): void {
  // Check minimum length requirement
  if (plainPassword.length < passwordConfig.minLength) {
    throw new Error(
      `Password must be at least ${passwordConfig.minLength} characters long.`
    );
  }

  // Check for uppercase characters
  if (passwordConfig.requireUppercase && !/[A-Z]/.test(plainPassword)) {
    throw new Error('Password must contain at least one uppercase letter.');
  }

  // Check for lowercase characters
  if (passwordConfig.requireLowercase && !/[a-z]/.test(plainPassword)) {
    throw new Error('Password must contain at least one lowercase letter.');
  }

  // Check for numbers
  if (passwordConfig.requireNumbers && !/[0-9]/.test(plainPassword)) {
    throw new Error('Password must contain at least one numeric digit.');
  }

  // Check for special characters
  if (
    passwordConfig.requireSpecialChars &&
    !/[^a-zA-Z0-9]/.test(plainPassword)
  ) {
    throw new Error('Password must contain at least one special character.');
  }
}

// -----------------------------------------------------------------------------------------------
// 1) hashPassword
// -----------------------------------------------------------------------------------------------
/**
 * @function hashPassword
 * @description
 * Hashes a password using Argon2id with configurable parameters for memory cost, time cost,
 * and parallelism. Also performs policy validation and memory wiping to minimize exposure 
 * of sensitive data in memory. Returns a base64-encoded Argon2id hash with the included salt 
 * and parameters.
 *
 * Steps (as specified):
 *  1. Validate password against minimum requirements.
 *  2. Generate cryptographically secure random salt.
 *  3. Configure Argon2id parameters from authConfig.
 *  4. Hash password using Argon2id with timing protection.
 *  5. Securely wipe password from memory.
 *  6. Return base64-encoded hash with parameters.
 *
 * @param password - The plain-text password to be hashed.
 * @returns Promise<string> - Resolved with the final base64-encoded Argon2id hash.
 */
export async function hashPassword(password: string): Promise<string> {
  // Step 1: Validate the plain-text password against the password policy
  validatePasswordPolicy(password);

  // Convert plain-text password to a Buffer for controlled memory wiping
  const passwordBuffer = Buffer.from(password, 'utf8');
  // Generate a cryptographically secure salt (Argon2 can auto-generate salt, but we do it as specified)
  const salt = crypto.randomBytes(passwordConfig.saltLength);

  try {
    // Step 3: Prepare Argon2id options from config
    const argon2Options = {
      type: argon2.argon2id,
      memoryCost: passwordConfig.hashingConfig.memoryCost,
      timeCost: passwordConfig.hashingConfig.timeCost,
      parallelism: passwordConfig.hashingConfig.parallelism,
      salt,
    };

    // Step 4: Hash the password buffer using Argon2id
    const hashedString = await argon2.hash(passwordBuffer, argon2Options);

    // Convert the Argon2 encoded output to base64
    const base64EncodedHash = Buffer.from(hashedString, 'utf8').toString(
      'base64'
    );

    // Return the base64-encoded Argon2id hash string
    return base64EncodedHash;
  } catch (error) {
    throw new Error(`Failed to hash password: ${error instanceof Error ? error.message : String(error)}`);
  } finally {
    // Step 5: Securely wipe the password buffer from memory
    passwordBuffer.fill(0);
  }
}

// -----------------------------------------------------------------------------------------------
// 2) verifyPassword
// -----------------------------------------------------------------------------------------------
/**
 * @function verifyPassword
 * @description
 * Verifies a plain-text password against a stored Argon2id hash. Uses constant-time
 * comparison (provided by Argon2) to mitigate timing attacks.
 *
 * Steps (as specified):
 *  1. Validate input parameters.
 *  2. Extract hash parameters via base64 decode.
 *  3. Verify password using Argon2id.
 *  4. Implement constant-time comparison (handled internally by Argon2).
 *  5. Securely wipe password from memory.
 *  6. Return boolean indicating match result.
 *
 * @param password - The plain-text password to verify.
 * @param hash - The base64-encoded Argon2id hash to compare against.
 * @returns Promise<boolean> - True if the password is correct, false otherwise.
 */
export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  // Step 1: Basic validation checks on input
  if (!password || !hash) {
    throw new Error('Both password and hash must be provided for verification.');
  }

  // Convert the plain-text password to a buffer for controlled memory wiping
  const passwordBuffer = Buffer.from(password, 'utf8');

  try {
    // Step 2: Decode the base64-encoded Argon2 hash
    const decodedHash = Buffer.from(hash, 'base64').toString('utf8');

    // Step 3 & 4: Use argon2.verify for the actual verification with Argon2id
    const match = await argon2.verify(decodedHash, passwordBuffer);

    // Argon2 internally ensures constant-time comparison. Return the match result.
    return match;
  } catch (error) {
    // If verification fails or the hash is invalid, we safely return false or re-throw
    return false;
  } finally {
    // Step 5: Best-effort memory wipe
    passwordBuffer.fill(0);
  }
}

// -----------------------------------------------------------------------------------------------
// 3) encryptData
// -----------------------------------------------------------------------------------------------
/**
 * @function encryptData
 * @description
 * Encrypts sensitive data using AES-256-GCM with authenticated encryption. Implements PBKDF2
 * key derivation from a user-provided key, an IV for randomization, and returns an object
 * containing ciphertext, IV, authentication tag, and salt.
 *
 * Steps (as specified):
 *  1. Validate input data and key.
 *  2. Generate random initialization vector (IV).
 *  3. Derive encryption key using PBKDF2 from the user-provided key + salt.
 *  4. Create AES-256-GCM cipher.
 *  5. Encrypt data with authenticated encryption.
 *  6. Securely wipe original data from memory.
 *  7. Return encrypted data object with ciphertext, iv, tag, and key parameters.
 *
 * @param data - The string data to be encrypted.
 * @param key - The user-supplied key (plain text) used for deriving the encryption key.
 * @returns object - { ciphertext, iv, salt, tag } all as base64-encoded strings.
 */
export function encryptData(
  data: string,
  key: string
): {
  ciphertext: string;
  iv: string;
  salt: string;
  tag: string;
} {
  // Step 1: Validate input data
  if (!data) {
    throw new Error('No data provided for encryption.');
  }
  if (!key) {
    throw new Error('No key provided for encryption.');
  }

  // Convert data to buffer for memory wiping
  const dataBuffer = Buffer.from(data, 'utf8');
  // Generate a new salt for PBKDF2 key derivation
  const salt = crypto.randomBytes(encryptionConfig.pbkdf2.saltLength);
  // Generate initialization vector
  const iv = crypto.randomBytes(encryptionConfig.aes.ivLength);

  try {
    // Step 3: Derive encryption key from user-supplied key + salt
    const derivedKey = crypto.pbkdf2Sync(
      Buffer.from(key, 'utf8'),
      salt,
      encryptionConfig.pbkdf2.iterations,
      encryptionConfig.aes.keyLength,
      encryptionConfig.pbkdf2.digest
    );

    // Step 4: Create AES-256-GCM cipher
    const cipher = crypto.createCipheriv(
      encryptionConfig.aes.algorithm,
      derivedKey,
      iv,
      { authTagLength: 16 }
    );

    // Step 5: Encrypt data using the cipher
    const encrypted = Buffer.concat([cipher.update(dataBuffer), cipher.final()]);

    // Obtain the authentication tag for AES-GCM
    const authTag = cipher.getAuthTag();

    // Step 7: Return encryption output as base64-encoded strings
    return {
      ciphertext: encrypted.toString('base64'),
      iv: iv.toString('base64'),
      salt: salt.toString('base64'),
      tag: authTag.toString('base64'),
    };
  } catch (error) {
    throw new Error(`Encryption failed: ${error instanceof Error ? error.message : String(error)}`);
  } finally {
    // Step 6: Best-effort to wipe original data
    dataBuffer.fill(0);
  }
}

// -----------------------------------------------------------------------------------------------
// 4) decryptData
// -----------------------------------------------------------------------------------------------
/**
 * @function decryptData
 * @description
 * Decrypts data using AES-256-GCM with full authentication tag verification. Expects an object that
 * was created by encryptData, including base64-encoded ciphertext, iv, salt, and tag.
 *
 * Steps (as specified):
 *  1. Validate encrypted data object structure.
 *  2. Verify authentication tag presence.
 *  3. Derive decryption key using PBKDF2 with the stored salt.
 *  4. Create AES-256-GCM decipher.
 *  5. Decrypt data with authentication.
 *  6. Securely wipe sensitive data from memory.
 *  7. Return decrypted string.
 *
 * @param encryptedData - Object containing { ciphertext, iv, salt, tag }.
 * @param key - The plain-text key to derive the decryption key.
 * @returns string - The decrypted plaintext.
 */
export function decryptData(
  encryptedData: {
    ciphertext: string;
    iv: string;
    salt: string;
    tag: string;
  },
  key: string
): string {
  // Step 1: Validate structure
  if (
    !encryptedData ||
    !encryptedData.ciphertext ||
    !encryptedData.iv ||
    !encryptedData.salt ||
    !encryptedData.tag
  ) {
    throw new Error('Invalid encrypted data object. Missing required fields.');
  }

  if (!key) {
    throw new Error('No key provided for decryption.');
  }

  // Convert base64 fields to Buffers
  const iv = Buffer.from(encryptedData.iv, 'base64');
  const salt = Buffer.from(encryptedData.salt, 'base64');
  const tag = Buffer.from(encryptedData.tag, 'base64');
  const ciphertext = Buffer.from(encryptedData.ciphertext, 'base64');

  try {
    // Step 3: Derive the key using PBKDF2
    const derivedKey = crypto.pbkdf2Sync(
      Buffer.from(key, 'utf8'),
      salt,
      encryptionConfig.pbkdf2.iterations,
      encryptionConfig.aes.keyLength,
      encryptionConfig.pbkdf2.digest
    );

    // Step 4: Create AES-256-GCM decipher
    const decipher = crypto.createDecipheriv(
      encryptionConfig.aes.algorithm,
      derivedKey,
      iv,
      { authTagLength: 16 }
    );

    // Step 2: Set the authentication tag before decryption
    decipher.setAuthTag(tag);

    // Step 5: Decrypt the data
    const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);

    // Step 7: Return decrypted string in UTF-8
    return decrypted.toString('utf8');
  } catch (error) {
    throw new Error(`Decryption failed or data tampered: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// -----------------------------------------------------------------------------------------------
// 5) generateEncryptionKey
// -----------------------------------------------------------------------------------------------
/**
 * @function generateEncryptionKey
 * @description
 * Generates a cryptographically secure key of a specified length. Optionally applies
 * a PBKDF2 or other derivation if specified in the options. This function can be used
 * to create ephemeral keys, or stored keys for longer-term use, depending on the 
 * application’s design. 
 *
 * Steps (as specified):
 *  1. Validate key length requirements.
 *  2. Generate random bytes using crypto.randomBytes.
 *  3. Apply key derivation if specified (e.g., PBKDF2).
 *  4. Implement secure key storage if needed (left as application-specific).
 *  5. Return the key buffer with optional parameters.
 *
 * @param length - The length in bytes of the key to be generated.
 * @param options - Optional object containing a derivation config object.
 * @returns Promise<Buffer> - The generated key buffer.
 */
export async function generateEncryptionKey(
  length: number,
  options?: {
    derivation?: {
      salt?: Buffer;
      iterations?: number;
      digest?: string;
    };
  }
): Promise<Buffer> {
  // Step 1: Validate length
  if (length < 1) {
    throw new Error('Key length must be a positive integer.');
  }

  // Step 2: Generate random bytes as the base key material
  const rawKey = await new Promise<Buffer>((resolve, reject) => {
    crypto.randomBytes(length, (err, buf) => {
      if (err) return reject(err);
      resolve(buf);
    });
  });

  // Step 3: Optionally apply PBKDF2 or other derivation
  if (options?.derivation) {
    const {
      salt = crypto.randomBytes(encryptionConfig.pbkdf2.saltLength),
      iterations = encryptionConfig.pbkdf2.iterations,
      digest = encryptionConfig.pbkdf2.digest,
    } = options.derivation;

    return crypto.pbkdf2Sync(rawKey, salt, iterations, length, digest);
  }

  // Step 5: Return the raw key if no derivation is requested
  return rawKey;
}