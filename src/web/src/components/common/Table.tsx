/**
 * @file Table.tsx
 * @description A highly performant, accessible, and type-safe reusable table component.
 * Supports sorting, pagination, column visibility, and customizable rendering via
 * comprehensive TypeScript generics. Integrates with usePagination for optimal
 * client-side pagination management and uses ARIA attributes for accessibility.
 */

// ---------------------------------------------------------
// External Imports (with library version comments)
// ---------------------------------------------------------
// react@^18.0.0
import { FC, ReactNode, useState, useCallback, useMemo, memo } from 'react';
// classnames@^2.3.2
import classNames from 'classnames';

// ---------------------------------------------------------
// Internal Imports
// ---------------------------------------------------------
import {
  PaginationParams,
  SortParams,
  SortDirection,
  ColumnVisibility
} from '../../types/common.types';
import usePagination from '../../hooks/usePagination';

// ---------------------------------------------------------
// Local Types
// ---------------------------------------------------------

/**
 * A type defining the possible ways to specify what data each column will render.
 * This can be either:
 *   - A key of the generic type T (e.g., "name" if T has a property name)
 *   - A function that receives the entire row and returns any ReactNode
 */
type ColumnAccessor<T> = keyof T | ((row: T) => ReactNode);

/**
 * The structure of each column definition within the table,
 * allowing for both simple and advanced use cases.
 */
export interface ColumnDef<T> {
  /**
   * A unique identifier for the column, used internally for
   * visibility toggles and keys. Must be unique across all columns.
   */
  id: string;

  /**
   * The label text (or ReactNode) for the column header.
   * This text is displayed in the table header cell.
   */
  header: string | ReactNode;

  /**
   * Optional property key or function describing how to retrieve
   * the cell data from a row object of type T.
   */
  accessor?: ColumnAccessor<T>;

  /**
   * An optional custom rendering function for the body cells.
   * If provided, this function will be used instead of the accessor
   * to display cell data, enabling advanced formatting or nested views.
   */
  renderCell?: (rowData: T, rowIndex: number) => ReactNode;

  /**
   * An optional property indicating the field name used for sorting.
   * Must match SortParams.field when sorting is applied on this column.
   */
  sortField?: string;

  /**
   * If set to true, enables interactive sorting via this column.
   * Corresponds to any custom logic in handleSort or an API call.
   */
  isSortable?: boolean;
}

/**
 * Props definition for the Table component, exposing
 * advanced configuration including data, columns,
 * sorting, pagination, and column visibility.
 */
export interface TableProps<T> {
  /**
   * The array of generic data objects to render as rows.
   * Requirements:
   *  - Must be of consistent shape matching columns' definitions.
   */
  data: T[];

  /**
   * An array of column definitions describing how each column
   * should display and (optionally) sort data.
   */
  columns: ColumnDef<T>[];

  /**
   * Callback invoked when the user triggers a sort action.
   * Supplies a SortParams object indicating the field and direction.
   */
  onSort: (params: SortParams) => void;

  /**
   * Contains all pagination parameters, including the total items,
   * current page, page size, and total pages. Used internally
   * with the usePagination hook.
   */
  pagination: PaginationParams;

  /**
   * Indicates whether the table is in a loading state (e.g., data
   * is being fetched). This can be used to display loading skeletons
   * or spinners.
   */
  isLoading: boolean;

  /**
   * Object describing visibility for each column by column ID,
   * enabling show/hide functionality without fully unmounting
   * or losing column definitions.
   */
  columnVisibility: ColumnVisibility;
}

// ---------------------------------------------------------
// Table Component
// ---------------------------------------------------------

/**
 * A highly configurable and memoized table component providing:
 *  - Sorting with visual/keyboard indicators
 *  - Client-side pagination using usePagination
 *  - Column visibility toggling
 *  - Accessible markup (ARIA attributes, keyboard handlers)
 *  - Type-safe generics for flexible yet robust usage
 *
 * @typeParam T - The generic type describing the shape of each row in the data array.
 */
const Table = <T,>(props: TableProps<T>): JSX.Element => {
  const {
    data,
    columns,
    onSort,
    pagination,
    isLoading,
    columnVisibility
  } = props;

  // -------------------------------------------------------
  // Local Sorting State
  // -------------------------------------------------------
  /**
   * Stores local sorting state as a SortParams object:
   *  - field: string (matches column.sortField)
   *  - direction: SortDirection (ASC or DESC)
   */
  const [sortState, setSortState] = useState<SortParams>({
    field: '',
    direction: SortDirection.ASC
  });

  // -------------------------------------------------------
  // Pagination Initialization
  // -------------------------------------------------------
  /**
   * The usePagination hook manages page boundaries, indexes,
   * and includes navigation functions. We initialize it with
   * pagination.totalItems, pagination.page, pagination.pageSize
   * in order to handle slicing of the dataset.
   */
  const {
    currentPage,
    pageSize,
    totalPages,
    goToPage,
    nextPage,
    previousPage,
    setPageSize,
    startIndex,
    endIndex,
    hasNextPage,
    hasPreviousPage,
    isFirstPage,
    isLastPage
  } = usePagination(pagination.totalItems, pagination.page, pagination.pageSize);

  // -------------------------------------------------------
  // Data Slicing
  // -------------------------------------------------------
  /**
   * Compute the sliced data array for display in the table body
   * based on the pagination indices. In real use cases, data might
   * already be paged by a server, but this approach can handle
   * client-side slicing if needed.
   */
  const visibleData = useMemo<T[]>(() => {
    return data.slice(startIndex, endIndex + 1);
  }, [data, startIndex, endIndex]);

  // -------------------------------------------------------
  // handleSort: Optimized Sorting Handler
  // -------------------------------------------------------
  /**
   * React hook-based callback that handles toggling the sort state.
   * 1. Checks if column is sortable (isSortable).
   * 2. Determines if sorting on the same field; toggles direction.
   * 3. Updates local sort state.
   * 4. Invokes onSort callback with new SortParams.
   * @param field - The field string used for sorting, typically column.sortField
   * @param isSortable - Whether the current column can be sorted
   */
  const handleSort = useCallback(
    (field: string, isSortable?: boolean) => {
      if (!field || !isSortable) {
        return;
      }
      setSortState((prev) => {
        let newDirection: SortDirection = SortDirection.ASC;

        // If user clicks on the same field, toggle direction
        if (prev.field === field) {
          newDirection =
            prev.direction === SortDirection.ASC
              ? SortDirection.DESC
              : SortDirection.ASC;
        }

        const updated = { field, direction: newDirection };
        onSort(updated);
        return updated;
      });
    },
    [onSort]
  );

  // -------------------------------------------------------
  // renderHeader: Renders Accessible Table Header
  // -------------------------------------------------------
  /**
   * Provides a memoized approach for generating a <th> element
   * that includes:
   *  - ARIA-sort attributes for screen readers
   *  - Keyboard events for toggling sort
   *  - Visual cues (e.g., sort arrows) indicating sort direction
   * @param column - The column definition for which we render the header
   * @param currentSort - The current sort parameters (field + direction)
   */
  const renderHeader = useCallback(
    (column: ColumnDef<T>, currentSort: SortParams): ReactNode => {
      const { header, sortField, isSortable } = column;

      // Determine if this column is actively sorted
      const isActiveSort = sortField && sortField === currentSort.field;
      let ariaSort: 'none' | 'ascending' | 'descending' = 'none';

      if (isActiveSort && currentSort.direction === SortDirection.ASC) {
        ariaSort = 'ascending';
      } else if (isActiveSort && currentSort.direction === SortDirection.DESC) {
        ariaSort = 'descending';
      }

      // Determine a visual sort indicator for the UI
      const sortIndicator = isActiveSort
        ? currentSort.direction === SortDirection.ASC
          ? '▲'
          : '▼'
        : '';

      // Compose classes for header cell
      const thClassName = classNames('table__header', {
        'table__header--sortable': isSortable,
        'table__header--active-sort': isActiveSort
      });

      /**
       * Handler for keyboard-based sorting activation
       * (e.g., pressing Enter/Space on a sortable header).
       */
      const onKeyDown = (e: React.KeyboardEvent) => {
        if (!isSortable) return;
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          handleSort(sortField || '', isSortable);
        }
      };

      return (
        <th
          key={column.id}
          scope="col"
          className={thClassName}
          aria-sort={ariaSort}
          tabIndex={isSortable ? 0 : undefined}
          onClick={() => handleSort(sortField || '', isSortable)}
          onKeyDown={onKeyDown}
        >
          <span className="table__header-label">
            {header}
            {isSortable && sortIndicator && (
              <span className="table__sort-indicator">{sortIndicator}</span>
            )}
          </span>
        </th>
      );
    },
    [handleSort]
  );

  // -------------------------------------------------------
  // Rendering the Table Markup
  // -------------------------------------------------------
  return (
    <div
      className={classNames('table__container', {
        'table__container--loading': isLoading
      })}
      role="table"
      aria-busy={isLoading}
      aria-rowcount={data.length}
      aria-colcount={columns.length}
    >
      {/* Table Element */}
      <table className="table" role="grid">
        <thead>
          <tr>
            {columns.map((col) => {
              // Check if this column is marked visible from columnVisibility
              const isVisible = columnVisibility[col.id] !== false;
              if (!isVisible) {
                return null;
              }
              return renderHeader(col, sortState);
            })}
          </tr>
        </thead>

        {/* Table Body */}
        <tbody>
          {visibleData.map((rowItem, rowIndex) => (
            <tr key={`row-${rowIndex}`} className="table__row">
              {columns.map((col) => {
                // Check column visibility
                const isVisible = columnVisibility[col.id] !== false;
                if (!isVisible) {
                  return null;
                }

                // Evaluate cell content
                let cellContent: ReactNode = null;
                if (col.renderCell) {
                  cellContent = col.renderCell(rowItem, rowIndex);
                } else if (col.accessor) {
                  if (typeof col.accessor === 'function') {
                    cellContent = col.accessor(rowItem);
                  } else {
                    cellContent = (rowItem as any)[col.accessor];
                  }
                }
                return (
                  <td key={`${col.id}-col-${rowIndex}`} className="table__cell">
                    {cellContent}
                  </td>
                );
              })}
            </tr>
          ))}

          {/* Loading or Empty State */}
          {isLoading && visibleData.length === 0 && (
            <tr>
              <td colSpan={columns.length} className="table__cell--empty">
                Loading...
              </td>
            </tr>
          )}
          {!isLoading && visibleData.length === 0 && (
            <tr>
              <td colSpan={columns.length} className="table__cell--empty">
                No records to display.
              </td>
            </tr>
          )}
        </tbody>

        {/* Optional Table Footer / Pagination Controls */}
        <tfoot>
          <tr>
            <td colSpan={columns.length}>
              <div className="table__footer-pagination">
                {/* Example pagination controls using the usePagination result */}
                <button
                  type="button"
                  disabled={!hasPreviousPage}
                  onClick={previousPage}
                  aria-label="Go to previous page"
                >
                  Prev
                </button>
                <span className="table__pagination-info">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  type="button"
                  disabled={!hasNextPage}
                  onClick={nextPage}
                  aria-label="Go to next page"
                >
                  Next
                </button>
                <label htmlFor="pageSize" className="table__page-size-label">
                  Items per page:
                </label>
                <select
                  id="pageSize"
                  value={pageSize}
                  onChange={(e) => {
                    const newSize = parseInt(e.target.value, 10);
                    setPageSize(newSize);
                  }}
                >
                  <option value={5}>5</option>
                  <option value={10}>10</option>
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                </select>
                <button
                  type="button"
                  onClick={() => goToPage(1)}
                  disabled={isFirstPage}
                  aria-label="Go to first page"
                >
                  First
                </button>
                <button
                  type="button"
                  onClick={() => goToPage(totalPages)}
                  disabled={isLastPage}
                  aria-label="Go to last page"
                >
                  Last
                </button>
              </div>
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  );
};

// ---------------------------------------------------------
// Memoized Export
// ---------------------------------------------------------
/**
 * The default export is a memoized version of the Table component,
 * minimizing unnecessary re-renders. This ensures high performance
 * even with large datasets or frequent prop changes.
 */
export default memo(Table) as <T>(props: TableProps<T>) => JSX.Element;