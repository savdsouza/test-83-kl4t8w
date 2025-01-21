/**
 * @file Pagination.tsx
 * @description A reusable, production-ready pagination component that provides accessible
 * navigation controls for paginated data displays. This component supports customizable
 * page sizes, fully responsive layout, RTL handling, keyboard navigation, and optional
 * internationalization strings for labels and hints. It leverages an internal
 * usePagination hook for managing pagination state and calculations, while also syncing
 * changes to and from parent props via callback handlers. 
 */

// -------------------------------------------------------------------------------------------------
// External Imports (with version comments)
// react@^18.0.0
// classnames@^2.3.2
// -------------------------------------------------------------------------------------------------
import React, {
  useMemo,
  useCallback,
  useEffect,
  useRef,
  KeyboardEvent,
  ChangeEvent
} from 'react';
import classNames from 'classnames';

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import usePagination from '../../hooks/usePagination'; // Custom pagination logic
import { PaginationParams } from '../../types/common.types'; // For typed reference to page + pageSize

// -------------------------------------------------------------------------------------------------
// i18n Interface
// -------------------------------------------------------------------------------------------------
/**
 * @interface PaginationI18n
 * @description Defines optional strings for pagination controls, enabling translation
 * or customization of button labels, page size labels, and more.
 */
export interface PaginationI18n {
  /**
   * Label for the "Previous" page button. Defaults to "Previous" if not provided.
   */
  previousLabel?: string;

  /**
   * Label for the "Next" page button. Defaults to "Next" if not provided.
   */
  nextLabel?: string;

  /**
   * Label for the page size dropdown. Defaults to "Items per page" if not provided.
   */
  pageSizeLabel?: string;

  /**
   * (Optional) Label or text used to indicate "Page" in aria announcements or page readouts.
   * Defaults to "Page".
   */
  pageLabel?: string;

  /**
   * (Optional) Label or text used to announce the total number of pages (e.g., "of").
   */
  ofLabel?: string;
}

// -------------------------------------------------------------------------------------------------
// Component Props
// -------------------------------------------------------------------------------------------------
/**
 * @interface PaginationProps
 * @description Props interface for the Pagination component. This interface declares all
 * required and optional fields for configuring the pagination, including total items,
 * currently active page, page size, callbacks for external state management, accessibility
 * attributes, and i18n support.
 */
export interface PaginationProps {
  /**
   * The total number of items in the dataset. Determines the maximum page count by
   * combining with pageSize.
   */
  totalItems: number;

  /**
   * The 1-based index of the currently active page. This prop is used for both initial
   * and controlled synchronization of the pagination state.
   */
  currentPage: number;

  /**
   * The number of items displayed per page. This prop is used for both initial and
   * controlled synchronization of the pagination state.
   */
  pageSize: number;

  /**
   * Callback function invoked whenever the page changes. The function receives the
   * updated 1-based page number as an argument.
   *
   * @param page - The new page number
   */
  onPageChange: (page: number) => void;

  /**
   * Callback function invoked whenever the page size changes. Receives the updated
   * page size as an argument.
   *
   * @param pageSize - The new page size
   */
  onPageSizeChange: (pageSize: number) => void;

  /**
   * An optional additional CSS class name for styling or theme integration.
   */
  className?: string;

  /**
   * If set to true, all pagination controls will be rendered in a disabled state,
   * preventing user interaction.
   */
  disabled?: boolean;

  /**
   * Provides an ARIA label for the navigation container, improving accessibility
   * for assistive technologies.
   */
  ariaLabel?: string;

  /**
   * An optional set of internationalization strings for customizing text labels.
   * By default, English labels are provided.
   */
  i18n?: PaginationI18n;
}

// -------------------------------------------------------------------------------------------------
// Default Internationalization Text
// -------------------------------------------------------------------------------------------------
const DEFAULT_I18N: Required<PaginationI18n> = {
  previousLabel: 'Previous',
  nextLabel: 'Next',
  pageSizeLabel: 'Items per page',
  pageLabel: 'Page',
  ofLabel: 'of'
};

// -------------------------------------------------------------------------------------------------
// Pagination Component Definition
// -------------------------------------------------------------------------------------------------
/**
 * @component Pagination
 * @description A fully accessible and responsive pagination component that uses
 * our custom usePagination hook to provide navigation controls for any paged dataset.
 * It synchronizes with external props for controlled behavior, calling onPageChange
 * and onPageSizeChange to keep the parent in sync. Additionally, it handles keyboard
 * navigation, focuses management, and offers a default set of page size options.
 */
const Pagination: React.FC<PaginationProps> = ({
  totalItems,
  currentPage,
  pageSize,
  onPageChange,
  onPageSizeChange,
  className = '',
  disabled = false,
  ariaLabel,
  i18n = {}
}) => {
  // Merge user-provided i18n strings with defaults.
  const labels = useMemo<Required<PaginationI18n>>(
    () => ({
      ...DEFAULT_I18N,
      ...i18n
    }),
    [i18n]
  );

  // We define some default page size options for the dropdown selector.
  // These can be enhanced or swapped with custom-chosen sizes if needed.
  const DEFAULT_PAGE_SIZE_OPTIONS = useRef<number[]>([5, 10, 20, 50, 100]);

  // -----------------------------------------------------------------------------------------------
  // Step 1: Use the custom hook to manage local pagination logic.
  // We initialize it with the parent's currentPage/pageSize, but we add an effect afterwards
  // to keep them in sync if the parent changes the props externally.
  // -----------------------------------------------------------------------------------------------
  const {
    currentPage: localPage,
    pageSize: localPageSize,
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
  } = usePagination(totalItems, currentPage, pageSize);

  // -----------------------------------------------------------------------------------------------
  // Step 2a: Keep local page in sync with parent prop changes.
  // If the parent has updated currentPage and it differs from the local page,
  // we adjust the local page accordingly.
  // -----------------------------------------------------------------------------------------------
  useEffect(() => {
    if (currentPage !== localPage) {
      goToPage(currentPage);
    }
  }, [currentPage, localPage, goToPage]);

  // -----------------------------------------------------------------------------------------------
  // Step 2b: Keep local pageSize in sync with parent prop changes.
  // -----------------------------------------------------------------------------------------------
  useEffect(() => {
    if (pageSize !== localPageSize) {
      setPageSize(pageSize);
    }
  }, [pageSize, localPageSize, setPageSize]);

  // -----------------------------------------------------------------------------------------------
  // Step 3a: Notify parent when localPage changes, so external state remains consistent.
  // -----------------------------------------------------------------------------------------------
  useEffect(() => {
    if (onPageChange && typeof onPageChange === 'function') {
      if (localPage !== currentPage) {
        onPageChange(localPage);
      }
    }
  }, [localPage, onPageChange, currentPage]);

  // -----------------------------------------------------------------------------------------------
  // Step 3b: Notify parent when localPageSize changes, so external state remains consistent.
  // -----------------------------------------------------------------------------------------------
  useEffect(() => {
    if (onPageSizeChange && typeof onPageSizeChange === 'function') {
      if (localPageSize !== pageSize) {
        onPageSizeChange(localPageSize);
      }
    }
  }, [localPageSize, onPageSizeChange, pageSize]);

  // -----------------------------------------------------------------------------------------------
  // Step 4: Create a memoized structure referencing the pagination parameters for debugging
  // or advanced usage. We also compute the total number of pages from the hook for clarity.
  // -----------------------------------------------------------------------------------------------
  const paginationParams: PaginationParams = useMemo(() => {
    return {
      page: localPage,
      pageSize: localPageSize,
      totalItems,
      totalPages
    };
  }, [localPage, localPageSize, totalItems, totalPages]);

  // -----------------------------------------------------------------------------------------------
  // Step 5: Build page navigation array with ellipsis to handle large numbers of pages.
  // For example, if we have more than 7 pages, we show the first page, two around the active page,
  // a last page, and ellipses in between appropriately.
  // -----------------------------------------------------------------------------------------------
  const visiblePages = useMemo(() => {
    const pages: (number | string)[] = [];
    const maxVisible = 7;

    // If totalPages is less or equal to maxVisible, display them all.
    if (totalPages <= maxVisible) {
      for (let i = 1; i <= totalPages; i += 1) {
        pages.push(i);
      }
      return pages;
    }

    // If we have many pages, we compute a short window around localPage.
    let start = localPage - 2;
    let end = localPage + 2;

    // Ensure the window is within valid boundaries.
    if (start < 1) {
      end += Math.abs(start) + 1;
      start = 1;
    }
    if (end > totalPages) {
      start -= end - totalPages;
      end = totalPages;
    }

    // Always push the first page.
    pages.push(1);

    // Insert ellipsis if there's a gap after page 1 and before the start window.
    if (start > 2) {
      pages.push('...');
    }

    // Fill in the range from start to end for the middle window.
    for (let i = start; i <= end; i += 1) {
      if (i > 1 && i < totalPages) {
        pages.push(i);
      }
    }

    // Insert ellipsis if there's a gap after the middle window and before the last page.
    if (end < totalPages - 1) {
      pages.push('...');
    }

    // Always push the last page.
    pages.push(totalPages);

    return pages;
  }, [localPage, totalPages]);

  // -----------------------------------------------------------------------------------------------
  // Step 6: Keyboard navigation handler for easy left/right arrow usage on the pagination container.
  // -----------------------------------------------------------------------------------------------
  const onKeyDownPagination = useCallback(
    (e: KeyboardEvent<HTMLDivElement>) => {
      if (disabled) return;
      if (e.key === 'ArrowLeft') {
        e.preventDefault();
        if (!isFirstPage) previousPage();
      } else if (e.key === 'ArrowRight') {
        e.preventDefault();
        if (!isLastPage) nextPage();
      }
    },
    [disabled, isFirstPage, isLastPage, previousPage, nextPage]
  );

  // -----------------------------------------------------------------------------------------------
  // Step 7: UI Handlers for page changes
  // -----------------------------------------------------------------------------------------------
  const handlePageClick = useCallback(
    (targetPage: number) => {
      if (!disabled) {
        goToPage(targetPage);
      }
    },
    [disabled, goToPage]
  );

  // -----------------------------------------------------------------------------------------------
  // Step 8: Handler for page size dropdown changes
  // -----------------------------------------------------------------------------------------------
  const handlePageSizeChange = useCallback(
    (e: ChangeEvent<HTMLSelectElement>) => {
      if (!disabled) {
        const newSize = parseInt(e.target.value, 10);
        setPageSize(newSize);
      }
    },
    [disabled, setPageSize]
  );

  // -----------------------------------------------------------------------------------------------
  // Step 9: Compose classes for container, buttons, etc.
  // -----------------------------------------------------------------------------------------------
  const rootClass = useMemo(
    () =>
      classNames('pagination-container', className, {
        'pagination-disabled': disabled
      }),
    [className, disabled]
  );

  // -----------------------------------------------------------------------------------------------
  // Step 10: Render the pagination UI with extensive accessibility features.
  // This includes an outer navigation region, ARIA labels, labeled controls,
  // previous/next buttons, numeric page links, ellipses, and a page size selector.
  // -----------------------------------------------------------------------------------------------
  return (
    <nav
      // Provide ARIA attributes for better screen reader navigation
      role="navigation"
      aria-label={ariaLabel || 'Pagination Navigation'}
      className={rootClass}
      onKeyDown={onKeyDownPagination}
      tabIndex={0}
    >
      {/* Page Size Selector (dropdown) */}
      <div className="pagination-size-selector">
        <label htmlFor="pageSizeSelect" className="sr-only">
          {labels.pageSizeLabel}
        </label>
        <select
          id="pageSizeSelect"
          aria-label={labels.pageSizeLabel}
          value={localPageSize}
          onChange={handlePageSizeChange}
          disabled={disabled}
        >
          {DEFAULT_PAGE_SIZE_OPTIONS.current.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
        {/* We can optionally render a textual label for clarity or a visually hidden label */}
        <span className="page-size-label">{labels.pageSizeLabel}</span>
      </div>

      {/* Page Information: e.g. "Page 3 of 10" */}
      <div className="pagination-info" aria-hidden={true}>
        <span>
          {labels.pageLabel} {localPage}
        </span>
        <span className="pagination-of-label">
          {labels.ofLabel} {totalPages}
        </span>
      </div>

      {/* Previous Page Button */}
      <button
        type="button"
        onClick={previousPage}
        disabled={disabled || isFirstPage}
        aria-label={labels.previousLabel}
        className="pagination-previous"
      >
        {labels.previousLabel}
      </button>

      {/* Page Number Items with Ellipses */}
      <ul className="pagination-pages" aria-label="Pages">
        {visiblePages.map((p, index) => {
          if (typeof p === 'string') {
            // Render ellipsis
            return (
              <li key={`ellipsis-${index}`} className="pagination-ellipsis">
                <span aria-hidden="true">…</span>
              </li>
            );
          } else {
            // Render page number button
            const pageNumber = p;
            const isActive = pageNumber === localPage;
            return (
              <li key={pageNumber} className="pagination-page-item">
                <button
                  type="button"
                  className={classNames('pagination-page-btn', {
                    'is-active': isActive
                  })}
                  disabled={disabled}
                  aria-current={isActive ? 'page' : undefined}
                  aria-label={`${labels.pageLabel} ${pageNumber}`}
                  onClick={() => handlePageClick(pageNumber)}
                >
                  {pageNumber}
                </button>
              </li>
            );
          }
        })}
      </ul>

      {/* Next Page Button */}
      <button
        type="button"
        onClick={nextPage}
        disabled={disabled || isLastPage}
        aria-label={labels.nextLabel}
        className="pagination-next"
      >
        {labels.nextLabel}
      </button>

      {/* Hidden debug block or reference to paginationParams (optional) */}
      <div className="sr-only" aria-hidden="true">
        {/* This region is visually hidden but could be used by screen readers or debugging. */}
        {JSON.stringify(paginationParams)}
      </div>
    </nav>
  );
};

// -------------------------------------------------------------------------------------------------
// Export
// -------------------------------------------------------------------------------------------------
export default Pagination;