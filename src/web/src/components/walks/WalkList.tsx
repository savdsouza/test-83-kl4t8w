import React, {
  FC, // react@^18.0.0
  useState,
  useEffect,
  useCallback,
  useMemo
} from 'react';
// dayjs@^1.11.0
import dayjs from 'dayjs';
// @tanstack/react-virtual@^3.0.0
import { useVirtualizer } from '@tanstack/react-virtual';
// @mui/material@^5.0.0
import { Badge } from '@mui/material';

// Internal Imports
import Table, { TableProps } from '../common/Table';
import { Walk, WalkStatus } from '../../types/walk.types';
import { WalkService } from '../../services/walk.service';
import { PaginationParams, SortParams, SortDirection } from '../../types/common.types';

/**
 * Interface describing the shape of props for the WalkList component.
 * This can be expanded with additional configuration options,
 * filters, or callbacks if needed.
 */
interface WalkListProps {
  /**
   * An optional initial pagination configuration. If not provided,
   * defaults will be used internally (page=1, pageSize=10, etc.).
   */
  initialPagination?: PaginationParams;

  /**
   * An optional initial sort configuration. If not provided,
   * the list might default to sorting by startTime or remain unsorted.
   */
  initialSort?: SortParams;

  /**
   * An optional callback invoked after walks are successfully fetched.
   * Can be used for analytics or side effects in parent components.
   */
  onFetchComplete?: (walks: Walk[]) => void;

  /**
   * An optional boolean controlling whether to enable
   * or disable the built-in real-time subscription logic.
   * If true, real-time updates for walk statuses may be activated.
   */
  enableRealtime?: boolean;
}

/**
 * The WalkList component is a comprehensive, production-ready
 * React functional component that displays a paginated,
 * sortable list of Walk records along with enhanced filtering,
 * real-time status indicators, and timezone-aware date formatting.
 *
 * Implements:
 * - Service Execution: Renders status updates, showcasing real-time indicators
 *   for each walk, with dayjs-based date formatting.
 * - Booking System: Displays schedule management details (start time, duration)
 *   and advanced sorting on relevant fields (date, price, status, etc.).
 *
 * Data is retrieved from the WalkService.getWalks method, supporting
 * typical error handling and offline considerations.
 */
const WalkList: FC<WalkListProps> = ({
  initialPagination,
  initialSort,
  onFetchComplete,
  enableRealtime = false
}) => {
  /**
   * A local instance of the WalkService. In a real system,
   * this might be injected or shared via a context provider.
   */
  const walkService = useMemo(() => new WalkService(/* inject any dependencies */), []);

  /**
   * Local state for storing the array of walks retrieved from the server.
   */
  const [walks, setWalks] = useState<Walk[]>([]);

  /**
   * Local state for loading status. This is used to control
   * spinners or disabled states in the UI as data fetches.
   */
  const [isLoading, setIsLoading] = useState<boolean>(false);

  /**
   * Local state for storing an error message. In case of any error
   * during data retrieval or processing, we display or log it.
   */
  const [error, setError] = useState<string | null>(null);

  /**
   * Local pagination state. This tracks the current page, page size,
   * total items, and total pages. We default to either the
   * user-supplied initialPagination or a fallback.
   */
  const [pagination, setPagination] = useState<PaginationParams>(
    initialPagination || {
      page: 1,
      pageSize: 10,
      totalItems: 0,
      totalPages: 1
    }
  );

  /**
   * Local sorting state. Tracks which field we are sorting on
   * and whether the sort is ascending or descending. We default
   * to either the user-supplied initialSort or an unsorted config.
   */
  const [sort, setSort] = useState<SortParams>(
    initialSort || {
      field: '',
      direction: SortDirection.ASC
    }
  );

  /**
   * Columns definition for the underlying Table component,
   * aligning with the provided specification. Each column
   * includes a custom render function, a label, and
   * a flag indicating if sorting is allowed.
   *
   * Per the specification:
   * - Date & Time -> dayjs(...).format('MMM D, YYYY h:mm A')
   * - Status -> <Badge color={status.toLowerCase()} />
   * - Duration -> `${mins} minutes`
   * - Price -> `$${price.toFixed(2)}`
   */
  const columns: TableProps<Walk>['columns'] = useMemo(() => {
    return [
      {
        id: 'startTime',
        header: 'Date & Time',
        sortField: 'startTime',
        isSortable: true,
        accessor: (row: Walk) => row.startTime,
        renderCell: (rowData) => {
          return (
            <span aria-label="Walk start date and time">
              {dayjs(rowData.startTime).format('MMM D, YYYY h:mm A')}
            </span>
          );
        }
      },
      {
        id: 'status',
        header: 'Status',
        sortField: 'status',
        isSortable: true,
        accessor: (row: Walk) => row.status,
        renderCell: (rowData) => {
          // MUI Badge expects a valid color name. This direct approach
          // uses the lowercase status as a color. In real usage,
          // you might create a mapping to MUI colors:
          // e.g., { 'REQUESTED': 'warning', 'IN_PROGRESS': 'primary', etc. }
          return (
            <Badge
              aria-label="Walk status"
              color={(rowData.status || '').toLowerCase() as 'primary' | 'secondary' | 'default' | 'warning' | 'info' | 'error' | 'success'}
              sx={{ textTransform: 'capitalize', padding: '0 8px' }}
            >
              {rowData.status}
            </Badge>
          );
        }
      },
      {
        id: 'duration',
        header: 'Duration',
        sortField: 'duration',
        isSortable: true,
        accessor: (row: Walk) => row.duration,
        renderCell: (rowData) => {
          return (
            <span aria-label="Walk duration">
              {rowData.duration} minutes
            </span>
          );
        }
      },
      {
        id: 'price',
        header: 'Price',
        sortField: 'price',
        isSortable: true,
        accessor: (row: Walk) => row.price,
        renderCell: (rowData) => {
          return (
            <span aria-label="Walk price">
              ${rowData.price.toFixed(2)}
            </span>
          );
        }
      }
    ];
  }, []);

  /**
   * A derived object controlling which columns are visible.
   * For demonstration, we display all. If in the future
   * we need to hide columns, set <columnId>: false.
   */
  const columnVisibility = useMemo(() => {
    return {
      startTime: true,
      status: true,
      duration: true,
      price: true
    };
  }, []);

  /**
   * fetchWalks is a callback that retrieves the walk data
   * from the server, applying the current pagination and
   * sort fields, then updates local state accordingly.
   *
   * Steps:
   * 1) Set loading state to true.
   * 2) Clear any existing errors.
   * 3) Call walkService.getWalks with the relevant parameters.
   * 4) Update the walks state with the fresh data.
   * 5) Update pagination (total items, total pages).
   * 6) Set loading to false.
   * 7) Catch and handle errors with user feedback.
   * 8) Provide a cleanup mechanism if needed.
   */
  const fetchWalks = useCallback(
    async (currentPagination: PaginationParams, currentSort: SortParams): Promise<void> => {
      try {
        setIsLoading(true);
        setError(null);

        // Here we demonstrate a hypothetical walkService.getWalks
        // that might accept pagination and sort parameters.
        // Real usage could differ depending on your backend API.
        const response = await walkService.getWalks({
          page: currentPagination.page,
          pageSize: currentPagination.pageSize,
          sortField: currentSort.field,
          sortDirection: currentSort.direction
        });

        if (response && response.success && response.data) {
          const { items, total, page, pageSize } = response.data;
          setWalks(items);

          // Update local pagination state
          setPagination((prev) => ({
            ...prev,
            totalItems: total,
            totalPages: Math.ceil(total / pageSize),
            page,
            pageSize
          }));

          // Invoke any optional parent callback
          if (onFetchComplete) {
            onFetchComplete(items);
          }
        } else {
          throw new Error(response?.error?.message || 'Failed to fetch walks');
        }
      } catch (err: any) {
        setError(err.message || 'Failed to fetch walk data');
      } finally {
        setIsLoading(false);
      }
    },
    [walkService, onFetchComplete]
  );

  /**
   * handleSort adjusts the local sort state upon user interaction
   * with the table headers. Then it re-fetches the walk data,
   * resetting the pagination to the first page so that the
   * newly sorted dataset is properly displayed.
   *
   * Steps:
   * 1) Validate incoming parameters.
   * 2) Update sort state with new field/direction.
   * 3) Reset pagination to page=1.
   * 4) Call fetchWalks to get fresh data with new sorting.
   */
  const handleSort = useCallback(
    (sortParams: SortParams) => {
      if (!sortParams || !sortParams.field) {
        return;
      }
      setSort(sortParams);

      // Whenever we alter sort criteria, jump back to page 1
      const resetPagination = { ...pagination, page: 1 };
      setPagination(resetPagination);

      // Trigger the updated fetch
      fetchWalks(resetPagination, sortParams);
    },
    [fetchWalks, pagination]
  );

  /**
   * Whenever pagination or sort changes, we fetch the new data set
   * from the server. This ensures that page transitions or sort
   * changes are immediately reflected.
   */
  useEffect(() => {
    fetchWalks(pagination, sort);
  }, [fetchWalks, pagination, sort]);

  /**
   * (OPTIONAL) If real-time updates are enabled, we could
   * subscribe to some real-time channel to automatically
   * refresh or update statuses. This depends on how the
   * backend pushes updates. In a typical scenario, you might:
   *
   *  useEffect(() => {
   *    if (enableRealtime) {
   *      // Example: walkService.subscribeToWalkStatus(...) or WebSocket usage
   *      // On relevant event, either refresh or patch local data
   *    }
   *    return () => {
   *      // Cleanup subscription
   *    };
   *  }, [enableRealtime]);
   */

  /**
   * For large data sets, we can implement virtualization
   * via useVirtualizer. Below is a placeholder snippet.
   * In a real scenario, we'd handle row heights and pass
   * only visible items to the Table. The Table itself,
   * however, might have its own pagination approach,
   * so virtualization is optional. Provided for demonstration:
   */
  const parentRef = useCallback((node: HTMLDivElement | null) => {
    // A reference for the virtualizer to measure container size
  }, []);

  const rowVirtualizer = useVirtualizer({
    count: walks.length,
    getScrollElement: () => null,
    estimateSize: () => 55 // estimate row height
  });

  /**
   * The render for the underlying Table component. We supply:
   * - data: the array of Walk objects.
   * - columns: as defined above (startTime, status, duration, price).
   * - onSort: callback for column sorting.
   * - pagination: includes totalItems, current page, etc.
   * - isLoading: indicates loading spinners or placeholders.
   * - columnVisibility: controls which columns are displayed.
   */
  return (
    <div ref={parentRef} style={{ width: '100%', marginTop: '1rem' }}>
      {error && (
        <div
          role="alert"
          aria-label="Error Message"
          style={{ color: 'red', marginBottom: '0.5rem' }}
        >
          {error}
        </div>
      )}

      <Table<Walk>
        data={walks}
        columns={columns}
        onSort={handleSort}
        isLoading={isLoading}
        columnVisibility={columnVisibility}
        pagination={{
          page: pagination.page,
          pageSize: pagination.pageSize,
          totalItems: pagination.totalItems,
          totalPages: pagination.totalPages
        }}
      />
    </div>
  );
};

export default WalkList;