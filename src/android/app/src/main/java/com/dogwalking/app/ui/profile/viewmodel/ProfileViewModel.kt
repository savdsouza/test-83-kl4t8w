package com.dogwalking.app.ui.profile.viewmodel

/***************************************************************************************************
 * External Imports with Specified Library Versions
 **************************************************************************************************/
import androidx.lifecycle.ViewModel // androidx.lifecycle version 2.6.1
import androidx.lifecycle.viewModelScope // androidx.lifecycle version 2.6.1
import androidx.lifecycle.SavedStateHandle // androidx.lifecycle version 2.6.1
import dagger.hilt.android.lifecycle.HiltViewModel // dagger.hilt.android.lifecycle version 2.44.2
import javax.inject.Inject // javax.inject version 1

import kotlinx.coroutines.flow.MutableStateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.StateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/***************************************************************************************************
 * Internal Imports
 **************************************************************************************************/
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.data.repository.UserRepository

/***************************************************************************************************
 * Enum Class: SyncState
 * Represents the synchronization state used in this ViewModel, mapping closely to the repository's
 * sync status while maintaining a clear separation of concerns at the UI layer.
 **************************************************************************************************/
enum class SyncState {
    /**
     * IDLE indicates no current synchronization activity.
     */
    IDLE,

    /**
     * IN_PROGRESS indicates a sync operation is currently ongoing.
     */
    IN_PROGRESS,

    /**
     * SUCCESS indicates the last sync completed successfully.
     */
    SUCCESS,

    /**
     * ERROR indicates the last sync attempt encountered an error.
     */
    ERROR
}

/***************************************************************************************************
 * @HiltViewModel
 * ProfileViewModel
 *
 * This ViewModel class is responsible for managing user profile data and offline-first operations
 * in the dog walking application. It leverages real-time updates through StateFlow, handling
 * synchronization between local and remote data sources via the UserRepository. Error handling is
 * robust and integrated with the lifecycle-aware coroutine scope to maintain reliability and
 * transparency for UI consumers.
 **************************************************************************************************/
@HiltViewModel
class ProfileViewModel @Inject constructor(
    /**
     * UserRepository instance that provides offline-first data handling and synchronization methods
     * for user profile management. Injected via Hilt for dependency management.
     */
    private val userRepository: UserRepository,

    /**
     * SavedStateHandle for preserving and restoring state across process death. This can be used to
     * save critical data that should survive configuration changes or background/foreground cycles.
     */
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {

    // ---------------------------------------------------------------------------------------------
    // Backing properties for user profile data, loading state, error messages, and sync state.
    // These properties are exposed to external consumers via immutable StateFlow interfaces.
    // ---------------------------------------------------------------------------------------------

    /**
     * Backing field for user profile state. Holds the current User object or null if none is loaded.
     */
    private val _userProfile: MutableStateFlow<User?> = MutableStateFlow(null)
    /**
     * Publicly exposed StateFlow to observe user profile changes in real time.
     */
    val userProfile: StateFlow<User?> = _userProfile

    /**
     * Backing field for indicating whether the ViewModel is in a loading state.
     */
    private val _isLoading: MutableStateFlow<Boolean> = MutableStateFlow(false)
    /**
     * Publicly exposed StateFlow for UI elements to show progress bars or disable controls.
     */
    val isLoading: StateFlow<Boolean> = _isLoading

    /**
     * Backing field for current error messages. Holds either a string with an error message or null.
     */
    private val _error: MutableStateFlow<String?> = MutableStateFlow(null)
    /**
     * Publicly exposed StateFlow to observe error messages. The UI can display them in dialogs or
     * toast notifications.
     */
    val error: StateFlow<String?> = _error

    /**
     * Backing field for synchronization state. Reflects the real-time status of profile data sync.
     */
    private val _syncState: MutableStateFlow<SyncState> = MutableStateFlow(SyncState.IDLE)
    /**
     * Publicly exposed StateFlow that allows external UI components to observe ongoing sync state.
     */
    val syncState: StateFlow<SyncState> = _syncState

    // ---------------------------------------------------------------------------------------------
    // Initialization block where we set up collection of user repository syncStatus and attempt
    // to restore any saved profile state. Additionally, we initialize error handling scaffolding.
    // ---------------------------------------------------------------------------------------------
    init {
        // Step 1: Observe the repository's syncStatus to update _syncState in real time.
        viewModelScope.launch {
            userRepository.syncStatus.collect { repoStatus ->
                // Map repository's internal states to the ViewModel's SyncState enum.
                // The repository uses (IDLE, SYNCING, SUCCESS, ERROR).
                // We map SYNCING -> IN_PROGRESS for consistent naming in the UI layer.
                val mappedState = when (repoStatus.name) {
                    "IDLE" -> SyncState.IDLE
                    "SYNCING" -> SyncState.IN_PROGRESS
                    "SUCCESS" -> SyncState.SUCCESS
                    "ERROR" -> SyncState.ERROR
                    else -> SyncState.IDLE
                }
                _syncState.value = mappedState
            }
        }

        // Step 2: Attempt to restore user profile from SavedStateHandle if any was saved previously.
        // This is an example of how one might restore state, but it can be more elaborate in practice.
        val restoredUser: User? = savedStateHandle.get("PROFILE_VIEWMODEL_USER")
        if (restoredUser != null) {
            _userProfile.value = restoredUser
        }

        // Step 3: Initialize error handling or additional setup if required (placeholder).
        // E.g., register an error logger or set up advanced analytics tracking.
    }

    // ---------------------------------------------------------------------------------------------
    // Function: loadUserProfile
    // Description: Fetches user profile data from the repository, using an offline-first approach.
    // It updates the loading state, clears any previous error, collects user data from the flow,
    // and finally updates the user profile for the UI.
    //
    // Parameters:
    //   userId: String - The unique identifier of the user to load.
    // Returns: Unit
    // ---------------------------------------------------------------------------------------------
    fun loadUserProfile(userId: String) {
        // Step 1: Indicate the start of a loading operation.
        _isLoading.value = true
        _error.value = null

        // Step 2: Launch a coroutine in the ViewModel's lifecycle-aware scope.
        viewModelScope.launch {
            try {
                // Step 3: Collect user data from the repository in an offline-first manner.
                userRepository.getUser(userId).collect { result ->
                    result.fold(
                        onSuccess = { userData ->
                            // Update the user profile flow with new data.
                            _userProfile.value = userData

                            // Step 4: Save the user profile state to SavedStateHandle for restoration if needed.
                            savedStateHandle["PROFILE_VIEWMODEL_USER"] = userData
                        },
                        onFailure = { throwable ->
                            // Step 5: Capture and expose the error to the UI layer.
                            _error.value = throwable.message
                        }
                    )
                }
            } catch (exception: Exception) {
                // Handle any unexpected exceptions in the data collection pipeline.
                _error.value = exception.message
            } finally {
                // Step 6: Mark loading as complete regardless of success or failure.
                _isLoading.value = false
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Function: updateUserProfile
    // Description: Updates the user profile with new data (e.g., changed phone number or name)
    // using offline-first approach. Handles validation, triggers background synchronization, and
    // provides robust error handling for conflict resolution or network errors.
    //
    // Parameters:
    //   updatedUser: User - The updated user domain model containing new profile fields.
    // Returns: Unit
    // ---------------------------------------------------------------------------------------------
    fun updateUserProfile(updatedUser: User) {
        // Step 1: Validate essential input fields before proceeding.
        if (updatedUser.id.isBlank()) {
            _error.value = "Cannot update profile: Invalid user ID."
            return
        }

        // Step 2: Indicate the start of an update operation.
        _isLoading.value = true
        _error.value = null

        // Step 3: Launch a coroutine to perform the repository update call.
        viewModelScope.launch {
            try {
                val updateResult = userRepository.updateUser(updatedUser)
                updateResult.fold(
                    onSuccess = { finalUser ->
                        // Step 4a: On success, update local user profile state.
                        _userProfile.value = finalUser
                        savedStateHandle["PROFILE_VIEWMODEL_USER"] = finalUser

                        // Step 4b: Optionally trigger background sync if we're online.
                        // For demonstration, we show a placeholder check.
                        if (isNetworkAvailable()) {
                            userRepository.syncUserData()
                        }
                    },
                    onFailure = { error ->
                        // Step 5: Capture and expose any error that occurred during the update.
                        _error.value = error.message
                    }
                )
            } catch (e: Exception) {
                // Handle exceptions that might occur during remote or local operations.
                _error.value = e.message
            } finally {
                // Step 6: Mark loading as complete after attempting the update.
                _isLoading.value = false
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Function: syncProfile
    // Description: Explicitly forces synchronization of profile data with the server. Checks network
    // availability, sets sync state, invokes the repository sync method, and handles conflicts or
    // errors. Useful in cases where the UI wants to manually synchronize user data.
    //
    // Parameters: None
    // Returns: Unit
    // ---------------------------------------------------------------------------------------------
    fun syncProfile() {
        // Step 1: Check network connectivity first.
        if (!isNetworkAvailable()) {
            _error.value = "No network connection available for syncing."
            return
        }

        // Step 2: Set sync state to IN_PROGRESS and clear any existing error.
        _syncState.value = SyncState.IN_PROGRESS
        _error.value = null

        // Step 3: Perform the synchronization in the ViewModel scope.
        viewModelScope.launch {
            try {
                // Step 4: The repository handles the actual logic. This call can handle conflicts.
                userRepository.syncUserData()
                // The repository’s internal syncStatus flow will update _syncState automatically.
            } catch (syncException: Exception) {
                // Step 5: If a sync error occurs, reflect it in the error message.
                _error.value = syncException.message
                _syncState.value = SyncState.ERROR
            } finally {
                // If the repository signals success, _syncState will be updated to SUCCESS in init block.
                // Otherwise, remain in error state. This block is mainly for final cleanups if needed.
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Function: onCleared
    // Description: Overridden lifecycle method for releasing resources when this ViewModel is about
    // to be destroyed. Cancels ongoing coroutines, clears state if necessary, and saves data that
    // must persist. This ensures no resource leaks or untracked states remain after the ViewModel’s
    // lifecycle ends.
    //
    // Parameters: None
    // Returns: Unit
    // ---------------------------------------------------------------------------------------------
    override fun onCleared() {
        // Step 1: Perform any resource cleanup or final state saving.
        // e.g. cached data or unsaved changes to user profile.

        // Step 2: Invoke the superclass onCleared method to ensure standard cleanup.
        super.onCleared()
    }

    // ---------------------------------------------------------------------------------------------
    // Private Helper Function: isNetworkAvailable
    // Description: Placeholder network connectivity check. In a real application, this might query
    // a connectivity manager or specialized utility class to confirm host reachability.
    //
    // @return Boolean indicating if the device has usable network connectivity.
    // ---------------------------------------------------------------------------------------------
    private fun isNetworkAvailable(): Boolean {
        // In production, implement a robust connectivity check. This is a stub for demonstration.
        return true
    }
}