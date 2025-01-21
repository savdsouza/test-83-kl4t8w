package com.dogwalking.app.utils

/**
 * Comprehensive utility and extension functions for domain model conversions, date/distance/
 * duration formatting, and performance enhancements. This file adheres to enterprise-grade
 * standards, providing detailed commentary and robust implementations for real-time tracking
 * and localized output.
 */

// -------------------------------------------------------------------------------------------------
// Internal Imports (Specified by Project Requirements) - Ensure correct usage based on
// source file contents and associated domain logic.
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.domain.models.Location
import com.dogwalking.app.domain.models.Walk
import com.dogwalking.app.domain.models.WalkStatus

// -------------------------------------------------------------------------------------------------
// External Imports with Version Comments and Purpose
// -------------------------------------------------------------------------------------------------
// Android location services integration (version: latest)
import android.location.Location as AndroidLocation
// Google Maps integration for precise location visualization (version: 21.0.0)
import com.google.android.gms.maps.model.LatLng
// Thread-safe date formatting utilities with timezone support (version: latest)
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ConcurrentHashMap

// -------------------------------------------------------------------------------------------------
// Private objects for caching and thread-local resources in order to optimize performance and
// maintain safe concurrency in an enterprise-grade environment.
// -------------------------------------------------------------------------------------------------

/**
 * Caches for various transformations that benefit from repeated usage.
 * Keys in these caches should use stable references to avoid memory leaks.
 */
private object ExtensionCaches {

    /**
     * Cache for converting domain model [Location] instances to [LatLng] when the data is valid.
     * We use a weak reference map or basic concurrent map for demonstration. In production, consider
     * advanced caching strategies and memory constraints.
     */
    val locationToLatLngCache: ConcurrentHashMap<Location, LatLng> = ConcurrentHashMap()

    /**
     * Cache for converting entire [Walk] routes to lists of [LatLng]. Keyed by a combination
     * of [Walk.id] and relevant route info if desired to ensure uniqueness.
     */
    val walkRouteLatLngCache: ConcurrentHashMap<String, List<LatLng>> = ConcurrentHashMap()

}

/**
 * Thread-local date formatter cache for performance and safe reuse of [SimpleDateFormat] objects.
 * We store them keyed by (pattern + timeZone.getID) to avoid collisions.
 */
private object DateFormatters {

    private val formatterMap = ConcurrentHashMap<String, ThreadLocal<SimpleDateFormat>>()

    /**
     * Retrieves or creates a thread-local [SimpleDateFormat] for the given pattern and timezone.
     * This ensures we do not create excessive format instances in multi-threaded environments.
     *
     * @param pattern Desired date/time format pattern.
     * @param timeZone TimeZone to apply for all formatting operations.
     */
    fun get(pattern: String, timeZone: TimeZone): SimpleDateFormat {
        val key = "$pattern-${timeZone.id}"
        val threadLocal = formatterMap.computeIfAbsent(key) {
            ThreadLocal.withInitial {
                SimpleDateFormat(pattern, Locale.getDefault()).apply {
                    this.timeZone = timeZone
                    // We disable lenient parsing for stricter date validation.
                    this.isLenient = false
                }
            }
        }
        return threadLocal.get()!!
    }
}

// -------------------------------------------------------------------------------------------------
// Extension Function #1: Location.toLatLng
// Description:
// Thread-safe extension to convert a domain [Location] object to a [LatLng] for Google Maps.
// Performs boundary validation on latitude and longitude, handles caching, and returns a
// newly created [LatLng] if valid. If invalid, returns a fallback coordinate (0.0, 0.0).
// -------------------------------------------------------------------------------------------------

/**
 * Converts this domain [Location] to a [LatLng], ensuring latitude/longitude validity. Uses an
 * internal cache to improve performance for repeated requests with the same data. Invalid
 * coordinates are handled gracefully by returning a default LatLng(0.0, 0.0).
 *
 * Steps:
 * 1. Check if result is already cached.
 * 2. Validate latitude/longitude bounds.
 * 3. Return cached or newly created LatLng.
 * 4. Place the newly created LatLng in the cache for future use if valid.
 *
 * @return A Google Maps [LatLng] object with validated coordinates.
 */
fun Location.toLatLng(): LatLng {
    // Attempt to retrieve a cached LatLng object
    ExtensionCaches.locationToLatLngCache[this]?.let { return it }

    // Validate raw lat/long range before transformation
    val validLatitude = latitude in -90.0..90.0
    val validLongitude = longitude in -180.0..180.0

    val latLng = if (validLatitude && validLongitude) {
        // Create LatLng with validated coordinates
        LatLng(latitude, longitude)
    } else {
        // Graceful fallback to (0.0, 0.0) if the domain model coordinates are out of range
        LatLng(0.0, 0.0)
    }

    // Cache the computed result, but only if valid
    if (validLatitude && validLongitude) {
        ExtensionCaches.locationToLatLngCache[this] = latLng
    }

    return latLng
}

// -------------------------------------------------------------------------------------------------
// Extension Function #2: Long.toFormattedDate
// Description:
// Converts a Long timestamp (milliseconds since epoch) into a localized date string using a
// user-specified pattern and timezone. Thread-safe thanks to local [SimpleDateFormat] retrieval.
// -------------------------------------------------------------------------------------------------

/**
 * Converts this [Long] timestamp (in milliseconds) to a formatted date string, applying the
 * specified pattern and timezone. If the timestamp is invalid (e.g., negative), a fallback
 * string is returned (e.g., "--").
 *
 * Steps:
 * 1. Retrieve thread-local [SimpleDateFormat] using [pattern] and [timeZone].
 * 2. Validate if timestamp is reasonable (>= 0). Quick check to skip date logic if obviously invalid.
 * 3. Format the date into a localized string and return.
 * 4. Fallback to "--" if the timestamp is invalid.
 *
 * @param pattern A date/time format pattern (e.g., "yyyy-MM-dd HH:mm").
 * @param timeZone The timezone to be applied for formatting.
 * @return The formatted date/time string or a fallback value if timestamp is invalid.
 */
fun Long.toFormattedDate(pattern: String, timeZone: TimeZone): String {
    if (this < 0) {
        // Negative timestamps are considered invalid in this scenario
        return "--"
    }
    val dateFormatter = DateFormatters.get(pattern, timeZone)
    return try {
        dateFormatter.format(this)
    } catch (ex: Exception) {
        // If formatting fails for any reason (extreme edge cases), return fallback
        "--"
    }
}

// -------------------------------------------------------------------------------------------------
// Extension Function #3: Double.toFormattedDistance
// Description:
// Locale-aware extension that converts a numeric distance in meters to either kilometers or miles
// depending on user locale, with graceful handling of edges. Returns a human-friendly string.
// -------------------------------------------------------------------------------------------------

/**
 * Interprets this [Double] as a distance in meters, then converts it to km or miles based on
 * the default locale or a simplistic region check. Provides localized number formatting and
 * returns a descriptive string (e.g., "1.2 km" or "0.7 mi").
 *
 * Steps:
 * 1. Detect the user's locale and decide whether to use metric or imperial units.
 * 2. Convert meters to the appropriate unit (km if metric, miles if imperial).
 * 3. Apply locale-specific number formatting for consistent output.
 * 4. Handle edge cases (zero, negative distances) by returning "0 km/mi" to maintain clarity.
 * 5. Return a fully localized distance string appended with the correct unit symbol.
 *
 * @return A [String] representing the distance in either km or mi, localized appropriately.
 */
fun Double.toFormattedDistance(): String {
    // If distance is below zero, we treat that as invalid data or simply clamp to 0
    val distanceMeters = if (this < 0) 0.0 else this

    // Quick check for zero distance
    if (distanceMeters == 0.0) {
        return "0 km"
    }

    // Determine country from default locale (simplistic approach)
    val countryCode = Locale.getDefault().country.uppercase()
    val usesImperial = countryCode == "US" || countryCode == "LR" || countryCode == "MM"

    // Convert
    val convertedDistance = if (usesImperial) {
        // Meters to miles
        distanceMeters / 1609.344
    } else {
        // Meters to kilometers
        distanceMeters / 1000.0
    }

    // Format number with limited decimals for clarity
    val formattedValue = String.format(Locale.getDefault(), "%.2f", convertedDistance)
    val unit = if (usesImperial) "mi" else "km"

    return "$formattedValue $unit"
}

// -------------------------------------------------------------------------------------------------
// Extension Function #4: Long.toFormattedDuration
// Description:
// Transforms a Long value (representing a duration in milliseconds) into a locale-aware string
// that expresses hours and minutes. Incorporates simplistic timezone support if needed for
// advanced calculations (placeholder logic).
// -------------------------------------------------------------------------------------------------

/**
 * Interprets this [Long] as a duration in milliseconds and converts it into a textual representation
 * of hours and minutes. For example, 3 hours and 15 minutes might become "3h 15m" in the current
 * locale. Negative or zero durations are handled gracefully.
 *
 * Steps:
 * 1. Validate the duration is >= 0; if negative, returns "--".
 * 2. Convert millis to total hours and remainder minutes.
 * 3. Construct a human-readable string using the local language or simplified formatting.
 * 4. Return the final localized duration string. (Timezone logic can be integrated if needed.)
 *
 * @return A [String] that describes the duration in hours/minutes (e.g., "1h 05m").
 */
fun Long.toFormattedDuration(): String {
    if (this <= 0) {
        // Non-positive durations are considered invalid or zero
        return "0m"
    }
    val totalMinutes = this / 60000
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60

    // Build a string that includes hours if present
    return if (hours > 0) {
        String.format(Locale.getDefault(), "%dh %02dm", hours, minutes)
    } else {
        String.format(Locale.getDefault(), "%dm", minutes)
    }
}

// -------------------------------------------------------------------------------------------------
// Extension Function #5: Walk.toRouteLatLngs
// Description:
// Converts the [Walk.route] (List of [Location]) into a list of [LatLng], filtering out invalid
// points and optionally caching the result for better performance on repeated calls.
// -------------------------------------------------------------------------------------------------

/**
 * Transforms the route (List of domain [Location]) in this [Walk] into a list of [LatLng] for use
 * with Google Maps. Filters invalid location data to ensure no out-of-bound errors. Implements
 * internal caching keyed by the walk's ID (and optionally route size), optimizing memory usage and
 * repeated transformations in real-time tracking features.
 *
 * Steps:
 * 1. Check if the route is already cached by the walk's unique key in [ExtensionCaches].
 * 2. Validate each [Location] with isValid(). Filter out any that fail, then map to [LatLng].
 * 3. Create a new collection that references only the valid [Location] objects.
 * 4. Store the calculated points in the cache for potential reuse.
 * 5. Return the resulting list of [LatLng].
 *
 * @return An optimized list of [LatLng] representing the walk's route for Google Maps usage.
 */
fun Walk.toRouteLatLngs(): List<LatLng> {
    // Create a key for caching based on the walk ID plus route size if desired
    val cacheKey = "${this.id}-${this.route.size}"

    // Return immediately if cached
    ExtensionCaches.walkRouteLatLngCache[cacheKey]?.let { return it }

    // Validate route data, ensure each location is valid, then convert
    val validPoints = this.route
        .filter { it.isValid() }
        .map { domainLocation -> domainLocation.toLatLng() }

    // If route is large, we could implement memory-usage optimization or chunking. Here we store
    // the entire route for demonstration. In production, consider partial caching or streaming.
    ExtensionCaches.walkRouteLatLngCache[cacheKey] = validPoints

    return validPoints
}