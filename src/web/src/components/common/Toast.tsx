// react@^18.0.0
import React, {
  memo,
  useCallback,
  useState,
  useEffect,
  useRef,
  type ReactNode,
  type AnimationEvent
} from 'react';

// classnames@^2.3.2
import classNames from 'classnames';

// Internal import from ToastContext, providing toast controls & types
import { useToast, ToastPosition } from '../../contexts/ToastContext';

/**
 * ----------------------------------------------------------------------------
 * Global Type Definitions (from JSON specification)
 * ----------------------------------------------------------------------------
 */

/**
 * Describes all accepted properties for the enhanced Toast component,
 * ensuring strong type safety and consistent integration across the UI.
 */
interface ToastProps {
  /**
   * Optional custom class name(s) for advanced styling or theming,
   * appended to default toast component classes.
   */
  className?: string;

  /**
   * Optional test identifier for improved test automation coverage.
   * Recommended for integration or E2E test suites.
   */
  testId?: string;

  /**
   * Position for the toast on screen, controlling location for
   * entry/exit animations and user perception.
   */
  position?: ToastPosition;

  /**
   * Duration (in milliseconds) to keep the toast visible before
   * auto-dismissal. If not defined, the toast remains until closed.
   */
  duration?: number;

  /**
   * Callback invoked immediately after the toast finishes its exit
   * animation sequence. Ideal for performing additional cleanup
   * or redirect actions.
   */
  onClose?: () => void;

  /**
   * Defines the visual and semantic severity for the toast
   * (e.g. 'success', 'error', 'warning', or 'info').
   */
  severity: 'success' | 'error' | 'warning' | 'info';

  /**
   * The main textual content to be displayed within the toast,
   * intended to provide brief feedback or status updates.
   */
  message: string;
}

/**
 * Enum-like severity type mapped to icon usage. This approach ensures
 * we can clearly discern which icon to render for a given severity.
 */
type ToastSeverity = 'success' | 'error' | 'warning' | 'info';

/**
 * ----------------------------------------------------------------------------
 * Icon Definitions (Placeholder Inline SVGs)
 * ----------------------------------------------------------------------------
 * In a production-grade system, these might come from a dedicated icon library
 * (e.g., heroicons, Material UI icons, etc.). Here, we define minimal inline
 * SVG placeholders for demonstration and compliance with the specification.
 */

/**
 * Render a 'success' check circle icon.
 * For real usage, import from a trusted icon library or custom asset.
 */
function CheckCircleIcon(): JSX.Element {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      width="1em"
      height="1em"
    >
      <path
        d="M12 2C6.486 2 2 6.486 2 12s4.486 10 10 10
           10-4.486 10-10S17.514 2 12 2zm-1 14.586-3.293-3.293
           1.414-1.414L11 13.758l3.879-3.879 1.414 1.414L11 16.586z"
        fill="currentColor"
      />
    </svg>
  );
}

/**
 * Render an 'error' X circle icon.
 */
function XCircleIcon(): JSX.Element {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      width="1em"
      height="1em"
    >
      <path
        d="M12 2C6.486 2 2 6.486 2 12s4.486 10 10 10
           10-4.486 10-10S17.514 2 12 2zm3.707 13.293
           -1.414 1.414L12 13.414l-2.293 2.293
           -1.414-1.414L10.586 12 8.293 9.707
           l1.414-1.414L12 10.586l2.293-2.293
           1.414 1.414L13.414 12l2.293 2.293z"
        fill="currentColor"
      />
    </svg>
  );
}

/**
 * Render a 'warning' exclamation circle icon.
 */
function ExclamationCircleIcon(): JSX.Element {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      width="1em"
      height="1em"
    >
      <path
        d="M12 2C6.479 2 2 6.479 2 12s4.479 10 10 10
           10-4.479 10-10S17.521 2 12 2zM13 17h-2v-2h2v2zm0
           -4h-2V7h2v6z"
        fill="currentColor"
      />
    </svg>
  );
}

/**
 * Render an 'info' information circle icon.
 */
function InformationCircleIcon(): JSX.Element {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      width="1em"
      height="1em"
    >
      <path
        d="M12 2C6.479 2 2 6.479 2 12s4.479 10 10 10
           10-4.479 10-10S17.521 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2
           v2z"
        fill="currentColor"
      />
    </svg>
  );
}

/**
 * ----------------------------------------------------------------------------
 * Helper Functions
 * ----------------------------------------------------------------------------
 */

/**
 * getToastIcon
 *
 * Provides the appropriate ReactNode (icon) for the given toast severity.
 * This mapping ensures that each severity type is visually distinct.
 *
 * @param severity The severity level of the toast
 * @returns A JSX Element representing the icon for the severity
 */
function getToastIcon(severity: ToastSeverity): ReactNode {
  switch (severity) {
    case 'success':
      return <CheckCircleIcon />;
    case 'error':
      return <XCircleIcon />;
    case 'warning':
      return <ExclamationCircleIcon />;
    case 'info':
    default:
      return <InformationCircleIcon />;
  }
}

/**
 * getPositionClasses
 *
 * Generates the appropriate CSS class names to position the toast
 * at the desired location on the screen, optionally including
 * distinct animation or transform classes for each location.
 *
 * @param position The chosen position from the ToastPosition set
 * @returns A string of space-separated class names
 */
function getPositionClasses(position: ToastPosition): string {
  // Base classes to ensure the toast is displayed above other elements
  // and uses a fixed position approach.
  const baseClasses = ['fixed', 'z-50'];

  // We'll define vertical/horizontal classes that position the toast container.
  // Each position pair indicates the corner or center locations for top/bottom.
  switch (position) {
    case 'top-left':
      return classNames(baseClasses, 'top-4', 'left-4');
    case 'top-center':
      return classNames(baseClasses, 'top-4', 'left-1/2', '-translate-x-1/2');
    case 'top-right':
      return classNames(baseClasses, 'top-4', 'right-4');
    case 'bottom-left':
      return classNames(baseClasses, 'bottom-4', 'left-4');
    case 'bottom-center':
      return classNames(baseClasses, 'bottom-4', 'left-1/2', '-translate-x-1/2');
    case 'bottom-right':
      return classNames(baseClasses, 'bottom-4', 'right-4');
    default:
      return classNames(baseClasses, 'top-4', 'right-4');
  }
}

/**
 * ----------------------------------------------------------------------------
 * Toast Component
 * ----------------------------------------------------------------------------
 * A reusable, enhanced toast notification component that leverages
 * both internal states and context-driven logic to display short
 * messages with optional auto-dismiss, improved accessibility,
 * and smooth animations in any corner of the UI.
 */

/**
 * Toast
 *
 * @description
 * Displays a single toast notification. Can be used standalone or in combination
 * with a toast manager context. Features configurable positions, severity levels,
 * optional auto-dismiss durations, and extensive accessibility attributes.
 */
export const Toast: React.FC<ToastProps> = memo(
  ({
    className,
    testId,
    position = 'top-right',
    duration,
    onClose,
    severity,
    message
  }: ToastProps) => {
    /**
     * Access the toast context to integrate with global
     * show/hide functionality. If used in a stand-alone
     * manner, these calls can also be optional.
     */
    const { hideToast } = useToast();

    /**
     * Local state to manage exit animation flows. When true,
     * we add an 'exit' class or handle logic to fade out the toast.
     */
    const [isExiting, setIsExiting] = useState<boolean>(false);

    /**
     * Use a ref to track whether the component has fully unmounted,
     * preventing state updates after the toast has completed.
     */
    const unmountedRef = useRef<boolean>(false);

    /**
     * handleClose
     *
     * Orchestrates the toast close operation, initiating the exit animation,
     * then finalizing callback calls once the animation completes.
     */
    const handleClose = useCallback((): void => {
      // Step 1: Trigger exit flow
      setIsExiting(true);
    }, []);

    /**
     * handleAnimationEnd
     *
     * Invoked after the toast completes either its entry or exit animations.
     * We check if the toast is currently exiting, then remove it from context
     * and call any provided onClose callback to finalize.
     */
    const handleAnimationEnd = useCallback(
      (e: AnimationEvent<HTMLDivElement>): void => {
        // If we are exiting, it's time to finalize cleanup.
        if (isExiting && !unmountedRef.current) {
          // Trigger the hideToast function from context to remove from global state.
          hideToast();
          // If there's a user-supplied callback, call it now.
          if (onClose) {
            onClose();
          }
        }
      },
      [hideToast, onClose, isExiting]
    );

    /**
     * Optionally auto-dismiss the toast if a duration is supplied.
     * This effect sets a timeout on mount, cleaned up on unmount,
     * ensuring the toast is closed automatically after 'duration' ms.
     */
    useEffect(() => {
      if (duration && duration > 0) {
        const autoDismissTimer = setTimeout(() => {
          handleClose();
        }, duration);
        return () => {
          clearTimeout(autoDismissTimer);
        };
      }
      return undefined;
    }, [duration, handleClose]);

    /**
     * Track component unmounting to avoid side-effects or
     * state updates after the toast is gone.
     */
    useEffect(() => {
      return () => {
        unmountedRef.current = true;
      };
    }, []);

    const icon: ReactNode = getToastIcon(severity);
    const positionClassNames: string = getPositionClasses(position);

    /**
     * Additional accessibility: we set role="alert" for error/warning to
     * emphasize urgency, and role="status" or "log" for less critical severities.
     * This ensures screen readers correctly announce the message.
     */
    const roleAttribute =
      severity === 'error' || severity === 'warning' ? 'alert' : 'status';

    /**
     * Combine classes for base styling, optional exit animations,
     * user-defined classes, and position.
     */
    const containerClasses = classNames(
      positionClassNames,
      'mb-4', // space from subsequent toasts if stacked
      'p-4',
      'rounded-md',
      'shadow-lg',
      'flex',
      'items-center',
      'gap-2',
      'text-white',
      {
        'bg-green-600': severity === 'success',
        'bg-red-600': severity === 'error',
        'bg-yellow-500': severity === 'warning',
        'bg-blue-600': severity === 'info',
        'animate-fade-out': isExiting
      },
      className
    );

    return (
      <div
        data-testid={testId || 'toast-container'}
        role={roleAttribute}
        aria-live={roleAttribute === 'alert' ? 'assertive' : 'polite'}
        className={containerClasses}
        onAnimationEnd={handleAnimationEnd}
      >
        {/* Icon indicating severity */}
        <span className="w-5 h-5 flex-shrink-0">{icon}</span>

        {/* Main text content */}
        <p className="text-sm font-medium flex-grow">{message}</p>

        {/* Close button (X) for manual dismissal if needed */}
        <button
          type="button"
          onClick={handleClose}
          aria-label="Close notification"
          className="focus:outline-none focus:ring-2 focus:ring-white focus:ring-offset-1 p-1"
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            width="1.25em"
            height="1.25em"
            aria-hidden="true"
          >
            <path
              d="M6.225 4.811a1 1 0 0 1 1.414 0L12 9.172l4.361-4.361
                 a1 1 0 0 1 1.414 1.414L13.414 10.586l4.361 4.361
                 a1 1 0 0 1-1.414 1.414L12 12l-4.361 4.361
                 a1 1 0 1 1-1.414-1.414l4.361-4.361-4.361-4.361
                 a1 1 0 0 1 0-1.414z"
              fill="currentColor"
            />
          </svg>
        </button>
      </div>
    );
  }
);

Toast.displayName = 'Toast';