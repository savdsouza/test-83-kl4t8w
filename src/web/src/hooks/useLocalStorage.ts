/**
 * A custom React hook that provides secure, type-safe access to the browser's localStorage
 * with automatic serialization, deserialization, optional AES encryption, cross-tab
 * synchronization, and comprehensive error handling. This hook aligns with the project's
 * requirements for secure and robust user data management in browser storage.
 */

//////////////////////////////////////////////////////////////
// External Imports (React ^18.2.0)
//////////////////////////////////////////////////////////////
import { useState, useEffect, useCallback } from 'react'; // version ^18.2.0

//////////////////////////////////////////////////////////////
// Internal Imports
//////////////////////////////////////////////////////////////
import {
  setLocalStorageItem,
  getLocalStorageItem,
  removeLocalStorageItem
} from '../utils/storage.utils';
import { ErrorState } from '../types/common.types';

//////////////////////////////////////////////////////////////
// Hook Definition
//////////////////////////////////////////////////////////////

/**
 * useLocalStorage
 *
 * This hook handles read/write/remove operations in localStorage,
 * optionally encrypting the stored data. It ensures safe
 * initialization by validating storage availability, handles
 * errors gracefully, and synchronizes state across browser tabs.
 *
 * @template T - The type of the data being stored and retrieved.
 * @param {string} key - A unique key used to store and retrieve the data from localStorage.
 * @param {T} initialValue - An initial default value to use if no value is found or errors occur.
 * @param {boolean} encrypt - Flag that determines whether the stored data should be encrypted.
 *
 * @returns {[T, (value: T) => void, () => void, ErrorState | null]} A tuple containing:
 *  1. The current stored value of type T.
 *  2. A setter function that updates localStorage (and React state).
 *  3. A remove function that securely deletes the key from localStorage.
 *  4. An ErrorState object or null, representing any encountered errors.
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T,
  encrypt: boolean
): [T, (value: T) => void, () => void, ErrorState | null] {
  //////////////////////////////////////////////////////////////
  // State & Error Initialization
  //////////////////////////////////////////////////////////////

  // Holds any encountered error condition (encryption, storage, etc.).
  const [error, setError] = useState<ErrorState | null>(null);

  // Stores the current value in React state, ensuring our UI stays in sync with localStorage.
  const [storedValue, setStoredValue] = useState<T>(() => {
    // Validate code runs only on the client side and localStorage is accessible.
    if (typeof window === 'undefined' || !window.localStorage) {
      // If not available, record an error in console and return initialValue.
      // The error state will be set below. We can store a partial fallback or log it.
      setError({
        code: 'STORAGE_003',
        message: 'localStorage is not available in this environment.',
        details: { context: { environment: typeof window } },
        timestamp: new Date(),
        severity: 2 // ErrorSeverity.ERROR
      });
      return initialValue;
    }

    // Attempt to retrieve the existing stored value for the given key.
    const result = getLocalStorageItem<T>(key, encrypt);
    if (!result.success) {
      // If retrieving fails, set error state. Return fallback (initialValue).
      setError(result.error);
      return initialValue;
    }
    // If data is found (non-null), use it; otherwise, fall back.
    return result.data !== null ? result.data : initialValue;
  });

  //////////////////////////////////////////////////////////////
  // Set Value Function
  //////////////////////////////////////////////////////////////

  /**
   * setValue
   *
   * A memoized callback that updates both localStorage (with optional encryption)
   * and the local React state, handling any errors gracefully.
   *
   * @param {T} value - The new value to store.
   */
  const setValue = useCallback(
    (value: T): void => {
      // Clear any existing errors before attempting an update.
      setError(null);

      // Save new data into localStorage using our utility function.
      const result = setLocalStorageItem<T>(key, value, encrypt);
      if (!result.success) {
        // If storing fails, store the error state and do not update local state.
        setError(result.error);
        return;
      }

      // If successful, update React state so the UI remains consistent with localStorage.
      setStoredValue(value);
    },
    [key, encrypt]
  );

  //////////////////////////////////////////////////////////////
  // Remove Value Function
  //////////////////////////////////////////////////////////////

  /**
   * removeValue
   *
   * A memoized callback that securely removes the associated key from localStorage.
   * Resets the local state to the initialValue (or a safe default), handling errors.
   */
  const removeValue = useCallback((): void => {
    // Clear any existing errors before attempting a remove operation.
    setError(null);

    // Use the removeLocalStorageItem utility for secure deletion.
    const removeResult = removeLocalStorageItem(key);
    if (!removeResult.success) {
      // If a failure occurs, store the error to inform the UI.
      setError(removeResult.error);
      return;
    }

    // Reset the local state to the original initial value to indicate removal.
    setStoredValue(initialValue);
  }, [key, initialValue]);

  //////////////////////////////////////////////////////////////
  // Cross-Tab Synchronization
  //////////////////////////////////////////////////////////////

  useEffect(() => {
    // Ensure we only add this event listener if running in a browser environment.
    if (typeof window === 'undefined') return;

    /**
     * handleStorageEvent
     *
     * Fired whenever localStorage changes in another browser tab.
     * If the change matches our key, we re-fetch the value and update state.
     */
    const handleStorageEvent = (event: StorageEvent) => {
      // Only respond if:
      // 1) The storage event is for the same localStorage object
      // 2) The changed key matches our hook's key
      if (
        event.storageArea === window.localStorage &&
        event.key === key
      ) {
        // Attempt to retrieve the new value for this key, using encryption as required.
        const result = getLocalStorageItem<T>(key, encrypt);
        if (!result.success) {
          // If retrieving fails, set the error state. Keep current local state for safety.
          setError(result.error);
          return;
        }
        // If the new retrieved data is null, revert to the initialValue; else set fetched data.
        setStoredValue(result.data !== null ? result.data : initialValue);
      }
    };

    // Register the event listener for storage events.
    window.addEventListener('storage', handleStorageEvent);

    // Cleanup event listener on unmount for memory and performance optimization.
    return () => {
      window.removeEventListener('storage', handleStorageEvent);
    };
  }, [key, encrypt, initialValue]);

  //////////////////////////////////////////////////////////////
  // Return Hook Output
  //////////////////////////////////////////////////////////////

  // Provide the stored value, the setter, the remover, and any error encountered.
  return [storedValue, setValue, removeValue, error];
}