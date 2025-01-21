import React, {
  FC, // react@^18.0.0
  useState,
  useEffect,
  useCallback,
  useMemo,
  useRef
} from 'react';
import { useNavigate } from 'react-router-dom'; // react-router-dom@^6.0.0
import { useQueryClient } from 'react-query'; // react-query@^4.0.0
import { ErrorBoundary } from 'react-error-boundary'; // react-error-boundary@^4.0.0

// --------------------------------------------------------------------------------------------
// Internal Imports (Per JSON Specification)
// --------------------------------------------------------------------------------------------
import PaymentList, {
  PaymentListProps
} from '../../components/payments/PaymentList'; // PaymentHistory display & offline support
import PaymentSummary, {
  PaymentSummaryProps
} from '../../components/payments/PaymentSummary'; // Real-time summary info
import { PaymentService } from '../../services/payment.service'; // Secure payment operations

// --------------------------------------------------------------------------------------------
// Additional Internal Type Imports (if needed for advanced usage or clarifications)
// --------------------------------------------------------------------------------------------
// These might include Payment, PaymentStatus, or other shared definitions.
// For demonstration purposes, we capture PaymentStatus for status transitions:
import { PaymentStatus } from '../../types/payment.types';

// --------------------------------------------------------------------------------------------
// INTERFACES & TYPES
// --------------------------------------------------------------------------------------------

/**
 * Represents the possible filtering parameters we might apply when
 * fetching payment data in this page. For detailed filtering, you may
 * expand this with additional fields such as date ranges or user IDs.
 */
interface PaymentFilters {
  /**
   * The general search term applied to Payment IDs, Walk IDs,
   * or other relevant fields. Expand this as needed.
   */
  searchTerm?: string;

  /**
   * If we wish to filter by status, we store a PaymentStatus
   * string or leave empty to get all statuses.
   */
  status?: PaymentStatus | '';
}

/**
 * Describes the shape of the local pagination state for this page
 * including current page number and page size. You can store total
 * items or total pages if you intend to manage server-side pagination.
 */
interface PageState {
  page: number;
  pageSize: number;
}

/**
 * The main props object for the Payments page component. In a larger
 * application, this interface might also include route parameters or
 * location states if relevant. For now, it's empty, as the spec only
 * indicates a top-level page with no direct props.
 */
interface PaymentsPageProps {}

/**
 * An optional shape describing how an update to a payment status
 * might be validated. This snippet is a placeholder for more
 * complex domain logic, e.g., preventing transitions from COMPLETED
 * to PENDING, etc.
 */
interface StatusTransitionRule {
  from: PaymentStatus;
  to: PaymentStatus;
  allowed: boolean;
}

// --------------------------------------------------------------------------------------------
// MAIN COMPONENT: Payments
// --------------------------------------------------------------------------------------------

/**
 * Payments
 * ----------------------------------------------------------------------------
 * Implements a main payments page responsible for:
 * 1) Displaying a secure payment history list with offline caching, pagination,
 *    and advanced filtering (PaymentList).
 * 2) Providing real-time status updates via a summary component (PaymentSummary)
 *    and PaymentService subscription.
 * 3) Comprehensive transaction management, including a function to update payment
 *    statuses (handleStatusChange) and a robust approach to error handling, caching,
 *    retry logic, accessibility, and performance enhancements.
 *
 * Production-Ready Features:
 *  - Uses react-query (@^4.0.0) for caching and synchronization.
 *  - Integrates PaymentService to leverage methods:
 *    getPaymentHistory, getPaymentStatus, updatePaymentStatus, subscribeToPaymentUpdates.
 *  - Offers an ErrorBoundary (react-error-boundary@^4.0.0) for graceful UI fallback.
 *  - Allows user navigation with react-router (useNavigate).
 *  - Implements advanced comments for enterprise maintainability.
 */
const Payments: FC<PaymentsPageProps> = () => {
  // ----------------------------------------------------------------------------
  // 1. STATE DECLARATIONS
  // ----------------------------------------------------------------------------

  /**
   * payments: an array of all fetched payments, used to power PaymentList display.
   */
  const [payments, setPayments] = useState<any[]>([]);

  /**
   * loading: indicates whether we are currently fetching data or updating status.
   */
  const [loading, setLoading] = useState<boolean>(false);

  /**
   * error: stores any error message encountered during data fetching or updates.
   * If non-null, the UI can display an alert or fallback message.
   */
  const [error, setError] = useState<string | null>(null);

  /**
   * filters: local state for basic filtering (searchTerm, status).
   * Additional fields can be added for more advanced filtering needs.
   */
  const [filters, setFilters] = useState<PaymentFilters>({
    searchTerm: '',
    status: ''
  });

  /**
   * pageState: local pagination info containing the current page number
   * and the size of each page. For advanced scenarios, also store totalItems, etc.
   */
  const [pageState, setPageState] = useState<PageState>({
    page: 1,
    pageSize: 10
  });

  /**
   * selectedPayment: references the user-selected payment from PaymentList, if any.
   * This is used to show the PaymentSummary in detail, including real-time status updates.
   */
  const [selectedPayment, setSelectedPayment] = useState<any | null>(null);

  /**
   * PaymentService reference, ensuring only one instance is created,
   * preserving subscription logic. This also avoids redundant
   * re-instantiation on re-renders.
   */
  const paymentServiceRef = useRef<PaymentService | null>(null);

  /**
   * For advanced caching logic (react-query), we can store a queryClient reference.
   * This allows us to set or retrieve cached data under certain keys.
   */
  const queryClient = useQueryClient();

  /**
   * Access to the router's navigation function, letting us programmatically
   * redirect if needed (e.g., after certain actions).
   */
  const navigate = useNavigate();

  /**
   * Initialize PaymentService if not yet created.
   */
  if (!paymentServiceRef.current) {
    paymentServiceRef.current = new PaymentService();
  }

  // ----------------------------------------------------------------------------
  // 2. SUBSCRIBE TO REAL-TIME UPDATES
  // ----------------------------------------------------------------------------

  /**
   * subscribeToUpdates
   * ----------------------------------------------------------------------------
   * Sets up a WebSocket subscription for payment updates. Any time a payment
   * record is updated, the callback merges the changes into local state.
   * This approach provides near real-time synchronization with server events.
   *
   * Implementation Steps:
   *  1) Initialize subscription via PaymentService.subscribeToPaymentUpdates.
   *  2) On incoming message, locate the matching payment and update local state.
   *  3) Implement optional reconnection logic if the socket drops (depends on PaymentService).
   *  4) Cleanup subscription on component unmount.
   */
  useEffect(() => {
    const service = paymentServiceRef.current;
    if (!service) return;

    // Step 1) Invoke the subscription method, providing a callback
    // that receives the updated payment data from the server (via WebSocket).
    const unsubscribe = service.subscribeToPaymentUpdates((updatedPayment: any) => {
      // Step 2) Merge updated payment into local state
      setPayments((prevPayments) => {
        const idx = prevPayments.findIndex((p) => p.id === updatedPayment.id);
        if (idx === -1) {
          // If it's a new record, optionally prepend or append
          return [updatedPayment, ...prevPayments];
        }
        const updatedArr = [...prevPayments];
        updatedArr[idx] = updatedPayment;
        return updatedArr;
      });

      // Also update the selectedPayment if it matches the updated one
      setSelectedPayment((prevSel) => {
        if (prevSel && prevSel.id === updatedPayment.id) {
          return { ...updatedPayment };
        }
        return prevSel;
      });
    });

    // Step 4) Cleanup the subscription upon unmount
    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, []);

  // ----------------------------------------------------------------------------
  // 3. FUNCTIONS / HANDLERS
  // ----------------------------------------------------------------------------

  /**
   * fetchPayments
   * ----------------------------------------------------------------------------
   * Fetches payment history data with filters and implements caching, retry logic,
   * and robust error handling. The function is memoized with useCallback for
   * performance and to ensure stable references.
   *
   * Steps:
   *  1) Check cache for existing data under a unique key (optional).
   *  2) Set loading state to true.
   *  3) Implement retry logic with exponential backoff if desired.
   *  4) Call PaymentService.getPaymentHistory to retrieve data.
   *  5) Update local state and react-query cache with the new data.
   *  6) Set loading state to false.
   *  7) Handle errors with fallback UI and error metrics.
   */
  const fetchPayments = useCallback(
    async (activeFilters: PaymentFilters, page: number, pageSize: number): Promise<void> => {
      if (!paymentServiceRef.current) return;
      setError(null);
      setLoading(true);

      try {
        // Step 1) (Optional) Check the react-query cache for a matching key
        const cacheKey = ['paymentHistory', activeFilters, page, pageSize];
        const cachedData = queryClient.getQueryData<any[]>(cacheKey);
        if (cachedData && cachedData.length > 0) {
          setPayments(cachedData);
          setLoading(false);
          return;
        }

        // Step 3) Example of retry logic with minimal exponential backoff
        // (Real implementation might wrap PaymentService in a function with backoff)
        let attempts = 0;
        const maxRetries = 3;
        let success = false;
        let data: any[] = [];

        while (!success && attempts < maxRetries) {
          try {
            // Step 4) Retrieve payment history from PaymentService
            // The PaymentService interface can take an object with filter/paging
            // For demonstration: getPaymentHistory({ searchTerm, status, page, pageSize })
            data = await (paymentServiceRef.current as any).getPaymentHistory({
              searchTerm: activeFilters.searchTerm || '',
              status: activeFilters.status || '',
              page,
              pageSize
            });
            success = true;
          } catch (fetchErr) {
            attempts += 1;
            if (attempts >= maxRetries) throw fetchErr;
            // Minimal backoff
            await new Promise((resolve) => setTimeout(resolve, 500 * attempts));
          }
        }

        // Step 5) Update local state and query cache
        setPayments(data);
        queryClient.setQueryData<any[]>(cacheKey, data);

        // Step 6) Done
        setLoading(false);
      } catch (err: any) {
        // Step 7) Handle error
        setLoading(false);
        setError(err?.message || 'Error fetching payments.');
        // In a real app, track error with analytics/logging
      }
    },
    [queryClient]
  );

  /**
   * handleStatusChange
   * ----------------------------------------------------------------------------
   * Handles payment status updates with optimistic UI changes and potential rollback.
   * This function is used to update a single payment's status, e.g. from PENDING to COMPLETED.
   *
   * Steps:
   *  1) Validate the new status transition for domain correctness (placeholder).
   *  2) Optimistically update local UI to reflect the new status.
   *  3) Call PaymentService.updatePaymentStatus to persist the change.
   *  4) Show success notification. If error occurs, rollback local state.
   *  5) Refresh payment cache or data to keep everything in sync.
   *  6) Update analytics or metrics if needed.
   */
  const handleStatusChange = useCallback(
    async (paymentId: string, newStatus: PaymentStatus): Promise<void> => {
      if (!paymentServiceRef.current) return;
      setError(null);

      // Step 1) For demonstration, assume all transitions are valid
      // Real logic: check domain constraints
      const isValidTransition = true;
      if (!isValidTransition) {
        setError('Invalid status transition requested.');
        return;
      }

      // Step 2) Optimistically update local state for the payment
      const prevPayments = [...payments];
      const paymentIndex = prevPayments.findIndex((p) => p.id === paymentId);
      if (paymentIndex === -1) {
        setError(`Cannot find payment with ID: ${paymentId}`);
        return;
      }
      const oldPayment = { ...prevPayments[paymentIndex] };
      prevPayments[paymentIndex] = { ...oldPayment, status: newStatus };
      setPayments(prevPayments);

      // If the selectedPayment is the same one, update that too
      setSelectedPayment((curr) =>
        curr && curr.id === paymentId ? { ...curr, status: newStatus } : curr
      );

      try {
        // Step 3) Perform the API update
        await (paymentServiceRef.current as any).updatePaymentStatus(paymentId, newStatus);

        // Step 4) Show success message or do a toast/notification
        console.log(`Payment ${paymentId} updated to status: ${newStatus}`);

        // Step 5) (Optional) Re-fetch or refresh cache
        // Could call fetchPayments again or specifically update the local item
        // We'll do a minimal approach here:
        // e.g., fetchPayments(filters, pageState.page, pageState.pageSize);
      } catch (updateError: any) {
        // Rollback local state if something fails
        setPayments((_) => {
          const rollbackArr = [..._];
          rollbackArr[paymentIndex] = oldPayment;
          return rollbackArr;
        });
        setError(
          `Failed to update status for payment ${paymentId}: ${updateError?.message || ''}`
        );
      }
      // Step 6) (Optional) track success/failure with analytics
    },
    [payments, filters, pageState]
  );

  // ----------------------------------------------------------------------------
  // 4. EFFECTS FOR DATA FETCHING
  // ----------------------------------------------------------------------------

  /**
   * Automatically fetch initial payment data on component mount or whenever
   * filters, page, or pageSize changes. This ensures PaymentList is up to date.
   */
  useEffect(() => {
    (async () => {
      await fetchPayments(filters, pageState.page, pageState.pageSize);
    })();
  }, [filters, pageState, fetchPayments]);

  // ----------------------------------------------------------------------------
  // 5. HELPER HANDLERS FOR FILTERS & PAGINATION
  // ----------------------------------------------------------------------------

  /**
   * onFilterChange
   * Allows the user to update searchTerm or status,
   * which triggers a re-fetch with the new filters.
   */
  const onFilterChange = useCallback((partial: Partial<PaymentFilters>) => {
    setFilters((prev) => ({
      ...prev,
      ...partial
    }));
  }, []);

  /**
   * onPageChange
   * Adjusts the page number, prompting a data re-fetch.
   */
  const onPageChange = useCallback((newPage: number) => {
    setPageState((prev) => ({
      ...prev,
      page: newPage < 1 ? 1 : newPage
    }));
  }, []);

  /**
   * onPageSizeChange
   * Adjusts the items per page, resetting the current page to 1 to avoid out-of-range issues.
   */
  const onPageSizeChange = useCallback((newSize: number) => {
    setPageState({
      page: 1,
      pageSize: newSize
    });
  }, []);

  /**
   * handlePaymentSelect
   * Called when the user selects a payment from PaymentList,
   * setting the selectedPayment state for PaymentSummary display.
   */
  const handlePaymentSelect = useCallback((payment: any) => {
    setSelectedPayment(payment);
  }, []);

  // ----------------------------------------------------------------------------
  // 6. RENDER UI
  // ----------------------------------------------------------------------------

  /**
   * Render the main payments page within an ErrorBoundary.
   * The PaymentList occupies one portion of the screen, while
   * PaymentSummary displays detailed info for the currently
   * selected payment (if any).
   */
  return (
    <ErrorBoundary
      FallbackComponent={() => (
        <div className="payments__error-fallback">
          <h2>An error occurred in the Payments page.</h2>
          <p>Please try reloading or contact support.</p>
        </div>
      )}
    >
      <div className="payments__container">
        {/* Header / Title region */}
        <header className="payments__header">
          <h1>Payments Management</h1>
          {error && <div className="payments__error-message">{error}</div>}
        </header>

        {/* Filter Controls: Basic demonstration with search term & status */}
        <div className="payments__filters">
          <label htmlFor="searchTermInput">Search:</label>
          <input
            id="searchTermInput"
            type="text"
            value={filters.searchTerm || ''}
            onChange={(e) => onFilterChange({ searchTerm: e.target.value })}
            placeholder="Search by Payment or Walk ID"
          />

          <label htmlFor="statusSelect">Status:</label>
          <select
            id="statusSelect"
            value={filters.status || ''}
            onChange={(e) => onFilterChange({ status: e.target.value as PaymentStatus | '' })}
          >
            <option value="">All</option>
            {Object.values(PaymentStatus).map((st) => (
              <option key={st} value={st}>
                {st}
              </option>
            ))}
          </select>
        </div>

        {/* PaymentList: displays the fetched payments with advanced pagination & sorting */}
        <section className="payments__list-section">
          <PaymentList
            initialPageSize={pageState.pageSize}
            onPaymentSelect={handlePaymentSelect}
          />
        </section>

        {/* Pagination Controls for demonstration */}
        <div className="payments__pagination">
          <button
            type="button"
            disabled={pageState.page <= 1}
            onClick={() => onPageChange(pageState.page - 1)}
          >
            Prev Page
          </button>
          <span>{`Page ${pageState.page}`}</span>
          <button type="button" onClick={() => onPageChange(pageState.page + 1)}>
            Next Page
          </button>

          <label htmlFor="pageSizeDropdown">Items per page: </label>
          <select
            id="pageSizeDropdown"
            value={pageState.pageSize}
            onChange={(e) => onPageSizeChange(Number(e.target.value))}
          >
            <option value={5}>5</option>
            <option value={10}>10</option>
            <option value={20}>20</option>
          </select>
        </div>

        {/* Optional loading indicator */}
        {loading && (
          <div className="payments__loading-indicator">Loading payment data, please wait...</div>
        )}

        {/* PaymentSummary for the currently selected payment */}
        {selectedPayment && (
          <section className="payments__summary-section">
            <PaymentSummary
              className="payments__summary"
              payment={selectedPayment}
              pollingInterval={5000}
              retryAttempts={3}
              onStatusChange={(newStatus) => {
                // If PaymentSummary detects a status change, we can refresh or do other logic
                console.log(`Payment status changed to ${newStatus} at the summary level.`);
              }}
            />
            {/* Example button to demonstrate handleStatusChange usage */}
            <div className="payments__status-change-controls">
              <button
                type="button"
                onClick={() => handleStatusChange(selectedPayment.id, PaymentStatus.COMPLETED)}
              >
                Mark Completed
              </button>
              <button
                type="button"
                onClick={() => handleStatusChange(selectedPayment.id, PaymentStatus.REFUNDED)}
              >
                Mark Refunded
              </button>
            </div>
          </section>
        )}
      </div>
    </ErrorBoundary>
  );
};

export default Payments;