/**
 * payment.config.ts
 * 
 * This configuration file provides all payment and currency-related settings
 * for the Payment Service, including Stripe integration details, currency 
 * validation, configurable payment limits, and webhook security. Additionally, 
 * it ensures all critical environment variables are loaded and validates their 
 * presence, preventing application startup if required values are missing.
 */

// dotenv ^16.0.0
import * as dotenv from 'dotenv';

/**
 * Initialize dotenv to load environment variables from a .env file if present.
 * These environment variables are crucial, especially for credentials such as
 * STRIPE_API_KEY and STRIPE_WEBHOOK_SECRET, which must not be committed to source control.
 */
dotenv.config();

/**
 * Throws an error with the supplied message, terminating further execution.
 * This function is used to enforce that required configuration values are present
 * and valid, preventing misconfiguration issues at runtime.
 * 
 * @param message - A descriptive error message
 * @returns never - Control flow does not return
 */
function throwError(message: string): never {
  throw new Error(message);
}

/**
 * Retrieve and validate the Stripe API key from environment variables.
 * The application will fail to start if STRIPE_API_KEY is not defined.
 */
const stripeApiKey: string =
  process.env.STRIPE_API_KEY || throwError('STRIPE_API_KEY is required');

/**
 * Retrieve and validate the Stripe Webhook secret key from environment variables.
 * The application will fail to start if STRIPE_WEBHOOK_SECRET is not defined.
 */
const stripeWebhookSecret: string =
  process.env.STRIPE_WEBHOOK_SECRET || throwError('STRIPE_WEBHOOK_SECRET is required');

/**
 * Retrieve the Stripe API version from environment variables, or default to 2023-10-16.
 * This version aligns with the Stripe API reference to ensure compatibility.
 */
const stripeApiVersion: string = process.env.STRIPE_API_VERSION || '2023-10-16';

/**
 * stripeConfig
 * 
 * Provides comprehensive configuration for integrating with Stripe, including
 * API credentials, retry logic, and request timeouts. These settings ensure
 * robust and reliable communication with Stripe’s payment APIs.
 */
export const stripeConfig = {
  /**
   * apiKey
   * The secret Stripe API key required to authenticate requests to Stripe.
   * Must be handled securely and never exposed to the client side.
   */
  apiKey: stripeApiKey,

  /**
   * apiVersion
   * Specifies the Stripe API version the application uses. Adhering to this version
   * mitigates potential breaking changes from updates in newer Stripe versions.
   */
  apiVersion: stripeApiVersion,

  /**
   * webhookSecret
   * The Stripe Webhook signing secret used to validate the authenticity of webhook events.
   * Protects against unauthorized or fake webhook notifications.
   */
  webhookSecret: stripeWebhookSecret,

  /**
   * maxRetries
   * Number of times to retry a failed Stripe operation request before giving up.
   * Helps handle transient network or server errors.
   */
  maxRetries: 3,

  /**
   * timeout
   * Timeout configuration (in milliseconds) for outgoing requests to Stripe’s services.
   * Avoids hanging connections and ensures graceful error handling.
   */
  timeout: 3000,
};

/**
 * A predefined list of supported currency codes conforming to ISO 4217 standards.
 * This list is referenced by the currency configuration for validation.
 */
const defaultSupportedCurrencies: string[] = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];

/**
 * currencyConfig
 * 
 * Provides comprehensive settings for currency handling, including a default currency,
 * an array of supported currency codes, a robust validation method, and an external
 * exchange rate provider specification for additional functionalities.
 */
export const currencyConfig = {
  /**
   * defaultCurrency
   * The primary currency used by the application when a specified currency is not chosen.
   * Must be part of the supportedCurrencies array to be considered valid.
   */
  defaultCurrency: 'USD',

  /**
   * supportedCurrencies
   * An array of permissible currency codes accepted by the application for payments.
   * Ensures only recognized and valid currencies are processed.
   */
  supportedCurrencies: defaultSupportedCurrencies,

  /**
   * validateCurrency
   * Function that validates a given currency code against the supportedCurrencies list
   * and checks if the code follows a valid ISO 4217 three-letter pattern.
   * 
   * @param currencyCode - The currency code to be validated (e.g., "USD", "eur")
   * @returns boolean - True if the currency code is valid and supported; otherwise false
   */
  validateCurrency: (currencyCode: string): boolean => {
    // Convert input to uppercase for consistent comparison
    const uppercaseCode = currencyCode.toUpperCase();

    // Step 1: Check basic ISO 4217 format (exactly three letters)
    const iso4217Pattern = /^[A-Z]{3}$/;
    if (!iso4217Pattern.test(uppercaseCode)) {
      return false;
    }

    // Step 2: Check if currency code exists in the configured list
    return defaultSupportedCurrencies.includes(uppercaseCode);
  },

  /**
   * exchangeRateProvider
   * Indicates the external service or API used to retrieve currency exchange rates.
   * Configurable to allow future changes if a different rate provider is preferred.
   */
  exchangeRateProvider: 'OpenExchangeRates',
};

/**
 * paymentLimits
 * 
 * Defines and enforces financial constraints for transactions, including minimum
 * and maximum amounts, daily and monthly limits, and a cooldown period.
 * These controls help mitigate fraud and ensure regulatory compliance.
 */
export const paymentLimits = {
  /**
   * minAmount
   * The smallest permissible transaction amount. Payments below this amount
   * will be automatically rejected.
   */
  minAmount: 1.0,

  /**
   * maxAmount
   * The largest permissible transaction amount. Payments exceeding this amount
   * will be automatically rejected.
   */
  maxAmount: 9999.99,

  /**
   * dailyTransactionLimit
   * The maximum number of transactions a user can initiate in a 24-hour period.
   * Prevents excessive or suspicious payment activities.
   */
  dailyTransactionLimit: 100,

  /**
   * monthlyAmountLimit
   * The maximum cumulative amount (in default currency) a user can transact
   * in a 30-day rolling window. Provides additional fraud mitigation.
   */
  monthlyAmountLimit: 50000,

  /**
   * maxTransactionsPerDay
   * Specifies the maximum number of successfully processed transactions allowed
   * for any account within a single day to prevent abuse.
   */
  maxTransactionsPerDay: 20,

  /**
   * cooldownPeriod
   * A required waiting time (in seconds) after a transaction before initiating
   * the next one, reducing potential transaction spam or rate-based attacks.
   */
  cooldownPeriod: 60,
};

/**
 * webhookConfig
 * 
 * Provides robust, production-grade settings for managing webhook event reception
 * and processing, including security tolerances, automatic retry attempts, 
 * backoff strategies, and source IP whitelisting for enhanced security.
 */
export const webhookConfig = {
  /**
   * secret
   * A strongly protected secret key used to verify incoming webhook requests, 
   * ensuring they originate from a trusted source (like Stripe).
   */
  secret: stripeWebhookSecret,

  /**
   * toleranceSeconds
   * The allowable time discrepancy (in seconds) between the webhook timestamp
   * and the receiver’s clock to accommodate network delays or minor server time mismatches.
   */
  toleranceSeconds: 300,

  /**
   * retryAttempts
   * The number of times to attempt re-processing webhook data if an error occurs,
   * preventing loss of critical payment event information.
   */
  retryAttempts: 3,

  /**
   * backoffStrategy
   * Strategy for spacing out subsequent retry attempts when a webhook fails.
   * Can be either "exponential", "linear", or a custom approach in a real production setting.
   */
  backoffStrategy: 'exponential',

  /**
   * ipWhitelist
   * A list of IP addresses from which webhook requests are considered valid.
   * Any request originating from an IP not in this list may be blocked outright.
   */
  ipWhitelist: ['192.168.100.1', '10.0.200.5'],
};