/**
 * This module provides utility functions for safely storing and retrieving
 * data in localStorage and sessionStorage. It includes AES encryption/decryption
 * support, robust error handling, and type-aware operations ensuring minimal risk
 * of runtime errors when parsing or stringifying JSON objects. 
 *
 * The implementation satisfies the following primary requirements:
 * 1) Enhanced encryption with AES (via CryptoJS).
 * 2) Strict, type-safe wrappers around browser storage.
 * 3) Robust error handling using a unified ErrorState structure.
 * 4) Extensive validation checks (storage availability, key correctness, etc.).
 * 5) Compliant with advanced security measures specified for user session data.
 */

//////////////////////////////////////////////////////////////
// External & Internal Imports
//////////////////////////////////////////////////////////////

// Importing AES encryption library. Version noted as required by specification.
// version ^4.1.1
import * as CryptoJS from 'crypto-js';

// Import the ErrorState interface (and optionally any other error constructs)
// from our internal types to handle error reporting consistently.
import { ErrorState, ErrorSeverity } from '../types/common.types';

//////////////////////////////////////////////////////////////
// Global Constants & Types
//////////////////////////////////////////////////////////////

/**
 * Environment-based encryption key fallback to 'default-key' if
 * process.env.REACT_APP_STORAGE_ENCRYPTION_KEY is not provided.
 */
export const STORAGE_ENCRYPTION_KEY: string =
  process.env.REACT_APP_STORAGE_ENCRYPTION_KEY || 'default-key';

/**
 * Enumerates possible storage-related error codes, aligning with
 * the requirement to clearly label error states for troubleshooting.
 */
export const STORAGE_ERROR_CODES = {
  INVALID_KEY: 'STORAGE_001',
  ENCRYPTION_ERROR: 'STORAGE_002',
  STORAGE_UNAVAILABLE: 'STORAGE_003',
};

/**
 * A generic Result type returning either a success payload or a typed error.
 * This structure provides consistent error propagation across all utilities.
 */
export type Result<T, E> =
  | { success: true; data: T }
  | { success: false; error: E };

//////////////////////////////////////////////////////////////
// Encryption & Decryption Utilities
//////////////////////////////////////////////////////////////

/**
 * Encrypts the provided data using AES encryption with a supplied key.
 * 
 * @param data - The data to be encrypted; can be a string or an object.
 * @param key - The encryption key; validation checks for non-empty keys.
 * @returns A Result object. On success, it contains the encrypted data in 'data'.
 *          On failure, it returns a fully populated ErrorState describing the issue.
 */
export function encryptData(
  data: string | object,
  key: string
): Result<string, ErrorState> {
  // Step 1: Validate input parameters.
  if (!data) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'No data provided for encryption.',
        details: { context: { providedData: data } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 2: Convert objects to string if necessary.
  let dataAsString: string;
  if (typeof data === 'object') {
    try {
      dataAsString = JSON.stringify(data);
    } catch (serializationError) {
      return {
        success: false,
        error: {
          code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
          message: 'Failed to stringify object before encryption.',
          details: { context: { originalError: serializationError } },
          timestamp: new Date(),
          severity: ErrorSeverity.ERROR
        }
      };
    }
  } else {
    dataAsString = data;
  }

  // Step 3: Validate the encryption key.
  if (!key || typeof key !== 'string' || key.trim().length === 0) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.INVALID_KEY,
        message: 'Encryption key is invalid or empty.',
        details: { context: { providedKey: key } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 4: Encrypt data using CryptoJS AES.
  try {
    const encrypted = CryptoJS.AES.encrypt(dataAsString, key).toString();
    return {
      success: true,
      data: encrypted
    };
  } catch (cryptoError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'An error occurred during AES encryption.',
        details: { context: { originalError: cryptoError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }
}

/**
 * Decrypts an AES-encrypted string using the supplied key.
 * 
 * @param encryptedData - The encrypted string to be decrypted.
 * @param key - The key to use for decryption; validation checks for non-empty keys.
 * @returns A Result object. On success, it contains the decrypted data in 'data'.
 *          On failure, it returns a fully populated ErrorState describing the issue.
 */
export function decryptData(
  encryptedData: string,
  key: string
): Result<string, ErrorState> {
  // Step 1: Validate input parameters.
  if (!encryptedData) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'No encrypted data provided for decryption.',
        details: { context: { providedData: encryptedData } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 2: Validate the decryption key.
  if (!key || typeof key !== 'string' || key.trim().length === 0) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.INVALID_KEY,
        message: 'Decryption key is invalid or empty.',
        details: { context: { providedKey: key } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 3: Attempt AES decryption.
  try {
    const bytes = CryptoJS.AES.decrypt(encryptedData, key);
    const decrypted = bytes.toString(CryptoJS.enc.Utf8);

    // Step 4: Validate decrypted data format. 
    // If the key is incorrect or data is malformed, result can be an empty string.
    if (!decrypted) {
      return {
        success: false,
        error: {
          code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
          message: 'Decryption produced an empty result. Possibly an invalid key.',
          details: { context: { decryptedValueIsEmpty: true } },
          timestamp: new Date(),
          severity: ErrorSeverity.ERROR
        }
      };
    }

    // Step 5: Return decrypted string on success.
    return {
      success: true,
      data: decrypted
    };
  } catch (cryptoError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'An error occurred during AES decryption.',
        details: { context: { originalError: cryptoError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }
}

//////////////////////////////////////////////////////////////
// Local Storage Utilities
//////////////////////////////////////////////////////////////

/**
 * Stores a type-safe value in localStorage. Optionally encrypts the data using AES.
 *
 * @param key - A string key under which to store the data.
 * @param value - The value to be stored, can be any type T.
 * @param encrypt - A boolean indicating whether or not to encrypt the data before storing.
 * @returns A Result type indicating either success or an ErrorState with details.
 */
export function setLocalStorageItem<T>(
  key: string,
  value: T,
  encrypt: boolean
): Result<void, ErrorState> {
  // Step 1: Validate storage availability.
  if (typeof window === 'undefined' || !window.localStorage) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'localStorage is not available in this environment.',
        details: { context: { environment: typeof window } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 2: Validate key parameter format.
  if (!key || key.trim().length === 0) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.INVALID_KEY,
        message: 'Provided storage key is invalid or empty.',
        details: { context: { providedKey: key } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 3: Convert the value to a string if it is an object.
  let stringValue: string;
  try {
    if (typeof value === 'object') {
      stringValue = JSON.stringify(value);
    } else {
      stringValue = String(value);
    }
  } catch (conversionError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'Failed to serialize value before storage.',
        details: { context: { originalError: conversionError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 4: Apply AES encryption if requested.
  if (encrypt) {
    const encryptedResult = encryptData(stringValue, STORAGE_ENCRYPTION_KEY);
    if (!encryptedResult.success) {
      // If encryption fails, propagate the error upward.
      return { success: false, error: encryptedResult.error };
    }
    stringValue = encryptedResult.data;
  }

  // Step 5: Attempt to store data in localStorage with robust error handling.
  try {
    window.localStorage.setItem(key, stringValue);
  } catch (storageError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'Failed to store item in localStorage.',
        details: { context: { originalError: storageError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 6: Return success upon successful storage.
  return { success: true, data: undefined };
}

/**
 * Retrieves a type-safe value from localStorage. Optionally decrypts the data using AES.
 *
 * @param key - A string key under which the data is stored.
 * @param decrypt - A boolean controlling whether the stored data should be decrypted.
 * @returns A Result type with the retrieved value of type T or null
 *          if no data found, or an ErrorState on failure.
 */
export function getLocalStorageItem<T>(
  key: string,
  decrypt: boolean
): Result<T | null, ErrorState> {
  // Step 1: Validate storage availability.
  if (typeof window === 'undefined' || !window.localStorage) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'localStorage is not available in this environment.',
        details: { context: { environment: typeof window } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 2: Validate key parameter format.
  if (!key || key.trim().length === 0) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.INVALID_KEY,
        message: 'Provided storage key is invalid or empty.',
        details: { context: { providedKey: key } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 3: Retrieve the stored data.
  let storedValue: string | null = null;
  try {
    storedValue = window.localStorage.getItem(key);
  } catch (storageError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'Failed to read item from localStorage.',
        details: { context: { originalError: storageError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // If the item was not found, return null in the success path.
  if (storedValue === null) {
    return { success: true, data: null };
  }

  // Step 4: Decrypt if requested.
  if (decrypt) {
    const decryptedResult = decryptData(storedValue, STORAGE_ENCRYPTION_KEY);
    if (!decryptedResult.success) {
      return { success: false, error: decryptedResult.error };
    }
    storedValue = decryptedResult.data;
  }

  // Step 5: Attempt to parse JSON if it looks like JSON data.
  let parsedValue: T | null = null;
  try {
    // We do a quick check to see if it might be JSON.
    // If parse fails, we assume it's raw string data.
    if (
      (storedValue.startsWith('{') && storedValue.endsWith('}')) ||
      (storedValue.startsWith('[') && storedValue.endsWith(']'))
    ) {
      parsedValue = JSON.parse(storedValue) as T;
    } else {
      // Assume it's a primitive or already a string representation of the actual data.
      // We'll just cast it to the requested type T.
      parsedValue = storedValue as unknown as T;
    }
  } catch (parseError) {
    // Parsing error will not strictly fail the operation, but let's treat it as an error 
    // because the data is not in the expected or decodable JSON format.
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'Failed to parse localStorage item as JSON.',
        details: { context: { originalError: parseError, rawData: storedValue } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 6: Return typed data in success result.
  return { success: true, data: parsedValue };
}

//////////////////////////////////////////////////////////////
// Session Storage Utilities
//////////////////////////////////////////////////////////////

/**
 * Stores a type-safe value in sessionStorage. Optionally encrypts the data using AES.
 *
 * @param key - A string key under which to store the data.
 * @param value - The value to be stored, can be any type T.
 * @param encrypt - A boolean indicating whether or not to encrypt the data before storing.
 * @returns A Result type indicating either success or an ErrorState with details.
 */
export function setSessionStorageItem<T>(
  key: string,
  value: T,
  encrypt: boolean
): Result<void, ErrorState> {
  // Step 1: Validate storage availability.
  if (typeof window === 'undefined' || !window.sessionStorage) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'sessionStorage is not available in this environment.',
        details: { context: { environment: typeof window } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 2: Validate key parameter format.
  if (!key || key.trim().length === 0) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.INVALID_KEY,
        message: 'Provided storage key is invalid or empty.',
        details: { context: { providedKey: key } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 3: Convert the value to a string if it is an object.
  let stringValue: string;
  try {
    if (typeof value === 'object') {
      stringValue = JSON.stringify(value);
    } else {
      stringValue = String(value);
    }
  } catch (conversionError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'Failed to serialize value before session storage.',
        details: { context: { originalError: conversionError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 4: Apply AES encryption if requested.
  if (encrypt) {
    const encryptedResult = encryptData(stringValue, STORAGE_ENCRYPTION_KEY);
    if (!encryptedResult.success) {
      return { success: false, error: encryptedResult.error };
    }
    stringValue = encryptedResult.data;
  }

  // Step 5: Attempt to store data in sessionStorage with robust error handling.
  try {
    window.sessionStorage.setItem(key, stringValue);
  } catch (storageError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'Failed to store item in sessionStorage.',
        details: { context: { originalError: storageError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 6: Return success upon successful storage.
  return { success: true, data: undefined };
}

/**
 * Retrieves a type-safe value from sessionStorage. Optionally decrypts the data using AES.
 * 
 * @param key - A string key under which the data is stored in sessionStorage.
 * @param decrypt - A boolean controlling whether the stored data should be decrypted.
 * @returns A Result type with the retrieved value of type T or null
 *          if no data found, or an ErrorState on failure.
 */
export function getSessionStorageItem<T>(
  key: string,
  decrypt: boolean
): Result<T | null, ErrorState> {
  // Step 1: Validate storage availability.
  if (typeof window === 'undefined' || !window.sessionStorage) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'sessionStorage is not available in this environment.',
        details: { context: { environment: typeof window } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 2: Validate key parameter format.
  if (!key || key.trim().length === 0) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.INVALID_KEY,
        message: 'Provided session storage key is invalid or empty.',
        details: { context: { providedKey: key } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 3: Retrieve the stored data.
  let storedValue: string | null = null;
  try {
    storedValue = window.sessionStorage.getItem(key);
  } catch (storageError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.STORAGE_UNAVAILABLE,
        message: 'Failed to read item from sessionStorage.',
        details: { context: { originalError: storageError } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // If the item was not found, return null in the success path.
  if (storedValue === null) {
    return { success: true, data: null };
  }

  // Step 4: Decrypt if requested.
  if (decrypt) {
    const decryptedResult = decryptData(storedValue, STORAGE_ENCRYPTION_KEY);
    if (!decryptedResult.success) {
      return { success: false, error: decryptedResult.error };
    }
    storedValue = decryptedResult.data;
  }

  // Step 5: Attempt to parse JSON if it looks like JSON data.
  let parsedValue: T | null = null;
  try {
    if (
      (storedValue.startsWith('{') && storedValue.endsWith('}')) ||
      (storedValue.startsWith('[') && storedValue.endsWith(']'))
    ) {
      parsedValue = JSON.parse(storedValue) as T;
    } else {
      parsedValue = storedValue as unknown as T;
    }
  } catch (parseError) {
    return {
      success: false,
      error: {
        code: STORAGE_ERROR_CODES.ENCRYPTION_ERROR,
        message: 'Failed to parse sessionStorage item as JSON.',
        details: { context: { originalError: parseError, rawData: storedValue } },
        timestamp: new Date(),
        severity: ErrorSeverity.ERROR
      }
    };
  }

  // Step 6: Return typed data in success result.
  return { success: true, data: parsedValue };
}

//////////////////////////////////////////////////////////////
// Exports
//////////////////////////////////////////////////////////////

// Exporting all individual functions according to specification.
export {
  setLocalStorageItem,
  getLocalStorageItem,
  setSessionStorageItem,
  getSessionStorageItem,
  encryptData,
  decryptData
};