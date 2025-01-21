package com.dogwalking.app.data.database.entities

// ---------------------------------------
// External Imports
// ---------------------------------------
// Room v2.6.0
import androidx.room.Entity // androidx.room v2.6.0
import androidx.room.PrimaryKey // androidx.room v2.6.0
import androidx.room.ColumnInfo // androidx.room v2.6.0
import androidx.room.ForeignKey // androidx.room v2.6.0
import androidx.room.Index // androidx.room v2.6.0

// GSON v2.10.1
import com.google.gson.Gson // com.google.gson v2.10.1
import com.google.gson.JsonSyntaxException // com.google.gson v2.10.1
import com.google.gson.reflect.TypeToken // com.google.gson v2.10.1

// ---------------------------------------
// Internal Imports
// ---------------------------------------
import com.dogwalking.app.domain.models.Dog
// Placeholder import for UserEntity referencing; actual class must exist in the same package or accessible module
import com.dogwalking.app.data.database.entities.UserEntity

/**
 * Represents the local database entity for a dog profile.
 * This data class is used for Room persistence, including foreign key constraints,
 * table indexing, and JSON-based field storage for complex data structures such as
 * medical information and special instructions.
 *
 * The entity enforces offline capabilities and sync-friendly fields to ensure
 * data consistency and integrity across devices.
 */
@Entity(
    tableName = "dogs",
    foreignKeys = [
        ForeignKey(
            entity = UserEntity::class,
            parentColumns = ["id"],
            childColumns = ["owner_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("owner_id")]
)
data class DogEntity(

    /**
     * Unique identifier for the dog record in the local database.
     * Acts as the primary key for Room.
     */
    @PrimaryKey
    @ColumnInfo(name = "id")
    var id: String,

    /**
     * Foreign key referencing the user's unique identifier (owner).
     * This enforces a relationship to the users table and triggers CASCADE on delete.
     */
    @ColumnInfo(name = "owner_id")
    var ownerId: String,

    /**
     * The dog's name, stored as a simple string.
     */
    @ColumnInfo(name = "name")
    var name: String,

    /**
     * The dog's breed name, intended for display and filtering.
     */
    @ColumnInfo(name = "breed")
    var breed: String,

    /**
     * Birth date of the dog in a YYYY-MM-DD string format.
     * This is kept as a string to simplify local storage and JSON conversions.
     */
    @ColumnInfo(name = "birth_date")
    var birthDate: String,

    /**
     * A JSON string containing key-value pairs for the dog's medical information.
     * Example:
     * {
     *   "allergies":"pollen",
     *   "medications":"none"
     * }
     */
    @ColumnInfo(name = "medical_info")
    var medicalInfoJson: String,

    /**
     * Indicates if the dog is currently active or not.
     * Inactive dogs may be hidden from certain UI queries.
     */
    @ColumnInfo(name = "active")
    var active: Boolean,

    /**
     * URL of the dog's profile image. If not specified, defaults to an empty string.
     */
    @ColumnInfo(name = "profile_image_url")
    var profileImageUrl: String?,

    /**
     * Weight of the dog (in kilograms). Must be greater than zero for a valid record.
     */
    @ColumnInfo(name = "weight")
    var weight: Float,

    /**
     * A JSON string containing any special instructions or care details.
     * Example:
     * [
     *   "Needs slow walks",
     *   "Cannot climb stairs"
     * ]
     */
    @ColumnInfo(name = "special_instructions")
    var specialInstructionsJson: String,

    /**
     * A UNIX timestamp (in milliseconds) denoting the last time the record was updated.
     * Used for synchronization logic to determine the latest changes.
     */
    @ColumnInfo(name = "last_updated")
    var lastUpdated: Long

) {
    /**
     * Initialization block for performing field validation and default assignments.
     */
    init {
        // 1. Validate input parameters for required fields
        require(id.isNotBlank()) { "Dog ID cannot be blank." }
        require(ownerId.isNotBlank()) { "Owner ID cannot be blank." }
        require(name.isNotBlank()) { "Dog name cannot be blank." }
        require(breed.isNotBlank()) { "Dog breed cannot be blank." }

        // 2. Set default values for optional fields if null
        if (profileImageUrl == null) {
            profileImageUrl = ""
        }

        // Validate weight must be positive
        require(weight > 0f) { "Dog weight must be a positive value." }

        // 3. Verify JSON string format for medicalInfoJson and specialInstructionsJson (light check)
        //    Full parsing and fallback logic is done in toDomainModel() to handle erroneous data gracefully.

        // 4. Initialize lastUpdated with current timestamp if not provided or invalid
        if (lastUpdated <= 0L) {
            lastUpdated = System.currentTimeMillis()
        }
    }

    /**
     * Converts this DogEntity database object into its corresponding domain model [Dog].
     * JSON deserialization is performed for complex fields (medicalInfo and specialInstructions)
     * to provide a strongly-typed object within higher layers of the application.
     *
     * @return A fully constructed [Dog] instance.
     */
    fun toDomainModel(): Dog {
        val gson = Gson()

        // Initialize collections to safe defaults in case of malformed JSON
        var parsedMedicalInfo: Map<String, String> = emptyMap()
        var parsedSpecialInstructions: List<String> = emptyList()

        // Attempt to parse medicalInfoJson into a Map<String, String>
        try {
            val mapType = object : TypeToken<Map<String, String>>() {}.type
            parsedMedicalInfo = gson.fromJson(medicalInfoJson, mapType)
        } catch (ex: JsonSyntaxException) {
            // Handle or log malformed JSON errors; fallback to empty map
        }

        // Attempt to parse specialInstructionsJson into a List<String>
        try {
            val listType = object : TypeToken<List<String>>() {}.type
            parsedSpecialInstructions = gson.fromJson(specialInstructionsJson, listType)
        } catch (ex: JsonSyntaxException) {
            // Handle or log malformed JSON errors; fallback to empty list
        }

        // Construct and return the domain model
        return Dog(
            id = id,
            ownerId = ownerId,
            name = name,
            breed = breed,
            birthDate = birthDate,
            medicalInfo = parsedMedicalInfo,
            active = active,
            profileImageUrl = profileImageUrl,
            weight = weight,
            specialInstructions = parsedSpecialInstructions,
            lastUpdated = lastUpdated
        )
    }
}