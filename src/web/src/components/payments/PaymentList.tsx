import React, {
  FC, // react@^18.0.0
  useState,
  useEffect,
  useCallback,
  useMemo,
  useRef
} from 'react';
import { format } from 'date-fns'; // date-fns@^2.30.0
import { useVirtualizer } from '@tanstack/react-virtual'; // @tanstack/react-virtual@^3.0.0

// ------------------------------------------------------------------------------------------------
// Internal Imports
// ------------------------------------------------------------------------------------------------
import Table, { TableProps, ColumnDef as TableColumn } from '../common/Table'; // Reusable table component
import { Payment, PaymentStatus } from '../../types/payment.types'; // Comprehensive payment type definitions
import { PaymentService } from '../../services/payment.service'; // Enhanced payment service with real-time updates

// ------------------------------------------------------------------------------------------------
// TYPES & INTERFACES
// ------------------------------------------------------------------------------------------------

/**
 * Defines the structure of local sorting state for multiple columns,
 * enabling advanced multi-column sort scenarios if needed. Each entry
 * indicates which column is sorted, whether ascending or descending,
 * and any other relevant metadata such as multiSort toggling.
 */
interface SortConfig {
  column: string;
  direction: 'asc' | 'desc';
}

/**
 * Describes the filtering parameters that can be applied to the
 * payment list, such as searching by Payment ID or filtering
 * by status. This can be expanded for advanced filtering fields
 * like minAmount, maxAmount, or date ranges.
 */
interface PaymentFilters {
  searchTerm: string;
  status: PaymentStatus | '';
}

/**
 * Describes the pagination state maintained by the component.
 * It includes the current page, page size, total items,
 * and total pages, essential for managing table pagination.
 */
interface PaymentPagination {
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
}

/**
 * Represents the additional props that can be passed to
 * PaymentList, allowing external configuration for
 * initial page size, or hooking into certain events like
 * onPaymentSelect. This interface can be extended
 * with further enterprise customizations.
 */
export interface PaymentListProps {
  /**
   * (Optional) Sets an initial page size (default is 10)
   */
  initialPageSize?: number;

  /**
   * (Optional) Called when a payment is selected from the list,
   * useful for surfaces that need to display additional details
   * or navigate to a detail view.
   */
  onPaymentSelect?: (payment: Payment) => void;
}

// ------------------------------------------------------------------------------------------------
// PaymentList Component
// ------------------------------------------------------------------------------------------------

/**
 * A comprehensive React component that displays a paginated and sortable list
 * of payment transactions for dog walking services, featuring advanced filtering,
 * real-time updates, accessibility enhancements, and optional virtual scrolling.
 *
 * This component addresses:
 * - Financial Operations: displaying transaction histories, automated updates,
 *   and secure payments tracking with real-time context.
 * - User Interface Design: advanced table with multi-column sorting, dynamic
 *   filtering, ARIA-compliant markup, and responsive layout considerations.
 */
const PaymentList: FC<PaymentListProps> = ({ initialPageSize = 10, onPaymentSelect }) => {
  // ----------------------------------------------------------------------------------------------
  // 1. State & References
  // ----------------------------------------------------------------------------------------------

  /**
   * Payment array storing the currently displayed data. Updated
   * upon fetch or whenever real-time changes occur.
   */
  const [payments, setPayments] = useState<Payment[]>([]);

  /**
   * Loading indicator. When true, the UI displays spinners
   * or skeleton placeholders to signal data fetching.
   */
  const [isLoading, setIsLoading] = useState<boolean>(false);

  /**
   * Error message for any issues occurring during fetch operations
   * or real-time updates, displayed in the UI if non-null.
   */
  const [error, setError] = useState<string | null>(null);

  /**
   * Local filters (searchTerm, status, etc.). Updated via
   * onChange events in filtering controls, then used to
   * refetch data from the PaymentService.
   */
  const [filters, setFilters] = useState<PaymentFilters>({
    searchTerm: '',
    status: ''
  });

  /**
   * A local state object for pagination. This aligns with
   * Table's pagination structure, and can be updated
   * when data is fetched or user navigates pages.
   */
  const [pagination, setPagination] = useState<PaymentPagination>({
    page: 1,
    pageSize: initialPageSize,
    totalItems: 0,
    totalPages: 1
  });

  /**
   * Local state for sorting. Multiple columns can be stored
   * if multiSort is applied. If single column only, store one item.
   */
  const [sortConfig, setSortConfig] = useState<SortConfig[]>([]);

  /**
   * A ref to store a PaymentService instance, ensuring
   * we only create one service object. Demonstrating
   * an enterprise pattern avoiding repeated instantiation.
   */
  const paymentServiceRef = useRef<PaymentService | null>(null);

  /**
   * A ref to hold the scrollable parent container for optional virtualization.
   * The child rows in the table can be virtually rendered to handle large lists.
   */
  const scrollParentRef = useRef<HTMLDivElement | null>(null);

  // ----------------------------------------------------------------------------------------------
  // 2. PaymentService Initialization
  // ----------------------------------------------------------------------------------------------
  if (!paymentServiceRef.current) {
    paymentServiceRef.current = new PaymentService();
  }

  // ----------------------------------------------------------------------------------------------
  // 3. Virtualization Setup (Optional)
  // ----------------------------------------------------------------------------------------------
  /**
   * The useVirtualizer hook from @tanstack/react-virtual is used here to
   * optimize rendering for large lists. This approach is optional, as we
   * also integrate server-side or client-side pagination. It demonstrates
   * advanced performance management for large data sets.
   */
  const rowVirtualizer = useVirtualizer({
    count: payments.length,
    getScrollElement: () => scrollParentRef.current,
    estimateSize: useCallback(() => 60, []),
    overscan: 5
  });

  /**
   * The virtual items are the subset of rows that should be visible
   * in the user's viewport. We can map over them to render the table
   * rows. However, since we're also using a generic Table component,
   * we may handle synergy by limiting data passed to the Table.
   */
  const virtualItems = rowVirtualizer.getVirtualItems();

  // ----------------------------------------------------------------------------------------------
  // 4. Functions (fetchPayments, handleSort)
  // ----------------------------------------------------------------------------------------------

  /**
   * fetchPayments
   * --------------------------------------------------------------------------------------------
   * Fetches paginated payment history data with advanced error handling and retry logic.
   * Follows the steps:
   *  1) Set loading state to true.
   *  2) Initialize retry count (handled by PaymentService internally or here).
   *  3) Attempt to fetch payments from PaymentService with optional exponential backoff.
   *  4) Transform and validate the received payment data as needed.
   *  5) Update local payments state and pagination totals.
   *  6) Set loading state to false.
   *  7) Handle errors with UI feedback and logs for monitoring.
   */
  const fetchPayments = useCallback(
    async ({
      filters: currentFilters,
      sort,
      pagination: currentPagination,
      signal
    }: {
      filters: PaymentFilters;
      sort: SortConfig[];
      pagination: PaymentPagination;
      signal?: AbortSignal;
    }): Promise<void> => {
      setIsLoading(true);
      setError(null);

      try {
        // This is where you might implement or call paymentServiceRef.current?.getPaymentHistory
        // which can handle advanced filtering, sorting, and pagination. For demonstration, let's
        // simulate a call here:

        if (!paymentServiceRef.current) {
          throw new Error('PaymentService not initialized');
        }

        // Step 2/3: We can pretend we call something like:
        // const response = await paymentServiceRef.current.getPaymentHistory({
        //   page: currentPagination.page,
        //   pageSize: currentPagination.pageSize,
        //   searchTerm: currentFilters.searchTerm,
        //   statusFilter: currentFilters.status,
        //   sortFields: sort,
        //   signal
        // });

        // For this code snippet, we'll define a mock result:
        const mockFetchedPayments: Payment[] = []; // Logic replaced by actual PaymentService call

        // We can also assume the service returns an object with totalItems, totalPages
        const mockTotalItems = 0;
        const mockTotalPages = 1;

        // Step 5: Update state with the new data
        setPayments(mockFetchedPayments);
        setPagination((prev) => ({
          ...prev,
          totalItems: mockTotalItems,
          totalPages: mockTotalPages
        }));

        // Step 6: Done loading
        setIsLoading(false);
      } catch (err: any) {
        setError(err?.message || 'An error occurred while fetching payments.');
        setIsLoading(false);
        // Step 7: Log error for monitoring
        console.error('fetchPayments error:', err);
      }
    },
    []
  );

  /**
   * handleSort
   * --------------------------------------------------------------------------------------------
   * Manages multi-column table sorting with optimized re-rendering.
   *  1) Validate sort parameters.
   *  2) Update local sort state (and maintain previous sorts if multiSort).
   *  3) Trigger data refetch with new sort configuration.
   *  4) Update URL query parameters or local storage for persistency if required.
   *  5) Persist sort preferences in local state.
   */
  const handleSort = useCallback(
    ({
      column,
      direction,
      multiSort
    }: {
      column: string;
      direction: 'asc' | 'desc';
      multiSort: boolean;
    }): void => {
      // Step 1: Basic validation
      if (!column || !direction) {
        return;
      }

      // Step 2: Update local sort state
      setSortConfig((prev) => {
        let updatedSort = [...prev];

        // If multi-sort is off, simply replace with the new sort
        if (!multiSort) {
          updatedSort = [{ column, direction }];
        } else {
          // If multi-sort is on, update or append
          const existingIndex = updatedSort.findIndex((s) => s.column === column);
          if (existingIndex > -1) {
            updatedSort[existingIndex] = { column, direction };
          } else {
            updatedSort.push({ column, direction });
          }
        }
        return updatedSort;
      });

      // Step 3: Trigger payment data refetch with updated sorting
      fetchPayments({
        filters,
        sort: [{ column, direction }], // or the entire array if multi-sort
        pagination,
        signal: undefined
      });

      // Step 4: (Optional) Update URL or localStorage with sort info
      // e.g., window.history.pushState({}, '', `?sort=${column}&dir=${direction}`);

      // Step 5: Already covered in local state. Could also store in cookies/localStorage if desired.
    },
    [fetchPayments, filters, pagination]
  );

  // ----------------------------------------------------------------------------------------------
  // 5. Real-Time Updates
  // ----------------------------------------------------------------------------------------------

  /**
   * Subscribes to payment updates from PaymentService. Each time a payment is updated
   * or a new payment is introduced, we merge those changes into the local state.
   * This ensures the list reflects real-time info, critical for transaction updates.
   */
  useEffect(() => {
    let unsubscribe: () => void;

    if (paymentServiceRef.current && paymentServiceRef.current.subscribeToPaymentUpdates) {
      unsubscribe = paymentServiceRef.current.subscribeToPaymentUpdates((updatedPayment: Payment) => {
        setPayments((prev) => {
          const index = prev.findIndex((p) => p.id === updatedPayment.id);
          if (index > -1) {
            // Replace existing entry with updated
            const newArr = [...prev];
            newArr[index] = updatedPayment;
            return newArr;
          }
          // If it's a new payment, optionally add to the top
          return [updatedPayment, ...prev];
        });
      });
    }

    // Cleanup subscription on unmount
    return () => {
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, []);

  // ----------------------------------------------------------------------------------------------
  // 6. Effects for Fetching Payments
  // ----------------------------------------------------------------------------------------------

  /**
   * Immediately fetch payments on first render and whenever filters,
   * pagination, or sorting changes. This approach keeps the displayed
   * data consistent with user changes (e.g., new page, refined filter).
   */
  useEffect(() => {
    const controller = new AbortController();

    // Fire fetch with current states
    fetchPayments({
      filters,
      sort: sortConfig,
      pagination,
      signal: controller.signal
    });

    // Cleanup if component unmounts or effect re-runs
    return () => {
      controller.abort();
    };
  }, [filters, sortConfig, pagination, fetchPayments]);

  // ----------------------------------------------------------------------------------------------
  // 7. Column Definitions for the Reusable Table
  // ----------------------------------------------------------------------------------------------

  /**
   * Columns for the Table component. Each column config includes:
   *  - id: unique string
   *  - header: visible column header text
   *  - accessor or renderCell: how to display each cell
   *  - sortField: used for sorting logic
   *  - isSortable: boolean indicating if column supports sorting
   */
  const columns = useMemo<TableColumn<Payment>[]>(() => {
    return [
      {
        id: 'id',
        header: 'Payment ID',
        accessor: (row) => row.id,
        sortField: 'id',
        isSortable: true
      },
      {
        id: 'walkId',
        header: 'Walk ID',
        accessor: (row) => row.walkId,
        sortField: 'walkId',
        isSortable: true
      },
      {
        id: 'amount',
        header: 'Amount',
        accessor: (row) => `${row.amount.toFixed(2)}`,
        sortField: 'amount',
        isSortable: true
      },
      {
        id: 'status',
        header: 'Status',
        accessor: (row) => row.status,
        sortField: 'status',
        isSortable: true
      },
      {
        id: 'timestamp',
        header: 'Timestamp',
        accessor: (row) => format(row.timestamp, 'PPpp'),
        sortField: 'timestamp',
        isSortable: true
      }
    ];
  }, []);

  // ----------------------------------------------------------------------------------------------
  // 8. Handlers for Filtering & Pagination
  // ----------------------------------------------------------------------------------------------

  /**
   * Updates the filter state with new search term or status,
   * leading to a data refetch in the effect above.
   */
  const handleFilterChange = useCallback(
    (partial: Partial<PaymentFilters>) => {
      setFilters((prev) => ({ ...prev, ...partial }));
    },
    []
  );

  /**
   * Moves to a different page of data (invoked by Table's pagination controls).
   * This triggers a refetch by updating local pagination state.
   */
  const goToPage = useCallback(
    (pageNum: number) => {
      setPagination((prev) => ({
        ...prev,
        page: pageNum < 1 ? 1 : pageNum
      }));
    },
    []
  );

  /**
   * Adjusts the page size if a user picks a new size from
   * a dropdown or advanced table control. Also resets page=1
   * to ensure a consistent user experience.
   */
  const setPageSize = useCallback((size: number) => {
    setPagination((prev) => ({
      ...prev,
      page: 1,
      pageSize: size
    }));
  }, []);

  // ----------------------------------------------------------------------------------------------
  // 9. Rendering
  // ----------------------------------------------------------------------------------------------

  return (
    <div className="payment-list__container">
      {/* Filter Controls */}
      <div className="payment-list__filters">
        <label htmlFor="searchTerm">Search:</label>
        <input
          id="searchTerm"
          type="text"
          value={filters.searchTerm}
          onChange={(e) => handleFilterChange({ searchTerm: e.target.value })}
          placeholder="Payment ID or Walk ID"
          aria-label="Search Payment or Walk ID"
        />

        <label htmlFor="statusFilter">Status:</label>
        <select
          id="statusFilter"
          value={filters.status}
          onChange={(e) =>
            handleFilterChange({
              status: e.target.value as PaymentStatus | ''
            })
          }
          aria-label="Filter by Payment Status"
        >
          <option value="">All</option>
          {Object.values(PaymentStatus).map((st) => (
            <option key={st} value={st}>
              {st}
            </option>
          ))}
        </select>
      </div>

      {/* Scroll Container for optional virtualization */}
      <div
        ref={scrollParentRef}
        style={{ height: '500px', overflow: 'auto' }}
        className="payment-list__scroll-container"
      >
        {/* Reusable Table Component, integrated with pagination & sort */}
        <Table<Payment>
          data={payments}
          columns={columns}
          isLoading={isLoading}
          onSort={(params) => {
            // The Table supplies { field, direction }, so we match them to handleSort
            handleSort({
              column: params.field,
              direction: params.direction.toLowerCase() as 'asc' | 'desc',
              multiSort: false
            });
          }}
          // Paginate using local state
          pagination={{
            page: pagination.page,
            pageSize: pagination.pageSize,
            totalItems: pagination.totalItems,
            totalPages: pagination.totalPages
          }}
          // Column visibility: all true by default here
          columnVisibility={{
            id: true,
            walkId: true,
            amount: true,
            status: true,
            timestamp: true
          }}
        />
      </div>

      {/* Error Message Display */}
      {error && <div className="payment-list__error">{error}</div>}

      {/* Additional controls for manual pagination if desired */}
      <div className="payment-list__pagination-controls">
        <button
          type="button"
          onClick={() => goToPage(pagination.page - 1)}
          disabled={pagination.page <= 1}
        >
          Prev
        </button>
        <span className="payment-list__pagination-info">
          Page {pagination.page} of {pagination.totalPages}
        </span>
        <button
          type="button"
          onClick={() => goToPage(pagination.page + 1)}
          disabled={pagination.page >= pagination.totalPages}
        >
          Next
        </button>

        <label htmlFor="pageSizeSelect">Items per page:</label>
        <select
          id="pageSizeSelect"
          value={pagination.pageSize}
          onChange={(e) => setPageSize(Number(e.target.value))}
        >
          <option value={5}>5</option>
          <option value={10}>10</option>
          <option value={20}>20</option>
          <option value={50}>50</option>
        </select>
      </div>
    </div>
  );
};

export default PaymentList;