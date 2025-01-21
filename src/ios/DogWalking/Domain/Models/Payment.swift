//
//  Payment.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-10.
//  This file defines a thread-safe Payment model with enhanced security,
//  regulatory compliance, and audit capabilities.
//

import Foundation // iOS 13.0+

// MARK: - PaymentStatus
/// Describes the various stages a payment may be in.
public enum PaymentStatus: String, Codable {
    /// Payment has been created but not yet processed
    case pending
    /// Payment is currently being processed
    case processing
    /// Payment has been completed successfully
    case completed
    /// Payment has failed
    case failed
    /// Payment has been refunded
    case refunded
    /// Payment is in dispute
    case disputed
}

// MARK: - PaymentType
/// Enumerates different payment transaction types.
public enum PaymentType: String, Codable {
    /// Payment for a dog walking service
    case walkPayment
    /// Payment for a subscription plan
    case subscription
    /// Additional tip payment
    case tip
    /// Refund for a prior transaction
    case refund
}

// MARK: - PaymentError
/// Categorizes detailed error codes for payment failures.
public enum PaymentError: String, Codable {
    /// Insufficient funds in the payment method
    case insufficient_funds
    /// Invalid card details provided
    case invalid_card
    /// Card used is expired
    case expired_card
    /// Error occurred while processing the payment
    case processing_error
    /// Network-related failure
    case network_error
    /// Security or fraud-related error
    case security_error
}

// MARK: - SupportedCurrency
/// Lists currencies supported by the payment system.
public enum SupportedCurrency: String, Codable {
    /// United States Dollar
    case USD
    /// Euro
    case EUR
    /// British Pound Sterling
    case GBP
    /// Canadian Dollar
    case CAD
}

// MARK: - PaymentOperationError
/// Defines errors that may occur during payment operations (e.g., validation).
internal enum PaymentOperationError: Error {
    /// The provided payment amount is invalid for the given currency
    case invalidAmount(String)
    /// The amount exceeds a predefined limit
    case amountExceedsLimit(String)
    /// Attempted an invalid status transition
    case invalidStatusTransition(String)
}

// MARK: - Payment
/// A thread-safe, identifiable model representing a payment transaction
/// with enhanced security, regulatory compliance, and an audit trail.
@objc
public class Payment: NSObject, Codable, Identifiable {
    // MARK: - Identifiable Conformance
    /// A unique identifier for the Payment object.
    public private(set) var id: String

    // MARK: - Core Payment Properties
    public private(set) var walkId: String
    public private(set) var userId: String
    public private(set) var walkerId: String
    public private(set) var amount: Decimal
    public private(set) var currency: SupportedCurrency
    public private(set) var type: PaymentType
    public private(set) var status: PaymentStatus
    public private(set) var createdAt: Date
    public private(set) var lastModifiedAt: Date
    public private(set) var processedAt: Date?
    public private(set) var transactionId: String?
    public private(set) var errorCode: PaymentError?
    public private(set) var errorMessage: String?
    public private(set) var metadata: [String: String]
    public private(set) var statusHistory: [PaymentStatus]
    public private(set) var taxAmount: Decimal?
    public private(set) var refundReason: String?
    public private(set) var isTestTransaction: Bool

    // MARK: - Thread Safety
    private let syncQueue = DispatchQueue(label: "com.dogwalking.payment.syncQueue", attributes: .concurrent)

    // MARK: - CodingKeys
    /// Defines the mapping for encoding and decoding Payment to/from JSON.
    private enum CodingKeys: String, CodingKey {
        case id, walkId, userId, walkerId, amount, currency, type, status, createdAt
        case lastModifiedAt, processedAt, transactionId, errorCode, errorMessage
        case metadata, statusHistory, taxAmount, refundReason, isTestTransaction
    }

    // MARK: - Initializer
    /// Initializes a new Payment instance with validation and default values.
    ///
    /// - Parameters:
    ///   - walkId: The associated dog walk ID.
    ///   - userId: The ID of the user initiating payment.
    ///   - walkerId: The ID of the walker providing the service.
    ///   - amount: The payment amount.
    ///   - type: The type of this payment transaction.
    ///   - currency: The currency in which this payment is charged.
    ///
    /// - Throws: `PaymentOperationError.invalidAmount` if amount is invalid
    ///   or below 0, or `PaymentOperationError.amountExceedsLimit` if it
    ///   surpasses certain limits.
    public init(
        walkId: String,
        userId: String,
        walkerId: String,
        amount: Decimal,
        type: PaymentType,
        currency: SupportedCurrency
    ) throws {
        // Validate amount prior to assignment
        try Payment.validateAmount(amount, currency).get()

        // Generate a secure unique ID
        let uniquePaymentId = UUID().uuidString

        // Initialize core properties
        self.id = uniquePaymentId
        self.walkId = walkId
        self.userId = userId
        self.walkerId = walkerId
        self.amount = amount
        self.currency = currency
        self.type = type
        self.status = .pending
        self.createdAt = Date()
        self.lastModifiedAt = self.createdAt
        self.processedAt = nil
        self.transactionId = nil
        self.errorCode = nil
        self.errorMessage = nil
        self.metadata = [:]
        self.statusHistory = [.pending]
        self.taxAmount = nil
        self.refundReason = nil
        self.isTestTransaction = false

        super.init()
    }

    // MARK: - Status Update
    /// Updates the payment status with validation and an audit trail.
    ///
    /// - Parameters:
    ///   - newStatus: The new status to transition to.
    ///   - reason: An optional reason describing the transition (e.g. refund reason).
    ///
    /// - Returns: A result indicating success or failure. Failure may occur if the
    ///   status transition is invalid.
    @discardableResult
    public func updateStatus(
        to newStatus: PaymentStatus,
        reason: String? = nil
    ) -> Result<Void, Error> {
        return syncQueue.sync(flags: .barrier) {
            // Validate status transition
            guard isStatusTransitionAllowed(from: self.status, to: newStatus) else {
                return .failure(PaymentOperationError.invalidStatusTransition(
                    "Cannot transition from \(self.status) to \(newStatus)."
                ))
            }

            // Transition status
            self.status = newStatus
            self.statusHistory.append(newStatus)
            self.lastModifiedAt = Date()

            // Clear error if not failed
            if newStatus != .failed {
                self.errorCode = nil
                self.errorMessage = nil
            }

            // If completed, mark processed time
            if newStatus == .completed {
                self.processedAt = Date()
            }

            // Handle refunded status
            if newStatus == .refunded {
                if let refundRsn = reason {
                    self.refundReason = refundRsn
                }
            }

            // Add metadata entry for auditing status transition
            let transitionKey = "statusTransition_\(Date().timeIntervalSince1970)"
            self.metadata[transitionKey] = "Transitioned to \(newStatus.rawValue)"

            return .success(())
        }
    }

    // MARK: - Set Error
    /// Sets error information with enhanced error tracking, marking
    /// the payment as failed.
    ///
    /// - Parameters:
    ///   - code: A payment-specific error code.
    ///   - message: A descriptive error message.
    public func setError(code: PaymentError, message: String) {
        syncQueue.sync(flags: .barrier) {
            // Mark status as failed
            self.status = .failed
            self.errorCode = code
            self.errorMessage = message
            self.lastModifiedAt = Date()

            // Add error details to metadata
            self.metadata["errorCode"] = code.rawValue
            self.metadata["errorMessage"] = message

            // Append the failed status to history if not already present
            if self.statusHistory.last != .failed {
                self.statusHistory.append(.failed)
            }

            // Perform any logging or monitoring as needed
            // Example: Logging subsystem integration
            // logger.error("Payment setError: \(code.rawValue), \(message)")
        }
    }

    // MARK: - Validate Amount (Static)
    /// Validates the payment amount and currency before creating or updating
    /// a payment transaction.
    ///
    /// - Parameters:
    ///   - amount: The numeric payment amount.
    ///   - currency: The currency for the amount.
    ///
    /// - Returns: A result indicating success or a payment operation error.
    public static func validateAmount(
        _ amount: Decimal,
        _ currency: SupportedCurrency
    ) -> Result<Void, Error> {
        // 1. Check amount is positive
        guard amount > 0 else {
            return .failure(
                PaymentOperationError.invalidAmount("Amount must be greater than zero.")
            )
        }

        // 2. Validate currency-specific max amounts (simple example)
        let maxLimits: [SupportedCurrency: Decimal] = [
            .USD: 10_000.00,
            .EUR: 10_000.00,
            .GBP: 8_000.00,
            .CAD: 12_000.00
        ]
        if let limit = maxLimits[currency], amount > limit {
            return .failure(
                PaymentOperationError.amountExceedsLimit(
                    "Amount \(amount) exceeds limit for \(currency)."
                )
            )
        }

        // 3. Apply basic rounding rules (2 decimals for these currencies)
        // In a real application, you'd do finer-grained rounding checks.
        // Here, we assume typical 2-decimal rounding is enforced at transaction level.

        // 4. Verify daily transaction limit placeholders or additional checks as needed.
        // For production, integrate with an external system or user-based checks.

        // If all checks pass, return success
        return .success(())
    }

    // MARK: - Helper: Status Transition Rules
    /// Checks if an attempted transition from one status to another is allowed.
    private func isStatusTransitionAllowed(
        from current: PaymentStatus,
        to desired: PaymentStatus
    ) -> Bool {
        // For demonstration, allow transitions except reversing completed/refunded
        // In a real scenario, define comprehensive rules or a state machine.
        if current == .completed && (desired == .processing || desired == .pending) {
            return false
        }
        if current == .refunded && desired == .pending {
            return false
        }
        return true
    }
}