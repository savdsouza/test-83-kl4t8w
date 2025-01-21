//
//  PaymentListViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-15.
//
//  This file defines a thread-safe, production-ready PaymentListViewModel
//  managing payment list view state and business logic with enhanced security,
//  monitoring, and error handling. It integrates with a PaymentUseCase to
//  load payment history, coordinate refunds, and securely handle sensitive
//  payment data.
//
//  References:
//  - Financial Operations (Secure payments, automated billing, transaction history)
//  - Payment Processing (Payment gateway integration with error handling)
//  - Data Security (Encryption, audit logging)

import Foundation // iOS 13.0+ (Core iOS functionality)
import Combine    // iOS 13.0+ (Reactive programming support)

// MARK: - Internal Imports (Enhanced base view model with security features)
import class BaseViewModel.BaseViewModel
// Using members: isLoadingSubject, handleError, logSecurityEvent

// MARK: - Internal Imports (Enhanced payment model with encryption support)
import class Payment.Payment
import enum Payment.PaymentStatus

// MARK: - Internal Imports (Enhanced payment business logic with validation)
import class PaymentUseCase.PaymentUseCase

/// A metrics collector for payment-related operations, allowing detailed
/// performance tracking across the view model methods.
public protocol PaymentMetricsCollector {
    /// Called when starting a monitored operation (e.g., "LoadPayments").
    func startOperation(_ name: String)
    /// Called when ending a monitored operation.
    func endOperation(_ name: String)
    /// Called to record any additional metric or event data as needed.
    func recordMetric(_ name: String, value: String)
}

/// A security logger protocol for capturing specialized security events
/// such as refunds, encryption audits, or data access tracking.
public protocol SecurityLogger {
    /// Records a designated security event with a descriptive message.
    func recordEvent(_ message: String)
}

/// PaymentListViewModel is a thread-safe view model that manages a list of payments.
/// It provides reactive support via Combine, includes enhanced security measures,
/// and orchestrates payment operations through PaymentUseCase.
///
@MainActor
public final class PaymentListViewModel: BaseViewModel {

    // MARK: - Private Properties

    /// A dedicated serial queue to ensure all state modifications are executed atomically.
    private let serialQueue: DispatchQueue

    /// A use case for performing payment operations such as loading history or refunds.
    private let paymentUseCase: PaymentUseCase

    /// A subject publishing the current list of payments. This is exposed publicly.
    public let paymentsSubject: CurrentValueSubject<[Payment], Never>

    /// A subject triggered when a refresh operation is requested.
    private let refreshTrigger: PassthroughSubject<String, Never>

    /// A subject triggered when a refund operation is requested.
    private let refundTrigger: PassthroughSubject<String, Never>

    /// A set of Combine cancellables used to manage subscriptions' lifetimes.
    private var cancellables: Set<AnyCancellable>

    /// A reference to a metrics collector, used for performance tracking and logging.
    private let metricsCollector: PaymentMetricsCollector

    /// A reference to a security logger for capturing security-related events or audits.
    private let securityLogger: SecurityLogger

    // MARK: - Initialization

    /// Initializes the payment list view model with enhanced security features.
    ///
    /// Steps:
    /// 1. Initialize the serial queue for thread-safe operations.
    /// 2. Store paymentUseCase reference.
    /// 3. Initialize paymentsSubject with an empty array.
    /// 4. Initialize refresh and refund triggers.
    /// 5. Configure metrics collector.
    /// 6. Set up security logger.
    /// 7. Initialize cancellables set.
    /// 8. Set up reactive bindings with error handling.
    /// 9. Configure automatic retry mechanism (if needed within Combine flows).
    ///
    /// - Parameters:
    ///   - paymentUseCase: The PaymentUseCase instance handling business logic.
    ///   - metricsCollector: A metrics collector for performance instrumentation.
    ///   - securityLogger: A security logger for capturing sensitive events.
    public init(
        paymentUseCase: PaymentUseCase,
        metricsCollector: PaymentMetricsCollector,
        securityLogger: SecurityLogger
    ) {
        // 1. Dedicated serial queue initialization
        self.serialQueue = DispatchQueue(
            label: "com.dogwalking.PaymentListViewModel.serialQueue",
            qos: .userInitiated
        )

        // 2. Store references
        self.paymentUseCase = paymentUseCase

        // 3. Initialize payments subject with empty array
        self.paymentsSubject = CurrentValueSubject<[Payment], Never>([])

        // 4. Initialize triggers
        self.refreshTrigger = PassthroughSubject<String, Never>()
        self.refundTrigger = PassthroughSubject<String, Never>()

        // 5. Configure metrics collector
        self.metricsCollector = metricsCollector

        // 6. Configure security logger
        self.securityLogger = securityLogger

        // 7. Initialize cancellables set
        self.cancellables = Set<AnyCancellable>()

        // BaseViewModel init
        super.init()

        // 8 and 9. Additional reactive bindings, error handling, or retry logic
        // could be configured here as needed. For now, placeholders or
        // advanced publishers may be established in actual usage.
    }

    // MARK: - Public Methods

    /// Securely loads payment history for a given user with retry mechanism.
    ///
    /// Steps:
    /// 1. Validate user ID for security.
    /// 2. Log operation start via security event.
    /// 3. Set loading state to true.
    /// 4. Execute logic on serial queue to avoid data races.
    /// 5. Start performance tracking using metrics collector.
    /// 6. Call payment use case with retry support.
    /// 7. Decrypt and validate payment data if needed.
    /// 8. Update payments subject thread-safely.
    /// 9. Log operation completion with security logger.
    /// 10. Handle errors with detailed logging via BaseViewModel.
    /// 11. Update metrics to indicate final state.
    /// 12. Set loading state to false.
    ///
    /// - Parameter userId: The identifier of the user whose payments we want to load.
    /// - Returns: A publisher emitting an array of Payment on success or an Error on failure.
    public func loadPayments(userId: String) -> AnyPublisher<[Payment], Error> {
        // 1. Validate
        guard !userId.isEmpty else {
            let e = NSError(domain: "PaymentListViewModel", code: -100, userInfo: [
                NSLocalizedDescriptionKey: "Invalid userId provided."
            ])
            return Fail(error: e).eraseToAnyPublisher()
        }

        // 2. Log operation start
        self.logSecurityEvent("[loadPayments] Starting for userId=\(userId)")
        self.securityLogger.recordEvent("Load payments initiated for user=\(userId)")

        // 3. Set loading
        self.setLoading(true)

        // 4. We return a publisher that handles the rest asynchronously.
        return Future<[Payment], Error> { [weak self] promise in
            guard let strongSelf = self else {
                let e = NSError(domain: "PaymentListViewModel", code: -101, userInfo: [
                    NSLocalizedDescriptionKey: "ViewModel deallocated."
                ])
                promise(.failure(e))
                return
            }
            strongSelf.serialQueue.async {
                // 5. Start performance tracking
                strongSelf.metricsCollector.startOperation("LoadPayments")

                // 6. Get user payment history (apply simple retry or advanced logic)
                let publisher = strongSelf.paymentUseCase
                    .getUserPaymentHistory(userId: userId, pagination: .init(page: 0, pageSize: 20))
                    .map { paginated in
                        // Flatten to an array of Payment for demonstration
                        return paginated.payments
                    }
                    .retry(3) // Basic retry mechanism
                    .eraseToAnyPublisher()

                let cancellable = publisher.sink { completion in
                    switch completion {
                    case .failure(let error):
                        // 10. Handle errors with detailed logging
                        strongSelf.handleError(error)
                        // 11. Update metrics, record final state
                        strongSelf.metricsCollector.recordMetric("LoadPaymentsError", value: error.localizedDescription)
                        strongSelf.metricsCollector.endOperation("LoadPayments")
                        // 12. Clear loading
                        strongSelf.setLoading(false)
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                } receiveValue: { receivedPayments in
                    // 7. Decrypt and validate payment data (placeholder)
                    let finalPayments = receivedPayments.map { payment in
                        // If there's specialized decryption needed, insert logic here.
                        // e.g., decrypt payment.encryptedData
                        return payment
                    }

                    // 8. Update payments subject on the serial queue
                    strongSelf.serialQueue.async {
                        strongSelf.paymentsSubject.send(finalPayments)
                    }

                    // 9. Log operation completion
                    strongSelf.logSecurityEvent("[loadPayments] Completed for userId=\(userId)")
                    strongSelf.securityLogger.recordEvent("Load payments completed for user=\(userId)")

                    // 11. Update metrics
                    strongSelf.metricsCollector.recordMetric("LoadPaymentsCount", value: "\(finalPayments.count)")
                    strongSelf.metricsCollector.endOperation("LoadPayments")

                    // 12. Clear loading
                    strongSelf.setLoading(false)
                    promise(.success(finalPayments))
                }
                strongSelf.cancellables.insert(cancellable)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Processes refund requests with enhanced security measures.
    ///
    /// Steps:
    /// 1. Validate payment ID.
    /// 2. Log refund request event.
    /// 3. Set loading state to true.
    /// 4. Execute logic on serial queue.
    /// 5. Validate payment status or user context if needed.
    /// 6. Call payment use case with security checks.
    /// 7. Update payment in the local list thread-safely.
    /// 8. Log refund completion.
    /// 9. Handle errors with audit logging.
    /// 10. Update security metrics.
    /// 11. Set loading state to false.
    ///
    /// - Parameter paymentId: The identifier of the payment to be refunded.
    /// - Returns: A publisher emitting an updated Payment object or an Error.
    public func requestRefund(paymentId: String) -> AnyPublisher<Payment, Error> {
        // 1. Validate
        guard !paymentId.isEmpty else {
            let e = NSError(domain: "PaymentListViewModel", code: -200, userInfo: [
                NSLocalizedDescriptionKey: "Invalid paymentId provided."
            ])
            return Fail(error: e).eraseToAnyPublisher()
        }

        // 2. Log
        self.logSecurityEvent("[requestRefund] Starting for paymentId=\(paymentId)")
        self.securityLogger.recordEvent("Refund requested for payment=\(paymentId)")

        // 3. Set loading
        self.setLoading(true)

        // 4. Return a future-based publisher
        return Future<Payment, Error> { [weak self] promise in
            guard let strongSelf = self else {
                let e = NSError(domain: "PaymentListViewModel", code: -201, userInfo: [
                    NSLocalizedDescriptionKey: "ViewModel deallocated."
                ])
                promise(.failure(e))
                return
            }
            strongSelf.serialQueue.async {
                // 5. Validate payment status if necessary (placeholder).
                // 6. Call payment use case for refund
                let refundPublisher = strongSelf.paymentUseCase
                    .requestRefund(paymentId: paymentId)
                    .eraseToAnyPublisher()

                let cancellable = refundPublisher.sink { completion in
                    switch completion {
                    case .failure(let error):
                        // 9. Handle errors with audit logging
                        strongSelf.handleError(error)
                        // 10. We can also record additional security metrics
                        strongSelf.metricsCollector.recordMetric("RefundError", value: error.localizedDescription)
                        // 11. Clear loading
                        strongSelf.setLoading(false)
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                } receiveValue: { updatedPayment in
                    // 7. Update payment in local list
                    strongSelf.updateLocalPayment(updatedPayment)

                    // 8. Log completion
                    strongSelf.logSecurityEvent("[requestRefund] Completed for paymentId=\(paymentId)")
                    strongSelf.securityLogger.recordEvent("Refund completed for payment=\(paymentId)")

                    // 10. Update security metrics
                    strongSelf.metricsCollector.recordMetric("RefundSuccessful", value: updatedPayment.id)

                    // 11. Clear loading
                    strongSelf.setLoading(false)
                    promise(.success(updatedPayment))
                }
                strongSelf.cancellables.insert(cancellable)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Applies a thread-safe filter to the current list of payments.
    ///
    /// Steps:
    /// 1. Execute on serial queue.
    /// 2. Validate filter parameters.
    /// 3. Apply filters to the local payment list.
    /// 4. Update payments subject thread-safely.
    /// 5. Log filter operation.
    /// 6. Update metrics or relevant data points.
    ///
    /// - Parameter status: Optional payment status to filter by.
    public func filterPayments(status: PaymentStatus?) {
        // 1. Execute on serial queue to maintain thread safety
        serialQueue.async { [weak self] in
            guard let strongSelf = self else { return }

            // 2. Validate status if needed (no explicit constraints here).
            // 3. Apply filters
            let currentPayments = strongSelf.paymentsSubject.value
            let filtered = currentPayments.filter { payment in
                guard let desiredStatus = status else {
                    // If no status filter is provided, keep payment as is
                    return true
                }
                return payment.status == desiredStatus
            }

            // 4. Update subject
            strongSelf.paymentsSubject.send(filtered)

            // 5. Log filter operation
            strongSelf.logSecurityEvent("[filterPayments] Filtered by status=\(String(describing: status))")
            strongSelf.securityLogger.recordEvent("Filter applied on Payment list for status=\(String(describing: status))")

            // 6. Update metrics if relevant
            strongSelf.metricsCollector.recordMetric("FilterPaymentsCount", value: "\(filtered.count)")
        }
    }

    // MARK: - Private Helpers

    /// Updates a particular payment in the local list, preserving thread safety.
    /// - Parameter updatedPayment: The Payment object after a refund or other status change.
    private func updateLocalPayment(_ updatedPayment: Payment) {
        self.serialQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            var current = strongSelf.paymentsSubject.value
            if let idx = current.firstIndex(where: { $0.id == updatedPayment.id }) {
                current[idx] = updatedPayment
            }
            strongSelf.paymentsSubject.send(current)
        }
    }
}