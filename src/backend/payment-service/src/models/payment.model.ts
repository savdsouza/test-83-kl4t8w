/* 
  payment.model.ts

  This file defines the Payment model for the Dog Walking Mobile Application's
  Payment Service, leveraging NestJS Mongoose for schema creation and validation.
  It includes extensive comments to clarify each property's function and validation
  constraints, supporting a secure, end-to-end payment lifecycle architecture.
*/

// External Imports - @nestjs/mongoose ^10.0.0
import { Schema as MongooseSchema, Prop, Schema, SchemaFactory } from '@nestjs/mongoose';

// Internal Imports
import { currencyConfig } from '../config/payment.config';

/**
 * PaymentStatus
 * 
 * Enum representing the full lifecycle of a payment, from the moment
 * it is initiated (PENDING), through processing, possible completion,
 * failure, or final refunded state.
 */
export enum PaymentStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
  REFUNDED = 'refunded',
}

/**
 * Payment
 * 
 * Enhanced schema class representing a comprehensive payment record with support for:
 * - Full payment lifecycle tracking
 * - Stripe integration fields (payment intent and refund IDs)
 * - Detailed transaction metadata
 * - Timestamps and indexing for robust query efficiency
 */
@Schema({ timestamps: true, collection: 'payments', versionKey: false })
export class Payment {
  /**
   * id
   * 
   * A unique identifier for the payment record. This may map to an internal
   * payment ID used by the application for reference and audits.
   */
  @Prop({ required: true, index: true })
  id!: string;

  /**
   * walkId
   * 
   * References the associated walk session that this payment is tied to.
   * Enables linking of financial operations to a specific dog walking session.
   */
  @Prop({ required: true, index: true })
  walkId!: string;

  /**
   * ownerId
   * 
   * The user ID of the dog owner initiating or responsible for the payment.
   * This field is indexed to promote quick lookups by owner.
   */
  @Prop({ required: true, index: true })
  ownerId!: string;

  /**
   * walkerId
   * 
   * The user ID of the walker who is being compensated for the service provided.
   * Indexing this field allows fast retrieval of payments by walker.
   */
  @Prop({ required: true, index: true })
  walkerId!: string;

  /**
   * amount
   * 
   * The total chargeable amount for this payment operation. Must be greater than
   * or equal to 0, reflecting a valid payable sum.
   */
  @Prop({
    required: true,
    min: 0,
    validate: {
      validator: (v: number) => v >= 0,
    },
  })
  amount!: number;

  /**
   * status
   * 
   * Indicates the current payment status, enforced by the PaymentStatus enum.
   * Allows efficient query of payments in different lifecycle stages.
   */
  @Prop({
    required: true,
    enum: PaymentStatus,
    index: true,
  })
  status!: PaymentStatus;

  /**
   * currency
   * 
   * Specifies the currency of the payment, restricted to supported currency codes
   * defined in currencyConfig. Defaults to the configured default currency if not specified.
   */
  @Prop({
    required: true,
    enum: currencyConfig.supportedCurrencies,
    default: currencyConfig.defaultCurrency,
  })
  currency!: string;

  /**
   * stripePaymentIntentId
   * 
   * Stores the unique Stripe Payment Intent ID. Indicates a successfully created
   * payment intent on the Stripe platform, enabling future references and updates.
   */
  @Prop({
    sparse: true,
    index: true,
  })
  stripePaymentIntentId?: string;

  /**
   * stripeRefundId
   * 
   * Stores the unique Stripe Refund ID, facilitating tracking of refunded payments
   * and reconciliation with the Stripe platform.
   */
  @Prop({
    sparse: true,
    index: true,
  })
  stripeRefundId?: string;

  /**
   * processedAt
   * 
   * Records the time at which the payment was successfully processed. Useful for
   * generating chronological transaction histories and providing accurate billing.
   */
  @Prop({
    index: true,
  })
  processedAt?: Date;

  /**
   * refundedAt
   * 
   * Records the time at which a payment was refunded. This timestamp ensures
   * transparency and comprehensive logging of financial reversals.
   */
  @Prop({
    index: true,
  })
  refundedAt?: Date;

  /**
   * metadata
   * 
   * Holds additional structured data for the payment record. A validator ensures
   * the object size does not exceed a threshold, preventing overly large metadata.
   */
  @Prop({
    type: Object,
    validate: {
      validator: (v: object) => Object.keys(v).length <= 50,
    },
  })
  metadata?: object;
}

// Export the Payment schema factory to enable Mongoose Model creation in NestJS
export const PaymentSchema = SchemaFactory.createForClass(Payment);

/**
 * Exports
 * 
 * Exporting the Payment class (with PaymentSchema implicitly usable),
 * and the PaymentStatus enum, enabling usage throughout the application
 * for advanced payment lifecycle handling, status checks, and data operations.
 */