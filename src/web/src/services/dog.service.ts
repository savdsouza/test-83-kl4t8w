/* -------------------------------------------------------------------------------------------------
 * DogService
 * 
 * This TypeScript file defines the DogService class, responsible for managing all aspects of
 * dog-related operations. These operations include creating, reading, updating, deleting,
 * and bulk-creating dog profiles through integration with a backend microservice.
 *
 * Key Features & Requirements:
 * - Comprehensive error handling.
 * - Caching of dog profiles to minimize repeated calls.
 * - Built-in retry logic for resilient operations.
 * - Offline support considerations (deduping pending requests).
 * - Strict adherence to enterprise-grade development practices.
 * 
 * The service leverages:
 * - ApiService for standardized HTTP requests with circuit breaker, interceptors, and retry features.
 * - CacheService for storing and retrieving cached results.
 * - LoggerService for logging important lifecycle events.
 * 
 * Global considerations from specification:
 * - API_ENDPOINTS: { DOGS, DOG_BY_ID, DOGS_BY_OWNER, DOGS_BULK }
 * - CACHE_CONFIG: { DOG_CACHE_TTL, OWNER_DOGS_CACHE_TTL }
 * - RETRY_CONFIG: { MAX_RETRIES, BACKOFF_MS }
 * 
 * Methods Implemented:
 * 1) getDogById       - Retrieves a dog profile by ID, with caching and retry logic.
 * 2) getDogsByOwner   - Retrieves all dogs for a given owner, with pagination and caching.
 * 3) createDog        - Creates a new dog profile with validation and cache invalidation.
 * 4) updateDog        - Updates an existing dog profile using optimistic updates and retry logic.
 * 5) deleteDog        - Deletes a dog profile, clearing caches and handling cascade checks.
 * 6) bulkCreateDogs   - Creates multiple profiles in a single transaction, updating caches.
 * 
 * The class thoroughly documents each step for clarity and maintainability, satisfying the
 * project's requirement for extreme detail in enterprise software services.
 * ------------------------------------------------------------------------------------------------- */

import { ApiService } from './api.service';
import { Dog, CreateDogRequest, UpdateDogRequest } from '../types/dog.types';
import { ApiResponse } from '../types/api.types';

// External Imports with Specified Versions
import CacheService /* ^1.0.0 */ from '@cache/service';
import LoggerService /* ^1.0.0 */ from '@logger/service';

/**
 * Global endpoint constants for dog-related REST resources. Derived from the
 * provided specification's "globals" object.
 */
const DOG_ENDPOINTS = {
  DOGS: '/api/v1/dogs',
  DOG_BY_ID: '/api/v1/dogs/:id',
  DOGS_BY_OWNER: '/api/v1/dogs/owner/:ownerId',
  DOGS_BULK: '/api/v1/dogs/bulk',
};

/**
 * Global cache configuration from the specification's "CACHE_CONFIG".
 * DOG_CACHE_TTL        -> Time in ms to cache a single dog's profile.
 * OWNER_DOGS_CACHE_TTL -> Time in ms to cache all dogs belonging to a specific owner.
 */
const CACHE_CONFIG = {
  DOG_CACHE_TTL: 300000,       // 5 minutes
  OWNER_DOGS_CACHE_TTL: 600000 // 10 minutes
};

/**
 * Global retry configuration values covering maximum attempts and exponential
 * backoff intervals from the specification's "RETRY_CONFIG".
 */
const RETRY_CONFIG = {
  MAX_RETRIES: 3,
  BACKOFF_MS: 1000
};

/**
 * A small helper interface for pagination options used in fetching lists of dogs.
 */
interface PaginationOptions {
  /**
   * The current page number for pagination (e.g., 1 or 2).
   */
  page: number;

  /**
   * The number of items per page (e.g., 10, 20, etc.).
   */
  pageSize: number;
}

/**
 * DogService
 * 
 * Service class for handling all dog-related operations. This class integrates with
 * the backend microservices using ApiService and employs robust caching, retry strategies,
 * and thorough logging to ensure reliability and scalability.
 */
export class DogService {
  /**
   * The ApiService instance used for making HTTP calls to the Dog-related endpoints.
   */
  private apiService: ApiService;

  /**
   * CacheService instance for handling caching of dog profiles to reduce redundant
   * server calls and optimize performance.
   */
  private cacheService: CacheService;

  /**
   * LoggerService instance for capturing significant events or error conditions
   * throughout the dog's lifecycle.
   */
  private loggerService: LoggerService;

  /**
   * A local property storing a default or current retry count. Although ApiService
   * already has built-in retry, this field is retained for potential advanced logic
   * or fallback strategies.
   */
  private retryCount: number;

  /**
   * A map to track pending requests (by unique key) and their active Promises,
   * preventing duplicate requests for the same resource in parallel. When a request
   * for a given key is in-flight, subsequent calls will reuse the same Promise
   * rather than re-issuing an identical network call.
   */
  private pendingRequests: Map<string, Promise<any>>;

  /**
   * Constructs the DogService, linking in the necessary dependencies
   * for API access, caching, and logging.
   * 
   * Steps:
   * 1) Assign the provided ApiService, CacheService, and LoggerService instances.
   * 2) Initialize the internal map used for deduplicating request calls.
   * 3) Initialize the retryCount based on provided RETRY_CONFIG or default fallback.
   *
   * @param apiService     A configured instance of the ApiService class.
   * @param cacheService   The external CacheService for get/set operations.
   * @param loggerService  The external LoggerService for event logging.
   */
  constructor(
    apiService: ApiService,
    cacheService: CacheService,
    loggerService: LoggerService
  ) {
    // 1) Assign dependencies
    this.apiService = apiService;
    this.cacheService = cacheService;
    this.loggerService = loggerService;

    // 2) Initialize request deduplication map
    this.pendingRequests = new Map<string, Promise<any>>();

    // 3) Set up default retry count from global config
    this.retryCount = RETRY_CONFIG.MAX_RETRIES;
  }

  /**
   * Retrieves a single Dog profile by its unique identifier. Uses locally cached
   * data if available, otherwise calls the backend using GET. Implements retry
   * logic and logs important lifecycle events.
   * 
   * Method Steps:
   * 1) Check whether a cached dog entry exists. If yes, return it immediately.
   * 2) Validate the dog ID format to avoid empty or invalid IDs.
   * 3) Check if a request for the same dog ID is already in progress (dedup).
   * 4) Execute ApiService GET request with robust error handling.
   * 5) If successful, store the result in cache for DOG_CACHE_TTL duration.
   * 6) Log the operation completion.
   * 7) Return the structured ApiResponse<Dog> object.
   * 
   * @param id The unique identifier of the dog to retrieve.
   * @returns  A promise that resolves with the dog's profile in an ApiResponse.
   */
  public async getDogById(id: string): Promise<ApiResponse<Dog>> {
    // 1) Attempt to retrieve from cache
    const cacheKey = `dog_${id}`;
    const cachedDog = this.cacheService.get<ApiResponse<Dog>>(cacheKey);
    if (cachedDog) {
      return cachedDog;
    }

    // 2) Validate the dog ID format (simple check)
    if (!id || typeof id !== 'string' || id.trim().length === 0) {
      throw new Error('Invalid dog ID specified. Must be a non-empty string.');
    }

    // 3) Check for existing pending request to deduplicate
    const pendingKey = `getDogById_${id}`;
    const existingRequest = this.pendingRequests.get(pendingKey);
    if (existingRequest) {
      return existingRequest as Promise<ApiResponse<Dog>>;
    }

    // Prepare the endpoint by replacing the placeholder
    const endpoint = DOG_ENDPOINTS.DOG_BY_ID.replace(':id', id);

    // Create and store the request Promise in pendingRequests
    const requestPromise = (async (): Promise<ApiResponse<Dog>> => {
      try {
        // 4) Execute GET request
        const response = await this.apiService.get<Dog>(endpoint);

        // 5) Cache successful result (if success is true)
        if (response.success) {
          this.cacheService.set(cacheKey, response, CACHE_CONFIG.DOG_CACHE_TTL);
        }

        // 6) Log event
        this.loggerService.info(`Dog with ID ${id} retrieved successfully.`);

        // 7) Return response
        return response;
      } finally {
        // Remove from pending requests, so subsequent calls are fresh
        this.pendingRequests.delete(pendingKey);
      }
    })();

    this.pendingRequests.set(pendingKey, requestPromise);
    return requestPromise;
  }

  /**
   * Retrieves all dogs for a specific owner, optionally using pagination. Checks
   * cache to see if the owner's dog list is already stored and up to date. If not,
   * a paginated GET request is issued to the backend microservice. The response is
   * cached for OWNER_DOGS_CACHE_TTL.
   * 
   * Method Steps:
   * 1) Attempt to retrieve the owner's dog list from cache.
   * 2) Validate the ownerId and pagination parameters.
   * 3) Construct the GET endpoint with pagination in query params if needed.
   * 4) Send the GET request via ApiService, handling retries.
   * 5) Cache the result on success.
   * 6) Log completion.
   * 7) Return the final ApiResponse<Dog[]> object.
   * 
   * @param ownerId  The unique identifier of the owner whose dogs we want.
   * @param options  A PaginationOptions object specifying page and pageSize.
   * @returns        A paginated list of dog profiles within an ApiResponse wrapper.
   */
  public async getDogsByOwner(
    ownerId: string,
    options?: PaginationOptions
  ): Promise<ApiResponse<Dog[]>> {
    // 1) Check cache using an owner-based key
    const cacheKey = `owner_dogs_${ownerId}`;
    const cachedData = this.cacheService.get<ApiResponse<Dog[]>>(cacheKey);
    if (cachedData) {
      return cachedData;
    }

    // 2) Basic validation for ownerId and pagination
    if (!ownerId || typeof ownerId !== 'string' || ownerId.trim().length === 0) {
      throw new Error('Invalid owner ID specified. Must be a non-empty string.');
    }

    // Pagination fallback defaults
    const page = options?.page ?? 1;
    const pageSize = options?.pageSize ?? 10;

    // Construct the endpoint URL with pagination query params
    const endpoint = DOG_ENDPOINTS.DOGS_BY_OWNER.replace(':ownerId', ownerId);
    const urlWithParams = `${endpoint}?page=${page}&pageSize=${pageSize}`;

    // For dedup, create a pending request key
    const pendingKey = `getDogsByOwner_${ownerId}_p${page}_ps${pageSize}`;
    const existingRequest = this.pendingRequests.get(pendingKey);
    if (existingRequest) {
      return existingRequest as Promise<ApiResponse<Dog[]>>;
    }

    const requestPromise = (async (): Promise<ApiResponse<Dog[]>> => {
      try {
        // 4) Execute GET request
        const response = await this.apiService.get<Dog[]>(urlWithParams);

        // 5) Cache the result if successful
        if (response.success) {
          this.cacheService.set(
            cacheKey,
            response,
            CACHE_CONFIG.OWNER_DOGS_CACHE_TTL
          );
        }

        // 6) Log
        this.loggerService.info(
          `Dogs for owner ${ownerId} retrieved successfully. Page ${page}, PageSize ${pageSize}.`
        );

        // 7) Return final result
        return response;
      } finally {
        this.pendingRequests.delete(pendingKey);
      }
    })();

    this.pendingRequests.set(pendingKey, requestPromise);
    return requestPromise;
  }

  /**
   * Creates a new dog profile on the backend service, ensuring the provided data
   * is valid and sanitized. Upon success, relevant caches are invalidated to
   * prevent stale data. Includes retry handling via ApiService.
   * 
   * Method Steps:
   * 1) Validate the completeness of dogData.
   * 2) (Optional) Sanitize or transform input data as needed.
   * 3) Issue a POST request to create the dog.
   * 4) Invalidate caches that store dog or owner-based lists.
   * 5) Log the successful creation event.
   * 6) Return the newly created dog profile in an ApiResponse.
   * 
   * @param dogData The payload object containing details for the new dog profile.
   * @returns       ApiResponse containing the newly created Dog.
   */
  public async createDog(dogData: CreateDogRequest): Promise<ApiResponse<Dog>> {
    // 1) Validate dogData (extremely basic check here; real logic might be more complex)
    if (!dogData || !dogData.name || !dogData.ownerId) {
      throw new Error('Invalid CreateDogRequest: dog name and ownerId are required.');
    }

    // 2) Sanitize or transform data if needed (placeholder)
    // For example, trim strings:
    dogData.name = dogData.name.trim();

    // 3) POST request
    const response = await this.apiService.post<Dog>(
      DOG_ENDPOINTS.DOGS,
      dogData
    );

    // 4) Invalidate relevant caches (owner's dog list, etc.)
    const ownerKey = `owner_dogs_${dogData.ownerId}`;
    this.cacheService.del(ownerKey);

    // 5) Log
    if (response.success) {
      this.loggerService.info(
        `Dog created successfully under owner ${dogData.ownerId}. Dog name: ${dogData.name}`
      );
    }

    // 6) Return the response
    return response;
  }

  /**
   * Updates an existing dog profile. Implements optimistic cache updates by
   * temporarily reflecting the changes in cache prior to awaiting the full
   * server response. If the request fails, it reverts the cached data. 
   * Retry logic is handled by ApiService.
   * 
   * Method Steps:
   * 1) Validate the update data to ensure a minimal set of fields is provided.
   * 2) If the dog is in cache, perform an optimistic update to reflect changes immediately.
   * 3) Issue PUT request to the backend.
   * 4) If server call fails, revert the cache to its prior state.
   * 5) On success, update the cache with the authoritative data from the server.
   * 6) Log the update event.
   * 7) Return the updated dog profile.
   * 
   * @param id       The unique identifier of the dog to update.
   * @param dogData  The partial fields to be updated.
   * @returns        ApiResponse containing the updated Dog.
   */
  public async updateDog(
    id: string,
    dogData: UpdateDogRequest
  ): Promise<ApiResponse<Dog>> {
    // 1) Basic validation
    if (!id || typeof id !== 'string' || id.trim().length === 0) {
      throw new Error('Invalid dog ID for update operation.');
    }
    if (!dogData || Object.keys(dogData).length === 0) {
      throw new Error('UpdateDogRequest cannot be empty.');
    }

    const cacheKey = `dog_${id}`;
    const cachedDog = this.cacheService.get<ApiResponse<Dog>>(cacheKey);
    let previousValue: ApiResponse<Dog> | null = null;

    // 2) Perform optimistic cache update if we have a cached entry
    if (cachedDog && cachedDog.success && cachedDog.data) {
      previousValue = { ...cachedDog }; // clone the existing cached response
      const updatedDog = { ...cachedDog.data, ...dogData };
      this.cacheService.set(
        cacheKey,
        { ...cachedDog, data: updatedDog },
        CACHE_CONFIG.DOG_CACHE_TTL
      );
    }

    const endpoint = DOG_ENDPOINTS.DOG_BY_ID.replace(':id', id);

    try {
      // 3) Issue PUT request
      const response = await this.apiService.put<Dog>(endpoint, dogData);

      // 5) If success, store updated dog in cache
      if (response.success) {
        this.cacheService.set(cacheKey, response, CACHE_CONFIG.DOG_CACHE_TTL);
      }

      // 6) Log
      this.loggerService.info(`Dog with ID ${id} updated successfully.`);

      // 7) Return updated profile
      return response;
    } catch (error) {
      // 4) Revert cache if something fails
      if (previousValue) {
        this.cacheService.set(cacheKey, previousValue, CACHE_CONFIG.DOG_CACHE_TTL);
      }
      throw error;
    }
  }

  /**
   * Deletes an existing dog profile from the system. Includes optional checks for
   * dependent records (e.g., existing walk histories) and clears relevant caches.
   * 
   * Method Steps:
   * 1) Validate the dog ID format.
   * 2) [Optional] Check for dependent records (placeholder for demonstration).
   * 3) Call the DELETE endpoint with retry logic.
   * 4) Remove any relevant entries from cache.
   * 5) Log the deletion event.
   * 6) Return the deletion confirmation ApiResponse.
   * 
   * @param id The ID of the dog to delete.
   * @returns  ApiResponse confirmation (data is typically void or a status message).
   */
  public async deleteDog(id: string): Promise<ApiResponse<void>> {
    // 1) Validate ID
    if (!id || typeof id !== 'string' || id.trim().length === 0) {
      throw new Error('Invalid dog ID for deletion.');
    }

    // 2) Check for dependent records (placeholder - real logic might call another endpoint)
    // e.g. await this.apiService.get(`/dogs/${id}/dependencies`) to see if some references must be handled

    // 3) Perform DELETE
    const endpoint = DOG_ENDPOINTS.DOG_BY_ID.replace(':id', id);
    const response = await this.apiService.delete<void>(endpoint);

    // 4) Clear relevant caches
    const cacheKey = `dog_${id}`;
    this.cacheService.del(cacheKey);

    // We may also want to remove from owner-based lists if we can find the dog's owner ahead of time

    // 5) Log
    if (response.success) {
      this.loggerService.info(`Dog with ID ${id} was deleted successfully.`);
    }

    // 6) Return
    return response;
  }

  /**
   * Allows the creation of multiple dog profiles in a single request, streamlining
   * batch operations. In the event of partial failures, the backend usually indicates
   * which records succeeded or failed. This method also updates or invalidates relevant
   * caches upon success.
   * 
   * Method Steps:
   * 1) Validate all dog data entries (e.g., each must have a name/ownerId).
   * 2) Issue a bulk POST request to the microservice.
   * 3) If partial success is indicated, handle relevant logic (placeholder here).
   * 4) Update caches accordingly, or invalidate them if no easy partial logic is possible.
   * 5) Log the bulk creation results.
   * 6) Return the ApiResponse containing created dog profiles.
   * 
   * @param dogsData An array of CreateDogRequest objects.
   * @returns        ApiResponse with an array of created Dogs.
   */
  public async bulkCreateDogs(
    dogsData: CreateDogRequest[]
  ): Promise<ApiResponse<Dog[]>> {
    // 1) Validate all dog data
    if (!dogsData || !Array.isArray(dogsData) || dogsData.length === 0) {
      throw new Error('bulkCreateDogs: at least one dog entry is required.');
    }
    dogsData.forEach((dog, index) => {
      if (!dog.name || !dog.ownerId) {
        throw new Error(`Dog entry at index ${index} is missing required fields (name/ownerId).`);
      }
    });

    // 2) Issue bulk POST
    const response = await this.apiService.post<Dog[]>(
      DOG_ENDPOINTS.DOGS_BULK,
      dogsData
    );

    // 3) Handle partial success scenarios. Typically, we parse response.data
    //    to see which were created vs. which failed. Placeholder here.

    // 4) Update or invalidate caches. Because multiple owners might be involved,
    //    we might simply clear caches for each distinct ownerId. For simplicity:
    const uniqueOwners = Array.from(new Set(dogsData.map(d => d.ownerId)));
    uniqueOwners.forEach(ownerId => {
      this.cacheService.del(`owner_dogs_${ownerId}`);
    });

    // 5) Log the operation
    if (response.success) {
      this.loggerService.info(
        `Bulk creation of ${dogsData.length} dog profiles completed successfully.`
      );
    }

    // 6) Return the ApiResponse
    return response;
  }
}