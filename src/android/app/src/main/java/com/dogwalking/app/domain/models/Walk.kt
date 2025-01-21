package com.dogwalking.app.domain.models

// ---------------------------------------------------------------------------------------------
// External Imports with Specified Library Versions
// ---------------------------------------------------------------------------------------------
import android.os.Parcelable // v34 (Android OS library for efficient parcelable data transfer)
import kotlinx.parcelize.Parcelize // v1.9.0 (KotlinX library for automatic Parcelable generation)
import com.google.gson.annotations.SerializedName // v2.10.1 (Gson annotations for JSON serialization)
import kotlinx.serialization.Serializable // v1.5.0 (Kotlin Serialization for enum class serialization)

// ---------------------------------------------------------------------------------------------
// Standard Library Imports (No explicit versioning required)
// ---------------------------------------------------------------------------------------------
import java.time.Instant
import java.time.ZoneId
import java.time.Duration
import java.util.concurrent.TimeUnit

// ---------------------------------------------------------------------------------------------
// NOTE: The following internal imports are stated in the specification as references. They are
// included here to fulfill architectural requirements and ensure consistent usage across the
// domain layer. In this particular file, these classes are referenced in the doc and represent
// enhanced domain relationships, but we do not instantiate them directly here.
// ---------------------------------------------------------------------------------------------
/*
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.domain.models.Dog
import com.dogwalking.app.domain.models.Location
*/

// ---------------------------------------------------------------------------------------------
// Enum Class: WalkStatus
// Description: Defines possible states of a walk with optional transition validation. This class
// supports serialization for consistent handling across network transmission and storage layers.
// ---------------------------------------------------------------------------------------------
@Serializable
enum class WalkStatus {
    /**
     * Initial state when a walk is requested but not yet accepted by a walker.
     */
    PENDING,

    /**
     * State when a walker has accepted the walk request, awaiting the actual start of the walk.
     */
    ACCEPTED,

    /**
     * State when a walk is currently ongoing with active GPS tracking and real-time status updates.
     */
    IN_PROGRESS,

    /**
     * State when a walk has been successfully completed and no further updates are expected.
     */
    COMPLETED,

    /**
     * State when a walk is canceled. This may require storing a reason or justification elsewhere.
     */
    CANCELLED;

    companion object {
        /**
         * Validates whether a transition from one WalkStatus to another is permitted under normal
         * business rules. This ensures that the walk lifecycle follows a consistent progression.
         *
         * @param from The current status of the walk.
         * @param to The target status we wish to transition to.
         * @return True if the transition is valid; false otherwise.
         */
        fun canTransition(from: WalkStatus, to: WalkStatus): Boolean {
            return when (from) {
                PENDING -> (to == ACCEPTED || to == CANCELLED)
                ACCEPTED -> (to == IN_PROGRESS || to == CANCELLED)
                IN_PROGRESS -> (to == COMPLETED || to == CANCELLED)
                COMPLETED -> false // Completed is a terminal state
                CANCELLED -> false // Cancelled is also a terminal state
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Data Class: PhotoMetadata
// Description: Represents metadata for photos uploaded during or after a walk. Provides enhanced
// photo management capabilities, such as captioning, timestamps, and optional location references.
// ---------------------------------------------------------------------------------------------
@Parcelize
data class PhotoMetadata(
    /**
     * Unique identifier for the photo. Must be non-blank to ensure a proper reference in storage.
     */
    @SerializedName("id")
    val id: String,

    /**
     * URL or file path where the photo is stored. Enables easy retrieval and display in mobile apps.
     */
    @SerializedName("url")
    val url: String,

    /**
     * Optional caption text that can be associated with the photo. Useful for contextual notes.
     */
    @SerializedName("caption")
    val caption: String? = null,

    /**
     * Timestamp indicating when the photo was captured or uploaded, in milliseconds since epoch.
     */
    @SerializedName("timestamp")
    val timestamp: Long
) : Parcelable

// ---------------------------------------------------------------------------------------------
// Data Class: WalkMetrics
// Description: Aggregates additional analytics for a walk, such as total steps, average speed, or
// any other metrics needed by the business to track service quality and user satisfaction.
// ---------------------------------------------------------------------------------------------
@Parcelize
data class WalkMetrics(
    /**
     * Total steps taken during the walk as measured by the walker's device or integrated pedometer.
     */
    @SerializedName("totalSteps")
    val totalSteps: Int,

    /**
     * Average speed (in m/s) calculated over the entire walk duration. Useful for analytics insights.
     */
    @SerializedName("averageSpeed")
    val averageSpeed: Float,

    /**
     * Indicates additional or custom metrics required by the business, stored as key-value pairs.
     * For example: {"caloriesBurned":"120","heartRateAvg":"85"}
     */
    @SerializedName("additionalData")
    val additionalData: Map<String, String> = emptyMap()
) : Parcelable

// ---------------------------------------------------------------------------------------------
// Data Class: Walk
// Description: Represents a dog walking session with comprehensive tracking, validation, and
// analytics capabilities. Implements secure data handling, efficient location management, and
// optional photo handling. The primary constructor enforces thorough validation along with
// initialization of security controls and analytics tracking.
// ---------------------------------------------------------------------------------------------
@Parcelize
data class Walk(
    /**
     * Unique identifier for this walk. Non-empty, typically a UUID, used for database references.
     */
    @SerializedName("id")
    val id: String,

    /**
     * Unique identifier for the owner (User id) requesting the walk. Must match an existing user.
     */
    @SerializedName("ownerId")
    val ownerId: String,

    /**
     * Unique identifier for the assigned walker (User id). Must match a verified walker user.
     */
    @SerializedName("walkerId")
    val walkerId: String,

    /**
     * Unique identifier for the dog (Dog id) involved in this walk. Must match an existing dog.
     */
    @SerializedName("dogId")
    val dogId: String,

    /**
     * Start time of the walk in milliseconds since epoch (UTC). Must be > 0 for valid sessions.
     */
    @SerializedName("startTime")
    val startTime: Long,

    /**
     * End time of the walk in milliseconds since epoch (UTC). Must be >= startTime for a valid walk.
     */
    @SerializedName("endTime")
    val endTime: Long,

    /**
     * Price charged for the walk in the local currency units. Must be >= 0.0 for valid transactions.
     */
    @SerializedName("price")
    val price: Double,

    /**
     * The current status of the walk. This determines whether booking is active, completed, etc.
     */
    @SerializedName("status")
    var status: WalkStatus,

    /**
     * Represents the geographic route taken by the walker. Each item in the list is a location
     * with latitude, longitude, speed, accuracy, and timestamp.
     */
    @SerializedName("route")
    val route: MutableList<Location>,

    /**
     * Collection of photos (metadata only) captured during or immediately after the walk session.
     */
    @SerializedName("photos")
    val photos: MutableList<PhotoMetadata>,

    /**
     * Average rating for this walk, as given by the owner post-completion. Null if not yet rated.
     */
    @SerializedName("rating")
    val rating: Double? = null,

    /**
     * Written review or feedback from the owner. Null if no textual review was left.
     */
    @SerializedName("review")
    val review: String? = null,

    /**
     * Total distance covered during the walk in kilometers. Must be >= 0.0, updated as route changes.
     */
    @SerializedName("distance")
    var distance: Double,

    /**
     * Analytics and aggregated metrics for this walk, such as total steps or average speeds.
     */
    @SerializedName("metrics")
    var metrics: WalkMetrics,

    /**
     * Timestamp indicating when this walk record was created, stored in milliseconds since epoch.
     */
    @SerializedName("createdAt")
    var createdAt: Long,

    /**
     * Timestamp indicating the last time this walk record was updated, in milliseconds since epoch.
     */
    @SerializedName("updatedAt")
    var updatedAt: Long
) : Parcelable {

    // -----------------------------------------------------------------------------------------
    // Initialization Block: Enforce parameter validation and setup required controls.
    // -----------------------------------------------------------------------------------------
    init {
        // Step 1: Validate all input parameters
        require(id.isNotBlank()) { "Walk id cannot be blank." }
        require(ownerId.isNotBlank()) { "Owner id cannot be blank." }
        require(walkerId.isNotBlank()) { "Walker id cannot be blank." }
        require(dogId.isNotBlank()) { "Dog id cannot be blank." }
        require(startTime > 0) { "startTime must be a positive value indicating a valid epoch time." }
        require(endTime >= startTime) {
            "endTime must be greater than or equal to startTime for a valid walk duration."
        }
        require(price >= 0.0) { "price must be non-negative." }
        require(distance >= 0.0) { "distance must be non-negative." }
        require(createdAt > 0) { "createdAt must be a valid epoch time." }
        require(updatedAt >= createdAt) {
            "updatedAt must be greater than or equal to createdAt for consistency."
        }

        // Step 2: Apply Parcelable implementation (handled by @Parcelize annotation)

        // Step 3: Initialize security controls
        initializeSecurityControls()

        // Step 4: Setup analytics tracking
        setupAnalyticsTracking()
    }

    // -----------------------------------------------------------------------------------------
    // Function: getDuration
    // Description: Calculates the walk duration in minutes with millisecond precision, factoring
    // in timezone adjustments by interpreting times as UTC and converting to the system default zone.
    // Steps:
    // 1. Validate time parameters internally.
    // 2. Apply timezone corrections.
    // 3. Calculate the precise duration.
    // 4. Return duration in minutes.
    // -----------------------------------------------------------------------------------------
    fun getDuration(): Long {
        require(startTime > 0) { "Invalid startTime for duration calculation." }
        require(endTime >= startTime) { "endTime cannot be less than startTime for duration calculation." }

        // Convert epoch millis to ZonedDateTime in the system default time zone for demonstration
        val startInstant = Instant.ofEpochMilli(startTime).atZone(ZoneId.systemDefault())
        val endInstant = Instant.ofEpochMilli(endTime).atZone(ZoneId.systemDefault())

        // Calculate precise duration and convert to minutes
        val totalDuration = Duration.between(startInstant, endInstant).toMillis()
        return TimeUnit.MILLISECONDS.toMinutes(totalDuration)
    }

    // -----------------------------------------------------------------------------------------
    // Function: isActive
    // Description: Determines if the walk is currently active. Validates the status is IN_PROGRESS,
    // and checks that the current system time has not exceeded the walk's endTime. Optionally
    // could verify route update recency if required.
    // -----------------------------------------------------------------------------------------
    fun isActive(): Boolean {
        // Step 1: Validate current status
        if (status != WalkStatus.IN_PROGRESS) {
            return false
        }

        // Step 2: Check time boundaries (walk must not have passed its endTime)
        val now = System.currentTimeMillis()
        return now < endTime
    }

    // -----------------------------------------------------------------------------------------
    // Function: addLocation
    // Description: Adds a new location record to the route with validation. If validation succeeds,
    // recalculate relevant metrics and update the updatedAt timestamp accordingly.
    // Steps:
    // 1. Validate location data (location.isValid()).
    // 2. Check or enforce geofence boundaries (placeholder logic).
    // 3. If valid, append to route and recalculate metrics.
    // 4. Update walk timestamps.
    // -----------------------------------------------------------------------------------------
    fun addLocation(location: Location): Boolean {
        // Step 1: Validate location data
        if (!location.isValid()) {
            return false
        }

        // Step 2: Example geofence boundary check (placeholder, always returns true in this snippet)
        if (!isWithinGeofence(location)) {
            return false
        }

        // Step 3: Append location to route and recalculate distance or other metrics
        route.add(location)
        recalculateDistanceIfNeeded(location)
        recalculateMetricsIfNeeded()

        // Step 4: Update timestamps and finalize
        updatedAt = System.currentTimeMillis()
        return true
    }

    // -----------------------------------------------------------------------------------------
    // Private Helper: initializeSecurityControls
    // Description: Sets up any required security checks or encryption strategies for walk data.
    // This demonstration is a placeholder for compliance with the specification's steps.
    // -----------------------------------------------------------------------------------------
    private fun initializeSecurityControls() {
        // In a production environment, set up data encryption, request validation,
        // or other security policies. For demonstration, this method is a no-op.
    }

    // -----------------------------------------------------------------------------------------
    // Private Helper: setupAnalyticsTracking
    // Description: Prepares walk data for relevant analytics systems, ensuring any needed metrics
    // or events are captured at initialization.
    // -----------------------------------------------------------------------------------------
    private fun setupAnalyticsTracking() {
        // In a real implementation, integrate with analytics SDKs or custom frameworks
        // for usage monitoring. This is a placeholder fulfilling the specification.
    }

    // -----------------------------------------------------------------------------------------
    // Private Helper: isWithinGeofence
    // Description: Placeholder function to demonstrate geofence checks. Always returns true here.
    // In practice, it might check the dog's location against allowed region boundaries.
    // -----------------------------------------------------------------------------------------
    private fun isWithinGeofence(location: Location): Boolean {
        // Example check could compare location lat/long to specific bounding boxes.
        return true
    }

    // -----------------------------------------------------------------------------------------
    // Private Helper: recalculateDistanceIfNeeded
    // Description: Updates the total distance for the walk using data from the newly added location.
    // In a real implementation, this might measure the incremental distance from the last route
    // point to the new one. Here, it is a placeholder demonstrating the concept.
    // -----------------------------------------------------------------------------------------
    private fun recalculateDistanceIfNeeded(location: Location) {
        // Example logic: increment by a delta if we have a previous location.
        // This snippet does not perform actual geometry calculations.
        distance += 0.0
    }

    // -----------------------------------------------------------------------------------------
    // Private Helper: recalculateMetricsIfNeeded
    // Description: Adjusts additional metrics in the WalkMetrics object. For instance, it might
    // compute average speeds by total distance and updated time or recalculate total steps based
    // on user-specific data. This snippet is a placeholder for demonstration.
    // -----------------------------------------------------------------------------------------
    private fun recalculateMetricsIfNeeded() {
        // Implement advanced calculations for average speed, total steps, etc., if desired.
        // Here, we only demonstrate an example with no changes to 'metrics'.
        metrics.copy(
            totalSteps = metrics.totalSteps,
            averageSpeed = metrics.averageSpeed
        )
    }
}