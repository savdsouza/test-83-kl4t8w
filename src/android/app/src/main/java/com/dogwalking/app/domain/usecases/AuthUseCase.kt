package com.dogwalking.app.domain.usecases

// ---------------------------------------------------------------------------------------------
// External Imports with Specified Versions
// ---------------------------------------------------------------------------------------------
import javax.inject.Inject // javax.inject version 1
import kotlinx.coroutines.flow.Flow // kotlinx.coroutines.flow version 1.7.0
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flow
import arrow.core.Either // arrow.core version 1.2.0
import arrow.core.left
import arrow.core.right
import androidx.biometric.BiometricPrompt // androidx.biometric version 1.2.0
import androidx.fragment.app.FragmentActivity // AndroidX FragmentActivity from fragment-ktx

// ---------------------------------------------------------------------------------------------
// Internal Imports Based on Provided Source Files
// ---------------------------------------------------------------------------------------------
import com.dogwalking.app.data.repository.AuthRepository
import com.dogwalking.app.data.repository.AuthToken
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.utils.SecurityUtils

/**
 * A sealed class representing various kinds of validation errors
 * that can occur while verifying user credentials or input data.
 */
sealed class ValidationError(val message: String) {

    /**
     * Represents an error triggered when the email format is invalid.
     */
    class EmailFormatError(message: String) : ValidationError(message)

    /**
     * Represents an error for insufficient or invalid password strength.
     */
    class PasswordStrengthError(message: String) : ValidationError(message)

    /**
     * Represents an error when the provided password is found in a well-known
     * list of common or compromised passwords.
     */
    class CommonPasswordError(message: String) : ValidationError(message)

    /**
     * Represents an error raised when the user has exceeded the maximum
     * number of allowed login attempts, triggering a lockout or waiting period.
     */
    class LockoutError(message: String) : ValidationError(message)

    /**
     * Represents a generic or unknown validation error for fallback scenarios.
     */
    class Unknown(message: String) : ValidationError(message)
}

/**
 * A use case class implementing comprehensive authentication business logic,
 * including advanced security checks, multi-factor authentication (MFA),
 * biometric support, and rate limiting. This class delegates low-level
 * operations to the [AuthRepository] while enforcing additional validations
 * and presenting a simplified interface for the application domain.
 *
 * @property authRepository The repository responsible for interacting with
 * authentication APIs and managing tokens or credentials.
 * @property securityUtils An enterprise-grade utility object enforcing
 * cryptographic and validation operations, such as email format checks
 * and password strength rules.
 * @property MAX_LOGIN_ATTEMPTS A configurable threshold for the maximum
 * number of login attempts allowed before a lockout is enforced.
 * @property RATE_LIMIT_DURATION A duration in milliseconds after which
 * login attempts may be reset or reevaluated.
 */
class AuthUseCase @Inject constructor(
    private val authRepository: AuthRepository,
    private val securityUtils: SecurityUtils
) {

    /**
     * Maximum allowed login attempts before triggering lockout.
     * Adjust as needed for the organization's security policy.
     */
    private val MAX_LOGIN_ATTEMPTS: Int = 5

    /**
     * Rate limit duration in milliseconds (e.g., 5 minutes).
     * This can be tied to an external system or an in-memory timer.
     */
    private val RATE_LIMIT_DURATION: Long = 300_000L

    /**
     * Tracks how many times the user has attempted to log in recently.
     * For a more robust approach, store or persist this in a secure
     * session or cache with timestamps to handle resets.
     */
    private var recentLoginAttempts: Int = 0

    /**
     * Basic initialization for this use case. Intended to illustrate how
     * dependencies or state could be set up at creation time.
     */
    init {
        // 1. Initialize repository dependency (handled by constructor).
        // 2. Initialize security utils dependency (handled by constructor).
        // 3. Set rate limiting parameters (configured above).
        // 4. Initialize any ephemeral or session-scoped state if necessary.
    }

    /**
     * Validates user login credentials with enhanced security checks,
     * returning an [Either] type from Arrow for functional error handling.
     *
     * Steps:
     * 1. Check rate limiting status.
     * 2. Validate email format using SecurityUtils or domain logic.
     * 3. Validate password complexity requirements (length, pattern).
     * 4. Check against known common or compromised password lists.
     * 5. Verify account lockout status if attempts have exceeded the max.
     * 6. Return either a success result or a detailed [ValidationError].
     *
     * @param email The user-input email to validate.
     * @param password The user-input password to validate.
     * @return An [Either] wrapping [ValidationError] on failure or [Unit] on success.
     */
    fun validateCredentials(
        email: String,
        password: String
    ): Either<ValidationError, Unit> {

        // 1. Check current rate limiting / recent attempts
        if (recentLoginAttempts >= MAX_LOGIN_ATTEMPTS) {
            return ValidationError.LockoutError(
                "Too many login attempts. Your account is temporarily locked."
            ).left()
        }

        // 2. Validate email format (placeholder call)
        val isEmailValid = securityUtils.validateEmailFormat(email)
        if (!isEmailValid) {
            return ValidationError.EmailFormatError(
                "Invalid email format: $email"
            ).left()
        }

        // 3. Validate password complexity
        val isComplex = securityUtils.validatePasswordStrength(password)
        if (!isComplex) {
            return ValidationError.PasswordStrengthError(
                "Password does not meet the required complexity."
            ).left()
        }

        // 4. Check against a common password list (placeholder approach)
        val commonPasswords = listOf("123456", "password", "qwerty", "123456789")
        if (commonPasswords.any { it.equals(password, ignoreCase = true) }) {
            return ValidationError.CommonPasswordError(
                "Password is too common or insecure."
            ).left()
        }

        // 5. Check account lockout if needed. Since we're incrementing attempts
        // during the login function, we won't do that here again. This step
        // remains a placeholder for re-verification logic if externally required.

        // 6. All checks passed
        return Unit.right()
    }

    /**
     * Authenticates a user with their email and password, applying the
     * validations and security measures required by the system. This function
     * returns a [Flow] of [Result], producing either a successful [AuthToken]
     * or an error upon collection.
     *
     * Steps:
     * 1. Call [validateCredentials] to ensure inputs meet security requirements.
     * 2. Increment the local attempt counter and handle lockout if needed.
     * 3. Attempt authentication via the [AuthRepository].
     * 4. Check if MFA is required; if so, proceed with MFA gating (placeholder).
     * 5. Update any login metrics or analytics via the repository if needed.
     * 6. Return the resulting Flow of authenticated tokens or errors.
     *
     * @param email The user's email.
     * @param password The user's password.
     * @return A Flow producing [Result<AuthToken>] for asynchronous collection.
     */
    fun login(
        email: String,
        password: String
    ): Flow<Result<AuthToken>> = flow {
        // 1. Validate credentials
        val validation = validateCredentials(email, password)
        if (validation.isLeft()) {
            // Construct an error and emit as a failing result
            val errorMsg = validation.swap().orNull()?.message ?: "Unknown validation error"
            emit(Result.failure(Exception(errorMsg)))
            return@flow
        }

        // 2. Increment local login attempt count
        recentLoginAttempts++

        // 3. Attempt authentication
        // The repository internally handles token storage, rate limiting logic, etc.
        emitAll(
            authRepository.login(email, password)
        )
    }.catch { e ->
        // Catches any unexpected exceptions during flow collection
        emit(Result.failure(Exception("Login flow failed: ${e.message}", e)))
    }

    /**
     * Registers a new user account with the specified details. This function
     * also validates the provided email and password prior to calling the
     * repository, ensuring the system's security rules are met.
     *
     * Steps:
     * 1. Validate user input (e.g. email format, password strength).
     * 2. Call the repository's register function with validated data.
     * 3. Return a Flow that can emit successes or failures with full detail.
     *
     * @param email The new user's email address.
     * @param password The new user's chosen password.
     * @param firstName The user's first name.
     * @param lastName The user's last name.
     * @param phone The user's phone number.
     * @param userType The role/type of the user (e.g., "OWNER" or "WALKER").
     * @return A Flow producing [Result<User>] that includes the newly created user info on success.
     */
    fun register(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        phone: String,
        userType: String
    ): Flow<Result<User>> = flow {
        // Perform minimal local validation. (We can reuse validateCredentials for full checks.)
        val validation = validateCredentials(email, password)
        if (validation.isLeft()) {
            val errorMsg = validation.swap().orNull()?.message ?: "Registration validation error"
            emit(Result.failure(Exception(errorMsg)))
            return@flow
        }

        // If minimal checks pass, proceed to call repository
        emitAll(
            authRepository.register(
                email = email,
                password = password,
                firstName = firstName,
                lastName = lastName,
                phone = phone,
                userType = userType
            )
        )
    }.catch { e ->
        emit(Result.failure(Exception("Registration failed: ${e.message}", e)))
    }

    /**
     * Manages biometric authentication by delegating to the repository layer,
     * while optionally performing additional checks or logging at the domain
     * level. Returns a Flow of Result wrapping a Boolean to indicate success.
     *
     * Steps:
     * 1. Verify biometric capability (placeholder check).
     * 2. Initialize or confirm security level requirements if needed.
     * 3. Call [AuthRepository.authenticateWithBiometrics] to show the prompt.
     * 4. Handle authentication callback results and update metrics if desired.
     * 5. Return a Flow that can emit success (true) or error upon collection.
     *
     * @param activity The activity from which to show the biometric prompt.
     * @return A Flow producing [Result<Boolean>] signifying success or failure.
     */
    fun authenticateWithBiometrics(
        activity: FragmentActivity
    ): Flow<Result<Boolean>> = flow {
        // Step 1. (Optional) Evaluate if device meets security threshold. For demonstration,
        // skipping advanced capability checks beyond the repository's internal approach.

        // Step 2. Possibly confirm advanced security contexts or session states here.

        // Step 3. Delegate to the repository's biometrics functionality
        emitAll(
            authRepository.authenticateWithBiometrics(activity)
        )
    }.catch { e ->
        emit(Result.failure(Exception("Biometric authentication failed: ${e.message}", e)))
    }

    /**
     * Processes multi-factor authentication (MFA) flow for an already logged-in user,
     * verifying the MFA code and updating the system's status accordingly. Returns
     * a Flow of Boolean results, signifying whether the code was valid.
     *
     * Steps:
     * 1. Validate MFA code format (e.g., length, numeric, etc.). This example is simplified.
     * 2. Check code expiration or timing constraints if needed.
     * 3. Call [AuthRepository.validateMFA] to confirm code accuracy server-side.
     * 4. Update any relevant user session or analytics in the domain if needed.
     * 5. Return a Flow emitting success (true) or error conditions.
     *
     * @param userId The ID of the user for whom MFA is being performed.
     * @param mfaCode The MFA code submitted by the user.
     * @return A Flow producing [Result<Boolean>] indicating if verification succeeded.
     */
    fun handleMFA(
        userId: String,
        mfaCode: String
    ): Flow<Result<Boolean>> = flow {
        // Step 1. Validate simple format or length checks (e.g., 6-digit numeric) if required.
        if (mfaCode.length < 4 || mfaCode.length > 8) {
            emit(Result.failure(Exception("MFA code format is invalid.")))
            return@flow
        }

        // Steps 2/3. Delegate to repository
        emitAll(authRepository.validateMFA(userId, mfaCode))
    }.catch { e ->
        emit(Result.failure(Exception("MFA process failed: ${e.message}", e)))
    }

    /**
     * Logs out the current user from the system by clearing tokens and resetting
     * relevant application state. This function does not return a Flow, as the
     * logout operation is typically a one-shot user action with no streaming
     * result required. Additional fields in the domain could be reset here if
     * they are stored at the use case level.
     */
    fun logout() {
        // Delegates the logout process to the repository, which clears credentials forcibly.
        authRepository.logout()

        // Reset local attempt counter
        recentLoginAttempts = 0
    }
}