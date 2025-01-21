package com.dogwalking.app.data.repository

/**
 * DogRepository.kt
 *
 * This file implements the DogRepository class, a repository class that utilizes an offline-first
 * architecture pattern for managing dog data. It operates with a local Room database and provides
 * reactive data flows for reading dog data, along with comprehensive error handling and data
 * consistency checks. All interactions with the underlying DogDao are conducted within the context
 * of Kotlin coroutines and returned as either Flows or suspendable operations to enable asynchronous
 * and efficient data processing.
 */

// ---------------------------------------------------------------------------------
// External Imports with Version Comments
// ---------------------------------------------------------------------------------
import javax.inject.Inject // v1

import kotlinx.coroutines.flow.Flow // v1.7.3
import kotlinx.coroutines.flow.map // v1.7.3
import kotlinx.coroutines.flow.catch // v1.7.3
import kotlinx.coroutines.flow.flowOn // v1.7.3
import kotlinx.coroutines.withContext // v1.7.3
import kotlinx.coroutines.Dispatchers // v1.7.3

// ---------------------------------------------------------------------------------
// Internal Imports
// ---------------------------------------------------------------------------------
import com.dogwalking.app.domain.models.Dog
import com.dogwalking.app.data.database.entities.DogEntity
import com.dogwalking.app.data.database.dao.DogDao

/**
 * Repository class implementing offline-first pattern for dog data management,
 * with robust error handling, data consistency checks, and reactive programming support.
 *
 * This class satisfies the following requirements:
 * 1. Offline Support: By leveraging a local Room database. (Referenced in the technical specs)
 * 2. Pet Profile Management: Managing dog records including retrieval, creation, update,
 *    and soft-delete operations.
 */
class DogRepository @Inject constructor(
    /**
     * DogDao is injected through the constructor to be used for all
     * local database operations involving DogEntity. This ensures
     * separation of concerns and testability.
     */
    private val dogDao: DogDao
) {

    /**
     * Retrieves a dog by its unique identifier as a Flow<Result<Dog?>>.
     *
     * The Flow emits:
     *   - Result.success(Dog) if found and successfully mapped.
     *   - Result.success(null) if no matching record is found.
     *   - Result.failure(exception) if any database or mapping error occurs.
     *
     * @param id The string identifier of the dog to retrieve.
     * @return A Flow that emits the requested dog wrapped in a Result, or null if not found.
     *
     * Steps:
     * 1. Validate the input parameter (id).
     * 2. Query the local database via dogDao.getDogById().
     * 3. Map the nullable DogEntity to a Dog domain model when not null.
     * 4. Wrap the emitted value in a Result object.
     * 5. Catch exceptions and emit them as Result.failure.
     * 6. Execute the flow on an IO dispatcher for non-blocking DB operations.
     */
    fun getDog(id: String): Flow<Result<Dog?>> {
        require(id.isNotBlank()) { "Dog ID parameter cannot be blank." }

        return dogDao.getDogById(id)
            .map { dogEntity: DogEntity? ->
                try {
                    if (dogEntity != null) {
                        // Convert entity to a domain model
                        Result.success(dogEntity.toDomainModel())
                    } else {
                        // Emit a null domain model if not found
                        Result.success(null)
                    }
                } catch (exception: Exception) {
                    // Wrap any failures in a Result.failure
                    Result.failure(exception)
                }
            }
            .catch { exception ->
                // In case of database or flow-related exceptions
                emit(Result.failure(exception))
            }
            .flowOn(Dispatchers.IO)
    }

    /**
     * Retrieves all active dogs for a specific owner, returning them as a Flow<Result<List<Dog>>>.
     *
     * The Flow emits:
     *   - Result.success(listOfDogs) for a successful local database query.
     *   - Result.success(emptyList()) if no records match.
     *   - Result.failure(exception) for any errors encountered.
     *
     * @param ownerId The owner's unique string identifier.
     * @return A Flow that emits a list of active dog's domain models wrapped in a Result.
     *
     * Steps:
     * 1. Validate the ownerId parameter.
     * 2. Query the local database for all dogs belonging to the owner.
     * 3. Filter the list to include only active dogs.
     * 4. Convert each DogEntity to the Dog domain model.
     * 5. Wrap the list in a Result object.
     * 6. Catch exceptions and handle them as Result.failure.
     * 7. Execute the flow on an IO dispatcher.
     */
    fun getOwnerDogs(ownerId: String): Flow<Result<List<Dog>>> {
        require(ownerId.isNotBlank()) { "Owner ID parameter cannot be blank." }

        return dogDao.getDogsByOwnerId(ownerId)
            .map { dogEntities: List<DogEntity> ->
                try {
                    // Filter for active dogs
                    val activeDogEntities = dogEntities.filter { it.active }
                    // Map Entity to Domain Model
                    val domainModels = activeDogEntities.map { it.toDomainModel() }
                    Result.success(domainModels)
                } catch (exception: Exception) {
                    Result.failure(exception)
                }
            }
            .catch { exception ->
                emit(Result.failure(exception))
            }
            .flowOn(Dispatchers.IO)
    }

    /**
     * Saves or updates a dog record in the local database, returning a suspendable
     * Result<Boolean> indicating success or failure.
     *
     * If the record already exists, it will be updated. Otherwise, a new record
     * is inserted. Exceptions are caught and returned within a Result.failure
     * to ensure robust error handling.
     *
     * @param dog The Dog domain model to be saved or updated.
     * @return A Result<Boolean> indicating the success or failure of the operation.
     *
     * Steps:
     * 1. Validate dog data for completeness (already checked by Dog model, but we ensure sanity here).
     * 2. Convert domain model (Dog) to DogEntity.
     * 3. Check if the record exists in the database.
     * 4. Insert if not found, otherwise update.
     * 5. Catch and handle database errors, wrapping them in a Result.
     * 6. Return a successful or failed Result accordingly.
     * 7. Execute on Dispatchers.IO for I/O off the main thread.
     */
    suspend fun saveDog(dog: Dog): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            // Basic validation checks (the Dog domain model constructor enforces further constraints)
            require(dog.id.isNotBlank()) { "Dog ID cannot be blank for saveDog operation." }

            val entityToSave: DogEntity = dog.toEntity()

            // Attempt to see if the entity is already present
            // We leverage a Flow-based read, converting it to a single emission
            val existingEntity = dogDao.getDogById(dog.id).map { it }.catch { }.firstOrNull()

            if (existingEntity == null) {
                // Insert new entity
                val insertResult = dogDao.insertDog(entityToSave)
                if (insertResult == -1L) {
                    return@withContext Result.failure<Boolean>(
                        IllegalStateException("Insert operation returned -1, indicating failure.")
                    )
                }
            } else {
                // Update existing entity
                val updateRows = dogDao.updateDog(entityToSave)
                if (updateRows == 0) {
                    return@withContext Result.failure<Boolean>(
                        IllegalStateException("Update operation did not affect any rows.")
                    )
                }
            }
            // If we reach here, the operation was successful
            Result.success(true)
        } catch (ex: Exception) {
            Result.failure(ex)
        }
    }

    /**
     * Soft deletes a dog by ID, marking it as inactive in the local database. Returns
     * a suspendable Result<Boolean> indicating success (true) or failure (false or exception).
     *
     * @param id The unique identifier of the dog to soft delete.
     * @return A Result<Boolean> indicating whether the soft-delete operation succeeded.
     *
     * Steps:
     * 1. Validate the input ID parameter (must not be blank).
     * 2. Check if the dog record exists (optional check).
     * 3. Execute the soft delete in the database by setting 'active' to false.
     * 4. Capture the row count updated; if 0, no record was found.
     * 5. Catch exceptions and handle them by returning Result.failure.
     * 6. Execute on Dispatchers.IO for non-blocking DB operations.
     */
    suspend fun deleteDog(id: String): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            require(id.isNotBlank()) { "Dog ID parameter must not be blank for deleteDog." }

            // Optionally we could verify record existence. Skipping direct check for brevity
            val rowsUpdated = dogDao.softDeleteDog(id)
            if (rowsUpdated > 0) {
                Result.success(true)
            } else {
                // Means nothing was updated -> likely the dog doesn't exist
                Result.success(false)
            }
        } catch (ex: Exception) {
            Result.failure(ex)
        }
    }
}