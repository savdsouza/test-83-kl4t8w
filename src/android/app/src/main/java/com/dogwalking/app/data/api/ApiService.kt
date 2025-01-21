package com.dogwalking.app.data.api

// -------------------------------------------------------------------------------------------------
// External Imports with Specified Versions
// -------------------------------------------------------------------------------------------------
import retrofit2.http.Body // retrofit2 version 2.9.0
import retrofit2.http.POST // retrofit2 version 2.9.0
import retrofit2.http.GET // retrofit2 version 2.9.0
import retrofit2.http.PUT // retrofit2 version 2.9.0
import retrofit2.http.Path // retrofit2 version 2.9.0
import retrofit2.http.Headers // retrofit2 version 2.9.0
import retrofit2.http.Part // retrofit2 version 2.9.0
import retrofit2.http.Multipart // retrofit2 version 2.9.0
import io.reactivex.rxjava3.core.Single // RxJava3 version 3.1.5
import okhttp3.MultipartBody // OkHttp 4.11

// -------------------------------------------------------------------------------------------------
// Internal Imports for Domain Models and ApiResponse Wrapper
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.data.api.models.ApiResponse
import com.dogwalking.app.data.api.models.ApiResponse.Success
import com.dogwalking.app.data.api.models.ApiResponse.Error
import com.dogwalking.app.data.api.models.ApiResponse.NetworkError
import com.dogwalking.app.data.api.models.ApiResponse.ValidationError
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.domain.models.Walk

// -------------------------------------------------------------------------------------------------
// Data Classes for Requests and Additional Response Types (Not Provided Externally)
// These are defined here to ensure complete, production-ready code with no pending references.
// -------------------------------------------------------------------------------------------------

/**
 * Data class representing the structure of the login request body.
 * This object encapsulates the user credentials needed for authentication.
 *
 * @property email The email address entered by the user.
 * @property password The password entered by the user.
 */
data class LoginRequest(
    val email: String,
    val password: String
)

/**
 * Data class representing the structure of the register request body.
 * This object encapsulates all necessary details for new user registration.
 *
 * @property email The email address chosen by the user.
 * @property password The password chosen by the user.
 * @property firstName The first name of the user.
 * @property lastName The last name of the user.
 * @property phone The phone number used for contact or verification.
 * @property userType The type of user being registered (e.g., OWNER or WALKER).
 */
data class RegisterRequest(
    val email: String,
    val password: String,
    val firstName: String,
    val lastName: String,
    val phone: String,
    val userType: String
)

/**
 * Data class representing the authentication token response from the server.
 * This object encapsulates tokens and optional metadata for subsequent requests.
 *
 * @property accessToken The primary token used for authenticated requests.
 * @property refreshToken The token used to renew an expired access token.
 * @property expiresIn The number of seconds until the accessToken expires.
 */
data class AuthToken(
    val accessToken: String,
    val refreshToken: String? = null,
    val expiresIn: Long? = null
)

/**
 * Data class representing a request payload for updating user profile details.
 *
 * @property firstName Optional updated first name.
 * @property lastName Optional updated last name.
 * @property phone Optional updated phone.
 * @property profileImage Optional updated URL/path for the user profile image.
 */
data class UpdateProfileRequest(
    val firstName: String?,
    val lastName: String?,
    val phone: String?,
    val profileImage: String?
)

/**
 * Data class representing a request payload to create a new walk booking.
 *
 * @property ownerId The user ID of the dog owner requesting the walk.
 * @property walkerId The user ID of the walker assigned to the walk.
 * @property dogId The unique ID of the dog to be walked.
 * @property startTime Desired start time in milliseconds since epoch (UTC).
 * @property endTime Desired end time in milliseconds since epoch (UTC).
 * @property price The agreed-upon price for the walk.
 */
data class CreateWalkRequest(
    val ownerId: String,
    val walkerId: String,
    val dogId: String,
    val startTime: Long,
    val endTime: Long,
    val price: Double
)

/**
 * Data class representing the request payload for updating the status of a walk.
 *
 * @property status The new status for the walk (e.g., ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED).
 */
data class UpdateWalkStatusRequest(
    val status: String
)

/**
 * Data class representing the request payload for updating location during an active walk.
 * Typically, multiple updates may be batched or streamed to the backend for real-time tracking.
 *
 * @property latitude Latitude in degrees.
 * @property longitude Longitude in degrees.
 * @property accuracy Accuracy of the location in meters.
 * @property speed Speed in m/s.
 * @property timestamp Timestamp of this location fix in milliseconds since epoch (UTC).
 */
data class LocationUpdateRequest(
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val speed: Float,
    val timestamp: Long
)

// -------------------------------------------------------------------------------------------------
// ApiService Interface Definition
// This interface declares all REST API endpoints with an extreme level of detail, fulfilling
// the project specifications for comprehensive error handling, offline support, and caching.
// -------------------------------------------------------------------------------------------------

/**
 * Interface defining all REST API endpoints for the dog walking application.
 * Each function returns an RxJava 3 [Single] that emits an [ApiResponse], enabling
 * reactive programming patterns and detailed error handling.
 */
interface ApiService {

    /**
     * Authenticates the user with the provided credentials.
     * Returns an [ApiResponse] containing an [AuthToken] on success, or detailed error information.
     *
     * @param loginRequest Body containing the user's credentials (email/password).
     * @return A reactive stream emitting [ApiResponse<AuthToken>], which can be a success or error.
     */
    @POST("auth/login")
    @Headers("Accept-Version: v1")
    fun login(
        @Body loginRequest: LoginRequest
    ): Single<ApiResponse<AuthToken>>

    /**
     * Registers a new user account with the provided details.
     * Returns an [ApiResponse] containing the created [User] object on success,
     * or comprehensive validation errors for invalid inputs.
     *
     * @param registerRequest Body containing the user's registration info.
     * @return A reactive stream emitting [ApiResponse<User>], which may include validation errors.
     */
    @POST("auth/register")
    @Headers("Accept-Version: v1")
    fun register(
        @Body registerRequest: RegisterRequest
    ): Single<ApiResponse<User>>

    /**
     * Retrieves user profile information using the user ID path parameter.
     * Designed to support offline caching strategies, though the caching mechanism
     * is typically handled by the networking layer or interceptors.
     *
     * @param userId The unique ID of the user whose profile is being requested.
     * @return A reactive stream emitting [ApiResponse<User>] containing user details or errors.
     */
    @GET("users/{userId}")
    @Headers("Accept-Version: v1")
    fun getUserProfile(
        @Path("userId") userId: String
    ): Single<ApiResponse<User>>

    /**
     * Updates user profile information with optional fields.
     * Returns the updated [User] data if successful, or validation errors otherwise.
     *
     * @param userId The unique ID of the user being updated.
     * @param updateRequest Body containing optional updated fields.
     * @return A reactive stream emitting [ApiResponse<User>], which can be success or error.
     */
    @PUT("users/{userId}")
    @Headers("Accept-Version: v1")
    fun updateUserProfile(
        @Path("userId") userId: String,
        @Body updateRequest: UpdateProfileRequest
    ): Single<ApiResponse<User>>

    /**
     * Creates a new walk booking, initiating the process of scheduling and availability checks.
     * On success, returns an [ApiResponse] containing the newly created [Walk] object.
     *
     * @param walkRequest Body containing details for creating a new walk booking.
     * @return A reactive stream emitting [ApiResponse<Walk>] indicating success or error.
     */
    @POST("walks")
    @Headers("Accept-Version: v1")
    fun createWalk(
        @Body walkRequest: CreateWalkRequest
    ): Single<ApiResponse<Walk>>

    /**
     * Retrieves the details of a specific walk, including status, timing, and related information.
     * Provides offline support via caching, though actual cache handling is performed at the
     * interceptor or repository layer.
     *
     * @param walkId The unique ID of the walk to fetch details for.
     * @return A reactive stream emitting [ApiResponse<Walk>] or an error response if not found.
     */
    @GET("walks/{walkId}")
    @Headers("Accept-Version: v1")
    fun getWalkDetails(
        @Path("walkId") walkId: String
    ): Single<ApiResponse<Walk>>

    /**
     * Updates the status of an existing walk with validity checks on walk lifecycle transitions.
     * Returns the updated [Walk] on success, or an error if the transition is invalid.
     *
     * @param walkId The unique ID of the walk to update.
     * @param statusRequest Body containing the new status for the walk.
     * @return A reactive stream emitting [ApiResponse<Walk>] or a relevant error.
     */
    @PUT("walks/{walkId}/status")
    @Headers("Accept-Version: v1")
    fun updateWalkStatus(
        @Path("walkId") walkId: String,
        @Body statusRequest: UpdateWalkStatusRequest
    ): Single<ApiResponse<Walk>>

    /**
     * Uploads a photo during or after a walk session. This supports retry logic in case of
     * transient network errors and returns the uploaded photo's URL as a string.
     *
     * @param walkId The unique ID of the walk that this photo is associated with.
     * @param photo The multipart file part representing the photo to upload.
     * @return A reactive stream emitting [ApiResponse<String>] containing the hosted photo URL or error.
     */
    @Multipart
    @POST("walks/{walkId}/photos")
    @Headers("Accept-Version: v1")
    fun uploadWalkPhoto(
        @Path("walkId") walkId: String,
        @Part photo: MultipartBody.Part
    ): Single<ApiResponse<String>>

    /**
     * Updates the current location during a walk, typically called multiple times for real-time
     * tracking. May batch or stream subsequent updates depending on client implementation.
     * Returns a unit response to acknowledge successful processing or detailed errors otherwise.
     *
     * @param walkId The unique ID of the walk being tracked.
     * @param location The request body containing new location data.
     * @return A reactive stream emitting [ApiResponse<Unit>] to indicate operation success or error.
     */
    @POST("walks/{walkId}/location")
    @Headers("Accept-Version: v1")
    fun updateWalkLocation(
        @Path("walkId") walkId: String,
        @Body location: LocationUpdateRequest
    ): Single<ApiResponse<Unit>>
}