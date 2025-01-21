// react@^18.0.0
import React, {
  createContext,
  useContext,
  useState,
  useRef,
  useCallback,
  useEffect,
  type ReactNode,
  type MutableRefObject
} from 'react';

// NOTE: We import LoadingState from our internal type definitions to leverage
// potential mappings of success/error statuses for toast notifications.
import { LoadingState } from '../types/common.types';

/**
 * A union type defining the possible toast notification variants, guiding
 * visuals and severity feedback. Aligned with system-wide severity levels
 * to ensure consistent user feedback.
 */
export type ToastType = 'success' | 'error' | 'warning' | 'info';

/**
 * A union type defining supported positions for toast notifications
 * on the screen, providing flexible placement across all device types
 * and layouts.
 */
export type ToastPosition =
  | 'top-right'
  | 'top-left'
  | 'bottom-right'
  | 'bottom-left'
  | 'top-center'
  | 'bottom-center';

/**
 * Describes the shape of the toast's internal state, capturing its critical
 * data including visibility status, the message to display, duration, and
 * positioning. Also includes an ariaLive attribute for accessibility cues.
 */
export interface ToastState {
  /**
   * Indicates whether the toast instance is currently displayed
   * on-screen (true) or hidden (false).
   */
  isVisible: boolean;

  /**
   * The main text content shown to the end user, intended to briefly
   * convey success, error, warning, or informational messages.
   */
  message: string;

  /**
   * The category or classification of the toast notification,
   * influencing styling and urgency.
   */
  type: ToastType;

  /**
   * An optional duration (ms) specifying how long to keep
   * the toast visible before automatically dismissing.
   */
  duration?: number;

  /**
   * Position for the toast on the screen, controlling the
   * starting point for its render transition.
   */
  position: ToastPosition;

  /**
   * Manages how screen readers announce the toast message,
   * ensuring accessible feedback. 'polite' for non-critical
   * statuses and 'assertive' for urgent alerts.
   */
  ariaLive?: 'polite' | 'assertive';
}

/**
 * Defines the contract exposed by the Toast Context, giving consumers
 * the tools to display a toast message, hide it, manage position, and
 * observe whether it is currently visible.
 */
export interface ToastContextType {
  /**
   * Displays a toast notification with the provided message,
   * classification, and optional auto-dismiss duration.
   * @param message A short descriptive text to inform the user.
   * @param type The category of the toast (success, error, warning, info).
   * @param duration Optional duration (ms) for auto-dismiss behavior.
   */
  showToast: (message: string, type: ToastType, duration?: number) => void;

  /**
   * Immediately hides the current toast, if visible, and clears
   * associated timers or accessibility attributes.
   */
  hideToast: () => void;

  /**
   * Reflects the current positioning of toast notifications within the UI.
   */
  position: ToastPosition;

  /**
   * Updates the current toast position to a new corner or edge, smoothly
   * handling transitions and user accessibility announcements.
   * @param position The position to which the toast will transition.
   */
  setPosition: (position: ToastPosition) => void;

  /**
   * A boolean flag indicating whether the toast is currently visible or not.
   */
  isVisible: boolean;
}

/**
 * Creates a new React Context to manage toast notifications. The
 * default value here is cast to satisfy TypeScript but is overridden
 * by the ToastProvider in actual usage.
 */
export const ToastContext = createContext<ToastContextType>({
  showToast: () => {
    /* no-op default */
  },
  hideToast: () => {
    /* no-op default */
  },
  setPosition: () => {
    /* no-op default */
  },
  position: 'top-right',
  isVisible: false
});

/**
 * The ToastProvider component defines the core logic for controlling
 * toast notifications throughout the application. It manages:
 *  - Displaying the toast (showToast)
 *  - Hiding the toast (hideToast)
 *  - Position transitions (setPosition)
 *  - Automatic dismissal timers
 */
export const ToastProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  /**
   * Maintains internal toast state, including visibility,
   * message, type, position, and optional ariaLive attribute.
   */
  const [toastState, setToastState] = useState<ToastState>({
    isVisible: false,
    message: '',
    type: 'info',
    position: 'top-right',
    ariaLive: 'polite'
  });

  /**
   * A reference to keep track of any running timer for automatic
   * dismissal, ensuring we can clear it if a new toast is shown
   * or the user hides the toast prematurely.
   */
  const toastTimer = useRef<NodeJS.Timeout | null>(null);

  /**
   * A separate reference to track the current position more
   * closely during transitions. Helps manage animation logic.
   */
  const positionRef: MutableRefObject<ToastPosition> = useRef<ToastPosition>('top-right');

  /**
   * Display a toast notification with extensive control over message,
   * type, position, and optional auto-dismiss. Automatically sets
   * appropriate aria-live attributes based on toast type for improved
   * accessibility cues.
   */
  const showToast = useCallback(
    (message: string, type: ToastType, duration?: number) => {
      // Step 1: Clear any existing timer to prevent stale cleanup
      if (toastTimer.current) {
        clearTimeout(toastTimer.current);
        toastTimer.current = null;
      }

      // Step 2: Sanitize input (whitespace trimming, etc.) if needed
      const sanitizedMessage = String(message).trim();

      // Optional: map toast types to loading states if relevant
      // For example, success => LoadingState.SUCCESS, error => LoadingState.ERROR
      // This can be extended for internal analytics or logging:
      if (type === 'success') {
        // e.g., triggering a success event or mapping to LoadingState.SUCCESS
        const successState = LoadingState.SUCCESS;
        // successState is not explicitly used here, but could be logged
        void successState;
      } else if (type === 'error') {
        // For error type, we could map to LoadingState.ERROR
        const errorState = LoadingState.ERROR;
        void errorState;
      }

      // Step 3: Update the core toast state with new parameters
      setToastState({
        isVisible: true,
        message: sanitizedMessage,
        type,
        duration,
        position: positionRef.current,
        ariaLive: type === 'error' ? 'assertive' : 'polite'
      });

      // Step 4: If a duration is provided, set up a timer for auto-dismiss
      if (duration && duration > 0) {
        toastTimer.current = setTimeout(() => {
          // Auto hide once the timer elapses
          setToastState((prev) => ({
            ...prev,
            isVisible: false
          }));
          toastTimer.current = null;
        }, duration);
      }
    },
    []
  );

  /**
   * Immediately hides the currently displayed toast, clears
   * any running timers, and resets the toast state while
   * preserving the last known position.
   */
  const hideToast = useCallback(() => {
    // Step 1: Mark visibility as false to trigger fade-out transitions
    setToastState((prev) => ({ ...prev, isVisible: false }));

    // Step 2: Clear the existing timer reference if still active
    if (toastTimer.current) {
      clearTimeout(toastTimer.current);
      toastTimer.current = null;
    }

    // Step 3: Reset relevant toast fields without losing position
    // done in a short delay if we want to handle animations.
    setTimeout(() => {
      setToastState((prev) => ({
        ...prev,
        message: '',
        type: 'info',
        ariaLive: 'polite',
        duration: undefined
      }));
    }, 200);
  }, []);

  /**
   * Smoothly transitions the toast to a new position on-screen.
   * Any currently displayed toast maintains or animates to
   * the new position.
   */
  const setPosition = useCallback((position: ToastPosition) => {
    // Step 1: Validate the new position. Here we assume the incoming
    // value is always correct. Additional checks can occur as needed.
    positionRef.current = position;

    // Step 2: Update the toast state with the new position.
    setToastState((prev) => ({
      ...prev,
      position
    }));
  }, []);

  /**
   * Whenever the toast's visibility changes to false (hidden), we could
   * add further cleanup or analytics triggers here if needed. Currently
   * unused, but available for extension.
   */
  useEffect(() => {
    // Observe toastState.isVisible to handle side effects if needed
  }, [toastState.isVisible]);

  return (
    <ToastContext.Provider
      value={{
        showToast,
        hideToast,
        position: toastState.position,
        setPosition,
        isVisible: toastState.isVisible
      }}
    >
      {children}
    </ToastContext.Provider>
  );
};

/**
 * A custom React hook providing direct access to the toast context.
 * Ensures consumers can read the toast state and call showToast/hideToast
 * in a type-safe manner with convenient usage across any React component.
 * @returns ToastContextType containing the context methods and state.
 */
export function useToast(): ToastContextType {
  const context = useContext(ToastContext);

  // Step 2: Perform runtime checks to ensure validity of context usage
  if (!context) {
    throw new Error(
      'useToast must be used within a ToastProvider. ' +
      'Please wrap your component tree with <ToastProvider>.'
    );
  }

  return context;
}