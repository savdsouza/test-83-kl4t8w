package com.dogwalking.app.domain.models

import android.os.Parcelable // android.os v34
import kotlinx.parcelize.Parcelize // kotlinx.parcelize v1.9.0
import com.google.gson.annotations.SerializedName // com.google.gson.annotations v2.10.1
import com.google.gson.Gson // com.google.gson v2.10.1

import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Data class representing a dog entity with comprehensive profile information.
 * Implements Parcelable for efficient Android component communication.
 * Provides serialization support via annotations and utility functions.
 */
@Parcelize
data class Dog(
    /**
     * Unique identifier for the dog.
     * Must not be blank or invalid.
     */
    @SerializedName("id")
    var id: String,

    /**
     * Unique identifier representing the owner of this dog.
     * Must match an existing user record in the system.
     */
    @SerializedName("ownerId")
    var ownerId: String,

    /**
     * Name of the dog.
     * Used for identification and display in the user interface.
     */
    @SerializedName("name")
    var name: String,

    /**
     * Breed of the dog (e.g., Golden Retriever).
     * Used for informational and filtering purposes.
     */
    @SerializedName("breed")
    var breed: String,

    /**
     * Birth date of the dog in YYYY-MM-DD format.
     * Required for calculating age, verifying maturity, and healthcare reasons.
     */
    @SerializedName("birthDate")
    var birthDate: String,

    /**
     * Medical information represented as a map of key-value pairs.
     * E.g., {"allergies":"pollen","medications":"none"}.
     */
    @SerializedName("medicalInfo")
    var medicalInfo: Map<String, String>,

    /**
     * Indicates if the dog is active or not.
     * An inactive dog profile might be archived or excluded from search operations.
     */
    @SerializedName("active")
    var active: Boolean,

    /**
     * URL of the dog's profile image if available.
     * If null is provided, it is initialized to an empty string by default.
     */
    @SerializedName("profileImageUrl")
    var profileImageUrl: String?,

    /**
     * Weight of the dog in kilograms.
     * Must be a positive number for valid records.
     */
    @SerializedName("weight")
    var weight: Float,

    /**
     * Special instructions or care details, stored as a list.
     * E.g., ["Requires gentle handling","Feed twice daily"].
     */
    @SerializedName("specialInstructions")
    var specialInstructions: List<String>,

    /**
     * Timestamp (in milliseconds) of the last update to this record.
     * Used for synchronization and record-keeping.
     */
    @SerializedName("lastUpdated")
    var lastUpdated: Long
) : Parcelable {

    init {
        // Validate required string fields
        require(id.isNotBlank()) { "Dog id cannot be blank." }
        require(ownerId.isNotBlank()) { "Owner id cannot be blank." }
        require(name.isNotBlank()) { "Dog name cannot be blank." }
        require(breed.isNotBlank()) { "Dog breed cannot be blank." }

        // Set default values for optional field if null
        if (profileImageUrl == null) {
            profileImageUrl = ""
        }

        // Validate weight must be positive
        require(weight > 0f) { "Dog weight must be a positive value." }

        // Check date format for birthDate
        require(isValidDateFormat(birthDate)) {
            "Dog birthDate must be in YYYY-MM-DD format (actual: $birthDate)."
        }
    }

    /**
     * Converts the current Dog domain model into a database entity representation.
     * Complex types (medicalInfo, specialInstructions) are serialized into JSON strings.
     *
     * @return DogEntity object suitable for database storage.
     */
    fun toEntity(): DogEntity {
        val gson = Gson()
        val medicalInfoJson: String = gson.toJson(medicalInfo)
        val specialInstructionsJson: String = gson.toJson(specialInstructions)

        return DogEntity(
            id = this.id,
            ownerId = this.ownerId,
            name = this.name,
            breed = this.breed,
            birthDate = this.birthDate,
            medicalInfoJson = medicalInfoJson,
            active = this.active,
            profileImageUrl = this.profileImageUrl ?: "",
            weight = this.weight,
            specialInstructionsJson = specialInstructionsJson,
            lastUpdated = this.lastUpdated
        )
    }

    /**
     * Calculates the dog's current age in whole years based on the birthDate.
     *
     * @return The computed age of the dog in years.
     */
    fun getAge(): Int {
        return try {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            dateFormat.isLenient = false
            val birth: Date = dateFormat.parse(birthDate) ?: return 0
            val now = Calendar.getInstance().time
            val ageInMillis = now.time - birth.time
            // Average year length in milliseconds (accounting for leap years)
            val millisInYear = 365.25 * 24 * 60 * 60 * 1000
            (ageInMillis / millisInYear).toInt()
        } catch (ex: ParseException) {
            0
        }
    }

    /**
     * Private helper function to verify if the date is valid in YYYY-MM-DD format.
     *
     * @param dateStr The date string to validate.
     * @return True if dateStr can be parsed in the specified format, false otherwise.
     */
    private fun isValidDateFormat(dateStr: String): Boolean {
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            sdf.isLenient = false
            sdf.parse(dateStr)
            true
        } catch (ex: ParseException) {
            false
        }
    }
}

/**
 * Internal data class representing a database entity for Dog.
 * Stores complex fields (medicalInfo, specialInstructions) as JSON strings.
 * Not intended for external usage.
 */
internal data class DogEntity(
    val id: String,
    val ownerId: String,
    val name: String,
    val breed: String,
    val birthDate: String,
    val medicalInfoJson: String,
    val active: Boolean,
    val profileImageUrl: String,
    val weight: Float,
    val specialInstructionsJson: String,
    val lastUpdated: Long
)