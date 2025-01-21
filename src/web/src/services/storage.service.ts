/**
 * Service class providing a high-level interface for securely handling browser storage
 * operations with AES-256 encryption, robust error handling, and strict data validation
 * for the dog walking application.
 *
 * This implementation aligns with the following high-level requirements:
 * 1) Secure handling of session and user data (addresses User Management).
 * 2) Integration with the Security Architecture to ensure AES-256 encryption of sensitive data.
 * 3) Compliance with Data Security guidelines for encryption, validation, and error tracking.
 */

////////////////////////////////////////////////////////////////////////////////
// External & Internal Imports
////////////////////////////////////////////////////////////////////////////////

import { ErrorState } from '../types/common.types';
import {
  setLocalStorageItem,
  getLocalStorageItem,
  removeLocalStorageItem,
  setSessionStorageItem,
  getSessionStorageItem,
  removeSessionStorageItem,
  encryptData,
  decryptData,
} from '../utils/storage.utils';
import * as CryptoJS from 'crypto-js'; // version ^4.1.1 (AES-256 encryption/decryption)
////////////////////////////////////////////////////////////////////////////////
// Support Types & Interfaces
////////////////////////////////////////////////////////////////////////////////

/**
 * Minimal User interface for demonstration purposes, representing
 * the object stored or retrieved by setUser() and getUser().
 * Adjust as necessary for broader domain usage.
 */
interface User {
  id: string;
  name: string;
  email?: string;
}

/**
 * A generic Result type, matching the signature defined in storage.utils
 * to uniformly handle success or failure when performing storage operations.
 */
type Result<T, E> =
  | { success: true; data: T }
  | { success: false; error: E };

////////////////////////////////////////////////////////////////////////////////
// StorageService Class
////////////////////////////////////////////////////////////////////////////////

export class StorageService {
  /**
   * A static encryption key for AES-256 encryption. In production,
   * this should be managed via environment variables or a secure
   * key management service rather than hard-coded values.
   */
  private static readonly ENCRYPTION_KEY: string = '__DW_ENCRYPTION_KEY__';

  /**
   * Key under which encrypted user data is stored in localStorage.
   */
  private static readonly USER_KEY: string = '__dw_user__';

  /**
   * Key under which encrypted auth token with expiry is stored.
   */
  private static readonly AUTH_TOKEN_KEY: string = '__dw_auth_token__';

  /**
   * Key under which encrypted user preferences might be stored.
   */
  private static readonly PREFERENCES_KEY: string = '__dw_preferences__';

  /**
   * Indicates the schema or structural version for stored data,
   * used for migrations or backward-compatibility considerations.
   */
  private static readonly STORAGE_VERSION: string = '1.0.0';

  //////////////////////////////////////////////////////////////////////////////
  // Private Helper Methods
  //////////////////////////////////////////////////////////////////////////////

  /**
   * Validates if browser storage is available and accessible, verifying
   * localStorage/sessionStorage APIs and checking for possible quota issues.
   *
   * NOTE: This method returns a boolean indicating success or failure
   * rather than throwing an exception. Caller methods must handle a false
   * return appropriately and propagate the error using a unified ErrorState
   * structure if required.
   */
  private validateStorageAvailability(): boolean {
    try {
      // Ensure window object is present.
      if (typeof window === 'undefined') {
        return false;
      }

      // Check localStorage availability with a simple set/remove test.
      const testKey = '__storage_test__';
      window.localStorage.setItem(testKey, 'test');
      window.localStorage.removeItem(testKey);

      // Check sessionStorage availability with a simple set/remove test.
      window.sessionStorage.setItem(testKey, 'test');
      window.sessionStorage.removeItem(testKey);

      // In some browsers, further checks for quota could be tested here,
      // though in practice, catching QuotaExceededError in set operations
      // is typically sufficient. If we needed further verification, we
      // could attempt to fill a known amount of space and catch exceptions.
    } catch (err) {
      // If any error occurs (SecurityError, QuotaExceededError, etc.),
      // report storage as unavailable.
      return false;
    }
    return true;
  }

  /**
   * Encrypts data using AES-256 encryption, returning the encrypted
   * string or an error result. This method leverages the class-level
   * ENCRYPTION_KEY as the cryptographic key.
   */
  private encryptData(data: any): Result<string, ErrorState> {
    // Delegate to the shared utility function for consistency.
    return encryptData(data, StorageService.ENCRYPTION_KEY);
  }

  /**
   * Decrypts an AES-256 encrypted string, returning the decrypted value (as any)
   * or an error result. This method leverages the class-level ENCRYPTION_KEY
   * as the cryptographic key.
   */
  private decryptData(encryptedData: string): Result<string, ErrorState> {
    return decryptData(encryptedData, StorageService.ENCRYPTION_KEY);
  }

  //////////////////////////////////////////////////////////////////////////////
  // Public Methods
  //////////////////////////////////////////////////////////////////////////////

  /**
   * Stores encrypted user data in localStorage with validation steps:
   * 1) Validate that the user object is defined (basic schema validation).
   * 2) Validate storage availability.
   * 3) Encrypt user data using AES-256.
   * 4) Store the encrypted payload in localStorage under USER_KEY.
   * 5) Return a success or an error result with an ErrorState.
   *
   * @param user - The user object to store securely.
   * @returns A Result indicating success or encapsulating an error.
   */
  public setUser(user: User): Result<void, ErrorState> {
    if (!user) {
      return {
        success: false,
        error: {
          code: 'STORAGE_USER_VALIDATION',
          message: 'Invalid user object. Cannot be null or undefined.',
          details: { context: { user } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Check browser storage availability.
    if (!this.validateStorageAvailability()) {
      return {
        success: false,
        error: {
          code: 'STORAGE_UNAVAILABLE',
          message: 'Browser storage is not available or accessible.',
          details: { context: { user } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Encrypt user data.
    const encryptionResult = this.encryptData(user);
    if (!encryptionResult.success) {
      return { success: false, error: encryptionResult.error };
    }

    // Store encrypted user in localStorage using the utility.
    const storeResult = setLocalStorageItem<string>(
      StorageService.USER_KEY,
      encryptionResult.data,
      false // false => we already encrypted the data
    );
    if (!storeResult.success) {
      return { success: false, error: storeResult.error };
    }

    return { success: true, data: undefined };
  }

  /**
   * Retrieves and decrypts user data from localStorage, performing:
   * 1) Validate storage availability.
   * 2) Retrieve the encrypted user string via getLocalStorageItem.
   * 3) Decrypt if data is found.
   * 4) Parse and validate the resulting user object.
   * 5) Return the user or null if none found.
   *
   * @returns A Result containing the decrypted user object or null on success,
   *          or an ErrorState on failure.
   */
  public getUser(): Result<User | null, ErrorState> {
    if (!this.validateStorageAvailability()) {
      return {
        success: false,
        error: {
          code: 'STORAGE_UNAVAILABLE',
          message: 'Browser storage is not available or accessible.',
          details: {},
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // We stored an encrypted string in localStorage for the user.
    const storageResult = getLocalStorageItem<string>(
      StorageService.USER_KEY,
      false // false => we expect the data to be an encrypted string
    );
    if (!storageResult.success) {
      return { success: false, error: storageResult.error };
    }

    // If the data is null, there's no stored user.
    if (storageResult.data === null) {
      return { success: true, data: null };
    }

    // Decrypt the stored value.
    const decryptionResult = this.decryptData(storageResult.data);
    if (!decryptionResult.success) {
      return { success: false, error: decryptionResult.error };
    }

    // Attempt to parse the decrypted JSON as a User object.
    let parsed: User | null = null;
    try {
      parsed = JSON.parse(decryptionResult.data) as User;
    } catch (parseError) {
      return {
        success: false,
        error: {
          code: 'STORAGE_USER_PARSE_ERROR',
          message: 'Failed to parse user data after decryption.',
          details: { context: { parseError, raw: decryptionResult.data } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Basic structural check (expand or refine as necessary).
    if (!parsed || !parsed.id) {
      return {
        success: false,
        error: {
          code: 'STORAGE_USER_VALIDATION',
          message: 'Decrypted user object is invalid or missing required fields.',
          details: { context: { parsed } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Return the validated user.
    return { success: true, data: parsed };
  }

  /**
   * Stores an authentication token with an expiry timestamp
   * in localStorage. The object is encrypted prior to storage.
   *
   * Steps:
   * 1) Validate token format and expiry duration.
   * 2) Build a payload with the token and an expiry time in epoch ms.
   * 3) Encrypt the payload.
   * 4) Store under AUTH_TOKEN_KEY in localStorage.
   * 5) Return a success or error result.
   *
   * @param token - The raw token string to store.
   * @param expiryInMinutes - The number of minutes until the token expires.
   * @returns A Result indicating success or an ErrorState on failure.
   */
  public setAuthToken(token: string, expiryInMinutes: number): Result<void, ErrorState> {
    if (!token || token.trim().length === 0 || expiryInMinutes <= 0) {
      return {
        success: false,
        error: {
          code: 'AUTH_TOKEN_VALIDATION',
          message: 'Invalid token or expiry duration provided.',
          details: { context: { token, expiryInMinutes } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    if (!this.validateStorageAvailability()) {
      return {
        success: false,
        error: {
          code: 'STORAGE_UNAVAILABLE',
          message: 'Browser storage is not available or accessible.',
          details: { context: { token, expiryInMinutes } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Construct the token payload with expiry in epoch milliseconds.
    const now = Date.now();
    const expiresAt = now + expiryInMinutes * 60_000;
    const payload = {
      token,
      expires: expiresAt,
    };

    // Encrypt the auth data.
    const encryptResult = this.encryptData(payload);
    if (!encryptResult.success) {
      return { success: false, error: encryptResult.error };
    }

    // Store in localStorage.
    const storeResult = setLocalStorageItem<string>(
      StorageService.AUTH_TOKEN_KEY,
      encryptResult.data,
      false // already encrypted
    );
    if (!storeResult.success) {
      return { success: false, error: storeResult.error };
    }

    return { success: true, data: undefined };
  }

  /**
   * Retrieves and validates an authentication token. Checks if the token
   * has expired; if so, returns null. If valid, returns the raw token string.
   *
   * Steps:
   * 1) Retrieve the encrypted payload from localStorage.
   * 2) Decrypt the payload and parse it as { token, expires }.
   * 3) If the current time > expires, treat it as expired, returning null.
   * 4) Otherwise, return the token string in a success result.
   *
   * @returns A Result holding a valid token or null if none/expired, or an ErrorState.
   */
  public getAuthToken(): Result<string | null, ErrorState> {
    if (!this.validateStorageAvailability()) {
      return {
        success: false,
        error: {
          code: 'STORAGE_UNAVAILABLE',
          message: 'Browser storage is not available or accessible.',
          details: {},
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    const fetchResult = getLocalStorageItem<string>(
      StorageService.AUTH_TOKEN_KEY,
      false // data is stored as an encrypted string
    );
    if (!fetchResult.success) {
      return { success: false, error: fetchResult.error };
    }

    if (fetchResult.data === null) {
      // No token stored; indicate success with null token.
      return { success: true, data: null };
    }

    // Decrypt the payload object.
    const decryptResult = this.decryptData(fetchResult.data);
    if (!decryptResult.success) {
      return { success: false, error: decryptResult.error };
    }

    // Parse the decrypted JSON to get { token, expires }.
    let tokenObj: { token: string; expires: number } | null = null;
    try {
      tokenObj = JSON.parse(decryptResult.data) as { token: string; expires: number };
    } catch (parseError) {
      return {
        success: false,
        error: {
          code: 'AUTH_TOKEN_PARSE_ERROR',
          message: 'Failed to parse auth token after decryption.',
          details: { context: { parseError, raw: decryptResult.data } },
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Validate expiry.
    const now = Date.now();
    if (!tokenObj.token || !tokenObj.expires || now >= tokenObj.expires) {
      // Token is missing or expired; return null in success data.
      return { success: true, data: null };
    }

    return { success: true, data: tokenObj.token };
  }

  /**
   * Securely clears all application data from browser storage, including:
   * 1) User data, 2) Auth token, and 3) Preferences, verifying removal.
   *
   * Steps:
   * 1) Validate storage availability.
   * 2) Remove each relevant key from localStorage (or sessionStorage).
   * 3) Verify keys are removed.
   * 4) Return success or error result as needed.
   *
   * @returns A Result indicating success or an ErrorState on failure.
   */
  public clearStorage(): Result<void, ErrorState> {
    if (!this.validateStorageAvailability()) {
      return {
        success: false,
        error: {
          code: 'STORAGE_UNAVAILABLE',
          message: 'Browser storage is not available or accessible.',
          details: {},
          timestamp: new Date(),
          severity: 'ERROR',
        },
      };
    }

    // Remove user data.
    const removeUserResult = removeLocalStorageItem(StorageService.USER_KEY);
    if (!removeUserResult.success) {
      return { success: false, error: removeUserResult.error };
    }

    // Remove auth token.
    const removeAuthResult = removeLocalStorageItem(StorageService.AUTH_TOKEN_KEY);
    if (!removeAuthResult.success) {
      return { success: false, error: removeAuthResult.error };
    }

    // Remove preferences if needed.
    const removePrefsResult = removeLocalStorageItem(StorageService.PREFERENCES_KEY);
    if (!removePrefsResult.success) {
      return { success: false, error: removePrefsResult.error };
    }

    // If we wanted to also clear sessionStorage items, we could do so here
    // via removeSessionStorageItem, or remove everything forcibly.

    return { success: true, data: undefined };
  }
}