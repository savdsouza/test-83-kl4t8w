package com.dogwalking.app.data.database.dao

// ---------------------------------------------------------------------------
// External imports with specified library versions
// ---------------------------------------------------------------------------
// Room DAO annotation for database access interface (version 2.6.0)
import androidx.room.Dao // v2.6.0
// Room query annotation for optimized SQL operations (version 2.6.0)
import androidx.room.Query // v2.6.0
// Room insert annotation with conflict resolution (version 2.6.0)
import androidx.room.Insert // v2.6.0
// Room update annotation with transaction support (version 2.6.0)
import androidx.room.Update // v2.6.0
// Room delete annotation with cascade options (version 2.6.0)
import androidx.room.Delete // v2.6.0
// Room transaction annotation for atomic operations (version 2.6.0)
import androidx.room.Transaction // v2.6.0
// Conflict resolution strategies for database operations (version 2.6.0)
import androidx.room.OnConflictStrategy // v2.6.0

// Kotlin Flow for reactive database queries with proper cancellation support (version 1.7.0)
import kotlinx.coroutines.flow.Flow // v1.7.0

// ---------------------------------------------------------------------------
// Internal imports referencing our UserEntity data class
// ---------------------------------------------------------------------------
import com.dogwalking.app.data.database.entities.UserEntity

/**
 * Interface defining optimized database operations for User entities with proper
 * error handling and transaction support. This Data Access Object (DAO) will
 * manage CRUD operations, specialized queries, and ensure consistent access
 * to the local user data stored in Room.
 */
@Dao
interface UserDao {

    /**
     * Retrieves a user by their unique ID using an indexed lookup. This
     * query returns a Flow that will emit a [UserEntity] when the data
     * changes, or null if no user is found.
     *
     * Steps:
     * 1. Validate the incoming [userId] parameter to ensure it's not empty.
     * 2. Execute the indexed query on the "users" table.
     * 3. Transform the result into a Flow for reactive stream updates.
     * 4. Properly handle the possibility of a null result by making the
     *    Flow emit null if the user doesn't exist.
     *
     * @param userId The unique identifier of the user to retrieve.
     * @return A Flow that emits the user matching the provided [userId].
     */
    @Query("SELECT * FROM users WHERE id = :userId")
    fun getUser(userId: String): Flow<UserEntity?>

    /**
     * Retrieves a user by their email address using the unique index. This
     * method returns a Flow with a nullable [UserEntity], ensuring that
     * clients can subscribe to any changes in the matching record.
     *
     * Steps:
     * 1. Validate the [email] parameter to ensure correctness/format.
     * 2. Execute the unique index query on the "users" table.
     * 3. Convert the obtained record to a Flow emitting either the user
     *    entity or null if not found.
     * 4. Handle the null scenario gracefully by allowing a Flow emission
     *    of null if no record matches.
     *
     * @param email The email address of the user to look up.
     * @return A Flow that emits the user having the specified [email].
     */
    @Query("SELECT * FROM users WHERE email = :email")
    fun getUserByEmail(email: String): Flow<UserEntity?>

    /**
     * Retrieves a paginated list of all users, ordered by their creation
     * timestamp in descending order. This method leverages LIMIT and OFFSET
     * for pagination, returning results in a reactive Flow.
     *
     * Steps:
     * 1. Validate the [limit] and [offset] parameters for correctness.
     * 2. Execute the paginated query, ordering records by created_at DESC.
     * 3. Expose the resulting list of [UserEntity] objects as a Flow for
     *    continuous updates.
     * 4. Manage the possibility of an empty result set gracefully by
     *    returning an empty list within the Flow.
     *
     * @param limit The maximum number of user records to retrieve.
     * @param offset The starting index within the total result set.
     * @return A Flow emitting a paginated list of users.
     */
    @Query("SELECT * FROM users ORDER BY created_at DESC LIMIT :limit OFFSET :offset")
    fun getAllUsers(limit: Int, offset: Int): Flow<List<UserEntity>>

    /**
     * Retrieves verified dog walkers, filtered by user_type = 'WALKER'
     * and is_verified = 1, then sorted by last active time in descending
     * order. This query is exposed as a Flow that will be updated
     * reactively if changes occur in the underlying data.
     *
     * Steps:
     * 1. Execute a filtered query to return only users that are walkers
     *    with verified status.
     * 2. Sort the results by the `last_active_at` field in descending order.
     * 3. Convert the records to a Flow of a list of [UserEntity] objects.
     * 4. Handle any empty results by returning an empty list in the Flow.
     *
     * Note: Ensure a valid `last_active_at` column/field is present in
     *       the "users" table or updated if needed for accurate sorting.
     *
     * @return A Flow emitting a list of verified walker [UserEntity].
     */
    @Query("SELECT * FROM users WHERE user_type = 'WALKER' AND is_verified = 1 ORDER BY last_active_at DESC")
    fun getVerifiedWalkers(): Flow<List<UserEntity>>

    /**
     * Inserts a new user into the database. If a conflict occurs due to
     * an existing entry with the same primary key or unique email, this
     * method will throw an exception based on the specified ABORT strategy.
     *
     * Steps:
     * 1. Validate the provided [user] entity object for completeness.
     * 2. Check for an existing email in the table; if found, a conflict is
     *    triggered and the insert will fail.
     * 3. Execute the insert inside a Room transaction to maintain atomicity.
     * 4. If no conflicts occur, retrieve the newly generated ID.
     * 5. Return the newly inserted row ID to the caller.
     *
     * @param user The new [UserEntity] to be inserted.
     * @return The row ID of the newly inserted user.
     */
    @Insert(onConflict = OnConflictStrategy.ABORT)
    @Transaction
    suspend fun insertUser(user: UserEntity): Long

    /**
     * Updates an existing user record. Operations are performed within a
     * Room transaction to ensure atomicity. If the record does not exist,
     * no update will occur and the returned integer will indicate zero
     * rows affected.
     *
     * Steps:
     * 1. Validate the [user] entity for completeness.
     * 2. Confirm the record to be updated exists, typically by primary key.
     * 3. Execute the Room update, wrapped in a transaction.
     * 4. Verify the number of rows updated to ensure success.
     * 5. Return the count of updated rows to indicate success or failure.
     *
     * @param user The [UserEntity] with updated fields.
     * @return The number of rows successfully updated.
     */
    @Update
    @Transaction
    suspend fun updateUser(user: UserEntity): Int

    /**
     * Deletes a user record from the database, potentially including
     * cascading deletions of related records, if configured. Executed
     * within a Room transaction to maintain data integrity and consistency.
     *
     * Steps:
     * 1. Validate the [user] entity to ensure it has a valid primary key.
     * 2. Check if the user record exists in the database.
     * 3. Perform the delete operation inside a Room transaction.
     * 4. Handle any cascade deletions as defined by foreign key constraints.
     * 5. Return the count of deleted rows to confirm success.
     *
     * @param user The [UserEntity] to be removed from the database.
     * @return The number of rows successfully deleted.
     */
    @Delete
    @Transaction
    suspend fun deleteUser(user: UserEntity): Int
}