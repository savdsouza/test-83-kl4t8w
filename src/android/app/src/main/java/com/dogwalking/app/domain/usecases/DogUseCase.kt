package com.dogwalking.app.domain.usecases

import javax.inject.Inject // v1
import kotlinx.coroutines.flow.Flow // v1.7.3
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.first
import kotlin.Result // v1.9.0

import com.dogwalking.app.domain.models.Dog
import com.dogwalking.app.data.repository.DogRepository

/**
 * DogUseCase provides comprehensive business logic for dog-related operations, following
 * clean architecture principles with enhanced validation, error handling, and offline support.
 *
 * This class addresses the following:
 * - Pet Profile Management (Owner/Walker profiles, Pet profiles) with validation.
 * - Offline Support via repository usage (local database, Flow-based data).
 * - Thorough error handling and result wrapping using Kotlin's Result type.
 * - Rich domain-level validations to ensure data completeness.
 *
 * @property dogRepository The injected repository for interacting with dog data in an offline-first manner.
 * @property validBreeds A list of valid and recognized dog breed names used for verification.
 * @property errorMessages A map of error keys to user-friendly or developer-oriented error messages.
 */
class DogUseCase @Inject constructor(
    private val dogRepository: DogRepository
) {

    /**
     * A predefined list of acceptable/valid dog breeds for domain-level validation.
     * Updatable if new breeds need to be supported.
     */
    private val validBreeds: List<String>

    /**
     * A map of error message templates used throughout validations for consistent
     * and centralized error communication.
     */
    private val errorMessages: Map<String, String>

    /**
     * Initializes the use case with default valid breed entries and error message templates.
     * Additional logic could be added here to load configurations from a remote or local source
     * if needed.
     */
    init {
        // Load or define a canonical list of breed names for validation checks
        validBreeds = listOf(
            "Golden Retriever", "Labrador Retriever", "German Shepherd",
            "Poodle", "Beagle", "Bulldog", "Rottweiler", "Pug",
            "Yorkshire Terrier", "Dachshund"
        )

        // Define a set of error messages that can be referenced throughout the domain logic
        errorMessages = mapOf(
            "INVALID_DOG_ID" to "The provided dog ID format is invalid.",
            "INACTIVE_DOG" to "Cannot process inactive dog profile.",
            "INVALID_AGE" to "Dog age appears invalid or out of allowable range.",
            "INVALID_MEDICAL_INFO" to "Dog medical info is incomplete or malformed.",
            "BREED_NOT_RECOGNIZED" to "The dog's breed is not in the valid breeds list.",
            "SAVE_ERROR" to "An error occurred while saving the dog profile.",
            "DEACTIVATION_ERROR" to "An error occurred while deactivating the dog profile.",
            "INVALID_OWNER_ID" to "The provided owner ID is invalid.",
            "INVALID_PAGE_PARAMS" to "Page or pageSize parameters are invalid.",
            "SPECIAL_INSTRUCTIONS_TOO_LONG" to "Special instructions exceed character limits.",
            "FUTURE_WALKS_CANCEL_ERROR" to "Could not cancel associated future walks.",
            "AUDIT_TRAIL_ERROR" to "Audit logging failed during dog deactivation."
        )
    }

    /**
     * Validates and retrieves dog information by its unique identifier with enhanced
     * error handling. The returned Flow emits a Result-wrapped Dog object or null if not found.
     *
     * Steps:
     * 1. Validate dogId format using UUID-check or regex.
     * 2. Check dog existence in repository.
     * 3. Validate dog active status.
     * 4. Verify age calculation validity.
     * 5. Check medical information completeness.
     * 6. Return Flow with comprehensive Result wrapper.
     *
     * @param dogId The unique ID of the dog to retrieve and validate.
     * @return A [Flow] emitting [Result<Dog?>], representing either a valid dog, null if not found, or an error.
     */
    fun getDog(dogId: String): Flow<Result<Dog?>> {
        return if (!isValidUuid(dogId)) {
            // Immediately emit an error if the dogId is invalid
            flow {
                emit(Result.failure(Exception(errorMessages["INVALID_DOG_ID"])))
            }
        } else {
            dogRepository.getDog(dogId).map { repositoryResult ->
                if (repositoryResult.isFailure) {
                    // Propagate the repository error as-is
                    repositoryResult
                } else {
                    val fetchedDog = repositoryResult.getOrNull()
                    if (fetchedDog == null) {
                        // No dog found for the given ID
                        Result.success(null)
                    } else {
                        // Additional domain-level validations
                        if (!fetchedDog.active) {
                            return@map Result.failure(
                                Exception(errorMessages["INACTIVE_DOG"])
                            )
                        }
                        val age = fetchedDog.getAge()
                        if (age < 0 || age > 35) {
                            return@map Result.failure(
                                Exception(errorMessages["INVALID_AGE"])
                            )
                        }
                        if (!isMedicalInfoComplete(fetchedDog.medicalInfo)) {
                            return@map Result.failure(
                                Exception(errorMessages["INVALID_MEDICAL_INFO"])
                            )
                        }
                        // If all checks pass, return the dog
                        Result.success(fetchedDog)
                    }
                }
            }.catch { exception ->
                emit(Result.failure(exception))
            }
        }
    }

    /**
     * Retrieves a filtered and sorted list of a specific owner's dogs with pagination support.
     * Results are returned in a [Flow] wrapped with [Result]. This includes applying an optional
     * search query via the repository if present, filtering active dogs, sorting by name, and
     * finally paging the list.
     *
     * Steps:
     * 1. Validate ownerId format.
     * 2. Apply pagination parameters.
     * 3. Filter active dogs.
     * 4. Apply search query if provided (uses a hypothetical 'searchDogs' method in the repository).
     * 5. Sort dogs by name.
     * 6. Return Flow with paginated results.
     *
     * @param ownerId The unique ID of the owner whose dogs are being retrieved.
     * @param page The page index (0-based) for pagination.
     * @param pageSize The number of items to include per page.
     * @param searchQuery An optional search term to filter dogs by name or other criteria.
     * @return A [Flow] emitting [Result<List<Dog>>], handling data retrieval, sorting, and pagination.
     */
    fun getOwnerDogs(
        ownerId: String,
        page: Int,
        pageSize: Int,
        searchQuery: String?
    ): Flow<Result<List<Dog>>> {
        if (!isValidUuid(ownerId)) {
            return flow {
                emit(Result.failure(Exception(errorMessages["INVALID_OWNER_ID"])))
            }
        }
        if (page < 0 || pageSize <= 0) {
            return flow {
                emit(Result.failure(Exception(errorMessages["INVALID_PAGE_PARAMS"])))
            }
        }

        // If a search query is provided, assume a "searchDogs" method on the repository
        val baseFlow = if (!searchQuery.isNullOrBlank()) {
            dogRepository.searchDogs(ownerId, searchQuery)
        } else {
            dogRepository.getOwnerDogs(ownerId)
        }

        return baseFlow.map { repositoryResult ->
            if (repositoryResult.isFailure) {
                repositoryResult
            } else {
                // Retrieve the list from the success result
                val dogList = repositoryResult.getOrDefault(emptyList())
                // Filter only active dogs
                val activeDogs = dogList.filter { it.active }
                // Sort by name
                val sortedDogs = activeDogs.sortedBy { it.name }
                // Apply pagination
                val startIndex = page * pageSize
                val endIndex = (startIndex + pageSize).coerceAtMost(sortedDogs.size)
                if (startIndex >= sortedDogs.size) {
                    // No more items beyond this page
                    Result.success(emptyList())
                } else {
                    Result.success(sortedDogs.subList(startIndex, endIndex))
                }
            }
        }.catch { exception ->
            emit(Result.failure(exception))
        }
    }

    /**
     * Validates and saves dog information with comprehensive checks. Returns a suspended
     * [Result<Boolean>] indicating success or an error.
     *
     * Steps:
     * 1. Validate required fields completeness.
     * 2. Verify breed against valid breeds list.
     * 3. Validate medical information format.
     * 4. Check special instructions length and format.
     * 5. Verify age constraints.
     * 6. Save dog using the repository with error handling.
     * 7. Return Result with detailed status.
     *
     * @param dog The dog domain model to validate and save.
     * @return [Result<Boolean>] indicating operation success or failure with details.
     */
    suspend fun saveDog(dog: Dog): Result<Boolean> {
        return try {
            // 1. Basic field completeness checks have also been enforced in Dog's init block, but reaffirm here:
            if (dog.name.isBlank() || dog.id.isBlank() || dog.breed.isBlank()) {
                return Result.failure(Exception(errorMessages["SAVE_ERROR"]))
            }

            // 2. Verify breed
            if (!validBreeds.contains(dog.breed)) {
                return Result.failure(Exception(errorMessages["BREED_NOT_RECOGNIZED"]))
            }

            // 3. Validate medical info
            if (!isMedicalInfoComplete(dog.medicalInfo)) {
                return Result.failure(Exception(errorMessages["INVALID_MEDICAL_INFO"]))
            }

            // 4. Check special instructions (e.g. limit each to 200 chars)
            val tooLongInstruction = dog.specialInstructions.firstOrNull { it.length > 200 }
            if (tooLongInstruction != null) {
                return Result.failure(Exception(errorMessages["SPECIAL_INSTRUCTIONS_TOO_LONG"]))
            }

            // 5. Verify age constraints (dog should not have negative or unrealistic age)
            val age = dog.getAge()
            if (age < 0 || age > 35) {
                return Result.failure(Exception(errorMessages["INVALID_AGE"]))
            }

            // 6. Save dog in repository
            val saveResult = dogRepository.saveDog(dog)
            if (saveResult.isFailure) {
                return Result.failure(Exception(errorMessages["SAVE_ERROR"], saveResult.exceptionOrNull()))
            }
            saveResult
        } catch (ex: Exception) {
            Result.failure(Exception(errorMessages["SAVE_ERROR"], ex))
        }
    }

    /**
     * Handles dog profile deactivation with associated cleanup. This is typically done
     * when an owner or system admin decides to remove or temporarily disable a dog's
     * profile from active listings.
     *
     * Steps:
     * 1. Validate dogId format.
     * 2. Check current dog status.
     * 3. Record deactivation reason.
     * 4. Cancel associated future walks (placeholder logic).
     * 5. Execute soft delete in repository.
     * 6. Log audit trail.
     * 7. Return Result with operation status.
     *
     * @param dogId The unique string identifier of the dog to deactivate.
     * @param reason The reason provided for deactivation (used for auditing).
     * @return [Result<Boolean>] indicating whether the deactivation process succeeded.
     */
    suspend fun deactivateDog(dogId: String, reason: String): Result<Boolean> {
        return try {
            if (!isValidUuid(dogId)) {
                return Result.failure(Exception(errorMessages["INVALID_DOG_ID"]))
            }

            // 2. Check current dog status
            val dogFlow = dogRepository.getDog(dogId)
            val dogResult = dogFlow.first() // collect one emission
            if (dogResult.isFailure) {
                return dogResult.mapCatching { false }
            }
            val dogData = dogResult.getOrNull()
                ?: return Result.success(false) // if dog doesn't exist, return success(false)

            if (!dogData.active) {
                // If already inactive, we exit early with success
                return Result.success(true)
            }

            // 3. Record deactivation reason (Placeholder: log for now)
            // In a real system, this might be persisted in an audit trail or a separate table.
            // For demonstration:
            // e.g., logger.info("Deactivating dog $dogId due to: $reason")

            // 4. Cancel associated future walks (Placeholder)
            // Possibly we call a scheduling service or walk service to cancel upcoming sessions.
            // If that call fails, we can return an error:
            // return Result.failure(Exception(errorMessages["FUTURE_WALKS_CANCEL_ERROR"]))

            // 5. Execute soft delete in repository
            val deleteResult = dogRepository.deleteDog(dogId)
            if (deleteResult.isFailure) {
                return Result.failure(Exception(errorMessages["DEACTIVATION_ERROR"], deleteResult.exceptionOrNull()))
            }
            val deleted = deleteResult.getOrDefault(false)

            // 6. Log audit trail (Placeholder)
            // More robust systems might store an event in an auditing microservice or local log.
            // If this fails, we could return an error:
            // return Result.failure(Exception(errorMessages["AUDIT_TRAIL_ERROR"]))

            // 7. Return final operation status
            Result.success(deleted)
        } catch (ex: Exception) {
            Result.failure(Exception(errorMessages["DEACTIVATION_ERROR"], ex))
        }
    }

    /**
     * Checks whether a provided string conforms to a UUID format. This function can be
     * updated or swapped for library-based checks as needed.
     *
     * @param possibleUuid The string to validate.
     * @return True if the string is in a valid UUID format, false otherwise.
     */
    private fun isValidUuid(possibleUuid: String): Boolean {
        return runCatching {
            java.util.UUID.fromString(possibleUuid)
            true
        }.getOrDefault(false)
    }

    /**
     * Checks that a dog's medical information is sufficiently complete. This demonstration
     * simply checks if the map is not null. In real scenarios, you might enforce certain keys
     * or ensure that values are non-empty.
     *
     * @param medicalInfo The dog's medical info map to validate.
     * @return True if the info is (in this demonstration) non-empty or non-null.
     */
    private fun isMedicalInfoComplete(medicalInfo: Map<String, String>?): Boolean {
        return !medicalInfo.isNullOrEmpty()
    }
}