package com.dogwalking.app.ui.walker.viewmodel

/***************************************************************************************************
 * Imports - External Libraries with Specified Versions
 ***************************************************************************************************/
import androidx.lifecycle.ViewModel // androidx.lifecycle version 2.6.1
import androidx.lifecycle.SavedStateHandle // androidx.lifecycle version 2.6.1
import kotlinx.coroutines.flow.StateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.MutableStateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject // javax.inject version 1

/***************************************************************************************************
 * Imports - Internal Modules
 ***************************************************************************************************/
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.domain.models.UserType
import com.dogwalking.app.domain.models.isEligibleForWalking
import com.dogwalking.app.data.repository.UserRepository

/***************************************************************************************************
 * HiltViewModel (Annotation)
 * This annotation indicates that WalkerViewModel participates in Hilt's dependency injection graph
 * for Android ViewModels, ensuring correct lifecycle handling and scoping.
 ***************************************************************************************************/
// Remove the comment below if using Hilt
// @HiltViewModel
class WalkerViewModel @Inject constructor(
    /**
     * The userRepository handles data operations such as retrieving users from the local cache,
     * making network requests, and persisting updated user data.
     */
    private val userRepository: UserRepository,

    /**
     * The savedStateHandle provides a mechanism to store and restore UI-related data
     * across process deaths, satisfying Android lifecycle requirements.
     */
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {

    /***********************************************************************************************
     * Private MutableStateFlow Properties:
     * _walkers     : Backing store for the list of walker-related User objects.
     * _loading     : Tracks whether a fresh load operation or network call is in progress.
     * _isOffline   : Indicates whether the ViewModel is currently relying on cached/offline data.
     **********************************************************************************************/
    private val _walkers: MutableStateFlow<List<User>> = MutableStateFlow(emptyList())
    private val _loading: MutableStateFlow<Boolean> = MutableStateFlow(false)
    private val _isOffline: MutableStateFlow<Boolean> = MutableStateFlow(false)

    /***********************************************************************************************
     * Publicly Exposed StateFlow Properties:
     * walkers    : A read-only Flow of currently loaded walker User objects.
     * loading    : A read-only Flow indicating if a loading operation is in progress.
     * isOffline  : A read-only Flow that signals whether data is served from offline cache.
     **********************************************************************************************/
    val walkers: StateFlow<List<User>> get() = _walkers
    val loading: StateFlow<Boolean> get() = _loading
    val isOffline: StateFlow<Boolean> get() = _isOffline

    /**
     * Local reference to store the last failed operation in a parameterless lambda for retry logic.
     * This will be set to the last function call that can be retried (e.g., loadWalkers).
     */
    private var lastFailedOperation: (() -> Unit)? = null

    init {
        /*******************************************************************************************
         * Constructor Initialization Steps:
         * 1. Restore any saved state from savedStateHandle if available.
         * 2. Initialize the walker list, loading, and offline states from previously stored data,
         *    ensuring that UI state remains consistent across process recreation.
         * 3. Optionally trigger an initial data load to populate the ViewModel with walker info.
         * 4. Setup error handling references for retryable operations if needed.
         ******************************************************************************************/

        // Restore walker data from savedStateHandle, if present
        val savedWalkers: List<User>? = savedStateHandle.get("WALKERS_SAVED_STATE")
        if (savedWalkers != null && savedWalkers.isNotEmpty()) {
            _walkers.value = savedWalkers
        }

        val savedOfflineFlag: Boolean? = savedStateHandle.get("OFFLINE_SAVED_STATE")
        if (savedOfflineFlag != null) {
            _isOffline.value = savedOfflineFlag
        }

        // We can optionally trigger an initial load from the repository or rely on the above data
        // being restored. Here, we choose to perform a non-forced load to prime data.
        CoroutineScope(Dispatchers.Main).launch {
            loadWalkers(forceRefresh = false)
        }
    }

    /**
     * loadWalkers
     *
     * Loads a verified walker list, supporting offline caching and optional forced refresh.
     *
     * Parameters:
     * @param forceRefresh Boolean flag indicating if a network call should be forced, bypassing
     *        any cached data if present.
     *
     * Steps:
     *  1. Set the loading state to true, so UI can display a progress indicator.
     *  2. Try reading cached walker data first if forceRefresh is false.
     *  3. If no cached data or forceRefresh is true, attempt to fetch from network by calling
     *     userRepository.getVerifiedWalkers(), filtering for users with userType = WALKER and
     *     isEligibleForWalking() = true.
     *  4. Handle any errors gracefully by capturing the exception and potentially marking
     *     an offline scenario.
     *  5. Save the final list of walker data and offline state into savedStateHandle to restore
     *     after process death or config changes.
     *  6. Set loading state to false upon completion.
     */
    fun loadWalkers(forceRefresh: Boolean) {
        _loading.value = true
        lastFailedOperation = { loadWalkers(forceRefresh) }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Step 2: Attempt to load from local cache if not forcing refresh
                if (!forceRefresh && _walkers.value.isNotEmpty()) {
                    // We already have cached data, mark isOffline = true
                    _isOffline.value = true
                } else {
                    // Step 3: Attempt network fetch for verified walkers
                    userRepository.getVerifiedWalkers().collect { result ->
                        result.fold(
                            onSuccess = { verifiedUsers ->
                                // Filter out only those that are actual verified "WALKER" users
                                val validWalkers = verifiedUsers.filter {
                                    it.userType == UserType.WALKER && it.isEligibleForWalking()
                                }
                                _walkers.value = validWalkers
                                _isOffline.value = false
                            },
                            onFailure = {
                                // If an error occurs, fallback to an offline scenario
                                _isOffline.value = true
                            }
                        )
                    }
                }
            } catch (e: Exception) {
                // If something goes wrong at a higher level, consider that a network or data error
                _isOffline.value = true
            } finally {
                // Step 5: Save final data states
                with(savedStateHandle) {
                    set("WALKERS_SAVED_STATE", _walkers.value)
                    set("OFFLINE_SAVED_STATE", _isOffline.value)
                }
                // Step 6: Mark loading as complete
                _loading.value = false
            }
        }
    }

    /**
     * getWalkerById
     *
     * Searches for a particular Walker by their unique ID. If not found in local state, it attempts
     * to fetch from the repository, merging offline and online data as needed.
     *
     * Parameters:
     * @param walkerId The unique string ID of the walker to be retrieved.
     *
     * Returns:
     *  A User object representing the walker if found, or null otherwise.
     *
     * Steps:
     *  1. Check the local list of walker data in _walkers.value to see if we have the user.
     *  2. If not found locally, attempt a direct repository call to retrieve user data
     *     (cached or online).
     *  3. Return the user if found; otherwise, return null.
     */
    fun getWalkerById(walkerId: String): User? {
        val localMatch = _walkers.value.firstOrNull { it.id == walkerId }
        if (localMatch != null) return localMatch

        // Fallback: Attempt to retrieve from repository if not found locally
        return try {
            // The userRepository.getUser(...) function from the provided code returns a Flow<Result<User>>
            // We can block for the immediate result to keep this function synchronous.
            var fetchedUser: User? = null
            CoroutineScope(Dispatchers.IO).launch {
                userRepository.getUser(walkerId).collect { userResult ->
                    userResult.onSuccess { successUser ->
                        // Confirm user is a valid walker
                        if (successUser.userType == UserType.WALKER && successUser.isEligibleForWalking()) {
                            fetchedUser = successUser
                        }
                    }
                }
            }.apply { this.join() }
            fetchedUser
        } catch (e: Exception) {
            null
        }
    }

    /**
     * retryFailedOperation
     *
     * Retries the last failed operation using an exponential backoff or any preferred retry policy.
     * This function references a stored lambda that captures the most recent operation capable
     * of being retried (e.g., loadWalkers with specific parameters).
     *
     * Steps:
     *  1. If lastFailedOperation is defined, launch a coroutine to execute it.
     *  2. Implement exponential backoff logic or a simpler immediate retry as needed.
     *  3. Update the state based on success/failure.
     */
    fun retryFailedOperation() {
        CoroutineScope(Dispatchers.IO).launch {
            // Example: simplistic immediate retry (no real exponential backoff)
            lastFailedOperation?.invoke()
        }
    }

    /**
     * onCleared
     *
     * Cleans up resources when the ViewModel is destroyed (e.g., when the activity or fragment
     * hosting it is finished). Cancels any ongoing coroutines, saves state to savedStateHandle,
     * and performs any required finalization steps.
     *
     * Steps:
     *  1. Perform parent class cleanup with super.onCleared().
     *  2. Cancel or finalize any ongoing asynchronous operations if needed.
     *  3. Persist final state in savedStateHandle for future restoration.
     *  4. Clear or obfuscate sensitive data.
     */
    override fun onCleared() {
        super.onCleared()
        // Step 3: Persist final state
        savedStateHandle["WALKERS_SAVED_STATE"] = _walkers.value
        savedStateHandle["OFFLINE_SAVED_STATE"] = _isOffline.value
        // Additional resource cleanup can be performed here if necessary
    }
}