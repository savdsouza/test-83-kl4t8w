import React, {
  FC, // ^18.0.0
  useEffect,
  useState,
  useRef,
  KeyboardEvent,
} from 'react';
import classNames from 'classnames'; // ^2.3.0

////////////////////////////////////////////////////////////////////////////////
// Internal Imports (Per JSON Specification)
////////////////////////////////////////////////////////////////////////////////
import { Card } from '../common/Card'; // Container component for the summary
import {
  Payment,
  PaymentStatus,
  PaymentMethod,
} from '../../types/payment.types'; // Type definitions for payment data
import { PaymentService } from '../../services/payment.service'; // Service for payment operations & real-time status

////////////////////////////////////////////////////////////////////////////////
// Interface Definition
////////////////////////////////////////////////////////////////////////////////

/**
 * PaymentSummaryProps
 * ----------------------------------------------------------------------------
 * Defines the expected properties for the PaymentSummary component,
 * including payment details, styling support, status polling, callbacks,
 * and accessibility-related requirements.
 */
export interface PaymentSummaryProps {
  /**
   * The Payment object containing essential data such as amount, status,
   * currency, and creation date for display in the component.
   */
  payment: Payment;

  /**
   * An optional CSS class name to apply custom styling over the base styling.
   */
  className?: string;

  /**
   * A callback function invoked whenever the payment status changes
   * (e.g., from PENDING to COMPLETED). Receives the new status as an argument.
   */
  onStatusChange: (status: PaymentStatus) => void;

  /**
   * The interval (in milliseconds) at which the component will poll for
   * the latest payment status. If set to 0 or undefined, polling is disabled.
   */
  pollingInterval: number;

  /**
   * The maximum number of retry attempts allowed when polling for payment status
   * encounters errors (e.g., network disruptions). Once exceeded, polling stops.
   */
  retryAttempts: number;
}

////////////////////////////////////////////////////////////////////////////////
// Utility Function
////////////////////////////////////////////////////////////////////////////////

/**
 * formatAmount
 * ----------------------------------------------------------------------------
 * Formats a numeric payment amount using locale-aware currency formatting.
 *
 * Steps:
 *  1) Create an Intl.NumberFormat instance with the given locale and currency.
 *  2) Format the provided numeric amount according to currency rules.
 *  3) Handle edge cases for zero or negative amounts if needed.
 *  4) Return the formatted currency string (e.g., "$49.99" or "CA$10.00").
 *
 * @param amount   - The numeric payment amount to format.
 * @param currency - The three-letter currency code (e.g., "USD", "CAD").
 * @param locale   - The desired locale for formatting (default: "en-US").
 * @returns A properly formatted currency string.
 */
function formatAmount(amount: number, currency: string, locale: string = 'en-US'): string {
  // (1) Create a localized formatter for the given currency with two decimal places.
  const formatter = new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  // (2) Format the amount.
  const formatted = formatter.format(amount);
  // (3) Edge cases for zero or negative amounts can be addressed if desired.
  // (4) Return the final string.
  return formatted;
}

////////////////////////////////////////////////////////////////////////////////
// Component Definition
////////////////////////////////////////////////////////////////////////////////

/**
 * PaymentSummary
 * ----------------------------------------------------------------------------
 * Renders a card displaying essential payment information such as the
 * total amount, payment method, current payment status, creation date,
 * and currency, along with real-time status updates and accessibility support.
 *
 * Features:
 *  - Real-time status updates via polling (using PaymentService).
 *  - Accessible design with ARIA labels, roles, and keyboard handling.
 *  - Internationalized amount formatting with currency symbols.
 *  - Configurable polling interval and retry attempts for robust error handling.
 *
 * Implementation Steps:
 *  (1) Destructure props including payment, callbacks, and config.
 *  (2) Initialize state for the current payment status, error messaging, and load flags.
 *  (3) Obtain or instantiate a PaymentService to manage real-time status checks.
 *  (4) Use a useEffect hook to poll the payment status at the specified interval, up to the max retries.
 *  (5) If the payment status changes, call the onStatusChange callback and update the local state.
 *  (6) Format the payment amount and creation date for display.
 *  (7) Render the summary information in a Card component with strong accessibility features (role, tabIndex, aria-label).
 *  (8) Provide screen-reader announcements (aria-live) for status updates to ensure inclusive UX.
 *  (9) Apply conditional styling based on the payment status using classNames utility.
 *  (10) Implement error handling and cessation of polling if maximum retries are exhausted.
 */
export const PaymentSummary: FC<PaymentSummaryProps> = ({
  payment,
  className,
  onStatusChange,
  pollingInterval,
  retryAttempts,
}) => {
  ////////////////////////////////////////////////////////////////////////
  // (2) State Management
  ////////////////////////////////////////////////////////////////////////

  /**
   * paymentStatus: Track the current status of the payment (e.g., PENDING, COMPLETED).
   * loading:       Indicates if the component is currently fetching status updates.
   * error:         Stores any error message that arises during status polling/updates.
   */
  const [paymentStatus, setPaymentStatus] = useState<PaymentStatus>(payment.status);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  /**
   * refAttempts: Keep track of how many polling attempts have been made
   * to avoid exceeding the user-defined retryAttempts threshold.
   */
  const refAttempts = useRef<number>(0);

  ////////////////////////////////////////////////////////////////////////
  // (3) Payment Service Instance
  ////////////////////////////////////////////////////////////////////////
  // Use a single PaymentService instance to handle real-time updates, etc.
  const paymentServiceRef = useRef<PaymentService | null>(null);
  if (!paymentServiceRef.current) {
    paymentServiceRef.current = new PaymentService();
  }

  ////////////////////////////////////////////////////////////////////////
  // (4) Polling Effect
  ////////////////////////////////////////////////////////////////////////
  useEffect(() => {
    // If pollingInterval is zero or undefined, skip real-time updates.
    if (!pollingInterval || pollingInterval <= 0) {
      return;
    }

    // Reset attempts state whenever the component restarts polling.
    refAttempts.current = 0;
    setError(null);

    const service = paymentServiceRef.current;
    let pollingTimer: number | undefined;

    /**
     * pollStatus
     * ----------------------------------------------------------------------------
     * Attempts to fetch the latest payment status from the PaymentService.
     * If successful and the status differs from the current cached status,
     * it updates local state and triggers the onStatusChange callback.
     */
    async function pollStatus() {
      if (!service) return;
      try {
        setLoading(true);
        // JSON Specification: "PaymentService" uses getPaymentStatus/pollPaymentStatus
        // These methods are presumably available in the real PaymentService.
        // We'll assume a getPaymentStatus method that retrieves the latest status as a string enum:
        // e.g., service.getPaymentStatus(payment.id)
        const newStatus = await (service as any).getPaymentStatus(payment.id);
        setLoading(false);
        setError(null);

        // If the status changed, sync local state and notify callers.
        if (newStatus && newStatus !== paymentStatus) {
          setPaymentStatus(newStatus);
          onStatusChange(newStatus);
        }
      } catch (pollError: any) {
        setLoading(false);
        refAttempts.current += 1;
        // If attempts are exhausted, store an error and clear the timer.
        if (refAttempts.current >= retryAttempts) {
          setError(`Polling stopped after ${retryAttempts} failed attempts: ${pollError?.message ?? 'Unknown error'}`);
          if (pollingTimer) {
            clearInterval(pollingTimer);
          }
          return;
        }
        // Otherwise, set a transient error message and continue attempts.
        setError(`Attempt ${refAttempts.current}: ${pollError?.message ?? 'An error occurred.'}`);
      }
    }

    /**
     * Initialize the status polling at the specified interval, clearing
     * the timer on component unmount or when the interval changes.
     */
    pollStatus(); // Immediate check on mount
    pollingTimer = window.setInterval(pollStatus, pollingInterval);

    return () => {
      if (pollingTimer) {
        clearInterval(pollingTimer);
      }
    };
  }, [payment.id, paymentStatus, pollingInterval, retryAttempts, onStatusChange]);

  ////////////////////////////////////////////////////////////////////////
  // (5) Payment Status Changes
  ////////////////////////////////////////////////////////////////////////
  // The effect above handles real-time updates. If the parent passes a
  // 'payment.status' that differs from the local state, we can sync
  // here. However, typically, we keep the local state synchronized to
  // avoid flash states.

  ////////////////////////////////////////////////////////////////////////
  // (6) Format Payment Data
  ////////////////////////////////////////////////////////////////////////

  /**
   * Format the date/time for the payment creation, using a user-friendly readable date.
   */
  const formattedDate = new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(payment.createdAt));

  /**
   * Format the payment amount using our utility function "formatAmount".
   */
  const formattedAmount = formatAmount(payment.amount, payment.currency);

  ////////////////////////////////////////////////////////////////////////
  // (7) Accessibility & (9) Conditional Styling
  ////////////////////////////////////////////////////////////////////////
  // We'll define a dynamic class to reflect the payment status, e.g. "payment-summary--completed".
  const statusClass = `payment-summary--${paymentStatus.toLowerCase()}`;
  const rootClassNames = classNames(
    'payment-summary', // base class for styling
    statusClass,
    className // any external className passed in
  );

  ////////////////////////////////////////////////////////////////////////
  // (8) Screen Reader Announcements
  ////////////////////////////////////////////////////////////////////////
  // We'll provide an aria-live region below for status updates, allowing screen readers
  // to automatically announce changes.
  //
  // Also define a simple keyboard handler if we want to allow certain key-press actions
  // (for demonstration).
  function handleKeyDown(e: KeyboardEvent<HTMLDivElement>) {
    if (e.key === 'Enter') {
      // Potentially focus an element or expand additional transaction details
      // This is left open for demonstration of keyboard accessibility.
    }
  }

  ////////////////////////////////////////////////////////////////////////
  // Render Component
  ////////////////////////////////////////////////////////////////////////

  return (
    <Card
      // Card supports className, role, tabIndex, among others
      className={rootClassNames}
      role="region"
      tabIndex={0}
      // We can pass an aria-label through the ...rest or directly:
      aria-label="Payment Summary Section"
      onKeyDown={handleKeyDown}
      elevation={2}
    >
      {/****************************************************************************************
       * Payment Summary Header
       ***************************************************************************************/}
      <header className="payment-summary__header">
        <h2>Payment Summary</h2>
      </header>

      {/****************************************************************************************
       * Real-time Status Announcement (ARIA)
       * We use a polite aria-live region to announce status changes to screen readers.
       ***************************************************************************************/}
      <div
        className="payment-summary__status-announcement"
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        {error ? (
          <p className="payment-summary__error" aria-live="assertive">
            {error}
          </p>
        ) : (
          <p className="payment-summary__status-text">
            {loading
              ? 'Fetching latest payment status...'
              : `Current Status: ${paymentStatus}`}
          </p>
        )}
      </div>

      {/****************************************************************************************
       * Main Content Displaying Payment Details
       ***************************************************************************************/}
      <div className="payment-summary__details">
        {/* Payment Amount */}
        <div className="payment-summary__row">
          <strong>Amount:</strong>
          <span>{formattedAmount}</span>
        </div>

        {/* Payment Method */}
        <div className="payment-summary__row">
          <strong>Method:</strong>
          <span>{PaymentMethod[payment.method] || payment.method}</span>
        </div>

        {/* Payment Status */}
        <div className="payment-summary__row">
          <strong>Status:</strong>
          <span>{PaymentStatus[paymentStatus] || paymentStatus}</span>
        </div>

        {/* Payment Currency */}
        <div className="payment-summary__row">
          <strong>Currency:</strong>
          <span>{payment.currency}</span>
        </div>

        {/* Payment Creation Date */}
        <div className="payment-summary__row">
          <strong>Created At:</strong>
          <time dateTime={new Date(payment.createdAt).toISOString()}>
            {formattedDate}
          </time>
        </div>
      </div>
    </Card>
  );
};