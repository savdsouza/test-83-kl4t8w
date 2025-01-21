package com.dogwalking.app.data.database

// -----------------------------------------------------------------------------
// External Imports with Specified Library Versions
// -----------------------------------------------------------------------------
// Android OS standard library for application context handling
import android.content.Context

// Room v2.6.0
import androidx.room.Database // androidx.room v2.6.0
import androidx.room.Room // androidx.room v2.6.0
import androidx.room.RoomDatabase // androidx.room v2.6.0
import androidx.room.TypeConverters // androidx.room v2.6.0

// -----------------------------------------------------------------------------
// Internal Imports for Entities (Data Classes) and DAOs
// -----------------------------------------------------------------------------
import com.dogwalking.app.data.database.entities.UserEntity
import com.dogwalking.app.data.database.entities.DogEntity
import com.dogwalking.app.data.database.entities.WalkEntity
import com.dogwalking.app.data.database.dao.UserDao
import com.dogwalking.app.data.database.dao.DogDao
import com.dogwalking.app.data.database.dao.WalkDao

import java.util.Date // Standard Java utility for Date handling
import android.database.sqlite.SQLiteException // Exception handling for database operations

// -----------------------------------------------------------------------------
// Main Database Configuration
// -----------------------------------------------------------------------------
/**
 * [AppDatabase] is the main Room database configuration class for the Dog Walking application.
 * It hosts all entity definitions and provides DAOs for data-related operations. This class
 * implements comprehensive migration support (placeholders for future versions), thread-safe
 * singleton instantiation, and the ability to cleanly clear all tables when necessary.
 *
 * By annotating with @Database, Room will generate the schema and necessary boilerplate at
 * compile time, ensuring robust offline persistence aligned with the application's requirements.
 *
 * @property userDao Data Access Object for all user-related operations within the local database.
 * @property dogDao Data Access Object for dog-related records, ensuring referential integrity with users.
 * @property walkDao Data Access Object for walks, referencing owners, walkers, and dogs.
 */
@Database(
    entities = [
        UserEntity::class,
        DogEntity::class,
        WalkEntity::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {

    /**
     * Provides direct access to User-related queries, updates, and other data operations within
     * the local Room database.
     */
    abstract fun userDao(): UserDao

    /**
     * Provides direct access to Dog-related queries, updates, and other data operations within
     * the local Room database.
     */
    abstract fun dogDao(): DogDao

    /**
     * Provides direct access to Walk-related queries, updates, and other data operations within
     * the local Room database.
     */
    abstract fun walkDao(): WalkDao

    // -----------------------------------------------------------------------------
    // Companion Object for Singleton Access
    // -----------------------------------------------------------------------------
    companion object {
        /**
         * Volatile instance of [AppDatabase], ensuring any thread accessing it sees the
         * most up-to-date version. This helps maintain singleton guarantees across
         * the application.
         */
        @Volatile
        private var INSTANCE: AppDatabase? = null

        /**
         * Thread-safe singleton retrieval method for [AppDatabase]. Uses a double-check
         * locking pattern to ensure that only one instance of the database is ever created
         * within the application process.
         *
         * Steps:
         * 1. Check if an existing instance is already cached (quick check).
         * 2. If null, synchronize on this class to avoid multi-threaded races.
         * 3. Double-check the instance. If still null, construct a new database using
         *    Room's databaseBuilder.
         * 4. Configure migration support, name, fallback strategies, and add any callbacks.
         * 5. Assign the new instance to [INSTANCE] and return it.
         *
         * @param context The application context used for database I/O.
         * @return A stable, thread-safe [AppDatabase] instance with the chosen configuration.
         */
        fun getDatabase(context: Context): AppDatabase {
            // First quick check
            val tempInstance = INSTANCE
            if (tempInstance != null) {
                return tempInstance
            }

            // Synchronize if no instance is found
            synchronized(this) {
                val existingInstance = INSTANCE
                if (existingInstance != null) {
                    return existingInstance
                }
                // Create the database with Room configuration
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "dogwalking_db"
                )
                    // Placeholder for migration logic if upgrading from older versions
                    // Add migration steps (e.g., addMigrations(MIGRATION_1_2, ...)) as needed
                    .fallbackToDestructiveMigration()
                    // Example of enabling database callbacks for custom operations
                    .addCallback(object : RoomDatabase.Callback() {
                        override fun onCreate(db: SupportSQLiteOpenHelper?) {
                            super.onCreate(db)
                            // Additional actions can be performed here upon DB creation,
                            // like pre-populating default data or setting up triggers.
                        }

                        override fun onOpen(db: SupportSQLiteOpenHelper?) {
                            super.onOpen(db)
                            // Actions performed whenever the DB is opened, e.g. integrity checks.
                        }
                    })
                    .build()

                INSTANCE = instance
                return instance
            }
        }
    }

    // -----------------------------------------------------------------------------
    // Utility Methods
    // -----------------------------------------------------------------------------

    /**
     * Clears all tables in the database while maintaining transaction integrity. This operation
     * is typically used for testing, debugging, or special reset scenarios. It deletes existing
     * records in the correct order to avoid referential constraint violations, and then resets
     * the auto-increment counters so that primary keys start fresh.
     *
     * Steps:
     * 1. Begin a Room database transaction.
     * 2. Delete all records from each dependent table in an order that respects foreign keys.
     * 3. Reset auto-increment counters for each table, allowing IDs to start again at 1.
     * 4. Commit the transaction upon success. Rolls back automatically on failure.
     *
     * Note: In practice, ensure that foreign keys, cascade rules, and indexing are configured
     * to match the table clearing sequence. In certain designs, clearing child tables before
     * parents prevents foreign key exceptions.
     */
    fun clearDatabase() {
        runInTransaction {
            try {
                // Acquire direct write access to the underlying SQLite DB
                val db = this.openHelper.writableDatabase

                // 1) Clear all relational data from referencing tables first
                db.execSQL("DELETE FROM walks")
                db.execSQL("DELETE FROM dogs")
                db.execSQL("DELETE FROM users")

                // 2) Reset auto-increment sequences for each table to restore PKs to start at 1
                db.execSQL("DELETE FROM sqlite_sequence WHERE name = 'walks'")
                db.execSQL("DELETE FROM sqlite_sequence WHERE name = 'dogs'")
                db.execSQL("DELETE FROM sqlite_sequence WHERE name = 'users'")
            } catch (ex: SQLiteException) {
                // If an error occurs, Room will handle rollback automatically
                // This catch block can log or re-throw if needed.
                throw ex
            }
        }
    }
}

// -----------------------------------------------------------------------------
// Converters for Complex Data Types
// -----------------------------------------------------------------------------
/**
 * [Converters] provides custom type conversion methods for Room. By default, Room only supports
 * a limited set of primitive data types. These methods handle conversions between common data
 * types (e.g., Long timestamps) and more complex data objects (e.g., [Date]) for storage in
 * the local SQLite database. Ensures null safety and error handling.
 */
class Converters {

    /**
     * Converts a nullable [Long] timestamp into a nullable [Date] object with robust null handling
     * and error-catching. If the timestamp is invalid or null, returns null instead of throwing
     * an exception.
     *
     * Steps:
     * 1. Check if the [value] is null. If so, return null immediately.
     * 2. Attempt to construct a [Date] using the provided timestamp.
     * 3. If any runtime error occurs (e.g., negative timestamp or parse anomaly),
     *    catch the exception and return null.
     *
     * @param value The [Long] timestamp (milliseconds since epoch) or null.
     * @return A [Date] object representing the timestamp, or null if invalid.
     */
    @androidx.room.TypeConverter
    fun fromTimestamp(value: Long?): Date? {
        if (value == null) {
            return null
        }
        return try {
            Date(value)
        } catch (ex: Exception) {
            null
        }
    }

    /**
     * Converts a nullable [Date] object into a nullable [Long] timestamp, handling edge cases
     * gracefully. If the date is null, returns null. This allows Room to store Date values
     * as raw epoch millisecond longs in the localized SQL schema.
     *
     * Steps:
     * 1. Check if [date] is null. If so, return null.
     * 2. Retrieve the epoch milliseconds from the [Date] object.
     * 3. Handle potential overflow or negative values if discovered, though typically not expected.
     * 4. Return the timestamp as a [Long].
     *
     * @param date The [Date] object to convert or null if no date is set.
     * @return A [Long] representing the epoch milliseconds of the provided [Date], or null.
     */
    @androidx.room.TypeConverter
    fun dateToTimestamp(date: Date?): Long? {
        return try {
            date?.time
        } catch (ex: Exception) {
            null
        }
    }
}