/**
 * Represents additional contextual details about an error,
 * including optional validation errors or correlation identifiers
 * that can assist in tracing the origin of the issue across
 * distributed services.
 */
export interface ErrorDetails {
  /**
   * A unique identifier used for tracking requests across
   * various services or microservices.
   */
  correlationId: string;

  /**
   * A collection of validation errors that might have occurred
   * during request processing, providing detailed feedback for
   * each field or parameter.
   */
  validationErrors?: ValidationError[];
}

/**
 * Describes a specific validation error with the field or parameter name,
 * a reason for the error, and optional metadata for additional context.
 */
export interface ValidationError {
  /**
   * The name of the field or parameter that failed validation.
   */
  field: string;

  /**
   * A high-level reason or summary of the validation error.
   */
  message: string;

  /**
   * Additional details or metadata that might be relevant for
   * debugging or further processing of validation failures.
   */
  details?: any;
}

/**
 * Represents metadata included with every API response,
 * allowing clients to understand specifics about request
 * handling and debugging.
 */
export interface ResponseMetadata {
  /**
   * The server-generated unique identifier for this request,
   * which is useful when tracing logs or triaging issues.
   */
  requestId: string;

  /**
   * A timestamp (in milliseconds since the Unix epoch) indicating
   * when the server processed the request.
   */
  serverTimestamp: number;

  /**
   * The semantic version or build version of the API currently in use,
   * facilitating client-side version checks and debugging.
   */
  apiVersion: string;

  /**
   * An optional object that can hold additional debugging or diagnostic
   * information, particularly useful in non-production environments.
   */
  debugInfo?: Record<string, any>;
}

/**
 * A fully structured error object returned from the API
 * whenever an operation fails or encounters an unexpected
 * situation, providing granular debugging capabilities.
 */
export interface ApiError {
  /**
   * A code representing the type or category of error (e.g. "AUTH_FAILED",
   * "VALIDATION_ERROR", or "SERVER_ERROR").
   */
  code: string;

  /**
   * A concise, human-readable message describing the error.
   */
  message: string;

  /**
   * Extended error information capturing correlation IDs, validation issues,
   * or additional diagnostics relevant to the error context.
   */
  details: ErrorDetails;

  /**
   * Timestamp (in milliseconds since the Unix epoch) indicating when the error
   * was generated, useful for event correlation and incident analysis.
   */
  timestamp: number;

  /**
   * Optionally available stack trace information to assist in debugging;
   * typically exposed in non-production environments.
   */
  stackTrace?: string;
}

/**
 * A generic response interface forming the basis of all
 * API responses, encapsulating both successful and error
 * outcomes along with supplementary metadata.
 */
export interface ApiResponse<T> {
  /**
   * Indicates whether the request was successfully processed.
   * If true, the 'data' property holds the successful response.
   * If false, the 'error' property provides error details.
   */
  success: boolean;

  /**
   * The data payload returned by the server for clients to
   * consume when the operation is successful.
   */
  data: T;

  /**
   * If an error occurs, contains the error details. Otherwise, null.
   */
  error: ApiError | null;

  /**
   * Additional information about the server’s response, including
   * debugging data, request identifiers, and API versioning.
   */
  metadata: ResponseMetadata;

  /**
   * A timestamp (in milliseconds since the Unix epoch) indicating
   * when the server generated this response, allowing clients to
   * measure latencies.
   */
  timestamp: number;
}

/**
 * Represents additional pagination data, typically used when
 * returning collections that may span multiple pages. Includes
 * sorting, filtering, and navigational fields.
 */
export interface PaginatedResponse<T> {
  /**
   * The array of items representing the current page of results.
   */
  items: T[];

  /**
   * The total count of items across all pages, for client display
   * or pagination controls.
   */
  total: number;

  /**
   * The current page index, typically starting at 1 (or 0 depending
   * on client convention).
   */
  page: number;

  /**
   * The maximum number of items included in this page.
   */
  pageSize: number;

  /**
   * Indicates whether additional pages of data are available.
   */
  hasMore: boolean;

  /**
   * Sorting information that describes the field(s) and direction(s)
   * used to sort the current set of items.
   */
  sort: SortInfo;

  /**
   * Criteria used for filtering or refining the elements in this result set.
   */
  filters: FilterCriteria;
}

/**
 * Provides information for sorting collections of data,
 * such as sorting by attribute name in ascending or
 * descending order.
 */
export interface SortInfo {
  /**
   * The data field or attribute to sort by.
   */
  sortBy: string;

  /**
   * The direction ("asc" or "desc") indicating whether the
   * sort should be ascending or descending.
   */
  direction: 'asc' | 'desc';
}

/**
 * Describes one or more conditions to filter a result set,
 * allowing clients to narrow down data based on field values
 * or logical operators.
 */
export interface FilterCriteria {
  /**
   * A collection of filtering rules, each describing how to match
   * or exclude certain data records based on field values.
   */
  rules: FilterRule[];
}

/**
 * Represents a single filtering condition applied to a field,
 * allowing for comparisons or pattern matching operators.
 */
export interface FilterRule {
  /**
   * The field name on which the filter is applied.
   */
  field: string;

  /**
   * The value to compare against, which may be a string, number,
   * or any other data type depending on the field's definition.
   */
  value: any;

  /**
   * The operator to use when comparing the field with the value,
   * such as 'eq', 'neq', 'like', 'gt', or 'lt'.
   */
  operator: string;
}

/**
 * A configuration object defining retry policies for requests,
 * indicating how many times to attempt a request and the
 * strategy for pacing these attempts.
 */
export interface RetryConfig {
  /**
   * The maximum number of retry attempts allowed if the request fails.
   */
  maxAttempts: number;

  /**
   * The strategy to use when pacing retries, for example 'exponential'
   * or 'linear', defining how the delay grows between successive attempts.
   */
  strategy: 'exponential' | 'linear';

  /**
   * The initial delay (in milliseconds) before the first retry attempt,
   * adjusted based on the chosen strategy.
   */
  delay: number;
}

/**
 * Defines caching behavior for requests, useful for reducing
 * round trips and optimizing performance under certain
 * conditions.
 */
export interface CacheConfig {
  /**
   * If true, caching is enabled for this request, storing
   * responses for quicker subsequent retrievals.
   */
  enabled: boolean;

  /**
   * The maximum period (in milliseconds) to keep the response
   * in the cache before it expires.
   */
  maxAge: number;

  /**
   * Additional time (in milliseconds) during which stale data
   * may be served while a background refresh is performed.
   */
  staleWhileRevalidate: number;
}

/**
 * Enum describing the relative importance of a request,
 * influencing scheduling or resource allocation in certain
 * advanced use cases.
 */
export enum RequestPriority {
  /**
   * Requests that are non-urgent and can be deprived of resources
   * in favor of higher priority tasks.
   */
  LOW = 'LOW',

  /**
   * Default level for most requests, offering balanced priority
   * and resource allocation.
   */
  NORMAL = 'NORMAL',

  /**
   * Requests requiring expedited handling given their criticality,
   * possibly preempting lower priority tasks.
   */
  HIGH = 'HIGH'
}

/**
 * Configuration object for an outbound request, providing
 * advanced customization such as headers, timeouts, caching
 * strategies, and retry policies.
 */
export interface RequestConfig {
  /**
   * A map of header key-value pairs to be included with this request,
   * supporting content negotiation, authentication, or custom logic.
   */
  headers: Record<string, string>;

  /**
   * A map of URL parameters or query parameters that will be appended
   * to the request URL prior to dispatch.
   */
  params: Record<string, any>;

  /**
   * The maximum time (in milliseconds) to wait for a server response
   * before the request is automatically aborted.
   */
  timeout: number;

  /**
   * Configuration specifying how and when to retry a failed request,
   * including the maximum number of attempts and any backoff strategy.
   */
  retryStrategy: RetryConfig;

  /**
   * Defines caching behavior for the request/response cycle, determining
   * whether responses are stored and how long they remain valid.
   */
  cacheControl: CacheConfig;

  /**
   * Indicates the priority level of this request, guiding scheduling
   * decisions or resource allocation in more sophisticated systems.
   */
  priority: RequestPriority;
}

/**
 * An interface capturing all the authentication-related
 * headers necessary for making secure calls to the API,
 * including authorization tokens, content negotiation, and
 * version control.
 */
export interface AuthHeaders {
  /**
   * Authorization header containing bearer tokens or other
   * authorized credentials.
   */
  Authorization: string;

  /**
   * Desired media or content type for responses (e.g. 'application/json').
   */
  Accept: string;

  /**
   * Specifies the content type of the request payload (e.g. 'application/json').
   */
  ContentType: string;

  /**
   * Indicates which version of the API the client is calling,
   * useful for contract negotiation and backward compatibility.
   */
  ApiVersion: string;

  /**
   * Unique identifier for the calling client or application,
   * helpful for analytics and usage tracking.
   */
  ClientId: string;

  /**
   * A token representing the user's active session, if available,
   * allowing the server to maintain identity context between requests.
   */
  SessionToken?: string;
}

/**
 * An enumeration including extended HTTP methods commonly used
 * for RESTful and non-RESTful endpoints, providing type safety
 * for method usage within the client or server codebase.
 */
export enum HttpMethod {
  /**
   * Retrieves data from a resource without causing side effects.
   */
  GET = 'GET',

  /**
   * Submits an entity to the specified resource, often causing a
   * change in state or side effects on the server.
   */
  POST = 'POST',

  /**
   * Replaces all current representations of the target resource
   * with the request payload.
   */
  PUT = 'PUT',

  /**
   * Deletes the specified resource.
   */
  DELETE = 'DELETE',

  /**
   * Applies partial modifications to a resource.
   */
  PATCH = 'PATCH',

  /**
   * Asks for a response identical to that of a GET request, but
   * without the response body.
   */
  HEAD = 'HEAD',

  /**
   * Used to describe the communication options for the target resource.
   */
  OPTIONS = 'OPTIONS'
}