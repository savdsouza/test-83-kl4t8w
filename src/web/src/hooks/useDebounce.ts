import { useState, useEffect } from 'react' // ^18.0.0

/**
 * useDebounce
 * 
 * A custom React hook that provides a debounced version of the provided value, 
 * ensuring that updates to the value are delayed until after a specified period 
 * of inactivity. This effectively reduces excessive rendering or API calls for 
 * user interfaces that require real-time inputs, such as search fields or form 
 * validations.
 * 
 * This hook addresses:
 * 1) Performance Optimization for real-time user input interactions.
 * 2) Smooth and responsive user interfaces for content updates.
 * 
 * @template T - The type for the debounced value.
 * @param {T} value - The input value to be debounced.
 * @param {number} delay - The delay duration (in milliseconds) after which the input value is updated if no further changes occur.
 * @returns {T} - Returns the latest debounced value after the delay has elapsed without any new updates.
 */
export default function useDebounce<T>(value: T, delay: number): T {
  // Maintains the internal state for the debounced value.
  const [debouncedValue, setDebouncedValue] = useState<T>(value)

  /**
   * useEffect hook to manage the side effect of updating the debouncedValue. 
   * - Starts a timeout each time the 'value' or 'delay' changes.
   * - If the value changes before the timeout finishes, the previous timeout 
   *   will be cleared, preventing an update to debouncedValue until there's 
   *   a stable period of inactivity defined by 'delay'.
   * - Returns a cleanup function to clear the timeout on component unmount 
   *   or when 'value' changes, preventing potential memory leaks.
   */
  useEffect(() => {
    // Create a timeout to update the debouncedValue after the specified delay.
    const timerId = setTimeout(() => {
      setDebouncedValue(value)
    }, delay)

    // Cleanup function to clear the timer, avoiding memory leaks 
    // and ensuring a new timer is set only after subsequent updates.
    return () => {
      clearTimeout(timerId)
    }
  }, [value, delay])

  // Return the current debouncedValue. It updates only after 
  // the specified delay if the value remains unchanged.
  return debouncedValue
}