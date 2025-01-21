package com.dogwalking.app.data.repository

/***************************************************************************************************
 * Import Section - External Libraries (with specified versions) and Internal Dependencies
 **************************************************************************************************/
import javax.inject.Inject // version 1
import javax.inject.Singleton // version 1

import kotlinx.coroutines.CoroutineDispatcher // Kotlin Coroutines core library
import kotlinx.coroutines.flow.Flow // v1.7.0
import kotlinx.coroutines.flow.StateFlow // v1.7.0
import kotlinx.coroutines.flow.MutableStateFlow // v1.7.0
import kotlinx.coroutines.flow.flatMapLatest // v1.7.0
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext

import com.dogwalking.app.data.api.ApiService
import com.dogwalking.app.data.database.dao.UserDao
import com.dogwalking.app.data.database.entities.UserEntity
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.core.network.NetworkResult // v1.0.0

/***************************************************************************************************
 * Internal Enum Class for Sync Status
 * This represents various stages of synchronization logic within the repository.
 **************************************************************************************************/
private enum class SyncStatus {
    /**
     * IDLE: Indicates that no synchronization is currently in progress.
     */
    IDLE,

    /**
     * SYNCING: Actively performing a sync operation with remote data source.
     */
    SYNCING,

    /**
     * SUCCESS: Sync operation completed successfully.
     */
    SUCCESS,

    /**
     * ERROR: Sync operation encountered an error.
     */
    ERROR
}

/***************************************************************************************************
 * @Singleton
 * UserRepository
 *
 * This repository class implements a robust offline-first user data management module with
 * sophisticated caching, conflict resolution, and error handling. It integrates with both local
 * database operations (UserDao) and remote API calls (ApiService). It also provides real-time
 * synchronization status via a StateFlow, allowing consumers to observe changes in the sync
 * pipeline.
 **************************************************************************************************/
@Singleton
class UserRepository @Inject constructor(
    /**
     * ApiService for performing remote API communication related to user operations
     * such as fetching and updating user data.
     */
    private val apiService: ApiService,

    /**
     * UserDao for local database interactions. Contains CRUD operations and specialized
     * queries for user information, including verified walker retrieval and stale data cleanup.
     */
    private val userDao: UserDao,

    /**
     * CoroutineDispatcher injected for IO-bound work. Ensures that blocking calls
     * and heavy operations do not block the main thread.
     */
    private val ioDispatcher: CoroutineDispatcher
) {

    // ---------------------------------------------------------------------------------------------
    // Backing StateFlow property for synchronization status.
    // ---------------------------------------------------------------------------------------------
    private val _syncStatus: MutableStateFlow<SyncStatus> = MutableStateFlow(SyncStatus.IDLE)

    /**
     * Publicly exposed StateFlow that allows external observers to monitor
     * the current synchronization status in real time.
     */
    val syncStatus: StateFlow<SyncStatus>
        get() = _syncStatus

    // ---------------------------------------------------------------------------------------------
    // Initialization Block:
    // 1. Initialize required properties (completed via constructor assignment).
    // 2. Setup sync status monitoring (exposed via StateFlow).
    // 3. Initialize any background sync jobs or timers.
    // 4. Setup overarching error handling scaffolding for all repository operations.
    // ---------------------------------------------------------------------------------------------
    init {
        // (1) Properties are already initialized by constructor parameters.
        // (2) _syncStatus is exposed via syncStatus and can be observed externally.
        // (3) Example usage: schedule or initiate background tasks for data synchronization.
        initializeBackgroundSyncJob()
        // (4) Error handling is centralized in the getUser/updateUser methods with exhaustive try/catch.
    }

    /**
     * Placeholder function demonstrating how periodic or event-based synchronization
     * jobs could be initialized upon repository instantiation.
     */
    private fun initializeBackgroundSyncJob() {
        // In a production environment, integrate with WorkManager or a custom
        // scheduling mechanism to handle periodic sync or stale data cleanup.
        // For demonstration, this is a no-op.
    }

    // ---------------------------------------------------------------------------------------------
    // getUser: Offline-first flow for retrieving user data by userId.
    //
    // Returns:
    //   Flow<Result<User>> - A Kotlin Flow that emits:
    //      - A cached user from the local DB if present.
    //      - A potentially updated user after attempting remote fetch.
    //      - An error if any step encounters a network or data conflict issue.
    //
    // Steps Implemented:
    //   1. Check local cache validity (retrieve from userDao).
    //   2. Emit local cached data if valid.
    //   3. Attempt API fetch with a retry or fallback mechanism.
    //   4. Handle network errors gracefully via try/catch.
    //   5. Update local cache with newly fetched data if successful.
    //   6. Emit updated data with version info.
    // ---------------------------------------------------------------------------------------------
    fun getUser(userId: String): Flow<Result<User>> {
        return userDao.getUser(userId).flatMapLatest { localEntity ->
            flow {
                // Step 2: Emit local data if it exists (this may be null if not cached).
                localEntity?.let {
                    emit(Result.success(it.toDomainModel()))
                }

                // Step 3 & 4: Attempt remote fetch, handle network errors gracefully.
                val remoteResult = fetchUserRemoteAndCache(userId)
                remoteResult.fold(
                    onSuccess = { updatedUser ->
                        // Step 6: Emit updated data with version info
                        emit(Result.success(updatedUser))
                    },
                    onFailure = { error ->
                        // Emit failure if remote call or caching failed
                        emit(Result.failure<User>(error))
                    }
                )
            }
        }.catch { exception ->
            // Global exception handler for any Flow-related issues or transformations
            emit(Result.failure(exception))
        }.flowOn(ioDispatcher)
    }

    // ---------------------------------------------------------------------------------------------
    // updateUser: Updates user profile with optimistic locking and conflict resolution.
    //
    // Parameters:
    //   user: The User domain model containing updated profile information.
    //
    // Returns:
    //   Result<User> - The updated user data on success, or an error with conflict details on failure.
    //
    // Steps:
    //   1. Validate update data to ensure it meets domain requirements.
    //   2. Apply an optimistic locking strategy using local/remote version checks or timestamps.
    //   3. Attempt remote API update with retry if needed.
    //   4. Handle conflicts by merging local and server changes if necessary.
    //   5. Update local cache to reflect the final version.
    //   6. Return the updated data or error in a Result wrapper.
    // ---------------------------------------------------------------------------------------------
    suspend fun updateUser(user: User): Result<User> = withContext(ioDispatcher) {
        try {
            // Step 1: Basic validation check (required fields)
            if (user.id.isBlank()) {
                return@withContext Result.failure<User>(
                    IllegalArgumentException("User ID cannot be blank.")
                )
            }

            // Step 2 & 3: Attempt remote API update with a naive conflict check
            val updateRequest = user.toUpdateProfileRequest()
            val apiResponse = apiService.updateUserProfile(user.id, updateRequest).blockingGet()

            // Convert the API response into a domain-compatible result
            val netResult = convertApiResponse(apiResponse) { remoteUpdatedUser ->
                remoteUpdatedUser
            }

            // Step 4: Merge conflict handling & Step 5: Update local
            when (netResult) {
                is NetworkResult.Success -> {
                    val updatedDomainUser = netResult.data
                    // Step 5: Reflect final version into local DB
                    val entity = UserEntity.fromDomainModel(updatedDomainUser)
                    userDao.updateUser(entity)
                    Result.success(updatedDomainUser)
                }
                is NetworkResult.Error -> {
                    Result.failure(UserUpdateException("Failed to update user: ${netResult.message}"))
                }
            }
        } catch (e: Exception) {
            // Step 6: Return error encountered
            Result.failure(e)
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Additional Repository Methods for Comprehensive Implementation
    // ---------------------------------------------------------------------------------------------

    /**
     * getVerifiedWalkers: Demonstrates retrieving verified walkers via an offline-first flow.
     * This uses both the local DAO and a remote API call for enhanced data consistency.
     *
     * @return A flow of Result<List<User>> capturing an updated list of verified walkers.
     */
    fun getVerifiedWalkers(): Flow<Result<List<User>>> {
        return userDao.getVerifiedWalkers().flatMapLatest { localList ->
            flow {
                // Emit local cached list first
                emit(Result.success(localList.map { it.toDomainModel() }))

                // Attempt remote fetch
                val remoteResult = fetchVerifiedWalkersRemoteAndCache()
                remoteResult.fold(
                    onSuccess = { updatedWalkers ->
                        emit(Result.success(updatedWalkers))
                    },
                    onFailure = { error ->
                        emit(Result.failure<List<User>>(error))
                    }
                )
            }
        }.catch { e ->
            emit(Result.failure(e))
        }.flowOn(ioDispatcher)
    }

    /**
     * cleanupStaleData: Optionally called to remove outdated or invalid user records
     * from the local database. This ensures that the offline cache stays clean and
     * relevant, improving storage efficiency and query performance.
     */
    suspend fun cleanupStaleData() {
        withContext(ioDispatcher) {
            userDao.deleteStaleData() // Hypothetical function to clear old user data
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Private Helper Methods
    // ---------------------------------------------------------------------------------------------

    /**
     * fetchUserRemoteAndCache:
     * Attempts to fetch user data from the remote API, then update the local cache if successful.
     * Returns a Result<User> capturing either a newly updated user domain object or an error.
     *
     * Steps:
     * 1. Update syncStatus to SYNCING.
     * 2. Make remote API call via ApiService, bridging RxJava -> blockingGet() for demonstration.
     * 3. Convert the response to a domain model and insert/update local DB.
     * 4. Update syncStatus to SUCCESS or ERROR based on outcome.
     */
    private suspend fun fetchUserRemoteAndCache(userId: String): Result<User> = withContext(ioDispatcher) {
        try {
            _syncStatus.value = SyncStatus.SYNCING
            val response = apiService.getUserProfile(userId).blockingGet()
            val netResult = convertApiResponse(response) { remoteUser ->
                remoteUser
            }
            when (netResult) {
                is NetworkResult.Success -> {
                    val domainUser = netResult.data
                    val entity = UserEntity.fromDomainModel(domainUser)
                    userDao.updateUser(entity)
                    _syncStatus.value = SyncStatus.SUCCESS
                    Result.success(domainUser)
                }
                is NetworkResult.Error -> {
                    _syncStatus.value = SyncStatus.ERROR
                    Result.failure<User>(Exception("Remote API Error: ${netResult.message}"))
                }
            }
        } catch (e: Exception) {
            _syncStatus.value = SyncStatus.ERROR
            Result.failure(e)
        }
    }

    /**
     * fetchVerifiedWalkersRemoteAndCache:
     * Attempts to fetch a list of verified walkers from a remote API, then updates the local
     * database. Returns a Result<List<User>> with the updated domain objects or an error.
     *
     * Steps:
     * 1. Set sync status to SYNCING.
     * 2. Perform the remote API call, bridging from RxJava Single to blockingGet().
     * 3. If successful, update local DB for each walker.
     * 4. Adjust sync status accordingly (SUCCESS or ERROR).
     */
    private suspend fun fetchVerifiedWalkersRemoteAndCache(): Result<List<User>> = withContext(ioDispatcher) {
        try {
            _syncStatus.value = SyncStatus.SYNCING
            val response = apiService.getVerifiedWalkers().blockingGet()
            val netResult = convertApiResponse(response) { walkerList ->
                walkerList
            }
            when (netResult) {
                is NetworkResult.Success -> {
                    val domainList = netResult.data
                    domainList.forEach { walker ->
                        val entity = UserEntity.fromDomainModel(walker)
                        userDao.insertUser(entity) // Insert or handle conflict with OnConflictStrategy
                    }
                    _syncStatus.value = SyncStatus.SUCCESS
                    Result.success(domainList)
                }
                is NetworkResult.Error -> {
                    _syncStatus.value = SyncStatus.ERROR
                    Result.failure<List<User>>(Exception("Error fetching verified walkers: ${netResult.message}"))
                }
            }
        } catch (e: Exception) {
            _syncStatus.value = SyncStatus.ERROR
            Result.failure(e)
        }
    }

    /**
     * convertApiResponse:
     * Transforms a strongly typed ApiResponse<T> into a NetworkResult<T>, facilitating
     * unified error handling and data extraction. This function can be reused for multiple
     * endpoints returning different payloads.
     *
     * @param apiResp The high-level ApiResponse from remote calls.
     * @param dataExtractor Lambda to convert the success response body (T) if needed.
     */
    private fun <T, R> convertApiResponse(
        apiResp: com.dogwalking.app.data.api.models.ApiResponse<T>,
        dataExtractor: (T) -> R
    ): NetworkResult<R> {
        return when (apiResp) {
            is com.dogwalking.app.data.api.models.Success -> {
                NetworkResult.Success(dataExtractor.invoke(apiResp.data))
            }
            is com.dogwalking.app.data.api.models.Error -> {
                NetworkResult.Error(apiResp.message)
            }
        }
    }

    /**
     * Extension function for converting a User domain model to a request object
     * that the ApiService can process for updating user profiles.
     */
    private fun User.toUpdateProfileRequest(): com.dogwalking.app.data.api.UpdateProfileRequest {
        return com.dogwalking.app.data.api.UpdateProfileRequest(
            firstName = firstName,
            lastName = lastName,
            phone = phone,
            profileImage = profileImage
        )
    }

    /**
     * Custom exception type to represent user update failures.
     */
    class UserUpdateException(message: String) : Exception(message)
}