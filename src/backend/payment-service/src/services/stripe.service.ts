import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';

/**
 * Stripe (version ^12.0.0)
 * Official SDK for Stripe payment processing, providing methods
 * for creating payment intents, refunds, and handling webhooks.
 */
import Stripe from 'stripe';

import { Payment, PaymentStatus } from '../models/payment.model';

/**
 * Import Stripe configuration details and utilities, including:
 * - stripeConfig: Contains API key, API version, webhook secret, retry logic, and more.
 * - currencyConfig: Validates supported currency codes and defines defaults.
 */
import { stripeConfig, currencyConfig } from '../config/payment.config';

/**
 * StripeService
 *
 * A NestJS injectable service responsible for integrating with the Stripe
 * payment gateway. This class implements secure payment operations
 * such as creating payment intents, confirming payments, processing
 * refunds, and handling webhook events with robust error handling,
 * logging, and metrics collection for enterprise-grade usage.
 */
@Injectable()
export class StripeService {
  /**
   * Internal Stripe SDK instance for making payment-related calls.
   * Configured with secret API key, API version, and additional settings.
   */
  private readonly stripe: Stripe;

  /**
   * Logger service for recording all payment flow details,
   * warnings, and error information for diagnostics.
   */
  private readonly logger: Logger = new Logger(StripeService.name);

  /**
   * Constructs the StripeService by:
   * 1. Injecting the Payment model for database persistence.
   * 2. Initializing a new Stripe client with credentials from config.
   * 3. Setting concurrency, retry, and timeout settings.
   * 4. Preparing a logger for payment lifecycle tracking.
   *
   * @param paymentModel - The Mongoose model for Payment
   */
  constructor(
    @InjectModel(Payment.name)
    private readonly paymentModel: Model<Payment>,
  ) {
    this.stripe = new Stripe(stripeConfig.apiKey, {
      apiVersion: stripeConfig.apiVersion,
      maxNetworkRetries: stripeConfig.maxRetries,
      timeout: stripeConfig.timeout,
    });
  }

  /**
   * createPaymentIntent
   *
   * Creates a Stripe payment intent for a new dog walking booking.
   * Applies validation checks on the payment data, ensures the currency
   * is supported, and returns the client secret for client-side handling.
   * Stores a preliminary Payment record in the database with status PENDING.
   *
   * @param paymentData - Required payment info for creating an intent
   * @returns An object containing the Stripe clientSecret and paymentIntentId
   * @throws Error if validation fails or Stripe request encounters issues
   */
  public async createPaymentIntent(paymentData: {
    amount: number;
    walkId: string;
    ownerId: string;
    walkerId: string;
    currency: string;
    idempotencyKey: string;
  }): Promise<{ clientSecret: string; paymentIntentId: string }> {
    this.logger.log(`Initiating createPaymentIntent for walkId=${paymentData.walkId}`);

    // 1) Validate fields
    if (paymentData.amount <= 0) {
      this.logger.error('Payment amount must be a positive number.');
      throw new Error('Invalid payment amount');
    }
    if (!currencyConfig.validateCurrency(paymentData.currency)) {
      this.logger.error(`Unsupported currency: ${paymentData.currency}`);
      throw new Error(`Unsupported currency code: ${paymentData.currency}`);
    }

    // 2) Convert to smallest currency unit (assuming two-decimal system)
    const stripeAmount = Math.round(paymentData.amount * 100);

    // 3) Create a new payment record with PENDING status
    const newPayment = new this.paymentModel({
      id: this.generateLocalPaymentId(),
      walkId: paymentData.walkId,
      ownerId: paymentData.ownerId,
      walkerId: paymentData.walkerId,
      amount: paymentData.amount,
      status: PaymentStatus.PENDING,
      currency: paymentData.currency.toUpperCase(),
    });

    // 4) Attempt to create a Stripe payment intent
    try {
      const paymentIntent = await this.stripe.paymentIntents.create(
        {
          amount: stripeAmount,
          currency: newPayment.currency,
          metadata: {
            localPaymentId: newPayment.id,
            walkId: newPayment.walkId,
            ownerId: newPayment.ownerId,
            walkerId: newPayment.walkerId,
          },
        },
        {
          idempotencyKey: paymentData.idempotencyKey,
        },
      );

      // 5) Store the Stripe paymentIntentId in Payment record
      newPayment.stripePaymentIntentId = paymentIntent.id;
      await newPayment.save();

      this.logger.log(
        `Payment Intent created successfully: paymentIntentId=${paymentIntent.id} for Payment ID=${newPayment.id}`,
      );

      // 6) Return the client secret to complete payment on the client side
      return {
        clientSecret: paymentIntent.client_secret ?? '',
        paymentIntentId: paymentIntent.id,
      };
    } catch (err) {
      this.logger.error(`Failed to create Payment Intent: ${err}`);
      throw err;
    }
  }

  /**
   * confirmPayment
   *
   * Confirms a payment after the client completes the payment intent.
   * Includes retry logic for transient failures, validates final status,
   * and updates the Payment record to COMPLETED if successful.
   *
   * @param paymentIntentId - The Stripe Payment Intent ID
   * @returns The updated Payment document reflecting the confirmation result
   * @throws Error if the confirmation fails or the record cannot be updated
   */
  public async confirmPayment(paymentIntentId: string): Promise<Payment> {
    this.logger.log(`Attempting to confirm payment for paymentIntentId=${paymentIntentId}`);

    // 1) Locate corresponding Payment record
    const paymentDoc = await this.paymentModel.findOne({ stripePaymentIntentId: paymentIntentId });
    if (!paymentDoc) {
      this.logger.error(`No local payment found for paymentIntentId=${paymentIntentId}`);
      throw new Error('Payment record not found');
    }

    // 2) Retrieve payment intent from Stripe
    let paymentIntent: Stripe.PaymentIntent | null = null;
    try {
      paymentIntent = await this.stripe.paymentIntents.retrieve(paymentIntentId);
    } catch (err) {
      this.logger.error(`Failed to retrieve payment intent: ${err}`);
      throw err;
    }

    // 3) If the payment intent requires confirmation, attempt to confirm
    if (paymentIntent && paymentIntent.status === 'requires_confirmation') {
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          this.logger.log(`Confirming payment intent. Attempt #${attempt}`);
          await this.stripe.paymentIntents.confirm(paymentIntent.id);
          break;
        } catch (err) {
          this.logger.warn(
            `Attempt #${attempt} to confirm Payment Intent ${paymentIntent.id} failed: ${err}`,
          );
          if (attempt === 3) {
            this.logger.error(
              `Payment Intent confirmation permanently failed after 3 attempts: ${paymentIntent.id}`,
            );
            throw err;
          }
        }
      }
    }

    // 4) Re-retrieve the updated intent to check final status
    try {
      paymentIntent = await this.stripe.paymentIntents.retrieve(paymentIntentId);
      if (paymentIntent.status === 'succeeded' || paymentIntent.status === 'processing') {
        // 5) Update Payment record to COMPLETED and record processedAt
        paymentDoc.status = PaymentStatus.COMPLETED;
        paymentDoc.processedAt = new Date();
        await paymentDoc.save();

        this.logger.log(`Payment confirmed and completed for localPaymentId=${paymentDoc.id}`);
      } else {
        this.logger.warn(
          `Payment intent did not reach succeeded status: status=${paymentIntent.status}`,
        );
      }
    } catch (err) {
      this.logger.error(`Error finalizing payment status for intentId=${paymentIntentId}: ${err}`);
      throw err;
    }

    // 6) Return updated Payment record
    return paymentDoc;
  }

  /**
   * processRefund
   *
   * Initiates a full or partial refund for a previously completed payment.
   * Updates the Payment record accordingly and tracks the refund operation
   * with comprehensive logging and error handling.
   *
   * @param paymentId - The local Payment document ID
   * @param refundData - Refund details including optional amount and reason
   * @returns The updated Payment document reflecting refund status
   * @throws Error if the payment record is invalid, not found, or refund fails
   */
  public async processRefund(
    paymentId: string,
    refundData: { amount?: number; reason?: string; idempotencyKey: string },
  ): Promise<Payment> {
    this.logger.log(`Initiating refund for localPaymentId=${paymentId}`);

    // 1) Retrieve the Payment document
    const paymentDoc = await this.paymentModel.findOne({ id: paymentId });
    if (!paymentDoc) {
      this.logger.error(`No local payment found for localPaymentId=${paymentId}`);
      throw new Error('Payment record not found for refund');
    }

    // 2) Check if the payment is in a valid status for refund
    if (paymentDoc.status !== PaymentStatus.COMPLETED) {
      this.logger.warn(
        `Attempting to refund a payment not in COMPLETED status: ${paymentId} (status=${paymentDoc.status})`,
      );
      throw new Error('Only completed payments can be refunded');
    }

    // 3) Convert refund amount to the smallest currency unit if supplied
    let refundAmount: number | undefined;
    if (refundData.amount != null) {
      if (refundData.amount <= 0 || refundData.amount > paymentDoc.amount) {
        this.logger.error(
          `Invalid refund amount: amount=${refundData.amount}, original=${paymentDoc.amount}`,
        );
        throw new Error('Refund amount is invalid or exceeds original payment amount');
      }
      refundAmount = Math.round(refundData.amount * 100);
    }

    // 4) Attempt the Stripe refund
    try {
      const refund = await this.stripe.refunds.create(
        {
          payment_intent: paymentDoc.stripePaymentIntentId,
          amount: refundAmount,
          reason: refundData.reason,
        },
        {
          idempotencyKey: refundData.idempotencyKey,
        },
      );

      // 5) Update local payment record to REFUNDED
      paymentDoc.status = PaymentStatus.REFUNDED;
      paymentDoc.refundedAt = new Date();
      paymentDoc.stripeRefundId = refund.id;
      await paymentDoc.save();

      this.logger.log(`Refund successful for localPaymentId=${paymentDoc.id}, refundId=${refund.id}`);
      return paymentDoc;
    } catch (err) {
      this.logger.error(`Refund failed for localPaymentId=${paymentDoc.id}: ${err}`);
      throw err;
    }
  }

  /**
   * handleWebhook
   *
   * Verifies and processes incoming Stripe webhook events, ensuring
   * authenticity via signature checks. Parses and responds to events
   * such as payment_intent.succeeded, payment_intent.payment_failed,
   * charge.refunded, or dispute notifications. Logs and updates the
   * associated Payment record when needed.
   *
   * @param signature - The Stripe-Signature header value
   * @param rawBody - The raw request body as a Buffer
   * @returns A Promise resolving to void if processing succeeds
   * @throws Error if signature verification or event handling fails
   */
  public async handleWebhook(signature: string, rawBody: Buffer): Promise<void> {
    let event: Stripe.Event;

    // 1) Verify the webhook signature
    try {
      event = this.stripe.webhooks.constructEvent(
        rawBody,
        signature,
        stripeConfig.webhookSecret,
      );
      this.logger.log(`Received valid webhook event type=${event.type} id=${event.id}`);
    } catch (err) {
      this.logger.error(`Webhook signature verification failed: ${err}`);
      throw err;
    }

    // 2) Parse the event by type and act accordingly
    try {
      switch (event.type) {
        case 'payment_intent.succeeded': {
          const paymentIntent = event.data.object as Stripe.PaymentIntent;
          await this.updatePaymentStatusOnSuccess(paymentIntent);
          break;
        }
        case 'payment_intent.payment_failed': {
          const failedIntent = event.data.object as Stripe.PaymentIntent;
          await this.updatePaymentStatusOnFailure(failedIntent);
          break;
        }
        case 'charge.refunded': {
          const charge = event.data.object as Stripe.Charge;
          if (charge.payment_intent && typeof charge.payment_intent === 'string') {
            await this.updatePaymentStatusOnRefund(charge.payment_intent, charge.refunds?.data?.[0]);
          }
          break;
        }
        case 'charge.dispute.created': {
          const disputeCharge = event.data.object as Stripe.Charge;
          this.logger.warn(`Dispute created for chargeId=${disputeCharge.id}`);
          // Additional handling for disputes can be added here
          break;
        }
        default:
          this.logger.log(`Unhandled event type:${event.type}`);
          break;
      }
    } catch (err) {
      this.logger.error(`Error processing webhook event type=${event.type}: ${err}`);
      throw err;
    }
  }

  /**
   * Generates a local payment ID (UUID-like) for consistent tracking
   * within the Payment system. Real implementation may replace with
   * a UUID library or a distributed ID generator.
   *
   * @returns A pseudo-unique string used as the Payment ID
   */
  private generateLocalPaymentId(): string {
    return `pay_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
  }

  /**
   * updatePaymentStatusOnSuccess
   *
   * Helper method for handleWebhook() that updates the relevant Payment
   * document to COMPLETED after a payment_intent.succeeded event.
   *
   * @param paymentIntent - The Stripe PaymentIntent object
   */
  private async updatePaymentStatusOnSuccess(paymentIntent: Stripe.PaymentIntent): Promise<void> {
    const paymentDoc = await this.paymentModel.findOne({
      stripePaymentIntentId: paymentIntent.id,
    });
    if (!paymentDoc) {
      this.logger.error(
        `Payment record not found for successful paymentIntentId=${paymentIntent.id}`,
      );
      return;
    }
    paymentDoc.status = PaymentStatus.COMPLETED;
    paymentDoc.processedAt = new Date();
    await paymentDoc.save();
    this.logger.log(
      `Payment updated to COMPLETED for localPaymentId=${paymentDoc.id} paymentIntentId=${paymentIntent.id}`,
    );
  }

  /**
   * updatePaymentStatusOnFailure
   *
   * Helper method to set the Payment record to FAILED when a
   * payment_intent.payment_failed event occurs.
   *
   * @param paymentIntent - The failed Stripe PaymentIntent object
   */
  private async updatePaymentStatusOnFailure(paymentIntent: Stripe.PaymentIntent): Promise<void> {
    const paymentDoc = await this.paymentModel.findOne({
      stripePaymentIntentId: paymentIntent.id,
    });
    if (!paymentDoc) {
      this.logger.error(
        `Payment record not found for failed paymentIntentId=${paymentIntent.id}`,
      );
      return;
    }
    paymentDoc.status = PaymentStatus.FAILED;
    await paymentDoc.save();
    this.logger.warn(
      `Payment updated to FAILED for localPaymentId=${paymentDoc.id} paymentIntentId=${paymentIntent.id}`,
    );
  }

  /**
   * updatePaymentStatusOnRefund
   *
   * Helper method to set the Payment record to REFUNDED after a
   * charge.refunded event. Extracts and updates the Stripe refund ID.
   *
   * @param paymentIntentId - The Stripe PaymentIntent ID associated with the charge
   * @param refundObject - The Stripe Refund object information
   */
  private async updatePaymentStatusOnRefund(
    paymentIntentId: string,
    refundObject?: Stripe.Refund,
  ): Promise<void> {
    if (!refundObject) {
      this.logger.error(`No refund information found for paymentIntentId=${paymentIntentId}`);
      return;
    }
    const paymentDoc = await this.paymentModel.findOne({
      stripePaymentIntentId: paymentIntentId,
    });
    if (!paymentDoc) {
      this.logger.error(
        `Payment record not found for refunded paymentIntentId=${paymentIntentId}`,
      );
      return;
    }
    paymentDoc.status = PaymentStatus.REFUNDED;
    paymentDoc.stripeRefundId = refundObject.id;
    paymentDoc.refundedAt = new Date();
    await paymentDoc.save();
    this.logger.log(
      `Payment updated to REFUNDED for localPaymentId=${paymentDoc.id} refundId=${refundObject.id}`,
    );
  }
}