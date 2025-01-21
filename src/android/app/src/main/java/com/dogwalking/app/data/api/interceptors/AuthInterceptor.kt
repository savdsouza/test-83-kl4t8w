package com.dogwalking.app.data.api.interceptors

// -----------------------------------------------------------------------------------------
// External Imports (OkHttp 4.11.0)
// -----------------------------------------------------------------------------------------
import okhttp3.Interceptor
import okhttp3.Response
import okhttp3.Request

// -----------------------------------------------------------------------------------------
// External Imports (javax.inject:1)
// -----------------------------------------------------------------------------------------
import javax.inject.Inject
import javax.inject.Singleton

// -----------------------------------------------------------------------------------------
// Internal Imports - Security Utilities
// -----------------------------------------------------------------------------------------
import com.dogwalking.app.utils.SecurityUtils.getStoredToken
import com.dogwalking.app.utils.SecurityUtils.refreshTokenIfNeeded

/**
 * AuthInterceptor is a thread-safe OkHttp interceptor responsible for:
 *  - Managing secure token-based authentication for API requests.
 *  - Inserting necessary HTTP headers, including authorization and security headers.
 *  - Refreshing tokens when needed using [refreshTokenIfNeeded].
 *  - Handling authentication-related response errors to maintain a robust flow.
 *
 * This interceptor ensures compliance with the multi-factor authentication
 * and JWT-based security controls specified in the design. It manipulates
 * outgoing requests to embed necessary credentials and monitors responses
 * for potential errors, taking remedial actions (e.g., token refresh) as required.
 */
@Singleton
class AuthInterceptor @Inject constructor() : Interceptor {

    /**
     * API_VERSION property identifies the target version of the backend API
     * and is added as a custom header. This helps backend services
     * handle versioned endpoints or backward compatibility processes.
     */
    private val API_VERSION: String = "1.0"

    /**
     * CONTENT_TYPE_JSON property signifies the default Content-Type for
     * JSON-based body content. It is appended to the request headers to
     * ensure the server interprets the data correctly.
     */
    private val CONTENT_TYPE_JSON: String = "application/json"

    /**
     * Intercept the chain of HTTP requests to incorporate authentication
     * and security features, fulfilling the following steps:
     *
     * 1. Obtain the original request from the chain.
     * 2. Attempt token refresh if necessary using [refreshTokenIfNeeded].
     * 3. Retrieve the current authentication token from secure storage.
     * 4. Construct a new request builder applying security headers.
     * 5. Add Authorization header with the Bearer token if available.
     * 6. Add an API version header (X-API-Version).
     * 7. Add Content-Type and Accept headers for JSON media type.
     * 8. Add a timestamp header for additional security and traceability.
     * 9. Optionally add a request signature if an extended security feature is enabled.
     * 10. Proceed with the modified request to obtain the response.
     * 11. Check if the response indicates an authentication error (e.g., 401).
     * 12. If an auth error occurs, attempt a token refresh (once), rebuild headers, and retry.
     *
     * @param chain The OkHttp [Interceptor.Chain] providing the request and giving
     *             the ability to continue the chain with a new or existing request.
     * @return The [Response] after executing the modified request, with potential retry logic.
     */
    override fun intercept(chain: Interceptor.Chain): Response {
        // Step 1: Get the original request from the chain
        val originalRequest: Request = chain.request()

        // Step 2: Attempt refreshing the token if needed
        refreshTokenIfNeeded()

        // Step 3: Retrieve the current authentication token after possible refresh
        val currentToken: String? = getStoredToken()

        // Step 4: Construct a new request builder; copy all existing request info
        val requestBuilder = originalRequest.newBuilder()

        // Step 5: Add the Authorization header if we have a token
        if (!currentToken.isNullOrBlank()) {
            requestBuilder.header("Authorization", "Bearer $currentToken")
        }

        // Step 6: Add the API version header
        requestBuilder.header("X-API-Version", API_VERSION)

        // Step 7: Add JSON-related headers for content negotiation
        requestBuilder.header("Content-Type", CONTENT_TYPE_JSON)
        requestBuilder.header("Accept", CONTENT_TYPE_JSON)

        // Step 8: Add a timestamp header to enhance security and debugging
        val currentTimestamp = System.currentTimeMillis().toString()
        requestBuilder.header("X-Timestamp", currentTimestamp)

        // Step 9 (Optional): Add a request signature if an extended security approach is used
        // For demonstration, a placeholder is provided. Implementation depends on project requirements.
        // requestBuilder.header("X-Request-Signature", generateSignatureIfNeeded(...))

        // Finalize the updated request
        val newRequest = requestBuilder.build()

        // Step 10: Proceed with the modified request
        var response = chain.proceed(newRequest)

        // Step 11: Check for authentication error (e.g., 401)
        if (response.code == 401) {
            // Close the current response to avoid leaking
            response.close()

            // Attempt token refresh again if there's a server-based invalidation
            refreshTokenIfNeeded()
            val updatedToken: String? = getStoredToken()

            // Build a second request if the token is updated
            val retryBuilder = originalRequest.newBuilder()
            if (!updatedToken.isNullOrBlank()) {
                retryBuilder.header("Authorization", "Bearer $updatedToken")
            }
            retryBuilder.header("X-API-Version", API_VERSION)
            retryBuilder.header("Content-Type", CONTENT_TYPE_JSON)
            retryBuilder.header("Accept", CONTENT_TYPE_JSON)
            retryBuilder.header("X-Timestamp", System.currentTimeMillis().toString())
            // Optional signature
            // retryBuilder.header("X-Request-Signature", generateSignatureIfNeeded(...))

            val retryRequest = retryBuilder.build()
            response = chain.proceed(retryRequest)
        }

        // Step 12: Return the response, possibly after a retry
        return response
    }
}