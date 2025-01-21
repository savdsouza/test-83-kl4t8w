package com.dogwalking.app.data.api.models

import kotlinx.serialization.Serializable // version 1.5.0

/**
 * A sealed class that provides a type-safe wrapper for all API responses in the application.
 *
 * Inspired by the technical specifications regarding:
 *  - Offline-first architecture (referencing Section 2. SYSTEM ARCHITECTURE/2.2 Component Details/2.2.1 Core Components).
 *  - Standard error responses and handling (referencing Section 2. SYSTEM ARCHITECTURE/2.3.3 API Security).
 *
 * This enables a unified way to handle both successful responses and error scenarios without
 * risking unchecked casts or manual type checks throughout the codebase. Furthermore, it
 * supports serialization to facilitate offline caching and seamless data persistence.
 *
 * @param T The type of data contained in a successful response.
 */
@Serializable
sealed class ApiResponse<T>

/**
 * Represents a successful state of the API response. Holds the typed response data.
 *
 * @param T The type of data contained in this success response.
 * @property data The actual data result returned by the API in a success scenario.
 * @constructor Creates a new success response holding the provided [data].
 */
@Serializable
data class Success<T>(
    val data: T
) : ApiResponse<T>()

/**
 * Represents an erroneous state of the API response. Provides standardized error information
 * useful for handling and displaying error messages, as well as for deeper application-level
 * logic (e.g., network retry, server issue handling, etc.).
 *
 * @property code The numerical error code indicating the nature of the error.
 * @property message A descriptive message explaining the reason for the error.
 * @constructor Creates a new error response with the given [code] and [message].
 */
@Serializable
data class Error(
    val code: Int,
    val message: String
) : ApiResponse<Nothing>() {

    /**
     * Determines whether this error is network-related, by checking against known network error
     * boundaries. In a production environment, this could be refined to match specific networking
     * error codes or statuses, such as HTTP 400 range errors.
     *
     * @return true if the [code] indicates a network-related issue, false otherwise.
     */
    fun isNetworkError(): Boolean {
        // Here, we treat errors in the 400–499 range as network/client errors.
        return code in 400..499
    }

    /**
     * Determines whether this error is server-related, by checking against known server-side
     * error boundaries. In a production environment, this can be refined to handle more
     * specific codes or statuses, such as HTTP 500 range errors.
     *
     * @return true if the [code] indicates a server-related issue, false otherwise.
     */
    fun isServerError(): Boolean {
        // Here, we treat errors in the 500–599 range as server errors.
        return code in 500..599
    }
}

/**
 * Extension function that indicates whether the current ApiResponse instance is of the
 * [Success] type. This helps simplify checks in client code, avoiding explicit type casting.
 *
 * Usage example:
 *  if (response.isSuccess()) {
 *      // Handle success
 *  }
 *
 * @receiver The [ApiResponse] instance.
 * @return true if this is an instance of [Success], false otherwise.
 */
fun <T> ApiResponse<T>.isSuccess(): Boolean {
    return this is Success<T>
}

/**
 * Extension function that indicates whether the current ApiResponse instance is of the
 * [Error] type. This helps simplify checks in client code, avoiding explicit type casting.
 *
 * Usage example:
 *  if (response.isError()) {
 *      // Process error details
 *  }
 *
 * @receiver The [ApiResponse] instance.
 * @return true if this is an instance of [Error], false otherwise.
 */
fun <T> ApiResponse<T>.isError(): Boolean {
    return this is Error
}

/**
 * Safely extracts the underlying data from an [ApiResponse] if it is of type [Success].
 * If the response is of type [Error], this returns null to avoid unchecked casting.
 *
 * This function is particularly helpful for simplifying data-retrieval logic:
 *  val data = response.getOrNull()
 *  if (data != null) {
 *      // Use the data
 *  } else {
 *      // Handle error scenario
 *  }
 *
 * @receiver The [ApiResponse] instance.
 * @return The typed data if this is a [Success], or null if this is an [Error].
 */
fun <T> ApiResponse<T>.getOrNull(): T? {
    return if (this is Success<T>) {
        this.data
    } else {
        null
    }
}