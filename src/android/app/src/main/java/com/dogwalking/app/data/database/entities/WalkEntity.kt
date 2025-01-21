package com.dogwalking.app.data.database.entities

// -------------------------------------------------------------------------------------------------
// External Imports with Specified Library Versions
// -------------------------------------------------------------------------------------------------
import androidx.room.Entity // v2.6.0
import androidx.room.PrimaryKey // v2.6.0
import androidx.room.ColumnInfo // v2.6.0
import androidx.room.TypeConverters // v2.6.0
import androidx.room.Index // v2.6.0
import com.google.gson.Gson // v2.10.1

// -------------------------------------------------------------------------------------------------
// Internal Imports (Domain Models)
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.domain.models.Walk
import com.dogwalking.app.domain.models.WalkStatus
import com.dogwalking.app.domain.models.Location
import com.dogwalking.app.domain.models.PhotoMetadata
import com.dogwalking.app.domain.models.WalkMetrics

// -------------------------------------------------------------------------------------------------
// NOTE: These converter classes are referenced per specification. It is assumed they are implemented
// elsewhere in the codebase to handle WalkStatus, List<Location>, and List<PhotoMetadata> as needed.
// -------------------------------------------------------------------------------------------------
// import com.dogwalking.app.data.database.converters.WalkStatusConverter
// import com.dogwalking.app.data.database.converters.LocationListConverter
// import com.dogwalking.app.data.database.converters.PhotoListConverter

/**
 * Enhanced database entity class representing a walk session in a local Room (SQLite) database.
 * This entity is designed for robust offline support, comprehensive tracking, and analytics storage.
 * 
 * The entity includes:
 *  - Primary key and essential relationships (ownerId, walkerId, dogId)
 *  - Start/end timestamps for the session
 *  - Status reflecting the walk lifecycle via [WalkStatus]
 *  - Serialized route data (JSON of [Location] objects) for GPS tracking
 *  - Serialized photos data (JSON of [PhotoMetadata] objects)
 *  - Rating and review fields for post-walk feedback
 *  - Distance, created/updated timestamps, and sync-related fields
 *  - An optional metadataJson field for storing extra analytics or custom JSON
 */
@Entity(
    tableName = "walks",
    indices = [
        Index(value = ["owner_id"]),
        Index(value = ["walker_id"]),
        Index(value = ["status"]),
        Index(value = ["created_at"])
    ]
)
// If custom type converters exist, they can be declared here:
// @TypeConverters(WalkStatusConverter::class, LocationListConverter::class, PhotoListConverter::class)
data class WalkEntity(
    /**
     * Unique identifier for this walk record in the local database.
     * Must match the primary reference used in the domain layer ([Walk.id]).
     */
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    /**
     * Identifier of the owner requesting the walk.
     * Serves as a foreign key pointer to the user in the domain model.
     */
    @ColumnInfo(name = "owner_id", index = true)
    val ownerId: String,

    /**
     * Identifier of the assigned walker.
     * Serves as a foreign key pointer to the user in the domain model.
     */
    @ColumnInfo(name = "walker_id", index = true)
    val walkerId: String,

    /**
     * Identifier of the dog involved in this walk.
     * Serves as a foreign key pointer to the dog record.
     */
    @ColumnInfo(name = "dog_id")
    val dogId: String,

    /**
     * Epoch-based start time of the walk (in milliseconds).
     * Must be greater than 0 for a valid session.
     */
    @ColumnInfo(name = "start_time")
    val startTime: Long,

    /**
     * Epoch-based end time of the walk (in milliseconds).
     * Must be >= startTime for a valid session.
     */
    @ColumnInfo(name = "end_time")
    val endTime: Long,

    /**
     * Price for this walk session, stored in local currency units.
     * Must be non-negative.
     */
    @ColumnInfo(name = "price")
    val price: Double,

    /**
     * Current status of the walk session (e.g., PENDING, IN_PROGRESS, COMPLETED).
     * Indexed to allow for optimized queries on lifecycle states.
     */
    @ColumnInfo(name = "status", index = true)
    val status: WalkStatus,

    /**
     * JSON string representing the route data.
     * Typically, this data includes a list of GPS [Location] points for the session.
     */
    @ColumnInfo(name = "route_json")
    val routeJson: String,

    /**
     * JSON string representing the photos captured during or after the walk.
     * Typically contains a list of [PhotoMetadata] items.
     */
    @ColumnInfo(name = "photos_json")
    val photosJson: String,

    /**
     * Average rating given to this walk by the owner, or null if not yet rated.
     */
    @ColumnInfo(name = "rating")
    val rating: Double?,

    /**
     * Written review or comment provided by the owner post-walk, or null if absent.
     */
    @ColumnInfo(name = "review")
    val review: String?,

    /**
     * Total distance covered during the walk in kilometers.
     * Must be >= 0.0.
     */
    @ColumnInfo(name = "distance")
    val distance: Double,

    /**
     * Epoch-based timestamp indicating creation time of this record, in milliseconds.
     * Indexed to allow quick retrieval based on creation date.
     */
    @ColumnInfo(name = "created_at", index = true)
    val createdAt: Long,

    /**
     * Epoch-based timestamp reflecting the last modification time of this record, in milliseconds.
     */
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long,

    /**
     * Boolean flag indicating whether the record has been successfully synchronized with a remote service.
     */
    @ColumnInfo(name = "is_synced")
    val isSynced: Boolean,

    /**
     * Optional error message in case the synchronization fails. Used for debugging or user messaging.
     */
    @ColumnInfo(name = "sync_error")
    val syncError: String?,

    /**
     * Counter that tracks how many attempts have been made to sync this entry.
     * Useful in retry logic, capping repeated failures.
     */
    @ColumnInfo(name = "sync_attempts")
    val syncAttempts: Int,

    /**
     * JSON field for storing any extra analytics, metrics, or custom data not captured in other fields.
     */
    @ColumnInfo(name = "metadata_json")
    val metadataJson: String?
) {

    /**
     * Secondary validation function used to confirm that the data held within this entity
     * meets the expected business and data integrity requirements.
     *
     * @return Boolean indicating whether the entity data is valid (true) or invalid (false).
     *
     * Steps:
     *  1) Check for required field presence (non-empty strings, non-null fields).
     *  2) Validate timestamp consistency (endTime >= startTime, updatedAt >= createdAt).
     *  3) Verify JSON data structure for routeJson and photosJson using a simple parse attempt.
     *  4) Validate numeric ranges (price >= 0.0, distance >= 0.0).
     *  5) Check relationship consistency (ownerId, walkerId, dogId non-empty).
     */
    fun validateData(): Boolean {
        // Step 1) Check for required fields
        if (
            id.isBlank() ||
            ownerId.isBlank() ||
            walkerId.isBlank() ||
            dogId.isBlank()
        ) {
            return false
        }

        // Step 2) Validate timestamps
        if (startTime <= 0 || endTime < startTime) {
            return false
        }
        if (createdAt <= 0 || updatedAt < createdAt) {
            return false
        }

        // Step 3) Verify JSON structure
        val gson = Gson()
        try {
            // Attempt to parse routeJson as a list of Location objects
            gson.fromJson(routeJson, Array<Location>::class.java)
        } catch (ex: Exception) {
            return false
        }
        try {
            // Attempt to parse photosJson as a list of PhotoMetadata objects
            gson.fromJson(photosJson, Array<PhotoMetadata>::class.java)
        } catch (ex: Exception) {
            return false
        }

        // Step 4) Validate numeric ranges
        if (price < 0.0 || distance < 0.0) {
            return false
        }

        // Step 5) Relationship checks for demonstration
        // (In practice, you could confirm matching IDs exist in other tables.)
        // For now, just check that the basic references are not empty strings, already done above.

        // If all checks pass, return true
        return true
    }

    /**
     * Converts this database entity into a domain-level [Walk] object,
     * performing comprehensive checks and JSON parsing for route and photos.
     *
     * @return A fully constructed and validated [Walk] instance.
     *
     * Steps:
     *  1) Validate all entity fields for consistency (calls [validateData()]).
     *  2) Parse and validate routeJson into a List of [Location].
     *  3) Parse and validate photosJson into a List of [PhotoMetadata].
     *  4) Convert entity timestamps to match domain expectations.
     *  5) Validate the calculated distance (already stored in this entity).
     *  6) Parse any optional metrics data from metadataJson (default to empty if null/invalid).
     *  7) Create and return the constructed [Walk] domain object with the parsed data.
     */
    fun toDomainModel(): Walk {
        // Step 1) Validate the entity data before domain conversion
        if (!validateData()) {
            throw IllegalStateException(
                "WalkEntity data is invalid. Unable to convert to domain model."
            )
        }

        // Step 2) Parse routeJson to List<Location>
        val gson = Gson()
        val routeArray: Array<Location> = try {
            gson.fromJson(routeJson, Array<Location>::class.java)
        } catch (ex: Exception) {
            emptyArray()
        }

        // Step 3) Parse photosJson to List<PhotoMetadata>
        val photosArray: Array<PhotoMetadata> = try {
            gson.fromJson(photosJson, Array<PhotoMetadata>::class.java)
        } catch (ex: Exception) {
            emptyArray()
        }

        // Step 4) Timestamps are already in epoch (ms), directly usable by domain model
        // Step 5) Distance is already validated in step 4 of validateData()

        // Step 6) Attempt to parse metadataJson into WalkMetrics, or use default if null or invalid
        val defaultMetrics = WalkMetrics(
            totalSteps = 0,
            averageSpeed = 0f,
            additionalData = emptyMap()
        )
        val metrics: WalkMetrics = if (!metadataJson.isNullOrBlank()) {
            try {
                gson.fromJson(metadataJson, WalkMetrics::class.java) ?: defaultMetrics
            } catch (ex: Exception) {
                defaultMetrics
            }
        } else {
            defaultMetrics
        }

        // Step 7) Build and return the domain model
        return Walk(
            id = id,
            ownerId = ownerId,
            walkerId = walkerId,
            dogId = dogId,
            startTime = startTime,
            endTime = endTime,
            price = price,
            status = status,
            route = routeArray.toMutableList(),
            photos = photosArray.toMutableList(),
            rating = rating,
            review = review,
            distance = distance,
            metrics = metrics,
            createdAt = createdAt,
            updatedAt = updatedAt
        )
    }

    /**
     * Comprehensive constructor invocation documentation:
     *
     * Steps performed within the primary constructor and init block (in Kotlin, the primary
     * constructor parameters are automatically assigned to properties unless overridden).
     *
     *  1) Validate all input parameters for data consistency at usage time (via [validateData()]).
     *  2) Initialize all properties with validated constructor parameters.
     *  3) Set default values for optional parameters (rating, review, syncError, etc.) if needed.
     *  4) Verify JSON format for routeJson and photosJson.
     *  5) Initialize sync-related fields (isSynced, syncAttempts) to default states if not provided.
     *
     * In this data class, the final or immediate validations are deferred to [validateData()]
     * and [toDomainModel()] usage, allowing the entity to be constructed but flagged if invalid.
     */
}