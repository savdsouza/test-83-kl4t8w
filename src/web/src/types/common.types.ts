import { ApiResponse } from './api.types'; // Internal import for generic API response handling

/**
 * Represents a geographic coordinate pair, ensuring type safety
 * for latitude/longitude usage in location tracking, mapping
 * features, and distance calculations throughout the application.
 */
export interface Coordinates {
  /**
   * The latitude value, expressed in decimal degrees (WGS84).
   * Positive values indicate the northern hemisphere,
   * while negative values indicate the southern hemisphere.
   */
  latitude: number;

  /**
   * The longitude value, expressed in decimal degrees (WGS84).
   * Positive values indicate the eastern hemisphere,
   * while negative values indicate the western hemisphere.
   */
  longitude: number;
}

/**
 * Defines a range between two date/time values, used for
 * scheduling, booking, and time-based filtering. The startTime
 * is expected to precede endTime in most cases, though validation
 * may occur at higher application layers to ensure correctness.
 */
export interface TimeRange {
  /**
   * A Date object denoting the start of the range,
   * typically used for comprehending scheduling windows.
   */
  startTime: Date;

  /**
   * A Date object denoting the end of the range,
   * forming a closed interval for time-based searches.
   */
  endTime: Date;
}

/**
 * Provides full pagination details for any paged data set
 * throughout the application. Integrates with local or remote
 * pagination controls to navigate large data sets.
 */
export interface PaginationParams {
  /**
   * The currently viewed page index, where 1 typically
   * denotes the first page (or 0, depending on convention).
   */
  page: number;

  /**
   * The maximum number of items included in each page.
   */
  pageSize: number;

  /**
   * The total number of items in the entire result set
   * spanning all pages.
   */
  totalItems: number;

  /**
   * The total number of pages, typically calculated by
   * totalItems / pageSize (rounded up).
   */
  totalPages: number;
}

/**
 * Specifies possible directions for sorting a data set.
 * Useful in preparing queries or performing client-side sorting.
 */
export enum SortDirection {
  /**
   * Ascending sort order, typically sorting from smallest
   * to largest (e.g., A to Z, 1 to 10).
   */
  ASC = 'ASC',

  /**
   * Descending sort order, typically sorting from largest
   * to smallest (e.g., Z to A, 10 to 1).
   */
  DESC = 'DESC',
}

/**
 * Describes a standard shape for how sorting is requested
 * in list or table components, ensuring uniformity across
 * all sorted datasets in the system.
 */
export interface SortParams {
  /**
   * The field or attribute name by which the dataset should
   * be sorted, such as "name", "dateCreated", or "rating".
   */
  field: string;

  /**
   * The direction for how the list is ordered (ascending or descending).
   */
  direction: SortDirection;
}

/**
 * A comprehensive set of status indicators used across
 * various entities (e.g., bookings, user profiles, tasks)
 * to unify state management within the application.
 */
export enum Status {
  /**
   * Indicates a resource or entry is currently active
   * and available.
   */
  ACTIVE = 'ACTIVE',

  /**
   * Indicates a resource or entry is not in use or has been
   * disabled, but remains in the system.
   */
  INACTIVE = 'INACTIVE',

  /**
   * Reflects a newly created or initiated process that awaits
   * confirmation or additional steps.
   */
  PENDING = 'PENDING',

  /**
   * Signifies a resource or process has completed its lifecycle
   * successfully.
   */
  COMPLETED = 'COMPLETED',

  /**
   * Implies the resource or process was intentionally stopped
   * before completion.
   */
  CANCELLED = 'CANCELLED',

  /**
   * Indicates something is currently in execution, especially useful
   * for tasks or workflows that have begun but are not yet finished.
   */
  IN_PROGRESS = 'IN_PROGRESS',
}

/**
 * Enumerates possible loading or process states in UI components,
 * data fetching hooks, or asynchronous flows, standardizing how the
 * application reflects ongoing and completed actions.
 */
export enum LoadingState {
  /**
   * Represents an idle or initial state, in which no action
   * or data request is in progress.
   */
  IDLE = 'IDLE',

  /**
   * Indicates that a loading or data-fetching operation
   * is currently in progress.
   */
  LOADING = 'LOADING',

  /**
   * Signifies that the operation has successfully completed
   * and the data is now available.
   */
  SUCCESS = 'SUCCESS',

  /**
   * Reflects that the operation encountered an error,
   * preventing successful completion.
   */
  ERROR = 'ERROR',

  /**
   * Implies that the operation completed partially, or
   * some data may have been retrieved while other parts
   * failed or remain pending.
   */
  PARTIAL = 'PARTIAL',
}

/**
 * Defines severity levels for categorizing errors, assisting in
 * logging, user notifications, and operational triage. A uniform
 * error severity structure aids in consistent error handling.
 */
export enum ErrorSeverity {
  /**
   * Informational events that may not require intervention
   * but are relevant for debugging or analytics.
   */
  INFO = 'INFO',

  /**
   * Potential issues that do not immediately impede
   * functionality but may require attention or resolution.
   */
  WARNING = 'WARNING',

  /**
   * Errors that cause an operation to fail but are
   * generally recoverable or localized to a specific action.
   */
  ERROR = 'ERROR',

  /**
   * Critical, system-level failures that imperil the system's
   * stability or security, requiring urgent attention.
   */
  CRITICAL = 'CRITICAL',
}

/**
 * Centralized interface for representing application errors,
 * capturing pertinent data for logging, user feedback,
 * and troubleshooting. Integrates with different severity
 * levels to bracket the impact of the issue.
 */
export interface ErrorState {
  /**
   * A concise label or identifier for the error category
   * (e.g., "NETWORK_FAILURE" or "VALIDATION_ERROR").
   */
  code: string;

  /**
   * A brief description suitable for display in user
   * interfaces or logs, indicating what caused the error.
   */
  message: string;

  /**
   * A collection of key-value pairs providing additional
   * contextual information, such as parameters involved in
   * the error or correlated IDs.
   */
  details: Record<string, any>;

  /**
   * Captures the exact date and time (to millisecond precision)
   * when this error was recorded, supporting chronological logging
   * and historical analysis.
   */
  timestamp: Date;

  /**
   * Specifies how critical the error is, aiding in routing the
   * issue to the correct resolution flow or alerting mechanism.
   */
  severity: ErrorSeverity;
}

/**
 * Enumerates the application’s theme modes, ensuring
 * consistent styling logic across various UI components.
 */
export enum Theme {
  /**
   * A bright, conventional user interface suitable for
   * well-lit or daytime environments.
   */
  LIGHT = 'LIGHT',

  /**
   * A darker, low-luminance interface, reducing glare
   * in dimly lit surroundings and potentially saving
   * device power.
   */
  DARK = 'DARK',

  /**
   * Automatically matches the operating system’s
   * theme preferences.
   */
  SYSTEM = 'SYSTEM',
}