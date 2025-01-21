//
// External Imports
//
// @stripe/stripe-js version ^2.1.0
import type { Stripe } from '@stripe/stripe-js';

//
// Internal Imports
//
import type { ApiResponse, ApiError as ErrorResponse } from './api.types';

//
// -------------------------------------------------------------------------------------
// ENUMS & TYPES
// -------------------------------------------------------------------------------------

/**
 * Enumerates all possible statuses that a payment can have throughout
 * its lifecycle. This enum covers the entire spectrum of scenarios,
 * from initial pending state to final settled, refunded, or disputed outcomes.
 */
export enum PaymentStatus {
  /**
   * Indicates that the payment has been initiated but not yet processed by the system.
   * This status typically applies to newly created payment intents.
   */
  PENDING = 'PENDING',

  /**
   * Signifies that the payment is being processed, e.g. the gateway or provider
   * is currently verifying and debiting payment instruments.
   */
  PROCESSING = 'PROCESSING',

  /**
   * Means the payment has been successfully completed, and funds have been
   * transferred without errors.
   */
  COMPLETED = 'COMPLETED',

  /**
   * Indicates that the payment could not be completed, possibly due to insufficient
   * funds, provider errors, or other processing issues.
   */
  FAILED = 'FAILED',

  /**
   * Shows that a full refund has been processed against a previously completed payment.
   */
  REFUNDED = 'REFUNDED',

  /**
   * Used when only a portion of the original payment amount has been returned
   * to the customer.
   */
  PARTIALLY_REFUNDED = 'PARTIALLY_REFUNDED',

  /**
   * Denotes that the payment is currently under dispute by the cardholder or bank,
   * which may lead to chargebacks.
   */
  DISPUTED = 'DISPUTED',
}

/**
 * Enumerates the supported payment methods or instruments that a user
 * might opt to use during checkout or payment processes, including
 * conventional options (credit/debit) and digital wallets.
 */
export enum PaymentMethod {
  /**
   * Payment made using a standard credit card (e.g., Visa, Mastercard, American Express).
   */
  CREDIT_CARD = 'CREDIT_CARD',

  /**
   * Payment made using a standard debit card linked directly to a bank account.
   */
  DEBIT_CARD = 'DEBIT_CARD',

  /**
   * Payment facilitated through Apple Pay on iOS and macOS platforms,
   * enhancing user convenience and security.
   */
  APPLE_PAY = 'APPLE_PAY',

  /**
   * Payment facilitated through Google Pay on Android and Web platforms,
   * offering a streamlined user experience.
   */
  GOOGLE_PAY = 'GOOGLE_PAY',
}

/**
 * Defines a finite set of currency codes supported by the dog walking
 * application's payment system. Currently, only USD and CAD are enabled,
 * but this type can be extended as the platform evolves globally.
 */
export type CurrencyCode = 'USD' | 'CAD';

//
// -------------------------------------------------------------------------------------
// INTERFACES
// -------------------------------------------------------------------------------------

/**
 * Represents metadata for a payment method that is non-sensitive and can be
 * safely stored for display or logging. Examples include the final digits
 * of a credit card, expiration dates, and brand identification.
 */
export interface PaymentMetadata {
  /**
   * The last 4 digits of the payment instrument (e.g., credit card).
   */
  last4: string;

  /**
   * The brand or network of the card (e.g., VISA, MASTERCARD, etc.).
   */
  brand: string;

  /**
   * Indicates the two-digit month when the card expires (e.g., 12 for December).
   */
  expiryMonth: number;

  /**
   * Indicates the four-digit year when the card expires (e.g., 2026).
   */
  expiryYear: number;
}

/**
 * A comprehensive interface for describing a payment entity within the dog
 * walking application. It covers all necessary fields to track a payment
 * from creation to settlement or refund, supporting real-time queries
 * and analytics.
 */
export interface Payment {
  /**
   * A unique identifier assigned to this payment record. Typically a UUID
   * or provider-issued ID that ensures global uniqueness.
   */
  id: string;

  /**
   * The ID of the walk (booking) associated with this payment.
   * This links financial transactions to specific dog walking services.
   */
  walkId: string;

  /**
   * The total amount of the payment, represented in the smallest currency units
   * if appropriate (e.g., cents if the currency is USD).
   */
  amount: number;

  /**
   * Indicates the currency code (e.g., USD or CAD) for this payment.
   */
  currency: CurrencyCode;

  /**
   * The current status of this payment (e.g., PENDING, COMPLETED).
   */
  status: PaymentStatus;

  /**
   * The method or instrument used (e.g., CREDIT_CARD, APPLE_PAY).
   */
  method: PaymentMethod;

  /**
   * An identifier returned by Stripe upon creation of a PaymentIntent.
   * Useful for referencing transactions in Stripe’s dashboard or the
   * dog walking application’s reconciliation processes.
   */
  stripePaymentIntentId: string;

  /**
   * Non-sensitive metadata describing the payment instrument,
   * including brand, last4, and expiry details.
   */
  metadata: PaymentMetadata;

  /**
   * The date and time when this payment record was initially created,
   * used for chronological ordering and auditing.
   */
  createdAt: Date;

  /**
   * The most recent date and time when this payment record was modified,
   * updated upon status changes or partial refunds.
   */
  updatedAt: Date;
}

/**
 * Specifies a structured request to create a payment in the dog walking
 * application. This interface captures all required fields that the
 * backend expects to initiate a transaction with the payment gateway.
 */
export interface CreatePaymentRequest {
  /**
   * The ID of the walk (booking) for which payment is being made.
   */
  walkId: string;

  /**
   * The monetary amount to charge for the dog walking service,
   * generally matched to the booking cost.
   */
  amount: number;

  /**
   * The currency code for the transaction (e.g., USD, CAD).
   */
  currency: CurrencyCode;

  /**
   * The user’s chosen payment method or instrument used
   * during checkout.
   */
  method: PaymentMethod;

  /**
   * A boolean indicating whether the user consents to or requires
   * their payment method to be stored for future usage or quick checkout.
   */
  setupFutureUsage: boolean;
}

/**
 * Encapsulates the response data when a payment is successfully created
 * or requires additional actions. This might include a client secret for
 * confirming the payment on the frontend and a flag for 3D Secure or SCA.
 */
export interface PaymentResponse {
  /**
   * The payment record in its current state, including metadata and status.
   */
  payment: Payment;

  /**
   * A client secret unique to this PaymentIntent, provided by Stripe,
   * enabling the client-side to confirm payment or handle additional steps
   * such as 3D Secure authentication.
   */
  clientSecret: string;

  /**
   * A boolean indicating whether the client needs to perform additional actions
   * (e.g., 3D Secure verification) before the payment can be completed.
   */
  requiresAction: boolean;
}

/**
 * Represents a structured request to initiate a refund on an existing
 * payment, specifying the overall amount to refund, the reason code,
 * and any additional metadata for context or reconciliation.
 */
export interface RefundRequest {
  /**
   * The unique identifier of the payment to be refunded.
   */
  paymentId: string;

  /**
   * The amount to be refunded, specified in the smallest currency units
   * if appropriate (e.g., cents for USD).
   */
  amount: number;

  /**
   * Indicates the reason for the refund, which could be duplication,
   * fraud suspicion, user request, or incomplete service provision.
   */
  reason: RefundReason;

  /**
   * Optional metadata providing more details about the refund request,
   * such as internal reference numbers or a textual justification.
   */
  metadata: Record<string, string>;
}

/**
 * Enum listing standard reasons under which a particular payment refund
 * may be processed. These reasons help with reporting and auditing,
 * ensuring clarity in financial transactions.
 */
export enum RefundReason {
  /**
   * The payment was determined to be a duplicate charge for the same
   * service or booking.
   */
  DUPLICATE = 'DUPLICATE',

  /**
   * The payment is suspected to be fraudulent or unauthorized,
   * requiring immediate refund to the cardholder.
   */
  FRAUDULENT = 'FRAUDULENT',

  /**
   * The customer has directly requested a refund for personal or
   * service-related reasons.
   */
  REQUESTED_BY_CUSTOMER = 'REQUESTED_BY_CUSTOMER',

  /**
   * The service was not (or could not be) provided, thereby justifying
   * a refund of the original payment.
   */
  SERVICE_NOT_PROVIDED = 'SERVICE_NOT_PROVIDED',
}

//
// -------------------------------------------------------------------------------------
// OPTIONAL: PAYMENT-SPECIFIC RESPONSE WRAPPER
// -------------------------------------------------------------------------------------

/**
 * Illustrative example of how one might wrap a payment entity in the
 * standardized API response structure imported from ./api.types. This
 * is not mandated by the JSON schema but demonstrates how the dog walking
 * application could return payment data in a consistent format.
 */
export type PaymentApiResponse = ApiResponse<Payment>;

//
// End of payment.types.ts
//