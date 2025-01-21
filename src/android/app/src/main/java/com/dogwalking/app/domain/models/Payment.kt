package com.dogwalking.app.domain.models

// -------------------------------------------------------------------------------------------------
// External Imports with Specified Library Versions
// -------------------------------------------------------------------------------------------------
import android.os.Parcelable // vlatest (Android OS library for efficient parcelable data transfer)
import kotlinx.parcelize.Parcelize // v1.9.0 (KotlinX library for automatic Parcelable generation)
import kotlinx.serialization.Serializable // v1.5.0 (Kotlin Serialization for data classes)
import kotlinx.serialization.json.JsonNames // v1.5.0 (Support multiple JSON field names for compatibility)

// -------------------------------------------------------------------------------------------------
// Internal Import (Walk) - Used to reference walk details (id, price) for payment processing
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.domain.models.Walk

// -------------------------------------------------------------------------------------------------
// Enum Class: PaymentStatus
// Description: Enhanced enumeration defining all possible states for a payment transaction,
// supporting additional states like DISPUTED and REQUIRES_ACTION for advanced payment flows.
// -------------------------------------------------------------------------------------------------
@Serializable
enum class PaymentStatus {
    /**
     * Payment is being processed or is awaiting authorization.
     */
    PENDING,

    /**
     * Payment has been authorized but not yet captured/posted.
     */
    AUTHORIZED,

    /**
     * Payment successfully completed.
     */
    COMPLETED,

    /**
     * Payment failed to process.
     */
    FAILED,

    /**
     * Payment has been fully refunded.
     */
    REFUNDED,

    /**
     * Payment has been partially refunded.
     */
    PARTIALLY_REFUNDED,

    /**
     * Payment was cancelled before completion.
     */
    CANCELLED,

    /**
     * Payment is under dispute or chargeback.
     */
    DISPUTED,

    /**
     * Payment requires additional user interaction (e.g., 3D Secure).
     */
    REQUIRES_ACTION
}

// -------------------------------------------------------------------------------------------------
// Enum Class: PaymentMethod
// Description: Comprehensive enumeration defining all supported payment methods, including
// modern wallet solutions and standard card-based methods.
// -------------------------------------------------------------------------------------------------
@Serializable
enum class PaymentMethod {
    /**
     * Payment using a credit card.
     */
    CREDIT_CARD,

    /**
     * Payment using a debit card.
     */
    DEBIT_CARD,

    /**
     * Payment via direct bank transfer.
     */
    BANK_TRANSFER,

    /**
     * Payment through a proprietary or third-party digital wallet.
     */
    WALLET,

    /**
     * Payment via Apple Pay.
     */
    APPLE_PAY,

    /**
     * Payment via Google Pay.
     */
    GOOGLE_PAY,

    /**
     * Payment via PayPal.
     */
    PAYPAL
}

// -------------------------------------------------------------------------------------------------
// Data Class: Payment
// Description: Represents a secure, validated, and auditable payment transaction for dog walking
// services. Implements Parcelable for Android inter-component transfers and leverages Kotlin
// serialization for unified JSON handling. Provides comprehensive fields, payment status tracking,
// and robust methods for updating status, processing refunds, and referencing walk details.
// -------------------------------------------------------------------------------------------------
@Parcelize
@Serializable
data class Payment(
    /**
     * Unique identifier for this payment, typically a UUID. Must be non-empty to ensure
     * consistent tracking in the database or external payment gateways.
     */
    val id: String,

    /**
     * Unique identifier referencing the walk that this payment is associated with.
     * Must match the corresponding 'id' field in a Walk object for successful validation.
     */
    val walkId: String,

    /**
     * Unique identifier for the payer. This could correspond to the dog owner's user id.
     */
    val payerId: String,

    /**
     * Unique identifier for the payee. This could correspond to the walker or service provider's user id.
     */
    val payeeId: String,

    /**
     * Monetary amount for this payment in the local currency units. Must be positive and within
     * acceptable business rules.
     */
    val amount: Double,

    /**
     * Current status of the payment. Determines if the payment flow is pending, completed, refunded, etc.
     */
    var status: PaymentStatus,

    /**
     * Payment method used for this transaction (e.g., CREDIT_CARD, BANK_TRANSFER, etc.).
     */
    val method: PaymentMethod,

    /**
     * Timestamp in milliseconds since epoch indicating when this payment was initiated or recorded.
     */
    var timestamp: Long,

    /**
     * Transaction identifier returned by an external payment gateway. May be null if not yet assigned.
     */
    var transactionId: String? = null,

    /**
     * Reason for failure if the payment did not go through. Used for advanced error reporting.
     */
    var failureReason: String? = null,

    /**
     * Count of how many times a retry has been attempted. Used to control repeated payment attempts.
     */
    var retryCount: Int = 0,

    /**
     * Indicates whether a payment can be refunded. This is typically assigned upon successful processing.
     */
    var isRefundable: Boolean = false,

    /**
     * URL to a digital or hosted receipt for this payment. May be null if not available.
     */
    var receiptUrl: String? = null

) : Parcelable {

    // ---------------------------------------------------------------------------------------------
    // Computed Properties
    // These read-only properties derive their values from the current 'status' and other fields.
    // ---------------------------------------------------------------------------------------------

    /**
     * True if the payment is in a final success state (COMPLETED, REFUNDED, PARTIALLY_REFUNDED).
     */
    val isSuccessful: Boolean
        get() = when (status) {
            PaymentStatus.COMPLETED,
            PaymentStatus.REFUNDED,
            PaymentStatus.PARTIALLY_REFUNDED -> true
            else -> false
        }

    /**
     * True if the payment is still pending, authorized, or requires additional action.
     */
    val isPending: Boolean
        get() = when (status) {
            PaymentStatus.PENDING,
            PaymentStatus.AUTHORIZED,
            PaymentStatus.REQUIRES_ACTION -> true
            else -> false
        }

    /**
     * True if the payment has failed and can no longer proceed without a retry.
     */
    val isFailed: Boolean
        get() = (status == PaymentStatus.FAILED)

    /**
     * True if the payment has been fully or partially refunded.
     */
    val isRefunded: Boolean
        get() = when (status) {
            PaymentStatus.REFUNDED,
            PaymentStatus.PARTIALLY_REFUNDED -> true
            else -> false
        }

    /**
     * True if the payment can be retried (e.g., if it has failed and retry attempts remain).
     */
    val canRetry: Boolean
        get() = (status == PaymentStatus.FAILED && retryCount > 0)

    /**
     * True if the payment requires user action or additional authentication steps.
     */
    val requiresAction: Boolean
        get() = (status == PaymentStatus.REQUIRES_ACTION)

    /**
     * Returns a formatted string for the monetary amount (e.g., "$12.34").
     */
    val formattedAmount: String
        get() = "$" + String.format("%.2f", amount)

    /**
     * Provides a textual description of the current payment status for display purposes.
     */
    val statusDescription: String
        get() = when (status) {
            PaymentStatus.PENDING -> "Payment is pending."
            PaymentStatus.AUTHORIZED -> "Payment is authorized."
            PaymentStatus.COMPLETED -> "Payment completed successfully."
            PaymentStatus.FAILED -> "Payment failed to process."
            PaymentStatus.REFUNDED -> "Payment has been refunded."
            PaymentStatus.PARTIALLY_REFUNDED -> "Payment has been partially refunded."
            PaymentStatus.CANCELLED -> "Payment was cancelled."
            PaymentStatus.DISPUTED -> "Payment is under dispute."
            PaymentStatus.REQUIRES_ACTION -> "Payment requires additional action."
        }

    // ---------------------------------------------------------------------------------------------
    // Initialization Block
    // Enforces necessary validation for IDs and amount. Initializes any optional parameters
    // and ensures the Payment object is ready for usage in a production-grade environment.
    // ---------------------------------------------------------------------------------------------
    init {
        // 1) Validate payment amount is positive and within an allowed range.
        require(amount > 0.0) {
            "Payment amount must be positive. Provided value: $amount"
        }

        // 2) Validate all required IDs are properly formatted and non-blank.
        require(id.isNotBlank()) {
            "Payment id cannot be blank."
        }
        require(walkId.isNotBlank()) {
            "walkId cannot be blank."
        }
        require(payerId.isNotBlank()) {
            "payerId cannot be blank."
        }
        require(payeeId.isNotBlank()) {
            "payeeId cannot be blank."
        }

        // 3) Primary constructor parameters are assigned directly.

        // 4) Default values for optional parameters are set via property initialization (above).

        // 5) Compute or initialize derived property logic. (All are read-only getters referencing state.)

        // 6) @Parcelize handles the Parcelable implementation automatically.

        // 7) @Serializable handles JSON serialization automatically.
    }

    // ---------------------------------------------------------------------------------------------
    // Function: updateStatus
    // Description: Updates the payment status with comprehensive validation, logging, and optional
    // timestamp refreshing. Returns true if the status change is successful, otherwise false.
    // Steps:
    //   1) Validate status transition is allowed
    //   2) Update payment status
    //   3) Set failure reason if status is FAILED
    //   4) Update timestamp if requested
    //   5) Log status change for audit
    //   6) Update computed properties (handled automatically by read-only getters)
    //   7) Return success status
    // ---------------------------------------------------------------------------------------------
    fun updateStatus(
        newStatus: PaymentStatus,
        failureReason: String? = null,
        updateTimestamp: Boolean = false
    ): Boolean {
        // 1) Validate if we can transition from current status to newStatus
        if (!canTransition(this.status, newStatus)) {
            return false
        }

        // 2) Perform the status update
        val oldStatus = this.status
        this.status = newStatus

        // 3) If new status is FAILED, store the failure reason if provided
        if (newStatus == PaymentStatus.FAILED && failureReason != null) {
            this.failureReason = failureReason
        }

        // 4) Optionally update the payment timestamp for audit or tracking
        if (updateTimestamp) {
            this.timestamp = System.currentTimeMillis()
        }

        // 5) Log the status change (placeholder)
        // In a production environment, integrate with a logging or analytics system here.
        // Example: Logger.info("Payment $id status changed from $oldStatus to $newStatus")

        // 6) Computed properties like isSuccessful, isFailed, etc. will reflect the latest status automatically.

        // 7) Return success status
        return true
    }

    // ---------------------------------------------------------------------------------------------
    // Function: processRefund
    // Description: Processes a refund for the payment, performing appropriate validation and
    // updates. Returns true if the refund is processed successfully. Automatically updates status
    // and logs transactions for auditing.
    // Steps:
    //   1) Validate refund eligibility
    //   2) Validate refund amount
    //   3) Process refund through payment gateway (placeholder)
    //   4) Update payment status
    //   5) Log refund transaction
    //   6) Generate refund receipt (placeholder)
    // ---------------------------------------------------------------------------------------------
    fun processRefund(refundAmount: Double, reason: String): Boolean {
        // 1) Validate refund eligibility
        if (!isRefundable) {
            // Refund not permitted
            return false
        }

        // 2) Validate that the requested refund amount is reasonable (<= total amount).
        if (refundAmount <= 0.0 || refundAmount > amount) {
            return false
        }

        // 3) Placeholder: simulate refund processing with an external gateway
        // TODO: Integrate with payment gateway's refund API

        // 4) Determine new status based on whether the refund is partial or full
        val newStatus = when {
            refundAmount == amount -> PaymentStatus.REFUNDED
            else -> PaymentStatus.PARTIALLY_REFUNDED
        }
        val updatedOk = updateStatus(newStatus, failureReason = null, updateTimestamp = true)
        if (!updatedOk) {
            return false
        }

        // 5) Log the refund transaction (placeholder)
        // Example: Logger.info("Refund of $refundAmount for Payment $id processed successfully.")

        // 6) Generate or update a refund receipt
        // For demonstration, we could append a query parameter (timestamp) or use a different logic
        this.receiptUrl = this.receiptUrl?.let { "$it?refunded=true" } ?: "https://receipts.example.com/refund/$id"

        return true
    }

    // ---------------------------------------------------------------------------------------------
    // Function: validateAgainstWalk
    // Description: Compares the internal payment details against the provided Walk object for
    // consistency. Ensures the payment references the correct walk and does not exceed the walk's
    // price in standard scenarios.
    // ---------------------------------------------------------------------------------------------
    fun validateAgainstWalk(walk: Walk): Boolean {
        // Check that the Payment's walkId matches the Walk's id
        if (this.walkId != walk.id) {
            return false
        }
        // Check that the Payment's amount is not abnormally larger than the walk's price
        // (Simple rule-of-thumb: it must be <= 2 * walk.price, for instance, to allow surcharges.)
        return (this.amount <= (walk.price * 2))
    }

    // ---------------------------------------------------------------------------------------------
    // Private Helper: canTransition
    // Description: Defines permissible transitions between payment statuses, preventing invalid
    // updates in the payment lifecycle. A more exhaustive rule set could be applied in production.
    // ---------------------------------------------------------------------------------------------
    private fun canTransition(from: PaymentStatus, to: PaymentStatus): Boolean {
        // Example transition logic. Adjust as desired for real business rules.
        return when (from) {
            PaymentStatus.PENDING -> {
                // From PENDING: can move to AUTHORIZED, COMPLETED, FAILED, CANCELLED, REFUNDED, PARTIALLY_REFUNDED, DISPUTED, REQUIRES_ACTION
                to in listOf(
                    PaymentStatus.AUTHORIZED,
                    PaymentStatus.COMPLETED,
                    PaymentStatus.FAILED,
                    PaymentStatus.CANCELLED,
                    PaymentStatus.REFUNDED,
                    PaymentStatus.PARTIALLY_REFUNDED,
                    PaymentStatus.DISPUTED,
                    PaymentStatus.REQUIRES_ACTION
                )
            }
            PaymentStatus.AUTHORIZED -> {
                // From AUTHORIZED: can move to COMPLETED, FAILED, CANCELLED, REFUNDED, PARTIALLY_REFUNDED, DISPUTED, REQUIRES_ACTION
                to in listOf(
                    PaymentStatus.COMPLETED,
                    PaymentStatus.FAILED,
                    PaymentStatus.CANCELLED,
                    PaymentStatus.REFUNDED,
                    PaymentStatus.PARTIALLY_REFUNDED,
                    PaymentStatus.DISPUTED,
                    PaymentStatus.REQUIRES_ACTION
                )
            }
            PaymentStatus.COMPLETED -> {
                // From COMPLETED: can move to REFUNDED, PARTIALLY_REFUNDED, DISPUTED
                to in listOf(
                    PaymentStatus.REFUNDED,
                    PaymentStatus.PARTIALLY_REFUNDED,
                    PaymentStatus.DISPUTED
                )
            }
            PaymentStatus.FAILED -> {
                // From FAILED: can move to PENDING (if retrying), CANCELLED, or DISPUTED
                to in listOf(
                    PaymentStatus.PENDING,
                    PaymentStatus.CANCELLED,
                    PaymentStatus.DISPUTED
                )
            }
            PaymentStatus.REFUNDED -> {
                // From REFUNDED: final in many cases, but could dispute after a refund
                to == PaymentStatus.DISPUTED
            }
            PaymentStatus.PARTIALLY_REFUNDED -> {
                // From PARTIALLY_REFUNDED: can move to REFUNDED or DISPUTED
                to in listOf(
                    PaymentStatus.REFUNDED,
                    PaymentStatus.DISPUTED
                )
            }
            PaymentStatus.CANCELLED -> {
                // From CANCELLED: typically final, though some systems might dispute a cancellation
                to == PaymentStatus.DISPUTED
            }
            PaymentStatus.DISPUTED -> {
                // From DISPUTED: can move to REFUNDED, PARTIALLY_REFUNDED, or CANCELLED
                to in listOf(
                    PaymentStatus.REFUNDED,
                    PaymentStatus.PARTIALLY_REFUNDED,
                    PaymentStatus.CANCELLED
                )
            }
            PaymentStatus.REQUIRES_ACTION -> {
                // From REQUIRES_ACTION: can move to AUTHORIZED, FAILED, CANCELLED, or DISPUTED
                to in listOf(
                    PaymentStatus.AUTHORIZED,
                    PaymentStatus.FAILED,
                    PaymentStatus.CANCELLED,
                    PaymentStatus.DISPUTED
                )
            }
        }
    }
}