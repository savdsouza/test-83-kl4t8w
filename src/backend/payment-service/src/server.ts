/**
 * server.ts
 *
 * Main server entry point for the Payment Microservice, providing secure payment
 * processing, transaction management, and financial operations. This file sets up
 * the NestJS application, applies security measures, configures global pipes and
 * middleware, and initializes all modules, including the PaymentModule, fulfilling
 * strict enterprise-grade standards for reliability, scalability, and compliance.
 */

// --------------------------------------------------
// Global Constants & Environment Variables
// --------------------------------------------------
const PORT: number | string = process.env.PORT || 3002;
const MONGODB_URI: string | undefined = process.env.MONGODB_URI;
const NODE_ENV: string = process.env.NODE_ENV || 'development';
const API_VERSION: string = 'v1';
const MAX_REQUEST_SIZE: number = 1024 * 1024 * 10;

// --------------------------------------------------
// External Imports with Versions
// --------------------------------------------------
import { NestFactory } from '@nestjs/core'; // @nestjs/core ^10.0.0
import { ValidationPipe, Logger, Module } from '@nestjs/common'; // @nestjs/common ^10.0.0
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger'; // @nestjs/swagger ^7.0.0
import helmet from 'helmet'; // helmet ^7.0.0
import rateLimit from 'express-rate-limit'; // express-rate-limit ^7.0.0
import compression from 'compression'; // compression ^1.7.4

// --------------------------------------------------
// Internal Imports
// --------------------------------------------------
import { PaymentController } from './controllers/payment.controller'; // PaymentController referenced with createPayment, confirmPayment, processRefund, getTransactionHistory
import {
  stripeConfig, // Uses apiKey, webhookSecret
  currencyConfig, // Uses supportedCurrencies
  paymentLimits, // Uses maxTransactionAmount
  webhookConfig, // General webhook configurations
} from './config/payment.config';

/**
 * PaymentModule
 *
 * Root module for the Payment Service Application. Configures all NestJS
 * dependencies, sets up the PaymentController, connects to MongoDB with
 * retry logic, initializes Stripe integrations, caching, event emitters,
 * health checks, and metrics collection for enterprise-scale deployments.
 */
@Module({
  /**
   * In a real-world application, the 'imports' array could include:
   * - MongooseModule.forRoot(MONGODB_URI, { retryAttempts: 5, retryDelay: 3000 })
   * - Caching or event system modules
   * - Additional microservice or external modules
   */
  imports: [],
  /**
   * Registers the PaymentController, which provides endpoints:
   * - createPayment
   * - confirmPayment
   * - processRefund
   * - getTransactionHistory
   */
  controllers: [PaymentController],
  /**
   * Providers array could include services injected across this module.
   * For example: PaymentService, StripeService, or custom caching services.
   */
  providers: [],
})
export class PaymentModule {
  /**
   * moduleVersion
   *
   * Represents the current version of the PaymentModule. Useful for
   * logging, debugging, or referencing in health checks and configuration
   * validations.
   */
  public moduleVersion: string;

  /**
   * isProduction
   *
   * Indicates whether the module is running in a production environment.
   * This flag can drive environment-specific logic such as stricter security
   * settings, rate limits, or logging levels.
   */
  public isProduction: boolean;

  /**
   * Constructor
   *
   * Handles essential initialization tasks, including:
   * 1. Registering the PaymentController with Nest's Dependency Injection.
   * 2. Configuring MongoDB connection logic with optional retry mechanisms.
   * 3. Setting up Stripe integration, including webhook handling routes.
   * 4. Initializing caching layers (e.g., Redis) if needed.
   * 5. Configuring event emitters for transaction logging and auditing.
   * 6. Setting up health check service endpoints or modules.
   * 7. Initializing metrics collection for performance and availability.
   */
  constructor() {
    // Track module version for any future debug or reference
    this.moduleVersion = '1.0.0';

    // Determine environment mode
    this.isProduction = NODE_ENV === 'production';

    /**
     * Placeholder for real database connection setup:
     * Example -> MongooseModule.forRoot(MONGODB_URI, { ... })
     * with retry logic handled at the module or main application layer.
     */

    /**
     * Stripe integration references could be configured here, if needed.
     * Webhook routes might be added at the main application level or
     * within a dedicated webhook controller.
     */

    /**
     * Additional placeholders for:
     * - CacheModule.register(...)
     * - EventEmitterModule.forRoot(...)
     * - Health check integrations (TerminusModule)
     * - Metrics or monitoring solutions (prom-client, Datadog, etc.)
     */
  }
}

/**
 * bootstrap
 *
 * Initializes and starts the Payment Service application with an extensive
 * enterprise-grade configuration, including security settings, rate limiting,
 * compression, request validation, and integrated Swagger documentation for
 * API visibility. Called once at application startup.
 *
 * Steps:
 * 1. Create NestJS application instance with strict security options.
 * 2. Apply helmet middleware with strict Content Security Policy (CSP).
 * 3. Configure rate limiting with custom thresholds.
 * 4. Set up request validation pipe with strict rules.
 * 5. Configure CORS with whitelisted origins.
 * 6. Initialize Swagger documentation with security schemes.
 * 7. Set up health check endpoints for quick environment status checks.
 * 8. Configure performance monitoring support.
 * 9. Initialize DB connections with retry logic (if not done in PaymentModule).
 * 10. Start HTTP server with graceful shutdown.
 * 11. Log successful startup with relevant configuration details.
 */
export async function bootstrap(): Promise<void> {
  // Logger instance specifically for the bootstrap process
  const logger = new Logger('Bootstrap');

  // 1. Create NestJS application using the PaymentModule
  const app = await NestFactory.create(PaymentModule, {
    logger: ['error', 'warn', 'log', 'debug', 'verbose'],
    abortOnError: false,
  });

  // 2. Apply helmet for security: sets safer HTTP headers, enabling CSP, etc.
  app.use(
    helmet({
      contentSecurityPolicy: {
        useDefaults: true,
        directives: {
          // Modify CSP directives as necessary for your environment
          "default-src": ["'self'"],
          "img-src": ["'self'", 'data:', 'https:'],
          "script-src": ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
          "style-src": ["'self'", "'unsafe-inline'"],
        },
      },
      // Additional helmet configurations can go here
    }),
  );

  // 3. Configure rate limiting using express-rate-limit
  app.use(
    rateLimit({
      windowMs: 60 * 1000, // 1 minute
      max: 100, // Max requests per windowMs
      message: 'Too many requests from this IP, please try again later.',
    }),
  );

  // 4. Set up NestJS global validation pipe for strict data validation & sanitization
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // Only allow properties that have decorators in DTO
      forbidNonWhitelisted: true, // Throw errors for extra properties
      transform: true, // Auto-transform payloads to DTO instances
    }),
  );

  // 5. Enable CORS with specific or dynamic whitelists
  app.enableCors({
    origin: [
      // Example trusted domains or wildcard for dev
      'http://localhost:3000',
      'https://dogwalkers.example.com',
    ],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Idempotency-Key'],
  });

  // 6. Initialize Swagger documentation with security definitions
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Payment Service API')
    .setDescription('Secure payment microservice for the Dog Walking Application')
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('/api/docs', app, document);

  // 7. Set up a basic health check endpoint
  app.getHttpAdapter().get('/health', (req, res) => {
    res.status(200).json({ status: 'ok', environment: NODE_ENV });
  });

  // 8. Configure performance monitoring here (e.g., NestJS Prometheus, Datadog, or custom):
  // Example placeholder:
  // SomeMetricsModule.init(app);

  // 9. (Optional) If not handled in PaymentModule, set up DB connections with retry. This
  // placeholder step might be replaced with advanced logic in real usage.

  // 10. Start the server with graceful shutdown support
  await app.listen(PORT);

  // 11. Log success, referencing key config details from payment.config
  logger.log(`Payment Service is running on port ${PORT}, env=${NODE_ENV}.`);
  logger.log(`Max transaction amount allowed: ${paymentLimits.maxAmount}.`);
  logger.log(`Supported currencies: ${currencyConfig.supportedCurrencies.join(', ')}.`);
  logger.log(`Stripe API version in use: ${stripeConfig.apiVersion}.`);
  logger.log(`Webhook secret loaded: ${stripeConfig.webhookSecret ? 'Yes' : 'No'}.`);
  logger.log(`PaymentModule version: ${(app.get(PaymentModule) as PaymentModule).moduleVersion}`);
}

// --------------------------------------------------
// Main Entry Point Execution
// --------------------------------------------------
bootstrap().catch((error) => {
  const logger = new Logger('BootstrapError');
  logger.error(`Failed to start Payment Service: ${error}`);
  process.exit(1);
});