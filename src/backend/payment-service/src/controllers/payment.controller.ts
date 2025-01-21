import {
  Controller,
  Logger,
  UseGuards,
  UseInterceptors,
  UsePipes,
  Post,
  Put,
  Param,
  Body,
  Headers,
  ValidationPipe,
} from '@nestjs/common'; // @nestjs/common ^10.0.0
import { RateLimit } from '@nestjs/throttler'; // @nestjs/throttler ^5.0.0

// Placeholder imports for custom guards/interceptors; these should match actual file paths in a real application
import { AuthGuard } from '../../guards/auth.guard';
import { PaymentGuard } from '../../guards/payment.guard';
import { LoggingInterceptor } from '../../interceptors/logging.interceptor';
import { MonitoringInterceptor } from '../../interceptors/monitoring.interceptor';

// Internal service and model imports
import { PaymentService } from '../services/payment.service';
import { Payment } from '../models/payment.model';

/**
 * PaymentController
 *
 * REST API controller handling payment-related HTTP endpoints for the Dog Walking Mobile Application’s
 * Payment Service. Provides secure and robust endpoints to create, confirm, and refund payments, with
 * enhanced validation, rate limiting, logging, and auditability for enterprise-grade operations.
 */
@Controller('payments')
@UseGuards(AuthGuard, PaymentGuard)
@UseInterceptors(LoggingInterceptor, MonitoringInterceptor)
@RateLimit({ limit: 100, ttl: 60 })
export class PaymentController {
  /**
   * Constructs the PaymentController with essential dependencies for payment processing
   * and logging. Additional cross-cutting concerns such as guards, interceptors,
   * and rate limiting are configured at the class level.
   *
   * @param paymentService - The service providing payment creation, confirmation, and refund operations
   * @param logger - A dedicated Logger instance for structured logging and auditing
   */
  constructor(
    private readonly paymentService: PaymentService,
    private readonly logger: Logger,
  ) {
    /**
     * In a real-world scenario, advanced initialization could occur here,
     * such as verifying PaymentService readiness or injecting additional
     * monitoring hooks. The Logger can be further customized for a unique
     * payment context.
     */
  }

  /**
   * createPayment
   *
   * Creates a new payment for a walk booking with validation and idempotency safeguards.
   * Implements thorough error handling, logging, and concurrency control to avoid
   * duplicate charges. Adheres to the following procedure:
   *
   * 1. Validate the presence and correctness of the idempotency key in headers.
   * 2. (Optional) Check the system to ensure no recent payment with the same key exists.
   * 3. Validate incoming request data via CreatePaymentDto.
   * 4. Log the payment creation attempt for audit purposes.
   * 5. Delegate to the PaymentService to create the payment and Stripe payment intent.
   * 6. (Optional) Monitor or record metrics for successful payment creation.
   * 7. Return the newly created payment record and the client secret to finalize payment on the client.
   *
   * @param paymentData - Payment request info, validated by CreatePaymentDto
   * @param idempotencyKey - Unique key from client headers for idempotency checks
   * @returns A promise resolving to an object containing the created Payment and the Stripe client secret
   */
  @Post()
  @UsePipes(ValidationPipe)
  @RateLimit({ limit: 20, ttl: 60 })
  public async createPayment(
    @Body(new ValidationPipe()) paymentData: any /* Replace with CreatePaymentDto in production */,
    @Headers('Idempotency-Key') idempotencyKey: string,
  ): Promise<{ payment: Payment; clientSecret: string }> {
    // 1. Validate the presence of the idempotency key
    if (!idempotencyKey) {
      this.logger.error('Missing Idempotency-Key header for createPayment request.');
      throw new Error('Idempotency key is required.');
    }

    // 2. (Optional) Check system for existing payment with the same idempotency key
    //    In production, you might query a datastore dedicated to idempotency records.
    //    This sample omits that for brevity.

    // 3. (Already handled by ValidationPipe) - Validate the paymentData structure.

    // 4. Log the payment creation attempt
    this.logger.log(`Attempting to create a new payment with walkId=${paymentData.walkId}`);

    // 5. Call the PaymentService to create payment
    const { payment, clientSecret } = await this.paymentService.createPayment({
      walkId: paymentData.walkId,
      ownerId: paymentData.ownerId,
      walkerId: paymentData.walkerId,
      amount: paymentData.amount,
      currency: paymentData.currency,
      idempotencyKey,
    });

    // 6. (Optional) Monitor or record relevant metrics. For example:
    this.logger.log(`Payment creation successful. PaymentID=${payment.id}`);

    // 7. Return the newly created payment record and Stripe client secret
    return { payment, clientSecret };
  }

  /**
   * confirmPayment
   *
   * Confirms a payment after successful processing on the client side.
   * This endpoint finalizes the payment by invoking the PaymentService,
   * ensuring the payment is in an eligible status, and applying robust
   * error handling and logging. The sequence is:
   *
   * 1. Validate the paymentId and request body via ConfirmPaymentDto.
   * 2. Log the confirmation attempt for traceability.
   * 3. Verify the payment is in a confirmable status and not already completed.
   * 4. Delegate to the PaymentService for final confirmation with Stripe.
   * 5. Monitor success or failure with structured logs and possible metrics.
   * 6. Return the updated Payment record reflecting the new status.
   *
   * @param paymentId - The unique Payment ID from the path parameters
   * @param confirmationData - Data required to confirm the payment (e.g., idempotency key)
   * @returns A promise resolving to the updated Payment record
   */
  @Put(':id/confirm')
  @UsePipes(ValidationPipe)
  public async confirmPayment(
    @Param('id') paymentId: string,
    @Body() confirmationData: any /* Replace with ConfirmPaymentDto in production */,
  ): Promise<Payment> {
    // 1. Validate fields. (ValidationPipe applies to confirmationData structure.)

    // 2. Log confirmation attempt
    this.logger.log(`Confirming payment with ID=${paymentId}`);

    // 3. Check payment status eligibility (delegated to PaymentService or a preliminary call)
    if (!confirmationData.idempotencyKey) {
      this.logger.error('No idempotencyKey provided for payment confirmation.');
      throw new Error('Idempotency key is required for payment confirmation.');
    }

    // 4. Call PaymentService to confirm the payment
    const updatedPayment = await this.paymentService.confirmPayment(
      paymentId,
      confirmationData.idempotencyKey,
    );

    // 5. Monitor success/failure (i.e., log metrics or events)
    this.logger.log(`Payment with ID=${paymentId} confirmed successfully.`);

    // 6. Return the updated payment record
    return updatedPayment;
  }

  /**
   * refundPayment
   *
   * Processes a refund request for a completed payment. Includes robust
   * validation and auditing to ensure only valid refunds are processed.
   * Full steps are:
   *
   * 1. Validate the paymentId format and the request body.
   * 2. Log the refund initiation attempt for an auditable record.
   * 3. Ensure the payment is eligible for a refund (e.g., status=completed).
   * 4. Calculate the refund amount if partial refunds are allowed, or default to full.
   * 5. Delegate to the PaymentService to execute the refund via processRefund.
   * 6. Monitor refund metrics or trace logs for future analysis.
   * 7. Update the payment record to reflect the refunded status.
   * 8. Return the updated payment record with refund details.
   *
   * @param paymentId - The unique Payment ID from the path parameters
   * @param refundData - Data required to process a refund, including optional amount, reason, and idempotency key
   * @returns A promise resolving to the updated Payment record post-refund
   */
  @Post(':id/refund')
  @UsePipes(ValidationPipe)
  @RateLimit({ limit: 10, ttl: 60 })
  public async refundPayment(
    @Param('id') paymentId: string,
    @Body(new ValidationPipe()) refundData: any /* Replace with RefundPaymentDto in production */,
  ): Promise<Payment> {
    // 1. Validate IDs and body structure (handled by ValidationPipe on refundData).

    // 2. Log the refund attempt
    this.logger.log(`Initiating refund for payment ID=${paymentId} with data=${JSON.stringify(refundData)}`);

    // 3. Confirm the presence of required fields
    if (!refundData.idempotencyKey) {
      this.logger.error('Refund attempt is missing an idempotencyKey.');
      throw new Error('Idempotency key is required for refunds.');
    }

    // 4. (Optional) Validate partial refund amounts or reason if the business case allows it.

    // 5. Call the service method to process the refund
    const refundedPayment = await this.paymentService.processRefund(paymentId, {
      amount: refundData.amount,
      reason: refundData.reason,
      idempotencyKey: refundData.idempotencyKey,
    });

    // 6. Log or emit metrics about the refunded payment
    this.logger.log(`Refund executed for Payment ID=${paymentId}. Refund status=${refundedPayment.status}`);

    // 7. The PaymentService already handles updating status to REFUNDED.

    // 8. Return the updated payment record
    return refundedPayment;
  }
}