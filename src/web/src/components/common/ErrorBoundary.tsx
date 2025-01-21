/**
 * ErrorBoundary.tsx
 *
 * A robust React Error Boundary component providing comprehensive error handling,
 * recovery mechanisms, accessible fallback UI, and integration points for both
 * user feedback and system monitoring. Complies with the provided technical
 * specification, addressing:
 *  - Error Handling (comprehensive boundary, recovery)
 *  - User Interface Design (accessible & user-friendly fallback)
 *  - System Monitoring (error tracking, retry logic)
 */

// react@^18.0.0
import React, { type ReactNode, type ErrorInfo } from 'react';

// Internal imports (as directed in JSON specification)
// NOTE: Adjusting to match actual usage based on provided file contents and IE1 rule:
import { showToast, ToastType } from './Toast'; // Referenced for user-friendly error notifications
import Loading from './Loading';               // Display loading state during error recovery attempts

/**
 * -------------------------------------------------------------------------
 * Global interfaces from JSON specification
 * -------------------------------------------------------------------------
 */

/**
 * Defines the properties accepted by the ErrorBoundary component, including
 * an optional fallback, error callback, and configurable recovery parameters.
 */
export interface ErrorBoundaryProps {
  /** Child nodes wrapped by this error boundary */
  children: ReactNode;
  /** Optional custom fallback UI to display when an error occurs */
  fallback?: ReactNode;
  /** Callback invoked upon error capture, providing error details */
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
  /** Maximum number of recovery attempts to perform */
  maxRetries?: number;
  /** Base retry interval in milliseconds for exponential backoff */
  retryInterval?: number;
}

/**
 * Maintains this boundary's internal error-tracking and recovery state.
 */
export interface ErrorBoundaryState {
  /** Indicates whether an error has occurred */
  hasError: boolean;
  /** The captured error object, if any */
  error: Error | null;
  /** Detailed error information from React, if available */
  errorInfo: ErrorInfo | null;
  /** Tracks the number of recovery attempts made */
  retryCount: number;
  /** Indicates whether the boundary is currently attempting recovery */
  isRecovering: boolean;
}

/**
 * -------------------------------------------------------------------------
 * The Enhanced ErrorBoundary Class
 * -------------------------------------------------------------------------
 * This boundary includes:
 *  - Automatic error capture (componentDidCatch/getDerivedStateFromError)
 *  - Optional user-defined fallback UI
 *  - Retry-based recovery mechanism with exponential backoff
 *  - Integrated system monitoring hooks (console logs / external services)
 *  - User-friendly notifications via showToast
 *  - Accessibility attributes for a better screen reader experience
 */

export default class ErrorBoundary extends React.Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  /**
   * Initializes the error boundary with stateful error tracking
   * and optional performance monitoring or logging hooks.
   */
  constructor(props: ErrorBoundaryProps) {
    super(props);
    // Step 1: Call super with props
    // Step 2: Initialize state with error tracking properties
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      retryCount: 0,
      isRecovering: false,
    };

    // Step 3: Set up error recovery configuration (if needed)
    // e.g., reading maxRetries, retryInterval from props
    // Step 4: Initialize performance monitoring (placeholder for external tooling)
    // e.g., console.log("[Performance Monitoring] ErrorBoundary mounted.");
  }

  /**
   * React lifecycle method (static) invoked after an error is thrown,
   * allowing us to update component state accordingly. This is a prime
   * spot for setting hasError to true and clearing any prior success state.
   */
  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    // Step 1: Sanitize error information (placeholder; can add more robust logic)
    const sanitizedError = error;

    // Step 2: Update error state with tracking data (hasError, error, reset errorInfo)
    // Step 3: Initialize recovery attempt counter (setting retryCount to 0)
    // Step 4: Return enhanced error state
    return {
      hasError: true,
      error: sanitizedError,
      errorInfo: null,
      retryCount: 0,
      isRecovering: false,
    };
  }

  /**
   * React lifecycle method invoked after an error is thrown in a child
   * component. We can log or track the error here, trigger user feedback,
   * and potentially initiate a recovery attempt.
   */
  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    // Step 1: Log error with enhanced details (console or external service)
    console.error("[ErrorBoundary] Caught error:", error, errorInfo);

    // Step 2: Track error in monitoring system (placeholder for real service)
    // e.g., monitoringService.logError({ error, errorInfo });

    // Step 3: Trigger error recovery mechanism or wait for user action
    // For demonstration, we do not automatically call attemptRecovery here,
    // but it could be done if you want immediate recovery attempts.

    // Step 4: Show accessible error notification (if feasible)
    showToast(error.message, 'error', 5000);

    // Step 5: Execute error callback if provided
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }

    // Finally, store the errorInfo in state for potential display
    this.setState({ errorInfo });
  }

  /**
   * Orchestrates the recovery process after an error has been caught,
   * using exponential backoff and a limited number of retries. This
   * simulates unmounting/remounting child components or refreshing
   * certain data to restore a functional UI.
   */
  attemptRecovery = async (): Promise<void> => {
    const { maxRetries = 3, retryInterval = 3000 } = this.props;
    const { retryCount } = this.state;

    // Step 1: Check if the retry count has reached the maximum
    if (retryCount >= maxRetries) {
      // If we've exceeded the maximum, do not proceed further
      return;
    }

    this.setState({ isRecovering: true });

    // Step 2: Implement exponential backoff
    // For each retry: delay = retryInterval * 2^(retryCount)
    const currentDelay = retryInterval * 2 ** retryCount;

    // Wait for the specified backoff delay
    await new Promise((resolve) => setTimeout(resolve, currentDelay));

    try {
      // Step 3: Attempt a "remount" by resetting error state
      // or refreshing relevant data. We mimic that by resetting:
      this.setState((prev) => ({
        hasError: false,
        error: null,
        errorInfo: null,
        retryCount: prev.retryCount + 1,
        isRecovering: false,
      }));

      // Step 4: Update recovery status and optionally do more logic
      // e.g., console.log("[ErrorBoundary] Successful recovery attempt!");

      // Step 5: If successful, the child component is re-rendered
      // with cleared error state. Additional success handling can go here.
    } catch (recoveryError) {
      // If the recovery attempt fails, increment retryCount, keep hasError
      this.setState((prev) => ({
        retryCount: prev.retryCount + 1,
        isRecovering: false,
      }));
      // Optionally re-throw or log
      console.error("[ErrorBoundary] Recovery attempt failed:", recoveryError);
    }
  };

  /**
   * Renders the child component tree if no error is present, the loading
   * indicator if we are actively recovering, or the fallback UI upon error.
   */
  render(): React.ReactNode {
    const { children, fallback } = this.props;
    const { hasError, error, errorInfo, isRecovering } = this.state;

    // Step 1: Check if we are currently in a recovery state
    if (isRecovering) {
      // Display a loading spinner or similar UI
      return (
        <div style={{ padding: '1rem' }}>
          <Loading
            text="Attempting recovery..."
            fullScreen={false}
          />
        </div>
      );
    }

    // Step 2: If an error has occurred and we are not recovering
    if (hasError && error) {
      // Step 3: If a custom fallback UI is provided, render it;
      // otherwise provide a default accessible fallback
      if (fallback) {
        return fallback;
      }

      // Default fallback with user-facing info and a retry option
      return (
        <div
          role="alert"
          aria-live="assertive"
          style={{
            border: '1px solid #f44336',
            padding: '1rem',
            margin: '1rem',
            borderRadius: '4px',
          }}
        >
          <h2 style={{ color: '#f44336' }}>Something went wrong.</h2>
          <p>
            {error.message || "An unexpected error occurred."}
            {!!errorInfo && (
              <em style={{ display: 'block', marginTop: '0.5rem' }}>
                Additional details logged to console.
              </em>
            )}
          </p>
          <button
            type="button"
            onClick={this.attemptRecovery}
            style={{
              background: '#2196F3',
              color: '#fff',
              padding: '0.5rem 1rem',
              borderRadius: '4px',
              border: 'none',
              cursor: 'pointer',
              marginTop: '1rem',
            }}
          >
            Try to Recover
          </button>
        </div>
      );
    }

    // Step 4: Otherwise, no error exists, so render children normally
    return children;
  }
}