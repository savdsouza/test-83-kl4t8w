package com.dogwalking.app.utils

// -----------------------------------------------------------------------------------------
// External Imports
// -----------------------------------------------------------------------------------------
// BuildConfig (latest) - Provides build-time configuration values such as API Base URL
import com.dogwalking.app.BuildConfig

// Google Play Location Services (com.google.android.gms:play-services-location:21.0.1)
// Provides constants for location request priorities and related functionalities
import com.google.android.gms.location.LocationRequest

// Android Context (Android platform)
// Used to reference context modes, such as MODE_PRIVATE for SharedPreferences
import android.content.Context

/**
 * An object that centralizes all constant values used across the application.
 * These constants cover network configurations, database parameters, shared preferences keys,
 * security and credential requirements, location-based settings, WebSocket parameters,
 * and other essential triggers that guide the internal logic of the Android app.
 *
 * Following the enterprise-grade requirements, every constant is grouped and annotated
 * with detailed comments for clarity, maintainability, and forward compatibility.
 */
object Constants {

    // -------------------------------------------------------------------------------------
    // Network and API-Related Constants
    // -------------------------------------------------------------------------------------

    /**
     * The base URL for all API calls, referencing the BuildConfig field.
     * This is set at build time and may vary for different build variants or environments.
     */
    val API_BASE_URL: String = BuildConfig.API_BASE_URL

    /**
     * The timeout duration (in seconds) for network requests.
     * When exceeded, the request will be aborted to preserve resources.
     */
    const val API_TIMEOUT_SECONDS: Long = 30L

    /**
     * The maximum number of retry attempts for any failed network call before
     * giving up and throwing an exception or error to the calling function.
     */
    const val API_RETRY_ATTEMPTS: Int = 3

    /**
     * The maximum number of requests allowed within a defined time window to
     * mitigate potential API abuse. This is an application-level control, and
     * additional server-side rate limiting may exist.
     */
    const val API_RATE_LIMIT_REQUESTS: Int = 100

    /**
     * The length of the time window (in minutes) for the defined API rate limit.
     * After this time, the rate limit count resets.
     */
    const val API_RATE_LIMIT_WINDOW_MINUTES: Int = 15

    // -------------------------------------------------------------------------------------
    // Database Configuration Constants
    // -------------------------------------------------------------------------------------

    /**
     * The name of the application's primary database used for local persistence.
     */
    const val DATABASE_NAME: String = "dog_walking_db"

    /**
     * The current version number of the database schema. Increment whenever
     * making structural changes to the stored data (tables, columns, etc.).
     */
    const val DATABASE_VERSION: Int = 1

    /**
     * Determines whether schema export is enabled. Generally used to
     * generate schema files for migrations or reference.
     */
    const val DATABASE_EXPORT_SCHEMA: Boolean = true

    // -------------------------------------------------------------------------------------
    // Shared Preferences Configuration Constants
    // -------------------------------------------------------------------------------------

    /**
     * The name of the SharedPreferences file where basic local settings,
     * user tokens, and simple caches are stored.
     */
    const val SHARED_PREFS_NAME: String = "dog_walking_prefs"

    /**
     * The operating mode for the SharedPreferences file, typically set
     * to Context.MODE_PRIVATE to ensure data isolation.
     */
    val SHARED_PREFS_MODE: Int = Context.MODE_PRIVATE

    /**
     * Key under which the user's authentication token (JWT, OAuth token, etc.)
     * is stored in SharedPreferences.
     */
    const val KEY_AUTH_TOKEN: String = "auth_token"

    /**
     * Key that references the refresh token for re-validating or obtaining
     * a new access token from the auth service.
     */
    const val KEY_REFRESH_TOKEN: String = "refresh_token"

    /**
     * Key representing the expiry timestamp of the stored token,
     * allowing the system to validate and proactively refresh tokens.
     */
    const val KEY_TOKEN_EXPIRY: String = "token_expiry"

    /**
     * Key referencing the unique user identifier of the currently logged-in user.
     * This helps associate local caches and user-specific data.
     */
    const val KEY_USER_ID: String = "user_id"

    /**
     * Key referencing the current user's type (owner, walker, admin), used for
     * role-based access control across the application.
     */
    const val KEY_USER_TYPE: String = "user_type"

    // -------------------------------------------------------------------------------------
    // Pagination, Security, and Credential Constants
    // -------------------------------------------------------------------------------------

    /**
     * Default number of items to load in paginated requests.
     */
    const val DEFAULT_PAGE_SIZE: Int = 20

    /**
     * Maximum allowable number of items to load in a single paginated request.
     */
    const val MAX_PAGE_SIZE: Int = 50

    /**
     * Minimum character length enforced for user passwords to satisfy
     * compliance and security policies.
     */
    const val MIN_PASSWORD_LENGTH: Int = 12

    /**
     * Maximum character length enforced for user passwords.
     * Prevents unbounded input for security and performance reasons.
     */
    const val MAX_PASSWORD_LENGTH: Int = 128

    /**
     * A robust regular expression pattern ensuring a minimum complexity level
     * that includes digits, lowercase letters, uppercase letters, special characters,
     * and excludes whitespace.
     */
    const val PASSWORD_PATTERN: String =
        "^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#\$%^&+=])(?=\\S+\$).{12,}\$"

    // -------------------------------------------------------------------------------------
    // Walk Session Constraints
    // -------------------------------------------------------------------------------------

    /**
     * Maximum allowed duration (in hours) for a single walk session before
     * it is flagged for potential extension or system intervention.
     */
    const val MAX_WALK_DURATION_HOURS: Int = 4

    /**
     * Minimum duration (in minutes) for any scheduled or on-demand walk session,
     * ensuring that a walker is booked for a reasonable time window.
     */
    const val MIN_WALK_DURATION_MINUTES: Int = 30

    // -------------------------------------------------------------------------------------
    // Location and Tracking Constants
    // -------------------------------------------------------------------------------------

    /**
     * Interval (in milliseconds) defining how frequently location updates
     * should be requested. This is balanced for power-efficiency and accuracy.
     */
    const val LOCATION_UPDATE_INTERVAL: Long = 10000L

    /**
     * The fastest interval (in milliseconds) for location updates. The system
     * will never provide updates at a rate faster than this.
     */
    const val LOCATION_FASTEST_INTERVAL: Long = 5000L

    /**
     * The minimum distance displacement (in meters) required to trigger a
     * location update. This helps optimize battery usage.
     */
    const val LOCATION_DISPLACEMENT_METERS: Float = 10f

    /**
     * The maximum waiting time (in milliseconds) for location updates before
     * batching them for optimal battery consumption.
     */
    const val LOCATION_MAX_WAIT_TIME: Long = 60000L

    /**
     * The priority level for location accuracy, set to balanced power accuracy
     * to maintain battery conservation while providing relevant location data.
     */
    val LOCATION_PRIORITY: Int = LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY

    // -------------------------------------------------------------------------------------
    // WebSocket Configuration Constants
    // -------------------------------------------------------------------------------------

    /**
     * The total number of reconnect attempts allowed for WebSocket connections
     * in case of connectivity issues or server downtime.
     */
    const val WEBSOCKET_RECONNECT_ATTEMPTS: Int = 5

    /**
     * The interval (in milliseconds) between each reconnect attempt to prevent
     * excessive network thrashing and server load.
     */
    const val WEBSOCKET_RECONNECT_INTERVAL: Long = 5000L

    /**
     * The interval (in milliseconds) after which a ping/pong message is sent
     * to the server to keep the connection alive and detect stale sockets.
     */
    const val WEBSOCKET_PING_INTERVAL: Long = 30000L
}

/**
 * Enum class defining all possible user roles within the application, supporting
 * a role-based access control mechanism. Each role is associated with specific
 * permissions, behaviors, and UI flows across the dog walking platform.
 */
enum class UserType {
    /**
     * OWNER: Represents a dog owner who can schedule walks, manage pet details,
     * and track active walk sessions.
     */
    OWNER,

    /**
     * WALKER: Represents a service provider taking walk requests, updating statuses,
     * and earning from completed sessions.
     */
    WALKER,

    /**
     * ADMIN: Represents an administrative user with elevated privileges
     * for oversight, system configuration, and moderation tasks.
     */
    ADMIN
}

/**
 * Enum class describing the various states a walk session can transition through.
 * This comprehensive list ensures that all edge cases around scheduling,
 * acceptance, and dispute resolutions are properly tracked and managed.
 */
enum class WalkStatus {
    /**
     * PENDING: Indicates the walk request has been created by an owner
     * but has not yet been accepted by any walker.
     */
    PENDING,

    /**
     * ACCEPTED: The walk request has been acknowledged by a walker,
     * but has not yet started.
     */
    ACCEPTED,

    /**
     * IN_PROGRESS: The dog walk is currently active and location tracking
     * is in progress.
     */
    IN_PROGRESS,

    /**
     * PAUSED: The dog walk is temporarily halted (e.g., rest break or emergency),
     * and may resume pending further user action.
     */
    PAUSED,

    /**
     * COMPLETED: The dog walking session has officially ended, and final updates
     * (like distance, photos, walker notes) have been recorded.
     */
    COMPLETED,

    /**
     * CANCELLED: The walk was called off by either the owner or the walker
     * before or during the walk, triggering partial or no billing as defined.
     */
    CANCELLED,

    /**
     * DISPUTED: There is an ongoing conflict regarding the concluded walk;
     * requires administrative review or resolution.
     */
    DISPUTED
}

/**
 * Enum class detailing possible payment statuses in the application.
 * These states are critical for a robust transaction flow, covering
 * everything from initial authorization to final settlement or refund.
 */
enum class PaymentStatus {
    /**
     * PENDING: Payment intent has been initiated but not yet authorized.
     */
    PENDING,

    /**
     * AUTHORIZED: The payment method has been validated and funds are reserved,
     * but the transaction has not yet been captured.
     */
    AUTHORIZED,

    /**
     * PROCESSING: The payment is in the process of being captured or confirmed
     * by the payment gateway.
     */
    PROCESSING,

    /**
     * COMPLETED: The payment has been successfully processed and settled.
     */
    COMPLETED,

    /**
     * FAILED: Payment attempt was unsuccessful, and no funds have been transferred.
     */
    FAILED,

    /**
     * REFUNDED: A successful payment has subsequently been returned to the payer.
     */
    REFUNDED,

    /**
     * DISPUTED: The payment is under review due to a chargeback, formal complaint,
     * or another conflict requiring resolution.
     */
    DISPUTED
}