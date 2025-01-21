//
//  AddPaymentViewModel.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-01.
//
//  This file defines a thread-safe, @MainActor ViewModel class responsible for
//  handling secure payment processing, comprehensive validation, and real-time
//  monitoring of payment operations in alignment with PCI DSS compliance.
//
//  The AddPaymentViewModel class incorporates advanced concurrency control
//  (via NSLock), extensive error handling with Combine publishers, and close
//  integration with PaymentUseCase to drive payment workflows such as walk
//  payments and tipping.
//

import Foundation // Foundation (iOS 13.0+)
import Combine    // Combine (iOS 13.0+)

// MARK: - Internal Imports

// BaseViewModel class for core VM functionality, including loading/error subjects.
// from: src/ios/DogWalking/Core/Base/BaseViewModel.swift
import class BaseViewModel.BaseViewModel
import class BaseViewModel.RetryPolicy

// Payment model & related enums (PaymentStatus, PaymentType, PaymentValidationError).
// from: src/ios/DogWalking/Domain/Models/Payment.swift
import class Payment.Payment
import enum Payment.PaymentStatus
import enum Payment.PaymentType
import enum Payment.PaymentError // Possibly imported if needed
import enum Payment.PaymentOperationError // Possibly imported if needed
import enum Payment.PaymentValidationError // Enums referencing validation issues

// PaymentUseCase providing secure payment operations with PCI DSS compliance.
// from: src/ios/DogWalking/Domain/UseCases/PaymentUseCase.swift
import class PaymentUseCase.PaymentUseCase

/**
 @MainActor
 A thread-safe ViewModel designed for secure payment handling, covering:

 1. Validation of payment details using PCI DSS standards and internal security checks.
 2. Processing of walk payments, including concurrency control and robust error handling.
 3. Handling of tip payments with separate validation logic.
 4. Publishing real-time payment status changes to the UI layer.
 5. Emitting detailed validation errors for user correction or logging.
 6. Maintaining compliance with enterprise-level security and auditing requirements.

 This class leverages Combine to broadcast updates through various publishers,
 ensuring that complex payment operations and their results are communicated
 back to the application's UI seamlessly, with minimal thread-safety risks. 
 Thread safety is enforced via an NSLock (paymentLock), and concurrency for 
 Combine subscriptions is managed in alignment with BaseViewModel features.
 */
@MainActor
public final class AddPaymentViewModel: BaseViewModel {
    
    // MARK: - Properties
    
    /// A reference to the PaymentUseCase that implements secure operations
    /// for processing payments, tips, and validation checks. This use case
    /// enforces PCI DSS compliance and robust error handling.
    private let paymentUseCase: PaymentUseCase
    
    /// A subject that emits Payment objects whenever a successful transaction
    /// or tip completes. Downstream subscribers can use this to update the UI,
    /// logs, or post-transaction analytics.
    private let paymentSubject: PassthroughSubject<Payment, Never>
    
    /// A collection of Combine cancellables used to manage the lifecycle of
    /// asynchronous streams, preventing memory leaks and ensuring that
    /// subscriptions are canceled appropriately when no longer needed.
    private var cancellables: Set<AnyCancellable>
    
    /// A subject that holds the current PaymentStatus (e.g., pending, processing,
    /// completed, failed, etc.) and broadcasts changes to any interested UI
    /// components or observers in real time.
    private let paymentStatusSubject: CurrentValueSubject<PaymentStatus, Never>
    
    /// A subject that publishes detailed validation errors of type
    /// PaymentValidationError. This enables the UI to display specific messages
    /// to users when their payment details fail certain security or data checks.
    private let validationErrorSubject: PassthroughSubject<PaymentValidationError, Never>
    
    /// A lock providing thread-safe access to payment operations, ensuring
    /// that concurrent attempts to process or validate payments do not result
    /// in race conditions or inconsistent state.
    private let paymentLock: NSLock
    
    // MARK: - Initialization
    
    /**
     Initializes the AddPaymentViewModel with a PaymentUseCase for secure payment
     processing, setting up all required subjects and concurrency mechanisms.

     Steps Performed:
     1. Initialize the inherited BaseViewModel to set up error/loading subjects.
     2. Store the reference to the provided PaymentUseCase (enforcing PCI DSS).
     3. Instantiate the paymentSubject for broadcasting Payment updates.
     4. Initialize paymentLock for thread-safe payment operations.
     5. Create a CurrentValueSubject for PaymentStatus with an initial value of `.pending`.
     6. Configure a PassthroughSubject for PaymentValidationError to report validations.
     7. Prepare the cancellables set for managing Combine subscription lifecycles.

     - Parameter paymentUseCase: The PaymentUseCase instance that will handle
       payment logic (walk payments, tips, refunds, etc.).
     */
    public init(paymentUseCase: PaymentUseCase) {
        // Call BaseViewModel initializer for loading/error subjects
        super.init()
        
        self.paymentUseCase = paymentUseCase
        self.paymentSubject = PassthroughSubject<Payment, Never>()
        self.paymentLock = NSLock()
        self.paymentStatusSubject = CurrentValueSubject<PaymentStatus, Never>(.pending)
        self.validationErrorSubject = PassthroughSubject<PaymentValidationError, Never>()
        self.cancellables = Set<AnyCancellable>()
    }
    
    // MARK: - Public Publishers
    
    /**
     A publisher that broadcasts the current payment status (PaymentStatus) to external
     subscribers. This allows UI elements or other components to react to real-time changes
     in payment processing state, including transitions from pending to processing, completed,
     or failed.
     
     - Returns: A type-erased publisher that emits PaymentStatus values with no error.
     */
    public var paymentStatusPublisher: AnyPublisher<PaymentStatus, Never> {
        paymentStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Public Methods
    
    /**
     Securely processes a new walk payment, applying validation checks, concurrency
     control, and robust error handling. This method:

     1. Acquires the thread-safe paymentLock to block concurrent modifications.
     2. Validates the payment details (amount limits, suspicious patterns, etc.).
     3. Logs and audits attempt (implementation placeholders as needed).
     4. Sets the loading state for UI feedback via isLoadingSubject.
     5. Calls PaymentUseCase.processWalkPayment, returning a publisher.
     6. Subscribes to the publisher, monitoring success or failure.
     7. On success: updates paymentStatusSubject, emits Payment via paymentSubject.
     8. On failure: forwards the error to errorSubject.
     9. Releases the paymentLock automatically via `defer`.
     10. Logs transaction completion for auditing or analytics.

     - Parameter payment: The Payment object representing a walk payment.
     - Returns: An AnyPublisher that emits the fully processed Payment or an Error.
     */
    public func processPayment(payment: Payment) -> AnyPublisher<Payment, Error> {
        return Future<Payment, Error> { [weak self] promise in
            guard let strongSelf = self else {
                promise(.failure(NSError(domain: "AddPaymentViewModel", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "AddPaymentViewModel deallocated"
                ])))
                return
            }
            
            // 1. Acquire the thread-safe paymentLock.
            strongSelf.paymentLock.lock()
            defer {
                strongSelf.paymentLock.unlock()
            }
            
            // 2. Validate payment details via local function call.
            let validationResult = strongSelf.validatePaymentDetails(payment)
            switch validationResult {
            case .failure(let valError):
                // Publish the validation error to inform UI or logs.
                strongSelf.validationErrorSubject.send(valError)
                promise(.failure(valError))
                return
            case .success:
                // 3. Log payment attempt (placeholder).
                // e.g., logger.log("Attempting walk payment for paymentId=\(payment.id)")
                
                // 4. Set loading state to true to show UI activity indicator.
                strongSelf.setLoading(true)
                
                // 5. Call PaymentUseCase.processWalkPayment to do the heavy lifting.
                let publisher = strongSelf.paymentUseCase.processWalkPayment(payment: payment)
                
                // 6. Subscribe to the publisher for success/failure.
                let subscription = publisher
                    .handleEvents(receiveCompletion: { completion in
                        // Stop loading state regardless of success/failure.
                        strongSelf.setLoading(false)
                    })
                    .sink { completion in
                        switch completion {
                        case .failure(let error):
                            // 8. Publish errors for UI-level or logging consumption.
                            strongSelf.errorSubject.send(error)
                            promise(.failure(error))
                        case .finished:
                            // 10. Log transaction completion if needed.
                            // e.g., logger.log("Walk payment completed for paymentId=\(payment.id)")
                            break
                        }
                    } receiveValue: { processedPayment in
                        // 7. Update PaymentStatus and broadcast the Payment object.
                        strongSelf.paymentStatusSubject.send(processedPayment.status)
                        strongSelf.paymentSubject.send(processedPayment)
                        
                        // Fulfill the promise with the final processed Payment.
                        promise(.success(processedPayment))
                    }
                
                // Store cancellable to keep subscription alive.
                strongSelf.cancellables.insert(subscription)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Processes a tip payment by performing specialized validation,
     concurrency control, and robust error handling. This method:

     1. Locks the paymentLock to prevent concurrent modifications.
     2. Validates the tip-specific data (tip amount boundaries, suspicious patterns).
     3. Logs and audits the tip attempt as a placeholder for compliance.
     4. Sets the loading state for UI feedback via isLoadingSubject.
     5. Invokes PaymentUseCase.processTipPayment with the Payment object.
     6. Subscribes to the resulting publisher to capture success/failure.
     7. On success: updates paymentStatusSubject and emits Payment via paymentSubject.
     8. On failure: routes the error to errorSubject.
     9. Unlocks paymentLock automatically.
     10. Logs final transaction or analytics hooks upon completion.

     - Parameter payment: A Payment instance representing the tip transaction.
     - Returns: An AnyPublisher emitting the updated Payment or an Error.
     */
    public func processTip(payment: Payment) -> AnyPublisher<Payment, Error> {
        return Future<Payment, Error> { [weak self] promise in
            guard let strongSelf = self else {
                promise(.failure(NSError(domain: "AddPaymentViewModel", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "AddPaymentViewModel deallocated"
                ])))
                return
            }
            
            // 1. Acquire thread-safe lock before tip processing.
            strongSelf.paymentLock.lock()
            defer {
                strongSelf.paymentLock.unlock()
            }
            
            // 2. Validate tip payment details with the local validatePaymentDetails function.
            let validationResult = strongSelf.validatePaymentDetails(payment)
            switch validationResult {
            case .failure(let valError):
                strongSelf.validationErrorSubject.send(valError)
                promise(.failure(valError))
                return
            case .success:
                // 3. Log attempt if needed (placeholder).
                // e.g., logger.log("Attempting tip payment for paymentId=\(payment.id)")
                
                // 4. Indicate loading for UI.
                strongSelf.setLoading(true)
                
                // 5. Use PaymentUseCase to process the tip, returning a publisher.
                let tipPublisher = strongSelf.paymentUseCase.processTipPayment(payment: payment)
                
                // 6. Subscribe and handle events.
                let subscription = tipPublisher
                    .handleEvents(receiveCompletion: { completion in
                        strongSelf.setLoading(false)
                    })
                    .sink { completion in
                        switch completion {
                        case .failure(let error):
                            strongSelf.errorSubject.send(error)
                            promise(.failure(error))
                        case .finished:
                            // 10. Final logs or analytics.
                            // e.g., logger.log("Tip payment concluded for paymentId=\(payment.id)")
                            break
                        }
                    } receiveValue: { tipPayment in
                        // 7. Update PaymentStatus and publish Payment object.
                        strongSelf.paymentStatusSubject.send(tipPayment.status)
                        strongSelf.paymentSubject.send(tipPayment)
                        
                        // Deliver final Payment to the caller.
                        promise(.success(tipPayment))
                    }
                
                // Maintain reference to subscription.
                strongSelf.cancellables.insert(subscription)
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     Performs comprehensive payment validation with security checks. This includes:

     - Ensuring the payment amount is within permissible or domain-specific boundaries.
     - Checking for suspicious patterns that might indicate fraud or invalid usage.
     - Verifying the payment method is properly secured and recognized.
     - Validating necessary identifiers (e.g., walkId, userId, currency).
     - Confirming the payment type is supported (walkPayment, tip, etc.).
     - Confirming the currency is valid for the region or service.
     - Logging validation outcomes for auditing or debugging.
     - Returning a Result that indicates success or specific validation errors.

     Internally, this method delegates to PaymentUseCase.validatePayment,
     which enforces enterprise-grade logic for PCI DSS compliance and
     domain-level rules.

     - Parameter payment: The Payment object to validate thoroughly.
     - Returns: A Result indicating either success (true) or a PaymentValidationError.
     */
    public func validatePaymentDetails(_ payment: Payment) -> Result<Bool, PaymentValidationError> {
        // Delegate to PaymentUseCase for deeper domain/compliance checks.
        let validationResult = paymentUseCase.validatePayment(payment: payment)
        
        // Additional hooking points for local or view-model-specific logic
        // can be inserted here if needed.
        
        // For demonstration, we simply return the use case's outcome.
        // Optionally, log or transform the result:
        switch validationResult {
        case .success:
            // e.g., logger.log("Payment validation succeeded for id=\(payment.id)")
            return .success(true)
        case .failure(let error):
            // e.g., logger.error("Payment validation failed for id=\(payment.id), error=\(error)")
            return .failure(error)
        }
    }
}
```