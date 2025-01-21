package com.dogwalking.app.domain.models

// External imports with specified library versions
import kotlinx.serialization.Serializable // v1.5.0
import android.os.Parcelable // v34
import kotlinx.parcelize.Parcelize // v1.9.0

/**
 * Sealed enumeration class defining the possible types of users within the dog walking platform.
 * This provides a clear, type-safe way to distinguish between different user roles.
 */
@Serializable
enum class UserType {
    /**
     * Dog owner who books and manages walk services.
     */
    OWNER,

    /**
     * Professional dog walker who provides walking services.
     */
    WALKER
}

/**
 * Immutable data class representing a user in the dog walking application. This class is designed
 * to handle both owners and walkers, offering comprehensive profile information and essential
 * business logic around user types and verification status.
 */
@Serializable
@Parcelize
data class User(
    /**
     * Unique identifier for the user. Must be a non-empty string that
     * differentiates this user from any other in the system.
     */
    val id: String,

    /**
     * Email address of the user. Must be a valid, properly formatted email
     * following a basic pattern check during initialization.
     */
    val email: String,

    /**
     * First name of the user. This will be later formatted for display
     * in full name calculations.
     */
    val firstName: String,

    /**
     * Last name of the user. This will be combined with the first name
     * for a proper display name.
     */
    val lastName: String,

    /**
     * Phone number associated with the user. Must be validated to ensure
     * it contains digits and adheres to a reasonable format (e.g., minimum length).
     */
    val phone: String,

    /**
     * Optional URL or file path referencing the profile image of the user.
     * Can be null if no image is provided.
     */
    val profileImage: String? = null,

    /**
     * Enumerated type specifying whether the user is an OWNER or a WALKER.
     * Used to differentiate capabilities and access levels within the system.
     */
    val userType: UserType,

    /**
     * Numerical rating of the user, represented with a Double. This is typically
     * used to show how owners/walkers are rated by one another and must be set
     * within a reasonable range in external services.
     */
    val rating: Double,

    /**
     * Total number of completed walks associated with this user. For owners,
     * this can represent walks they have successfully booked, and for walkers,
     * walks they have successfully provided.
     */
    val completedWalks: Int,

    /**
     * Indicates whether the user has passed all necessary verification steps,
     * such as background checks, identity validation, or other trust measures.
     */
    val isVerified: Boolean,

    /**
     * Timestamp in milliseconds marking when the user was created. Primarily
     * used for auditing and chronological tracking within the application.
     */
    val createdAt: Long,

    /**
     * Timestamp in milliseconds indicating the last time the user record was
     * updated. This may change due to profile updates or administrative actions.
     */
    val updatedAt: Long
) : Parcelable {

    init {
        // Validate email format (simple pattern check)
        val emailRegex = Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}$")
        require(emailRegex.matches(email)) {
            "Invalid email format: $email"
        }

        // Validate phone number format (basic length check or regex)
        // Adjust pattern or logic if more advanced checks are required.
        val phoneRegex = Regex("^\\+?[0-9]{7,15}\$")
        require(phoneRegex.matches(phone)) {
            "Invalid phone number format: $phone"
        }
    }

    /**
     * Returns a properly formatted full name by capitalizing the first letter
     * of both the first and last names, then trimming any extra whitespace.
     *
     * Steps:
     * 1. Capitalize the first letter of firstName.
     * 2. Capitalize the first letter of lastName.
     * 3. Combine them into a single string with a space in between.
     * 4. Trim any extra whitespace to ensure clean output.
     *
     * @return Combined full name with capitalization.
     */
    fun getFullName(): String {
        val formattedFirst = firstName.replaceFirstChar { it.uppercaseChar() }.trim()
        val formattedLast = lastName.replaceFirstChar { it.uppercaseChar() }.trim()
        return "$formattedFirst $formattedLast".trim()
    }

    /**
     * Determines if the current user is eligible to provide dog walking services.
     * This is true for verified WALKERs who have completed the necessary steps
     * to confirm their reliability and trustworthiness.
     *
     * Steps:
     * 1. Check if userType is UserType.WALKER.
     * 2. Verify isVerified is set to true.
     * 3. Return the combined condition result.
     *
     * @return True if the user is a verified walker, otherwise false.
     */
    fun isEligibleForWalking(): Boolean {
        return (userType == UserType.WALKER) && isVerified
    }
}