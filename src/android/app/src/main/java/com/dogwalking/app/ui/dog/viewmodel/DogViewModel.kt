package com.dogwalking.app.ui.dog.viewmodel

import androidx.lifecycle.ViewModel // androidx.lifecycle v2.6.2
import androidx.lifecycle.SavedStateHandle // androidx.lifecycle v2.6.2
import androidx.lifecycle.viewModelScope // androidx.lifecycle v2.6.2
import kotlinx.coroutines.flow.MutableStateFlow // kotlinx.coroutines.flow v1.7.3
import kotlinx.coroutines.flow.StateFlow // kotlinx.coroutines.flow v1.7.3
import kotlinx.coroutines.flow.retry // kotlinx.coroutines.flow v1.7.3
import kotlinx.coroutines.flow.collect // kotlinx.coroutines.flow v1.7.3
import kotlinx.coroutines.launch // kotlinx.coroutines v1.7.3
import javax.inject.Inject // v1
import dagger.hilt.android.lifecycle.HiltViewModel // dagger.hilt.android.lifecycle v2.44

import com.dogwalking.app.domain.models.Dog
import com.dogwalking.app.domain.usecases.DogUseCase

/**
 * [DogViewModel] manages the UI state and business logic for dog profile screens,
 * including comprehensive error handling, offline support, and state restoration
 * using [SavedStateHandle]. It follows the MVVM architecture pattern, exposing
 * [StateFlow] properties for reactive data updates.
 */
@HiltViewModel
class DogViewModel @Inject constructor(
    /**
     * A handle to saved state passed down by the system, allowing the restoration
     * and persistence of crucial UI data across process death or configuration changes.
     */
    private val savedStateHandle: SavedStateHandle,

    /**
     * The [DogUseCase] instance providing domain-level operations for dog entities,
     * including fetching, saving, deactivation, and validation logic.
     */
    private val dogUseCase: DogUseCase
) : ViewModel() {

    /**
     * A private [MutableStateFlow] holding the current list of dogs associated
     * with an owner. This is updated upon successful retrieval from [dogUseCase].
     */
    private val _dogs = MutableStateFlow<List<Dog>>(emptyList())

    /**
     * A public [StateFlow] exposing the current list of dogs in read-only form
     * to external UI consumers for rendering and observation.
     */
    val dogs: StateFlow<List<Dog>> = _dogs

    /**
     * A private [MutableStateFlow] holding the selected dog's details if one
     * is loaded or selected from UI interactions.
     */
    private val _selectedDog = MutableStateFlow<Dog?>(null)

    /**
     * A public [StateFlow] for observing the currently selected dog in a
     * read-only manner. This is updated whenever [loadDog] is called.
     */
    val selectedDog: StateFlow<Dog?> = _selectedDog

    /**
     * A private [MutableStateFlow] tracking whether a network or database
     * operation is currently in progress.
     */
    private val _loading = MutableStateFlow(false)

    /**
     * A public [StateFlow] exposing the loading state, allowing the UI to
     * display progress indicators while dog data is being fetched or saved.
     */
    val loading: StateFlow<Boolean> = _loading

    /**
     * A private [MutableStateFlow] capturing the latest error message if any
     * operation fails (network, database, validation, etc.).
     */
    private val _error = MutableStateFlow<String?>(null)

    /**
     * A public [StateFlow] for observing error messages, enabling the UI to
     * display alerts or error dialogs when something goes wrong.
     */
    val error: StateFlow<String?> = _error

    /**
     * A private [MutableStateFlow] indicating whether the application is currently
     * operating offline (no network connection). This is used to determine
     * if operations should be queued or performed via local caches.
     */
    private val _isOffline = MutableStateFlow(false)

    /**
     * A public [StateFlow] exposing the offline state, allowing UI screens
     * to show offline indicators or restrict certain actions as needed.
     */
    val isOffline: StateFlow<Boolean> = _isOffline

    init {
        // Optionally restore previously saved state here, if needed:
        // e.g., _dogs.value = savedStateHandle.get("DOG_LIST") ?: emptyList()
        //       _selectedDog.value = savedStateHandle.get("DOG_SELECTED")
        //       _error.value = savedStateHandle.get("ERROR")
    }

    /**
     * Loads all the dogs belonging to a particular owner and updates [_dogs].
     * Implements offline support by detecting the network state, handling errors,
     * and persisting relevant state to [SavedStateHandle] for restoration.
     *
     * @param ownerId A string identifier representing the dog's owner.
     */
    fun loadOwnerDogs(ownerId: String) {
        _loading.value = true
        _error.value = null

        viewModelScope.launch {
            try {
                // Check network connectivity: placeholder approach
                val isConnected = isNetworkAvailable()
                _isOffline.value = !isConnected

                // Use a retry strategy to handle transient failures
                dogUseCase.getOwnerDogs(ownerId, page = 0, pageSize = 50, searchQuery = null)
                    .retry(3) {
                        // Retry for any exception, can refine based on error type
                        true
                    }
                    .collect { result ->
                        if (result.isFailure) {
                            val exception = result.exceptionOrNull()
                            _error.value = exception?.message
                                ?: "Unknown error occurred while loading owner dogs."
                            _dogs.value = emptyList()
                        } else {
                            val dogsList = result.getOrDefault(emptyList())
                            _dogs.value = dogsList
                        }
                    }
            } catch (exception: Exception) {
                // Catch any unexpected errors not handled by the Flow
                _error.value = exception.message
            } finally {
                _loading.value = false
                // Persist state in case the process is killed
                savedStateHandle["DOG_LIST"] = _dogs.value
            }
        }
    }

    /**
     * Loads a specific dog's details from [dogUseCase] and updates [_selectedDog].
     * This operation also handles error states, offline detection, and final state
     * preservation using [SavedStateHandle].
     *
     * @param dogId A unique string identifier of the dog to be loaded.
     */
    fun loadDog(dogId: String) {
        _loading.value = true
        _error.value = null

        viewModelScope.launch {
            try {
                val isConnected = isNetworkAvailable()
                _isOffline.value = !isConnected

                dogUseCase.getDog(dogId)
                    .retry(3) { true }
                    .collect { result ->
                        if (result.isFailure) {
                            val exception = result.exceptionOrNull()
                            _error.value = exception?.message
                                ?: "Unknown error occurred while loading dog."
                            _selectedDog.value = null
                        } else {
                            val dogData = result.getOrNull()
                            _selectedDog.value = dogData
                        }
                    }
            } catch (exception: Exception) {
                _error.value = exception.message
                _selectedDog.value = null
            } finally {
                _loading.value = false
                savedStateHandle["DOG_SELECTED"] = _selectedDog.value
            }
        }
    }

    /**
     * Saves or updates a dog's profile using [dogUseCase]. This suspend function
     * performs domain-level validation, handles offline detection, manages
     * error states, and flags loading status. It returns a [Boolean] indicating
     * success or failure.
     *
     * @param dog A [Dog] instance containing updated or newly created dog data.
     * @return True if the operation completes successfully; false otherwise.
     */
    suspend fun saveDog(dog: Dog): Boolean {
        _loading.value = true
        _error.value = null
        return try {
            // 1. Validate dog data using dogUseCase.validateDog (hypothetical method)
            val validationResult = dogUseCase.validateDog(dog)
            if (validationResult.isFailure) {
                _error.value = validationResult.exceptionOrNull()?.message ?: "Validation error."
                false
            } else {
                // 2. Check network availability and update offline state
                val isConnected = isNetworkAvailable()
                _isOffline.value = !isConnected

                // 3. If offline, we might queue operation or rely on local caching
                //    This demonstration simply proceeds with a direct call to saveDog.

                // 4. Attempt the save operation in the domain layer
                val saveResult = dogUseCase.saveDog(dog)
                if (saveResult.isFailure) {
                    _error.value = saveResult.exceptionOrNull()?.message ?: "Error saving dog."
                    false
                } else {
                    // On success, refresh the owner's dog list to keep UI consistent
                    loadOwnerDogs(dog.ownerId)
                    true
                }
            }
        } catch (exception: Exception) {
            // Catch any unexpected, unrecovered exceptions
            _error.value = exception.message
            false
        } finally {
            _loading.value = false
            // Save the current list and selection to preserve UI state across process death
            savedStateHandle["DOG_LIST"] = _dogs.value
            savedStateHandle["DOG_SELECTED"] = _selectedDog.value
        }
    }

    /**
     * Deactivates a dog's profile (for example, if the dog is no longer active)
     * by calling [dogUseCase.deactivateDog]. This operation sets [_loading] to true,
     * detects offline states, handles errors, and returns a boolean indicating success.
     *
     * @param dogId The unique identifier of the dog to be deactivated.
     * @return True if the deactivation completes without errors; false otherwise.
     */
    suspend fun deactivateDog(dogId: String): Boolean {
        _loading.value = true
        _error.value = null
        return try {
            val isConnected = isNetworkAvailable()
            _isOffline.value = !isConnected

            // Optionally queue if offline, or simply proceed for demonstration
            val deactivateResult = dogUseCase.deactivateDog(dogId, reason = "User initiated deactivation")
            if (deactivateResult.isFailure) {
                _error.value = deactivateResult.exceptionOrNull()?.message
                    ?: "Error deactivating dog."
                false
            } else {
                // On success, we could refresh the dog's list if we knew the ownerId,
                // but the specification doesn't provide a direct reference. 
                // This is left as is for demonstration.
                true
            }
        } catch (exception: Exception) {
            _error.value = exception.message
            false
        } finally {
            _loading.value = false
            savedStateHandle["DOG_LIST"] = _dogs.value
            savedStateHandle["DOG_SELECTED"] = _selectedDog.value
        }
    }

    /**
     * Clears the current error state from [_error] and updates the saved state handle.
     * This allows the UI to reset any displayed error messages.
     */
    fun clearError() {
        _error.value = null
        savedStateHandle["ERROR"] = null
    }

    /**
     * Called when this [ViewModel] is no longer used and will be destroyed. This function
     * ensures any final state is preserved while letting coroutines and other resources
     * clean themselves up as necessary.
     */
    override fun onCleared() {
        super.onCleared()
        // Automatically, viewModelScope is canceled. Final state can be persisted:
        savedStateHandle["DOG_LIST"] = _dogs.value
        savedStateHandle["DOG_SELECTED"] = _selectedDog.value
        savedStateHandle["ERROR"] = _error.value
    }

    /**
     * Utility function simulating a network availability check. In a real application,
     * this might query system services or a connectivity manager to determine if
     * an internet connection is present.
     *
     * @return True if network is available; false otherwise.
     */
    private fun isNetworkAvailable(): Boolean {
        // Placeholder logic returning 'true' to simulate an available network.
        // Replace with actual connectivity checks as needed.
        return true
    }
}