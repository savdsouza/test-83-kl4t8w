package com.dogwalking.app.data.database.entities

// -----------------------------------------------
// External imports with specified library versions
// -----------------------------------------------
// Room annotations (version 2.6.0)
import androidx.room.Entity // v2.6.0
import androidx.room.PrimaryKey // v2.6.0
import androidx.room.ColumnInfo // v2.6.0
import androidx.room.Index      // v2.6.0

// -----------------------------------------------
// Internal imports referencing domain models
// -----------------------------------------------
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.domain.models.UserType

/**
 * Data class representing a user entity in the local Room database.
 * This entity is mapped to the "users" table and includes all
 * relevant fields for user persistence, indexing, and data conversion.
 *
 * The indices defined below ensure efficient lookups and data constraints:
 * 1. A unique index on 'email' to prevent duplicate user records.
 * 2. An additional index on 'user_type' for optimized queries filtering
 *    by user type (e.g., owners vs. walkers).
 */
@Entity(
    tableName = "users",
    indices = [
        Index(value = ["email"], unique = true),
        Index(value = ["user_type"])
    ]
)
data class UserEntity(
    /**
     * Unique identifier for the user record.
     * This is the primary key in the "users" table.
     */
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    /**
     * Email address of the user. A unique index is created to ensure
     * no two records share the same email. This field is used for
     * local identification and login operations.
     */
    @ColumnInfo(name = "email", index = true)
    val email: String,

    /**
     * First name of the user. Typically capitalized or normalized
     * before display or usage in the mobile application.
     */
    @ColumnInfo(name = "first_name")
    val firstName: String,

    /**
     * Last name of the user. Combined with the first name to create
     * a full name for UI display or other operations.
     */
    @ColumnInfo(name = "last_name")
    val lastName: String,

    /**
     * Phone number associated with the user. Used primarily for
     * contact verification or potential support calls.
     */
    @ColumnInfo(name = "phone")
    val phone: String,

    /**
     * Optional URL or file path to the user's profile image. Can
     * be null if the user has not uploaded a profile image.
     */
    @ColumnInfo(name = "profile_image")
    val profileImage: String?,

    /**
     * Enumerated type (OWNER or WALKER) designating the user's
     * role within the dog walking platform.
     */
    @ColumnInfo(name = "user_type", index = true)
    val userType: UserType,

    /**
     * Numeric rating for the user, ranging from 0.0 and up. This rating
     * can be updated whenever the user receives new accolades or reviews.
     */
    @ColumnInfo(name = "rating")
    val rating: Double,

    /**
     * Total number of walks completed by this user, whether as an owner
     * who booked walks or as a walker who fulfilled them.
     */
    @ColumnInfo(name = "completed_walks")
    val completedWalks: Int,

    /**
     * Flag indicating whether the user is fully verified (e.g., identity
     * checks, background checks for walkers). This drives UI and logic
     * around trust and security.
     */
    @ColumnInfo(name = "is_verified")
    val isVerified: Boolean,

    /**
     * Creation timestamp for the user record, stored as milliseconds since
     * the Unix epoch. Primarily used for auditing and sorting.
     */
    @ColumnInfo(name = "created_at")
    val createdAt: Long,

    /**
     * Timestamp of the last update to this user record, stored as milliseconds
     * since the Unix epoch. Updates can be triggered by profile changes
     * or administrative actions.
     */
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long
) {

    /**
     * Converts this UserEntity (the Room-specific data class) to a User
     * domain model, preserving all relevant fields. This function is
     * essential for mapping database records back into the higher-level
     * objects used by the application and business logic.
     *
     * Steps:
     * 1. Create a new User instance using the values from this entity.
     * 2. Directly initialize each property with its counterpart.
     * 3. Return the fully constructed User domain object.
     *
     * @return A User domain model containing all relevant data.
     */
    fun toDomainModel(): User {
        return User(
            id = this.id,
            email = this.email,
            firstName = this.firstName,
            lastName = this.lastName,
            phone = this.phone,
            profileImage = this.profileImage,
            userType = this.userType,
            rating = this.rating,
            completedWalks = this.completedWalks,
            isVerified = this.isVerified,
            createdAt = this.createdAt,
            updatedAt = this.updatedAt
        )
    }

    companion object {
        /**
         * Creates a fully populated UserEntity instance from a User domain
         * model. This function ensures all fields are appropriately mapped
         * and converted to types suitable for local database storage.
         *
         * Steps:
         * 1. Extract all fields from the provided User domain object.
         * 2. Convert data (timestamps, nullables, etc.) as needed.
         * 3. Build and return a new UserEntity instance.
         *
         * @param user The domain model from which to derive the entity.
         * @return A new UserEntity ready for insertion or updating in Room.
         */
        fun fromDomainModel(user: User): UserEntity {
            return UserEntity(
                id = user.id,
                email = user.email,
                firstName = user.firstName,
                lastName = user.lastName,
                phone = user.phone,
                profileImage = user.profileImage,
                userType = user.userType,
                rating = user.rating,
                completedWalks = user.completedWalks,
                isVerified = user.isVerified,
                createdAt = user.createdAt,
                updatedAt = user.updatedAt
            )
        }
    }
}