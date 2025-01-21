package com.dogwalking.app.ui.payment.viewmodel

// -------------------------------------------------------------------------------------------------
// External Imports with Specified Versions
// -------------------------------------------------------------------------------------------------
import androidx.lifecycle.ViewModel // version 2.6.1
import androidx.lifecycle.viewModelScope // version 2.6.1
import javax.inject.Inject // version 1
import kotlinx.coroutines.flow.MutableStateFlow // version 1.7.3
import kotlinx.coroutines.flow.StateFlow // version 1.7.3
import kotlinx.coroutines.flow.asStateFlow // version 1.7.3
import kotlinx.coroutines.flow.catch // version 1.7.3
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch // version 1.7.3
import android.net.ConnectivityManager // version default

// Optional analytics import if needed for extended tracking:
// import com.google.firebase.analytics.FirebaseAnalytics // version 21.3.0

// -------------------------------------------------------------------------------------------------
// Internal Imports (Named) - Domain and Use Cases
// -------------------------------------------------------------------------------------------------
import dagger.hilt.android.lifecycle.HiltViewModel
import com.dogwalking.app.domain.usecases.PaymentUseCase
import com.dogwalking.app.domain.usecases.PaymentFilter
import com.dogwalking.app.domain.usecases.Pagination
import com.dogwalking.app.domain.models.Payment

/**
 * # PaymentViewModel
 *
 * Enhanced ViewModel managing payment-related UI state and user interactions in the dog walking
 * application, fulfilling the financial operations scope (see Technical Specification §1.3).
 * Provides comprehensive offline support, real-time error handling, and integration with
 * [PaymentUseCase].
 *
 * @constructor Injects the [PaymentUseCase] dependency along with optional Android system
 * services (e.g., [ConnectivityManager]) to monitor network changes.
 *
 * Steps during initialization:
 * 1. Store the [PaymentUseCase] reference.
 * 2. Initialize all internal [MutableStateFlow] properties for payments, UI state, and offline status.
 * 3. Optionally set up network connectivity monitoring to update offline/online status in real time.
 */
@HiltViewModel
class PaymentViewModel @Inject constructor(
    private val paymentUseCase: PaymentUseCase,
    private val connectivityManager: ConnectivityManager?
) : ViewModel() {

    // ---------------------------------------------------------------------------------------------
    // Private Backing StateFlows
    // ---------------------------------------------------------------------------------------------

    /**
     * Holds a mutable list of [Payment] objects representing the current or most recently
     * fetched transaction data. Initially empty.
     */
    private val _payments: MutableStateFlow<List<Payment>> = MutableStateFlow(emptyList())

    /**
     * Publicly exposed read-only [StateFlow] of payment transactions. Observers (e.g., UI) can
     * collect this flow to receive real-time updates on payment history or newly processed
     * transactions.
     */
    val payments: StateFlow<List<Payment>> = _payments.asStateFlow()

    /**
     * Holds the mutable UI state reflecting various stages of payment operations, such
     * as Loading, Processing, or Error. Initially set to [PaymentUIState.Idle].
     */
    private val _uiState: MutableStateFlow<PaymentUIState> =
        MutableStateFlow(PaymentUIState.Idle)

    /**
     * Publicly exposed read-only [StateFlow] representing the current UI state for payment
     * screens. Intended for direct observation by composables or Fragment-based UIs.
     */
    val uiState: StateFlow<PaymentUIState> = _uiState.asStateFlow()

    /**
     * Tracks whether the application is currently offline, determined by a network connectivity
     * check. True indicates offline mode; false indicates online mode.
     */
    private val _isOffline: MutableStateFlow<Boolean> = MutableStateFlow(false)

    /**
     * Publicly exposed [StateFlow] reflecting the offline/online status of the app. This can be
     * used to toggle UI elements or block operations that require network access.
     */
    val isOffline: StateFlow<Boolean> = _isOffline.asStateFlow()

    // ---------------------------------------------------------------------------------------------
    // Initialization Block
    // ---------------------------------------------------------------------------------------------
    init {
        // Perform any additional setup here, such as connectivity monitoring.
        monitorConnectivity()
    }

    // ---------------------------------------------------------------------------------------------
    // Function: processPayment
    // Description:
    // Processes a new payment transaction with complete offline support, validation, analytics
    // tracking, and error handling. Implements the steps described in the technical specification:
    // 1. Check network connectivity; if offline, queue payment for later processing.
    // 2. If online, validate payment details and proceed with payment processing in a coroutine.
    // 3. Update [uiState] according to success or failure scenarios.
    // 4. Implement optional retry mechanism for transient failures.
    // ---------------------------------------------------------------------------------------------
    fun processPayment(payment: Payment) {
        viewModelScope.launch {
            // Step 1: Check network connectivity; update offline state appropriately
            val offlineNow = !isNetworkConnected()
            _isOffline.value = offlineNow

            if (offlineNow) {
                // If offline, queue payment for later processing, then update UI state accordingly
                try {
                    // Attempt to queue offline
                    paymentUseCase.queueOfflinePayment(payment)
                    _uiState.value = PaymentUIState.OfflineQueued(payment)
                } catch (ex: Exception) {
                    // If queuing fails, show an error state
                    _uiState.value = PaymentUIState.Error(
                        message = "Failed to queue payment offline",
                        cause = ex
                    )
                }
                return@launch
            }

            // Step 2: If online, update UI state to display 'Loading' or 'Validating' stage
            _uiState.value = PaymentUIState.Validating

            // Validate payment details
            val validationResult = paymentUseCase.validatePayment(payment)
            if (validationResult.isFailure) {
                // Handle validation error
                val errorMsg = validationResult.exceptionOrNull()?.message ?: "Validation failed"
                _uiState.value = PaymentUIState.Error(message = errorMsg)
                return@launch
            }

            val validationData = validationResult.getOrNull()
            if (validationData == null || !validationData.isValid) {
                // If validation result indicates an invalid payment
                _uiState.value = PaymentUIState.Error(
                    message = validationData?.errorMessage ?: "Payment is not valid"
                )
                return@launch
            }

            // Step 3: Proceed with payment processing
            _uiState.value = PaymentUIState.Processing
            paymentUseCase.processPayment(payment)
                .catch { exception ->
                    // Capture any exception from the flow
                    _uiState.value = PaymentUIState.Error(
                        message = "Error while processing payment",
                        cause = exception
                    )
                }
                .collect { result ->
                    // Step 4: Handle success or failure from PaymentUseCase
                    if (result.isSuccess) {
                        val processedPayment = result.getOrNull()
                        // Update payments list if needed
                        processedPayment?.let { updated ->
                            val updatedList = _payments.value.toMutableList().apply {
                                add(updated)
                            }
                            _payments.value = updatedList
                        }
                        _uiState.value = PaymentUIState.Success(
                            message = "Payment processed successfully",
                            payment = processedPayment
                        )
                    } else {
                        val failureEx = result.exceptionOrNull()
                        // Implement optional single retry (example) or show error
                        if (failureEx != null) {
                            // Here, we can decide to show an error or do a retry
                            // For demonstration, we'll transition to Error directly
                            _uiState.value = PaymentUIState.Error(
                                message = "Payment processing failed",
                                cause = failureEx
                            )
                        }
                    }
                }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Function: loadPaymentHistory
    // Description:
    // Loads paginated payment history for a specific user, applying any desired filters and
    // updating the associated UI states. Demonstrates offline caching and live data dissemination
    // to [payments] and [uiState].
    // ---------------------------------------------------------------------------------------------
    fun loadPaymentHistory(userId: String, page: Int, pageSize: Int, filter: PaymentFilter) {
        viewModelScope.launch {
            // Immediately indicate Loading state to the UI
            _uiState.value = PaymentUIState.Loading

            // Launch a coroutine to fetch paginated payment history
            paymentUseCase.getPaymentHistory(
                userId = userId,
                filter = filter,
                pagination = Pagination(page, pageSize)
            ).catch { exception ->
                // In case of error, show the Error state
                _uiState.value = PaymentUIState.Error(
                    message = "Failed to load payment history",
                    cause = exception
                )
            }.collect { paginatedResult ->
                // On success, update Payment list and UI state
                _payments.value = paginatedResult.items
                _uiState.value = PaymentUIState.Success(
                    message = "Payment history loaded successfully",
                    payments = paginatedResult.items
                )
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Function: refundPayment
    // Description:
    // Initiates a refund operation on an existing payment. Validates refund details, performs
    // asynchronous communication through [PaymentUseCase], and updates [uiState] accordingly.
    // ---------------------------------------------------------------------------------------------
    fun refundPayment(paymentId: String, amount: Double, reason: String) {
        viewModelScope.launch {
            // Indicate an ongoing UI operation
            _uiState.value = PaymentUIState.Loading

            // Call the PaymentUseCase to process the refund
            paymentUseCase.refundPayment(paymentId, request = com.dogwalking.app.domain.usecases.RefundRequest(
                amount = amount,
                reason = reason
            ))
            .catch { exception ->
                // Capture exceptions in the refund flow
                _uiState.value = PaymentUIState.Error(
                    message = "Error while initiating refund",
                    cause = exception
                )
            }
            .collect { result ->
                // Evaluate success or failure
                if (result.isSuccess) {
                    // If successful, update UI to reflect success
                    _uiState.value = PaymentUIState.Success(
                        message = "Refund processed successfully"
                    )
                } else {
                    val failureEx = result.exceptionOrNull()
                    _uiState.value = PaymentUIState.Error(
                        message = failureEx?.message ?: "Unknown refund error",
                        cause = failureEx
                    )
                }
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Private Function: monitorConnectivity
    // Description:
    // Demonstrates establishing a mechanism to observe network connectivity changes. In a full
    // implementation, you would register a [ConnectivityManager.NetworkCallback] or use a similar
    // approach to detect real-time network status updates, updating _isOffline accordingly.
    // ---------------------------------------------------------------------------------------------
    private fun monitorConnectivity() {
        // For demonstration, this snippet only checks connectivity once. In production, implement
        // a continuous monitoring mechanism with a registered callback or a flow-based approach.
        _isOffline.value = !isNetworkConnected()
    }

    // ---------------------------------------------------------------------------------------------
    // Private Function: isNetworkConnected
    // Description:
    // Helper method to check if the device has any active network connection, returning false if
    // [connectivityManager] is null or no network is available.
    // ---------------------------------------------------------------------------------------------
    private fun isNetworkConnected(): Boolean {
        // In a real implementation, this logic might rely on a NetworkCallback or APIs such as
        // connectivityManager.activeNetwork. Here, returning a best-guess boolean for demonstration.
        return connectivityManager?.activeNetwork != null
    }
}

/**
 * # PaymentUIState
 *
 * Enhanced sealed class representing various UI states for the payment screens, including
 * offline support, loading, retry mechanics, and error handling. Conforms to the technical
 * specification requirements for robust user feedback and offline-first architecture.
 */
sealed class PaymentUIState {

    /**
     * Represents an idle or default state of the UI, typically shown when no operation
     * is in progress and no particular status is displayed.
     */
    object Idle : PaymentUIState()

    /**
     * Indicates that an operation (e.g., loading payment history, initiating a refund) is
     * in progress, and the UI may show a spinner or loading indicator.
     */
    object Loading : PaymentUIState()

    /**
     * Displayed when payment details are being validated, for example, prior to processing
     * a payment or refund. The UI may show a verification indicator or message.
     */
    object Validating : PaymentUIState()

    /**
     * Represents an in-progress state while a payment is being processed online. The UI
     * typically shows a progress bar or disables user interactions until processing completes.
     */
    object Processing : PaymentUIState()

    /**
     * Indicates that a payment has been queued locally for offline processing due to
     * network unavailability. The UI may show a notification that the transaction will
     * be retried when connectivity is restored.
     *
     * @property payment The payment object queued for offline processing.
     */
    data class OfflineQueued(val payment: Payment) : PaymentUIState()

    /**
     * Represents a successful operation (e.g., loaded payment history, completed payment,
     * or processed refund).
     *
     * @property message Optional message providing details about the success.
     * @property payment Optional single payment object, if relevant to the operation.
     * @property payments Optional list of payments, e.g., when loading history.
     */
    data class Success(
        val message: String? = null,
        val payment: Payment? = null,
        val payments: List<Payment>? = null
    ) : PaymentUIState()

    /**
     * Represents an error state, capturing a message and optionally the underlying exception.
     * The UI may display an error dialog, toast, or retry prompt for the user.
     *
     * @property message A human-readable description of the error.
     * @property cause An optional throwable containing technical details for logging.
     */
    data class Error(
        val message: String,
        val cause: Throwable? = null
    ) : PaymentUIState()

    /**
     * Indicates that a failed operation is being retried. Can be used to notify the UI
     * that an automated or manual retry attempt is in progress, providing a chance to
     * display progress or wait states.
     *
     * @property attempt The current retry attempt count.
     */
    data class Retrying(val attempt: Int) : PaymentUIState()
}