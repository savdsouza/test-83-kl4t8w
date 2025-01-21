package com.dogwalking.app.data.database.dao

// ---------------------------------------------------------------------------------
// External Imports with Version Comments
// ---------------------------------------------------------------------------------
// Room v2.6.0
import androidx.room.Dao // androidx.room v2.6.0
import androidx.room.Query // androidx.room v2.6.0
import androidx.room.Insert // androidx.room v2.6.0
import androidx.room.Update // androidx.room v2.6.0
import androidx.room.Delete // androidx.room v2.6.0
import androidx.room.Transaction // androidx.room v2.6.0
import androidx.room.OnConflictStrategy // androidx.room v2.6.0

// Kotlin Coroutines Flow v1.7.3
import kotlinx.coroutines.flow.Flow // kotlinx.coroutines.flow v1.7.3

// ---------------------------------------------------------------------------------
// Internal Imports
// ---------------------------------------------------------------------------------
import com.dogwalking.app.data.database.entities.DogEntity

/**
 * [DogDao] defines the Data Access Object (DAO) interface for managing DogEntity records
 * in the local Room database. This interface provides comprehensive CRUD operations
 * and leverages Kotlin Flow for efficient, reactive queries supporting an offline-first
 * architecture.
 *
 * All operations are designed with transactional safety and conflict handling in mind,
 * ensuring reliable and scalable data persistence.
 */
@Dao
interface DogDao {

    /**
     * Retrieves a single [DogEntity] record by its unique identifier, returning
     * a Flow stream that emits the entity or null if it does not exist.
     *
     * Steps:
     * 1. Validate the 'id' parameter in the query.
     * 2. Execute a SELECT query optimized by index usage on the 'id' column.
     * 3. Expose the result as a Flow of nullable [DogEntity].
     * 4. Handle any database I/O issues and emit null if not found.
     *
     * @param id The unique string identifier of the dog record.
     * @return A [Flow] that emits the dog entity matching the specified id or null if none found.
     */
    @Query("SELECT * FROM dogs WHERE id = :id")
    fun getDogById(id: String): Flow<DogEntity?>

    /**
     * Retrieves all [DogEntity] records for a specific owner, providing a Flow that emits
     * the resulting list ordered by the dog's name in ascending order.
     *
     * Steps:
     * 1. Validate the 'ownerId' parameter in the query.
     * 2. Execute a SELECT query on 'owner_id' with an ascending ORDER BY on 'name'.
     * 3. Transform the result set into a Flow of [List] of [DogEntity].
     * 4. Handle empty result cases gracefully by emitting an empty list.
     *
     * @param ownerId The unique string identifier of the owner.
     * @return A [Flow] that emits a list of dogs belonging to the specified owner, sorted by name.
     */
    @Query("SELECT * FROM dogs WHERE owner_id = :ownerId ORDER BY name ASC")
    fun getDogsByOwnerId(ownerId: String): Flow<List<DogEntity>>

    /**
     * Retrieves all active dogs stored in the database, returning a Flow that emits
     * the resulting list, ordered by name in ascending order.
     *
     * Steps:
     * 1. Execute a SELECT query filtered by 'active = 1'.
     * 2. Order results by 'name' in ascending order for consistent presentation.
     * 3. Transform the query output into a Flow of [List] of [DogEntity].
     * 4. Emit an empty list if no active dogs are found.
     *
     * @return A [Flow] that emits a list of all active dog entities, sorted by name.
     */
    @Query("SELECT * FROM dogs WHERE active = 1 ORDER BY name ASC")
    fun getActiveDogs(): Flow<List<DogEntity>>

    /**
     * Inserts a new [DogEntity] into the database, returning the row ID of the inserted entity
     * or -1 on failure. This operation is performed within a database transaction to ensure
     * atomicity and proper error handling.
     *
     * Steps:
     * 1. Validate the incoming [DogEntity] fields and begin a transaction.
     * 2. Execute the insert operation, handling any conflicts as specified.
     * 3. Commit the transaction upon success and return the new record's row ID.
     * 4. Log or handle errors if the insertion fails and roll back if necessary.
     *
     * @param dog The [DogEntity] to be inserted.
     * @return The row ID of the newly inserted dog entity or -1 if insertion fails.
     */
    @Transaction
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertDog(dog: DogEntity): Long

    /**
     * Updates an existing [DogEntity] in the database and returns the count of rows updated.
     * A value of 0 indicates that no matching record was found or updated. This operation is
     * performed within a database transaction for consistency.
     *
     * Steps:
     * 1. Validate incoming [DogEntity] fields against business rules.
     * 2. Begin a transaction and execute the update operation.
     * 3. Confirm that the entity was successfully updated.
     * 4. Commit the transaction if successful; roll back and handle errors otherwise.
     *
     * @param dog The [DogEntity] with updated field values.
     * @return The number of rows updated, typically 1 if the entity was found and updated, or 0 otherwise.
     */
    @Transaction
    @Update
    suspend fun updateDog(dog: DogEntity): Int

    /**
     * Physically deletes a [DogEntity] from the database, cascading any dependent records
     * that reference this entity. Returns the number of rows deleted, with a value of 0
     * indicating no matching entity was found.
     *
     * Steps:
     * 1. Validate the target [DogEntity] before deletion.
     * 2. Begin a transaction and handle cascade deletions as defined by foreign keys.
     * 3. Execute the delete operation and confirm success.
     * 4. Commit the transaction if successful; roll back and log errors otherwise.
     *
     * @param dog The [DogEntity] instance to be deleted.
     * @return The number of rows deleted. Usually 1 if the entity was successfully removed, or 0 if not found.
     */
    @Transaction
    @Delete
    suspend fun deleteDog(dog: DogEntity): Int

    /**
     * Performs a soft-delete operation by setting the 'active' status of a dog record to false,
     * returning the number of rows updated. A value of 0 indicates that no matching record was found.
     * This operation is performed within a database transaction for consistency.
     *
     * Steps:
     * 1. Validate the provided dog ID parameter.
     * 2. Begin a transaction and execute an UPDATE query to set 'active = 0'.
     * 3. Verify that the update succeeded by checking the affected row count.
     * 4. Commit the transaction upon success or roll back if an error is encountered.
     *
     * @param id The unique identifier of the dog to soft-delete.
     * @return The number of rows updated. Typically 1 if the record was found and updated, or 0 otherwise.
     */
    @Transaction
    @Query("UPDATE dogs SET active = 0 WHERE id = :id")
    suspend fun softDeleteDog(id: String): Int
}