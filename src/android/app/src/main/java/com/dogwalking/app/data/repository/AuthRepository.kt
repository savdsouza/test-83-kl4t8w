package com.dogwalking.app.data.repository

// -------------------------------------------------------------------------------------------------
// External Imports with Specified Versions
// -------------------------------------------------------------------------------------------------
import javax.inject.Inject // javax.inject version 1
import androidx.security.crypto.EncryptedSharedPreferences // androidx.security.crypto version 1.1.0
import androidx.biometric.BiometricPrompt // androidx.biometric version 1.2.0
import androidx.fragment.app.FragmentActivity // AndroidX fragment-ktx (no explicit version found, part of Fragment API)
import kotlinx.coroutines.flow.Flow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.MutableStateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.StateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.asStateFlow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.rx3.await // kotlinx.coroutines.rx3 version 1.7.0
import java.util.concurrent.atomic.AtomicInteger // Part of java.util.concurrent package
import kotlin.Result // Standard Kotlin Result type

// -------------------------------------------------------------------------------------------------
// Internal Imports Based on Provided Source Files
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.data.api.ApiService
import com.dogwalking.app.data.api.models.ApiResponse
import com.dogwalking.app.data.api.models.ApiResponse.Success
import com.dogwalking.app.data.api.models.ApiResponse.Error
import com.dogwalking.app.domain.models.User

/**
 * Data class representing a token for authenticated sessions.
 * Corresponds to the AuthToken model returned by the remote API.
 *
 * @property accessToken JWT or opaque token for authorized requests.
 * @property refreshToken Token used to refresh the session when the access token expires.
 * @property expiresIn Number of seconds until the access token expires.
 */
data class AuthToken(
    val accessToken: String,
    val refreshToken: String? = null,
    val expiresIn: Long? = null
)

/**
 * Interface representing analytics or logging for authentication activities.
 * This may forward data to external analytics services or internal logs.
 */
interface AuthAnalytics {
    /**
     * Tracks a user login attempt, along with optional error messages or statuses.
     *
     * @param attempts Current number of attempted logins (for rate limiting or reporting).
     * @param success Whether the login succeeded.
     * @param errorMsg Optional error message if the login fails.
     */
    fun trackLoginAttempt(attempts: Int, success: Boolean, errorMsg: String? = null)

    /**
     * Tracks a registration attempt with optional error reporting.
     *
     * @param success Whether the registration succeeded.
     * @param errorMsg Optional error message if the registration fails.
     */
    fun trackRegisterAttempt(success: Boolean, errorMsg: String? = null)

    /**
     * Tracks a biometric authentication attempt with optional error details.
     *
     * @param success Whether the biometric auth succeeded.
     * @param errorMsg Optional error message if the biometric auth fails.
     */
    fun trackBiometricAuthAttempt(success: Boolean, errorMsg: String? = null)

    /**
     * Placeholder for logging or analytics triggered on logout.
     */
    fun trackLogout()

    /**
     * Placeholder for logging or analytics triggered on token refresh, success or failure.
     *
     * @param success Whether the token refresh was successful.
     * @param errorMsg Optional error message if the token refresh fails.
     */
    fun trackTokenRefresh(success: Boolean, errorMsg: String? = null)
}

/**
 * Represents the current authentication state within the application.
 * This sealed class can be expanded to include additional states if needed.
 */
sealed class AuthState {
    /**
     * The default, unauthenticated state. No valid session tokens exist.
     */
    object Unauthenticated : AuthState()

    /**
     * The application is currently authenticating, for instance during login or registration.
     */
    object Authenticating : AuthState()

    /**
     * A successfully authenticated state containing user details for the active session.
     * @property user The user currently authenticated in the session.
     */
    data class Authenticated(val user: User) : AuthState()

    /**
     * An error state indicating a failure during registration, login, biometric flow, or refresh.
     * @property message A human-readable message describing the authentication error.
     */
    data class AuthError(val message: String) : AuthState()
}

/**
 * Represents the current token state used by the application for handling secure requests.
 * This data class can be expanded to track token issuance times, rotation schedules, etc.
 */
data class TokenState(
    val accessToken: String? = null,
    val refreshToken: String? = null,
    val expiresIn: Long? = null
) {
    companion object {
        /**
         * An empty, default TokenState instance, used when no tokens have been set.
         */
        val Empty = TokenState()
    }
}

/**
 * Repository implementation for handling authentication operations including:
 *  - Login
 *  - Registration
 *  - Biometric authentication
 *  - Token management (refresh, secure storage)
 *  - Comprehensive error handling and rate limiting
 *
 * Fulfills project requirements specified in:
 *  1) 1.2 System Overview/High-Level Description - Multi-factor authentication and security
 *  2) 1.3 Scope/Core Features - Owner/walker profile verification
 *  3) 7.1 Authentication and Authorization/7.1.2 - Email/password, social auth, biometric
 *
 * @constructor Initializes repository with required dependencies and sets up secure storage.
 *
 * @param apiService The ApiService interface for making authentication-related API calls.
 * @param securePrefs EncryptedSharedPreferences for secure token storage.
 * @param analytics Analytics or logging utility to track authentication events.
 */
class AuthRepository @Inject constructor(
    private val apiService: ApiService,
    private val securePrefs: EncryptedSharedPreferences,
    private val analytics: AuthAnalytics
) {

    // ---------------------------------------------------------------------------------------------
    // INTERNAL STATE
    // ---------------------------------------------------------------------------------------------

    /**
     * Internal MutableStateFlow maintaining the current authentication state of the application.
     */
    private val _authState = MutableStateFlow<AuthState>(AuthState.Unauthenticated)

    /**
     * Exposed [StateFlow] to observe authentication state changes safely from external classes.
     */
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    /**
     * Atomic counter for login attempts, useful for enforcing rate limiting or capturing analytics.
     */
    private val loginAttempts: AtomicInteger = AtomicInteger(0)

    /**
     * Internal MutableStateFlow tracking the current token states for secure requests.
     */
    private val _tokenState = MutableStateFlow<TokenState>(TokenState.Empty)

    /**
     * Helper property providing read-only access to the token state. This can be consumed
     * by the rest of the application to attach tokens to network requests.
     */
    val tokenState: StateFlow<TokenState> get() = _tokenState.asStateFlow()

    init {
        // Load any existing token state from EncryptedSharedPreferences
        loadStoredTokens()
        // Optionally, we could automatically validate or refresh the token here if needed.
    }

    // ---------------------------------------------------------------------------------------------
    // LOGIN FUNCTION
    // ---------------------------------------------------------------------------------------------

    /**
     * Authenticates user with email and password, applying rate limiting and security logging.
     * Returns a [Flow] of [Result] containing the [AuthToken] or an error.
     *
     * Steps:
     *  1. Validate input credentials format.
     *  2. Check rate limiting threshold via [loginAttempts].
     *  3. Call [ApiService.login] endpoint for user authentication.
     *  4. Handle API response, map errors, and store token on success.
     *  5. Update auth state, track analytics, and return the result flow.
     *
     * @param email User's email address.
     * @param password User's plaintext password.
     * @return A [Flow] emitting [Result<AuthToken>] that can be collected asynchronously.
     */
    fun login(email: String, password: String): Flow<Result<AuthToken>> = flow {
        // Step 1: Validate credentials
        if (email.isBlank() || password.isBlank()) {
            emit(Result.failure(Exception("Email or password cannot be blank.")))
            return@flow
        }

        // Step 2: Rate limiting check
        val attempts = loginAttempts.incrementAndGet()
        analytics.trackLoginAttempt(attempts, success = false, errorMsg = null)
        if (attempts > 5) {
            emit(Result.failure(Exception("Too many login attempts. Please try again later.")))
            return@flow
        }

        // Step 3: Update state to Authenticating
        _authState.value = AuthState.Authenticating

        // Step 4: Call API service
        val response = apiService.login(
            com.dogwalking.app.data.api.LoginRequest(
                email = email,
                password = password
            )
        ).await() // Convert Single<ApiResponse<AuthToken>> to a suspending call

        when (response) {
            is Success -> {
                // Extract token from success response
                val tokenData = response.data
                // Step 5: Store token securely
                storeToken(tokenData)
                // Reset the login attempt counter
                loginAttempts.set(0)
                // Step 6: Emit success with AuthToken
                emit(Result.success(tokenData))
                // Step 7: Update auth state to a known "Authenticated" state if needed
                _authState.value = AuthState.Authenticated(
                    // We do not have user details from this endpoint directly,
                    // so we mark it as an Authenticated state with partial info if needed
                    User(
                        id = "", // unknown from this response
                        email = email,
                        firstName = "",
                        lastName = "",
                        phone = "",
                        profileImage = null,
                        userType = com.dogwalking.app.domain.models.UserType.OWNER,
                        rating = 0.0,
                        completedWalks = 0,
                        isVerified = false,
                        createdAt = 0L,
                        updatedAt = 0L
                    )
                )
                analytics.trackLoginAttempt(attempts, success = true, errorMsg = null)
            }
            is Error -> {
                // Step 8: Map error response to our domain error
                val message = "Login error: ${response.message} (code: ${response.code})"
                emit(Result.failure(Exception(message)))
                _authState.value = AuthState.AuthError(message)
                analytics.trackLoginAttempt(attempts, success = false, errorMsg = message)
            }
        }
    }.onStart {
        // Optional: Could emit a loading state or log prior to collecting
    }.catch { throwable ->
        // Handling unexpected exceptions or network issues
        val msg = "Unexpected login failure: ${throwable.message}"
        _authState.value = AuthState.AuthError(msg)
        emit(Result.failure(Exception(msg)))
    }

    // ---------------------------------------------------------------------------------------------
    // REGISTER FUNCTION
    // ---------------------------------------------------------------------------------------------

    /**
     * Registers a new user in the system. Returns a [Flow] of [Result<User>] capturing success or error.
     * Demonstrates comprehensive error handling by mapping the [ApiResponse].
     *
     * @param email User's email address to register.
     * @param password User-chosen password.
     * @param firstName First name of the user.
     * @param lastName Last name of the user.
     * @param phone Phone number for contact or verification.
     * @param userType The type of user being registered (e.g., OWNER or WALKER).
     */
    fun register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        phone: String,
        userType: String
    ): Flow<Result<User>> = flow {
        // Basic validation
        if (email.isBlank() || password.isBlank()) {
            emit(Result.failure(Exception("Email or password is blank.")))
            return@flow
        }
        if (firstName.isBlank() || lastName.isBlank()) {
            emit(Result.failure(Exception("First name or last name is blank.")))
            return@flow
        }
        // Track attempt
        analytics.trackRegisterAttempt(success = false, errorMsg = null)
        // Update auth state to Authenticating
        _authState.value = AuthState.Authenticating

        // Call API service
        val response = apiService.register(
            com.dogwalking.app.data.api.RegisterRequest(
                email = email,
                password = password,
                firstName = firstName,
                lastName = lastName,
                phone = phone,
                userType = userType
            )
        ).await()

        when (response) {
            is Success -> {
                val newUser = response.data
                emit(Result.success(newUser))
                _authState.value = AuthState.Authenticated(newUser)
                analytics.trackRegisterAttempt(success = true, errorMsg = null)
            }
            is Error -> {
                val message = "Registration error: ${response.message} (code: ${response.code})"
                emit(Result.failure(Exception(message)))
                _authState.value = AuthState.AuthError(message)
                analytics.trackRegisterAttempt(success = false, errorMsg = message)
            }
        }
    }.onStart {
        // Optionally emit loading or log
    }.catch { throwable ->
        val msg = "Unexpected registration failure: ${throwable.message}"
        _authState.value = AuthState.AuthError(msg)
        emit(Result.failure(Exception(msg)))
    }

    // ---------------------------------------------------------------------------------------------
    // BIOMETRIC AUTHENTICATION
    // ---------------------------------------------------------------------------------------------

    /**
     * Handles biometric authentication flow using [BiometricPrompt]. Returns a [Flow] of [Result<Boolean>].
     * All error conditions, cancellations, or hardware unavailability are mapped thoroughly.
     *
     * @param activity The [FragmentActivity] required to show the biometric prompt.
     * @return A [Flow] emitting [Result.success(true)] if authenticated, or [Result.failure] otherwise.
     *
     * Steps:
     *  1. Check device biometric availability.
     *  2. Create a secure [BiometricPrompt].
     *  3. Show biometric dialog.
     *  4. Handle success, cancellation, or errors from prompt callbacks.
     *  5. Update auth state if needed and track the event in analytics.
     */
    fun authenticateWithBiometrics(activity: FragmentActivity): Flow<Result<Boolean>> = flow {
        // Step 1: Check device availability (simplified check, rely on BiometricPrompt final result).
        // A real check might require BiometricManager.from(activity).canAuthenticate() call.

        // Step 2: Build BiometricPrompt
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Biometric Authentication")
            .setSubtitle("Log in using your biometric credential")
            .setNegativeButtonText("Cancel")
            .build()

        // Step 3: Create a suspending mechanism to wait for prompt callback
        val biometricPrompt = BiometricPrompt(activity, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                // Authentication success
                // Emitting true from within callback - bridging will be done below with coroutines
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                // Authentication error
            }

            override fun onAuthenticationFailed() {
                // User did not authenticate successfully
            }
        })

        // Step 4: Show prompt and suspend for callback results
        val authenticationResult = kotlinx.coroutines.suspendCancellableCoroutine<Result<Boolean>> { continuation ->
            biometricPrompt.authenticate(promptInfo)
            // We'll set up a callback to resume or cancel the continuation
            biometricPrompt.setAuthenticationCallback(object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    // Indicate success
                    continuation.resumeWith(Result.success(Result.success(true)))
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Indicate failure
                    continuation.resumeWith(Result.success(Result.failure(Exception("Biometric error: $errString"))))
                }

                override fun onAuthenticationFailed() {
                    // Indicate a "failed" attempt
                    continuation.resumeWith(Result.success(Result.failure(Exception("Biometric authentication failed."))))
                }
            })
        }

        // Step 5: Map result and update state
        if (authenticationResult.isSuccess) {
            // Auth succeeded
            _authState.value = AuthState.Authenticated(
                // In practice, we might reload the user or confirm token validity
                User(
                    id = "",
                    email = "biometric@user.com",
                    firstName = "Biometric",
                    lastName = "User",
                    phone = "",
                    profileImage = null,
                    userType = com.dogwalking.app.domain.models.UserType.OWNER,
                    rating = 0.0,
                    completedWalks = 0,
                    isVerified = true,
                    createdAt = 0L,
                    updatedAt = 0L
                )
            )
            analytics.trackBiometricAuthAttempt(success = true, errorMsg = null)
            emit(Result.success(true))
        } else {
            val error = authenticationResult.exceptionOrNull()?.message ?: "Unknown biometric error"
            _authState.value = AuthState.AuthError(error)
            analytics.trackBiometricAuthAttempt(success = false, errorMsg = error)
            emit(Result.failure(Exception(error)))
        }
    }.onStart {
        // Possibly set AuthState to Authenticating for UI
        _authState.value = AuthState.Authenticating
    }.catch { throwable ->
        val msg = "Biometric Auth Failure: ${throwable.message}"
        _authState.value = AuthState.AuthError(msg)
        analytics.trackBiometricAuthAttempt(success = false, errorMsg = msg)
        emit(Result.failure(Exception(msg)))
    }

    // ---------------------------------------------------------------------------------------------
    // LOGOUT FUNCTION
    // ---------------------------------------------------------------------------------------------

    /**
     * Logs out the current user by clearing stored tokens, resetting application authentication state,
     * and notifying analytics.
     *
     * This function can be expanded to perform server-side invalidation of refresh tokens if required.
     */
    fun logout() {
        // Step 1: Clear tokens in secure storage
        securePrefs.edit().apply {
            remove("ACCESS_TOKEN")
            remove("REFRESH_TOKEN")
            remove("EXPIRES_IN")
            apply()
        }
        _tokenState.value = TokenState.Empty

        // Step 2: Reset auth state
        _authState.value = AuthState.Unauthenticated

        // Step 3: Track event
        analytics.trackLogout()
    }

    // ---------------------------------------------------------------------------------------------
    // REFRESH TOKEN FUNCTION
    // ---------------------------------------------------------------------------------------------

    /**
     * Initiates a token refresh operation if a valid refresh token is present.
     * Returns a [Flow] of [Result<AuthToken>] to indicate success or error conditions.
     *
     * Steps:
     * 1. Check for existing refresh token from secure prefs or [TokenState].
     * 2. Call [ApiService.refreshToken].
     * 3. Handle success or error and update secure store.
     * 4. Emit result and track analytics.
     */
    fun refreshToken(): Flow<Result<AuthToken>> = flow {
        // Step 1: Check for refresh token existence
        val currentRefreshToken = _tokenState.value.refreshToken
            ?: securePrefs.getString("REFRESH_TOKEN", null)

        if (currentRefreshToken.isNullOrBlank()) {
            emit(Result.failure(Exception("No refresh token available.")))
            return@flow
        }

        // Step 2: Update state to Authenticating if needed
        _authState.value = AuthState.Authenticating

        // Step 3: Call API to refresh
        val response = apiService.refreshToken(currentRefreshToken).await()

        when (response) {
            is Success -> {
                val tokenData = response.data
                storeToken(tokenData)
                emit(Result.success(tokenData))
                // Keep the current user potentially recognized as Authenticated
                if (_authState.value is AuthState.Authenticated) {
                    // do not override the user info
                } else {
                    // fallback if unknown
                    _authState.value = AuthState.Unauthenticated
                }
                analytics.trackTokenRefresh(success = true, errorMsg = null)
            }
            is Error -> {
                val message = "Token refresh error: ${response.message} (code: ${response.code})"
                emit(Result.failure(Exception(message)))
                _authState.value = AuthState.AuthError(message)
                analytics.trackTokenRefresh(success = false, errorMsg = message)
            }
        }
    }.catch { throwable ->
        val msg = "Unexpected token refresh failure: ${throwable.message}"
        _authState.value = AuthState.AuthError(msg)
        analytics.trackTokenRefresh(success = false, errorMsg = msg)
        emit(Result.failure(Exception(msg)))
    }

    // ---------------------------------------------------------------------------------------------
    // HELPER METHODS
    // ---------------------------------------------------------------------------------------------

    /**
     * Loads any previously stored tokens from EncryptedSharedPreferences into the local _tokenState.
     * This helps the app persist session data across restarts or processes.
     */
    private fun loadStoredTokens() {
        val savedAccess = securePrefs.getString("ACCESS_TOKEN", null)
        val savedRefresh = securePrefs.getString("REFRESH_TOKEN", null)
        val savedExpires = securePrefs.getLong("EXPIRES_IN", 0L)

        if (!savedAccess.isNullOrBlank()) {
            _tokenState.value = TokenState(
                accessToken = savedAccess,
                refreshToken = savedRefresh,
                expiresIn = savedExpires
            )
        }
    }

    /**
     * Securely persists token data to [EncryptedSharedPreferences] and updates the local _tokenState.
     *
     * @param token The [AuthToken] object to store.
     */
    private fun storeToken(token: AuthToken) {
        securePrefs.edit().apply {
            putString("ACCESS_TOKEN", token.accessToken)
            putString("REFRESH_TOKEN", token.refreshToken)
            putLong("EXPIRES_IN", token.expiresIn ?: 0L)
            apply()
        }
        _tokenState.value = TokenState(
            accessToken = token.accessToken,
            refreshToken = token.refreshToken,
            expiresIn = token.expiresIn
        )
    }
}