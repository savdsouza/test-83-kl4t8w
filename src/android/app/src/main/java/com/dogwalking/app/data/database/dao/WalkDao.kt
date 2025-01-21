package com.dogwalking.app.data.database.dao

// -------------------------------------------------------------------------------------------------
// External Imports with Specified Library Versions
// -------------------------------------------------------------------------------------------------
import androidx.room.Dao // v2.6.0
import androidx.room.Query // v2.6.0
import androidx.room.Insert // v2.6.0
import androidx.room.Update // v2.6.0
import androidx.room.Delete // v2.6.0
import androidx.room.Transaction // v2.6.0
import kotlinx.coroutines.flow.Flow // v1.7.3

// -------------------------------------------------------------------------------------------------
// Internal Imports (Entity Classes)
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.data.database.entities.WalkEntity

/**
 * Data Access Object (DAO) interface for all walk-related database operations. This DAO leverages
 * the Room persistence library to provide robust offline support, optimized queries, reactive data
 * streaming with [Flow], and atomic transaction handling for insertion, updates, and deletions.
 *
 * The interface implements a comprehensive set of methods as specified in the system architecture
 * and technical requirements. Each query or operation is carefully designed to handle filtering,
 * ordering, and status-based constraints to facilitate efficient data management within the
 * Dog Walking mobile application.
 */
@Dao
interface WalkDao {

    /**
     * Retrieves a specific walk by its unique ID. Exposes a [Flow] that continuously emits updated
     * results if the underlying data changes.
     *
     * Steps:
     * 1) Validate the [walkId] parameter in calling scope to ensure it is not blank.
     * 2) Query the local "walks" table using the primary key index on "id".
     * 3) Return the result wrapped in a [Flow] for reactive data observation.
     * 4) Handle the null case if no matching record is found.
     *
     * @param walkId Identifies which walk record to retrieve.
     * @return A reactive [Flow] emitting the matching [WalkEntity] or null if not found.
     */
    @Query("SELECT * FROM walks WHERE id = :walkId")
    fun getWalkById(walkId: String): Flow<WalkEntity?>

    /**
     * Retrieves all walks associated with a specific owner, ordered by creation timestamp in
     * descending order. Returns a [Flow] that emits updates whenever the backing data changes.
     *
     * Steps:
     * 1) Validate the [ownerId] parameter in calling scope to ensure it is not blank.
     * 2) Query the "walks" table using the "owner_id" index.
     * 3) Sort the result by "created_at" in descending order.
     * 4) Return a [Flow] of the resulting list for reactive observation.
     *
     * @param ownerId The unique owner identifier used to filter walks.
     * @return [Flow] emitting a list of [WalkEntity] objects for the given owner.
     */
    @Query("SELECT * FROM walks WHERE owner_id = :ownerId ORDER BY created_at DESC")
    fun getWalksByOwnerId(ownerId: String): Flow<List<WalkEntity>>

    /**
     * Retrieves all walks associated with a specific walker, ordered by creation timestamp in
     * descending order. Returns a [Flow] that emits updates whenever the data changes.
     *
     * Steps:
     * 1) Validate the [walkerId] parameter in calling scope to ensure it is not blank.
     * 2) Query the "walks" table using the "walker_id" index.
     * 3) Sort the result by "created_at" in descending order.
     * 4) Return a [Flow] of the resulting list for reactive observation.
     *
     * @param walkerId The unique walker identifier used to filter walks.
     * @return [Flow] emitting a list of [WalkEntity] objects for the given walker.
     */
    @Query("SELECT * FROM walks WHERE walker_id = :walkerId ORDER BY created_at DESC")
    fun getWalksByWalkerId(walkerId: String): Flow<List<WalkEntity>>

    /**
     * Retrieves all currently active walks, filtering based on specific status values to
     * identify in-progress or scheduled sessions. Results are ordered by creation time in ascending
     * order. Returns a [Flow] for real-time data updates.
     *
     * Steps:
     * 1) Query the "walks" table using the "status" index for statuses 'IN_PROGRESS' and 'SCHEDULED'.
     * 2) Sort the list by "created_at" ascending (earliest first).
     * 3) Emit changes reactively through [Flow].
     *
     * @return [Flow] containing a list of active [WalkEntity] records.
     */
    @Query("SELECT * FROM walks WHERE status IN ('IN_PROGRESS', 'SCHEDULED') ORDER BY created_at ASC")
    fun getActiveWalks(): Flow<List<WalkEntity>>

    /**
     * Inserts a new walk record into the database. The operation is performed within a transactional
     * context to ensure atomicity. If any constraints are violated, the transaction is rolled back.
     *
     * Steps:
     * 1) Validate the [walk] entity fields in calling scope (e.g., ensuring required fields are set).
     * 2) Begin a new transaction, guaranteeing ACID compliance.
     * 3) Insert the record into the "walks" table.
     * 4) Commit the transaction upon success or roll back on failure.
     * 5) Return the newly inserted row ID.
     *
     * @param walk The [WalkEntity] to be inserted.
     * @return The row ID of the inserted record.
     */
    @Insert
    @Transaction
    suspend fun insertWalk(walk: WalkEntity): Long

    /**
     * Updates an existing walk record in the database based on primary key matching. This operation
     * supports optimistic locking if a version or concurrency field is present in the entity.
     * Executed within a transaction for consistency.
     *
     * Steps:
     * 1) Validate the [walk] entity prior to update (ensuring primary key is valid).
     * 2) Begin a new transaction to maintain atomicity.
     * 3) Check for version or concurrency conflicts if applicable.
     * 4) Execute the update operation in the "walks" table.
     * 5) Commit or roll back based on success/failure.
     * 6) Return the count of rows affected (should be 1 if successful).
     *
     * @param walk The [WalkEntity] containing updated data.
     * @return The number of rows updated.
     */
    @Update
    @Transaction
    suspend fun updateWalk(walk: WalkEntity): Int

    /**
     * Updates the status of a specific walk record along with the "updated_at" timestamp. Executes
     * within a transactional context to ensure atomic updates.
     *
     * Steps:
     * 1) Validate input parameters ([walkId], [status], and [timestamp]) in calling scope.
     * 2) Update the "status" and "updated_at" fields for the matching record.
     * 3) Commit the transaction, ensuring changes are atomic.
     * 4) Return the count of rows updated (should be 1 if successful).
     *
     * @param walkId The unique identifier of the walk to update.
     * @param status The new status value as a String, e.g. "IN_PROGRESS" or "COMPLETED".
     * @param timestamp Epoch time (in ms) marking the update event.
     * @return The number of rows successfully updated.
     */
    @Query("UPDATE walks SET status = :status, updated_at = :timestamp WHERE id = :walkId")
    @Transaction
    suspend fun updateWalkStatus(walkId: String, status: String, timestamp: Long): Int

    /**
     * Deletes a specified walk record from the database. This method may cascade related data if
     * properly configured in the entity relationships. The operation is transactional, ensuring
     * that partial deletions cannot occur.
     *
     * Steps:
     * 1) Validate the [walk] entity before attempting deletion.
     * 2) Begin a new transaction to enforce atomicity.
     * 3) Optionally delete dependent records in child tables if cascading is enabled.
     * 4) Delete the target record from the "walks" table.
     * 5) Commit or roll back based on success/failure.
     * 6) Return the count of rows deleted (should be 1 if successful).
     *
     * @param walk The [WalkEntity] to remove from the database.
     * @return The number of rows actually deleted.
     */
    @Delete
    @Transaction
    suspend fun deleteWalk(walk: WalkEntity): Int
}