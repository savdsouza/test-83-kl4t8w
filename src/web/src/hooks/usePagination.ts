/**
 * @file usePagination.ts
 * @description A custom React hook that provides comprehensive pagination functionality
 * with optimized performance, robust boundary condition checks, and type safety for
 * managing paginated data displays within the application.
 */

//
// External Imports (with library version comment)
// react@^18.0.0
//
import { useState, useCallback, useMemo } from 'react';

//
// Internal Imports
//
import { PaginationParams } from '../types/common.types';

/**
 * The shape of the value returned by the usePagination hook.
 */
interface UsePaginationResult {
  /**
   * The current page number, maintained as a 1-based index.
   */
  currentPage: number;

  /**
   * The number of items displayed per page. Changing this value
   * recalculates boundary data and total pages.
   */
  pageSize: number;

  /**
   * The total number of pages derived from the total items and current page size.
   */
  totalPages: number;

  /**
   * Memoized function to jump to a specific page. Automatically clamps
   * values to valid boundaries (1 to totalPages).
   * @param pageNumber The requested page number (1-based).
   */
  goToPage: (pageNumber: number) => void;

  /**
   * Memoized function to advance the pagination state to the next page.
   * Safely clamps to the maximum valid page if invoked on the last page.
   */
  nextPage: () => void;

  /**
   * Memoized function to regress the pagination state to the previous page.
   * Safely clamps to the minimum valid page if invoked on the first page.
   */
  previousPage: () => void;

  /**
   * Memoized function to update the number of items per page.
   * This recalculates the current page if it exceeds totalPages.
   * @param newSize The new number of items per page.
   */
  setPageSize: (newSize: number) => void;

  /**
   * The computed starting index of items for the current page (0-based).
   */
  startIndex: number;

  /**
   * The computed ending index (inclusive) of items for the current page (0-based).
   * If the current page does not fully fill the page size, this index is adjusted.
   */
  endIndex: number;

  /**
   * A memoized boolean indicating whether another page follows the current page.
   */
  hasNextPage: boolean;

  /**
   * A memoized boolean indicating whether a previous page exists before the current page.
   */
  hasPreviousPage: boolean;

  /**
   * A memoized boolean that resolves to true when the current page is the first page.
   */
  isFirstPage: boolean;

  /**
   * A memoized boolean that resolves to true when the current page is the final page.
   */
  isLastPage: boolean;
}

/**
 * A comprehensive React hook that manages pagination state,
 * providing page navigation functions, boundary checks, and
 * performance optimizations. The result offers both calculated
 * indices for item slicing and metadata for controlling
 * navigation in a paginated interface.
 *
 * @param totalItems The total number of items across all pages.
 * @param initialPage The default initial page for the pagination state (1-based).
 * @param initialPageSize The default initial number of items displayed per page.
 * @returns An object containing pagination state, navigation functions,
 * and derived calculations such as boundary indices and helper booleans.
 */
export default function usePagination(
  totalItems: number,
  initialPage: number,
  initialPageSize: number
): UsePaginationResult {
  // STEP 1: Validate input parameters for valid ranges and types.
  //         We throw errors if input parameters mismatch expectations to
  //         preserve type safety and robust runtime checks.
  if (Number.isNaN(totalItems) || totalItems < 0) {
    throw new Error(
      `[usePagination] Invalid totalItems: Expected a non-negative number, received ${totalItems}.`
    );
  }
  if (Number.isNaN(initialPage) || initialPage < 1) {
    throw new Error(
      `[usePagination] Invalid initialPage: Expected a page >= 1, received ${initialPage}.`
    );
  }
  if (Number.isNaN(initialPageSize) || initialPageSize < 1) {
    throw new Error(
      `[usePagination] Invalid initialPageSize: Expected pageSize >= 1, received ${initialPageSize}.`
    );
  }

  // STEP 2: Initialize state for currentPage and pageSize with validated inputs.
  //         Using React's useState, we store the current page as 1-based
  //         and the pageSize as a positive integer.
  const [currentPage, setCurrentPage] = useState<number>(initialPage);
  const [pageSize, setInternalPageSize] = useState<number>(initialPageSize);

  // STEP 3: Calculate totalPages using a memo to prevent redundant calculations
  //         on every render. Ensures performance optimization.
  const totalPages = useMemo<number>(() => {
    // We define a minimum of 1 page even if totalItems is zero, ensuring
    // that the pagination UI always has at least one valid page.
    const computedTotal = Math.ceil(totalItems / pageSize);
    return computedTotal < 1 ? 1 : computedTotal;
  }, [totalItems, pageSize]);

  /**
   * STEP 3b (Optional): Construct a local PaginationParams object
   * using PaginationParams to ensure type safety and reference
   * the relevant interface from our internal types. This data can
   * be used for internal consistency or debugging. We do not
   * explicitly return this object but rely on it as a typed structure.
   */
  const paginationParams: PaginationParams = useMemo(() => {
    return {
      page: currentPage,
      pageSize: pageSize,
      totalItems,
      totalPages
    };
  }, [currentPage, pageSize, totalItems, totalPages]);

  // STEP 4: Calculate startIndex and endIndex using memos with boundary checks.
  //         These indices are commonly used for slicing data arrays.
  const startIndex = useMemo<number>(() => {
    return (currentPage - 1) * pageSize;
  }, [currentPage, pageSize]);

  const endIndex = useMemo<number>(() => {
    // The final index is clamped to totalItems - 1 so we never exceed
    // the array bounds if fewer items are available.
    const potentialEnd = startIndex + pageSize - 1;
    return potentialEnd >= totalItems ? totalItems - 1 : potentialEnd;
  }, [startIndex, pageSize, totalItems]);

  // STEP 5: Create memoized navigation functions with boundary checks.
  //         We use useCallback to ensure the references only change
  //         when necessary, improving performance in re-renders.

  /**
   * Moves to the specified page, clamping the number within valid limits.
   * @param pageNumber The desired page to navigate to (1-based).
   */
  const goToPage = useCallback(
    (pageNumber: number) => {
      if (Number.isNaN(pageNumber) || pageNumber < 1) {
        setCurrentPage(1);
      } else if (pageNumber > totalPages) {
        setCurrentPage(totalPages);
      } else {
        setCurrentPage(pageNumber);
      }
    },
    [totalPages]
  );

  /**
   * Advances to the next page if possible, otherwise clamping to the last page.
   */
  const nextPage = useCallback(() => {
    setCurrentPage((prevPage) => {
      const next = prevPage + 1;
      return next > totalPages ? totalPages : next;
    });
  }, [totalPages]);

  /**
   * Moves back to the previous page if possible, otherwise clamping to the first page.
   */
  const previousPage = useCallback(() => {
    setCurrentPage((prevPage) => {
      const prev = prevPage - 1;
      return prev < 1 ? 1 : prev;
    });
  }, []);

  /**
   * Updates the page size while recalculating and clamping the current page
   * if the new page size changes the total pages below the existing current page.
   * @param newSize The new number of items per page.
   */
  const setPageSize = useCallback(
    (newSize: number) => {
      if (Number.isNaN(newSize) || newSize < 1) {
        throw new Error(
          `[usePagination] setPageSize: Invalid page size provided: ${newSize}. Must be >= 1.`
        );
      }
      setInternalPageSize(newSize);
      // Immediately clamp currentPage if totalPages changes beyond new boundary.
      setCurrentPage((prevPage) => {
        const newTotal = Math.ceil(totalItems / newSize);
        const boundedTotal = newTotal < 1 ? 1 : newTotal;
        return prevPage > boundedTotal ? boundedTotal : prevPage;
      });
    },
    [totalItems]
  );

  // STEP 6: Memoize helper boolean flags for page status, ensuring
  //         stable identities for usage across components.
  const hasNextPage = useMemo<boolean>(() => currentPage < totalPages, [currentPage, totalPages]);
  const hasPreviousPage = useMemo<boolean>(() => currentPage > 1, [currentPage]);
  const isFirstPage = useMemo<boolean>(() => currentPage === 1, [currentPage]);
  const isLastPage = useMemo<boolean>(() => currentPage === totalPages, [currentPage, totalPages]);

  // STEP 7: Return comprehensive pagination state and control functions.
  return {
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
  };
}