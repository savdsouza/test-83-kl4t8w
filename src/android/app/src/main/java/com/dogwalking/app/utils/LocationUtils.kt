package com.dogwalking.app.utils

// ----------------------------------------------
// External imports with specified versions
// ----------------------------------------------
// com.google.android.gms.location version 21.0.1
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.Priority
// android.os version default
import android.os.PowerManager
// android.content version default
import android.content.Context
// android.Manifest version default
import android.Manifest
// android.content.pm version default
import android.content.pm.PackageManager

// ----------------------------------------------
// Internal imports
// ----------------------------------------------
import com.dogwalking.app.domain.models.Location

/**
 * Comprehensive utility class providing secure and battery-optimized location
 * operations for the dog walking app, including adaptive location tracking,
 * precise distance calculations, and enhanced permission management.
 */
object LocationUtils {

    /**
     * Global constants for location-related calculations and configurations.
     */
    const val EARTH_RADIUS_METERS: Double = 6371000.0
    const val LOCATION_UPDATE_INTERVAL_MS: Long = 10000L
    const val LOCATION_FASTEST_INTERVAL_MS: Long = 5000L
    const val LOCATION_MIN_DISPLACEMENT_METERS: Float = 5.0f

    /**
     * Caches permission checks for optimizing repeated calls within a session.
     * The key in this cache represents whether background permission was required.
     */
    private val permissionCache: MutableMap<Boolean, Boolean> = mutableMapOf()

    /**
     * Defines possible formatting styles for displaying location information.
     * Adjusts precision and output format based on chosen style.
     */
    enum class FormatStyle {
        SHORT,   // Minimal coordinate representation
        MEDIUM,  // Slightly detailed format
        LONG     // Verbose, human-readable representation
    }

    /**
     * Creates and configures an optimized LocationRequest object with adaptive
     * intervals based on battery conditions, user requirements, and power-saving modes.
     *
     * @param context Android context required for checking power state (Battery Saver).
     * @param isHighAccuracyRequired If true, uses high accuracy priority and tighter intervals.
     * @return A fully built LocationRequest instance optimized for current battery conditions.
     */
    fun createLocationRequest(
        context: Context,
        isHighAccuracyRequired: Boolean
    ): LocationRequest {
        // Step 1: Check the device power state using PowerManager to see if Battery Saver is enabled.
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isBatterySaverActive = powerManager?.isPowerSaveMode == true

        // Step 2: Determine optimal update intervals based on Battery Saver mode.
        // By default, we use LOCATION_UPDATE_INTERVAL_MS and LOCATION_FASTEST_INTERVAL_MS.
        // If Battery Saver mode is on, we increase the intervals to conserve power.
        val standardIntervalMillis = LOCATION_UPDATE_INTERVAL_MS
        val standardFastestMillis = LOCATION_FASTEST_INTERVAL_MS
        val batterySaverIntervalMillis = LOCATION_UPDATE_INTERVAL_MS * 3
        val batterySaverFastestMillis = LOCATION_FASTEST_INTERVAL_MS * 3

        val selectedInterval = if (isBatterySaverActive) batterySaverIntervalMillis else standardIntervalMillis
        val selectedFastestInterval = if (isBatterySaverActive) batterySaverFastestMillis else standardFastestMillis

        // Step 3: Create a new LocationRequest Builder instance.
        // Step 4: Set priority based on accuracy requirement and battery state.
        //   - If high accuracy is required and Battery Saver is not active, use PRIORITY_HIGH_ACCURACY.
        //   - Otherwise, use a balanced power-priority setting.
        val priority = if (isHighAccuracyRequired && !isBatterySaverActive) {
            Priority.PRIORITY_HIGH_ACCURACY
        } else {
            Priority.PRIORITY_BALANCED_POWER_ACCURACY
        }

        val builder = LocationRequest.Builder(priority, selectedInterval).apply {
            // Step 5: Configure adaptive interval settings, ensuring we have a fastest interval.
            setMinUpdateIntervalMillis(selectedFastestInterval)

            // Step 6: Set displacement threshold. If high accuracy is requested, keep it tight.
            // Otherwise, expand to conserve battery. Using LOCATION_MIN_DISPLACEMENT_METERS as baseline.
            val displacement = if (isHighAccuracyRequired) LOCATION_MIN_DISPLACEMENT_METERS else (LOCATION_MIN_DISPLACEMENT_METERS * 3)
            setMinUpdateDistanceMeters(displacement)

            // Step 7: Apply power-saving optimizations if needed.
            // In Battery Saver mode, we might reduce the wait for accurate location to reduce power drain.
            // If Battery Saver is active, do not wait for the most accurate reading.
            setWaitForAccurateLocation(!isBatterySaverActive && isHighAccuracyRequired)
        }

        // Step 8: Build and return the optimized LocationRequest object.
        return builder.build()
    }

    /**
     * Calculates the precise distance in meters between two locations using an
     * enhanced Haversine formula that includes optional altitude difference
     * if available. If any location data is invalid, returns 0.0.
     *
     * @param start The starting Location object.
     * @param end The ending Location object.
     * @return The precise distance in meters between start and end points.
     */
    fun calculateDistance(
        start: Location,
        end: Location
    ): Double {
        // Step 1: Validate location coordinates.
        // If either location is not valid, return 0.0.
        if (!start.isValid() || !end.isValid()) {
            return 0.0
        }

        // Step 2: Extract coordinates. The current domain model does not define altitude.
        // If altitude becomes available in future updates, we can incorporate it.
        val lat1 = Math.toRadians(start.latitude)
        val lon1 = Math.toRadians(start.longitude)
        val lat2 = Math.toRadians(end.latitude)
        val lon2 = Math.toRadians(end.longitude)

        // Using 0.0 for altitude difference demonstration since domain model has no altitude field.
        val altitudeStart = 0.0
        val altitudeEnd = 0.0
        val altitudeDiff = altitudeEnd - altitudeStart

        // Step 3: Apply the base Haversine formula for surface distance.
        val deltaLat = lat2 - lat1
        val deltaLon = lon2 - lon1
        val a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
                Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2)
        val c = 2.0 * Math.asin(Math.sqrt(a))
        val surfaceDistance = EARTH_RADIUS_METERS * c

        // Step 4: Combine surface distance with altitude difference if available.
        // Both are in meters. Simple Pythagorean formula to combine.
        var totalDistance = Math.sqrt((surfaceDistance * surfaceDistance) + (altitudeDiff * altitudeDiff))

        // Step 5: Apply precision rounding to reduce floating-point noise.
        totalDistance = Math.round(totalDistance * 100.0) / 100.0

        // Step 6: Return the final calculated distance.
        return totalDistance
    }

    /**
     * Checks if the application has appropriate location permissions,
     * including background access if required, using a caching mechanism
     * to avoid repetitive checks. Ensures both fine and coarse permissions
     * are granted, and optionally checks background permission depending on
     * the requireBackground parameter.
     *
     * @param context The Context used for checking permission grants.
     * @param requireBackground If true, verifies ACCESS_BACKGROUND_LOCATION on supported platforms.
     * @return True if all necessary location permissions are granted, false otherwise.
     */
    fun hasLocationPermission(
        context: Context,
        requireBackground: Boolean
    ): Boolean {
        // Step 1: Check cached permission status. If cached, return it immediately.
        permissionCache[requireBackground]?.let {
            return it
        }

        // Step 2: Verify ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION.
        val fineLocationGranted = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarseLocationGranted = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

        // Step 3: If background permission is required, check ACCESS_BACKGROUND_LOCATION,
        // mindful of Android SDK level. If not required or not available, ignore.
        var backgroundLocationGranted = true
        if (requireBackground) {
            val hasBackgroundPermission = context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
            backgroundLocationGranted = hasBackgroundPermission
        }

        // Step 4: Validate final permission status. All must be true for success.
        val finalPermissionStatus = fineLocationGranted && coarseLocationGranted && backgroundLocationGranted

        // Step 5: Update the permission cache with the result and return combined status.
        permissionCache[requireBackground] = finalPermissionStatus
        return finalPermissionStatus
    }

    /**
     * Formats location data for UI display with multiple format options and locale support.
     * If location data is invalid, returns a "N/A" string. Currently, altitude is not part
     * of the domain model, so only latitude and longitude will be rendered.
     *
     * @param location A domain model representing the location data.
     * @param style Desired format style (e.g., SHORT, MEDIUM, LONG).
     * @return A locale-aware string representing the location.
     */
    fun formatLocationForDisplay(
        location: Location,
        style: FormatStyle
    ): String {
        // Step 1: Validate location data. If invalid, return "N/A".
        if (!location.isValid()) {
            return "N/A"
        }

        // Step 2: Determine the user's locale. Use Locale.getDefault() for general usage.
        val currentLocale = java.util.Locale.getDefault()

        // Step 3: Prepare lat/long with selected precision based on style.
        val lat = location.latitude
        val lon = location.longitude

        // Step 4: Build the output string according to the chosen style.
        return when (style) {
            FormatStyle.SHORT -> {
                // Minimal representation with ~3 decimal places
                String.format(currentLocale, "%.3f, %.3f", lat, lon)
            }
            FormatStyle.MEDIUM -> {
                // Slightly more verbose with ~5 decimal places
                val latString = String.format(currentLocale, "Lat: %.5f", lat)
                val lonString = String.format(currentLocale, "Lon: %.5f", lon)
                "$latString | $lonString"
            }
            FormatStyle.LONG -> {
                // Very descriptive with ~6 decimal places
                val latString = String.format(currentLocale, "Latitude: %.6f", lat)
                val lonString = String.format(currentLocale, "Longitude: %.6f", lon)
                // Altitude could be appended if present in domain model in the future.
                "Location Details -> $latString, $lonString"
            }
        }
    }
}