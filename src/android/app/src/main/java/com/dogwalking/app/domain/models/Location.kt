package com.dogwalking.app.domain.models

import android.os.Parcelable // android.os version default – Facilitates inter-component data serialization in Android
import kotlinx.parcelize.Parcelize // kotlinx.parcelize version 1.9.0 – Provides the @Parcelize annotation for automatic Parcelable generation
import com.google.gson.annotations.SerializedName // com.google.gson.annotations version 2.9.0 – Enables field-level JSON serialization naming
import com.google.gson.Gson // com.google.gson version 2.9.0 – Core JSON processing library
import com.google.gson.GsonBuilder
import com.google.gson.TypeAdapter
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import java.util.Locale

/**
 * Data class representing a GPS location point with essential tracking information for dog walks.
 * This model implements Parcelable for efficient data sharing between Android components.
 * It includes comprehensive validation logic to ensure location data integrity, conforming
 * to all business requirements for real-time GPS tracking and walk monitoring.
 */
@Parcelize
data class Location(
    /**
     * Unique identifier for this GPS location entry.
     * Must be non-blank and used to correlate with database records.
     */
    @SerializedName("id")
    val id: String,

    /**
     * Unique identifier referencing the dog walk session this location belongs to.
     * Must be non-blank and used to associate location data with specific active or past walks.
     */
    @SerializedName("walkId")
    val walkId: String,

    /**
     * Latitude in degrees. Valid range: -90.0 to 90.0.
     * Values outside this range will fail validation.
     */
    @SerializedName("latitude")
    val latitude: Double,

    /**
     * Longitude in degrees. Valid range: -180.0 to 180.0.
     * Values outside this range will fail validation.
     */
    @SerializedName("longitude")
    val longitude: Double,

    /**
     * Accuracy of the location measurement in meters.
     * Must be a non-negative value less than 100 meters to be considered valid.
     */
    @SerializedName("accuracy")
    val accuracy: Float,

    /**
     * Speed of the user/device in meters per second.
     * Must be a non-negative value less than 30 m/s to be considered valid.
     */
    @SerializedName("speed")
    val speed: Float,

    /**
     * Timestamp (in milliseconds since epoch) indicating when this location was recorded.
     * Invalid if it is more than 5 minutes old or is set in the future.
     */
    @SerializedName("timestamp")
    val timestamp: Long

) : Parcelable {

    /**
     * Validates if the location data is within acceptable bounds and meets
     * all integrity requirements for dog walking tracking scenarios.
     *
     * @return True if all location fields are valid; false otherwise.
     */
    fun isValid(): Boolean {
        // Check valid latitude: must be between -90 and 90 degrees.
        if (latitude < -90.0 || latitude > 90.0) {
            return false
        }
        // Check valid longitude: must be between -180 and 180 degrees.
        if (longitude < -180.0 || longitude > 180.0) {
            return false
        }
        // Check accuracy: must be >= 0 and less than 100 meters.
        if (accuracy < 0.0f || accuracy >= 100.0f) {
            return false
        }
        // Check speed: must be >= 0 and less than 30 m/s (approx 108 km/h, well above normal walking).
        if (speed < 0.0f || speed >= 30.0f) {
            return false
        }

        // Ensure timestamp is not more than 5 minutes in the past and not set in the future.
        val currentTime = System.currentTimeMillis()
        val fiveMinutesInMs = 5 * 60 * 1000
        if (timestamp > currentTime) {
            return false
        }
        if (timestamp < (currentTime - fiveMinutesInMs)) {
            return false
        }

        // Validate that both 'id' and 'walkId' are not blank.
        if (id.isBlank() || walkId.isBlank()) {
            return false
        }

        // Return true only if all the above checks pass.
        return true
    }

    /**
     * Converts this location data into a JSON string.
     * Only produces a valid JSON representation if the data passes all validation checks.
     * Provides precise number formatting via custom TypeAdapters for Double and Float fields.
     *
     * @return JSON string representation of the location data. Returns "{}" if invalid.
     */
    fun toJson(): String {
        // If the location is invalid, return an empty JSON object.
        if (!isValid()) {
            return "{}"
        }

        // Build a Gson instance with custom adapters for controlling numeric output formatting.
        val gsonWithCustomAdapters: Gson = GsonBuilder()
            .registerTypeAdapter(Double::class.java, object : TypeAdapter<Double>() {
                /**
                 * Writes a Double value with a fixed 6-decimal precision to ensure uniform output.
                 */
                override fun write(out: JsonWriter, value: Double?) {
                    if (value == null) {
                        out.nullValue()
                    } else {
                        out.value(String.format(Locale.US, "%.6f", value))
                    }
                }

                /**
                 * Reads a Double value from the JSON stream.
                 * This implementation simply parses the numeric string.
                 */
                override fun read(`in`: JsonReader): Double {
                    return try {
                        `in`.nextString().toDouble()
                    } catch (e: NumberFormatException) {
                        0.0
                    }
                }
            })
            .registerTypeAdapter(Float::class.java, object : TypeAdapter<Float>() {
                /**
                 * Writes a Float value with a fixed 2-decimal precision to ensure uniform output.
                 */
                override fun write(out: JsonWriter, value: Float?) {
                    if (value == null) {
                        out.nullValue()
                    } else {
                        out.value(String.format(Locale.US, "%.2f", value))
                    }
                }

                /**
                 * Reads a Float value from the JSON stream.
                 * This implementation handles possible NumberFormatExceptions gracefully.
                 */
                override fun read(`in`: JsonReader): Float {
                    return try {
                        `in`.nextString().toFloat()
                    } catch (e: NumberFormatException) {
                        0.0f
                    }
                }
            })
            .disableHtmlEscaping() // Ensures characters like '<', '>' are properly preserved.
            .create()

        // Return the serialized JSON representation using the custom GSON instance.
        return gsonWithCustomAdapters.toJson(this)
    }
}