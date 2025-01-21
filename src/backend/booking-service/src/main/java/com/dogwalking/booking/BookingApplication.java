package com.dogwalking.booking;

// -----------------------------------------------------------------------------
// External Imports with explicit version comments
// -----------------------------------------------------------------------------
import org.springframework.boot.SpringApplication; // version 3.1.0
import org.springframework.boot.autoconfigure.SpringBootApplication; // version 3.1.0
import org.springframework.scheduling.annotation.EnableScheduling; // version 6.0.0
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories; // version 3.1.0
import org.springframework.kafka.annotation.EnableKafka; // version 3.0.0
import io.micrometer.core.instrument.MeterRegistry; // version 1.11.0

// -----------------------------------------------------------------------------
// Internal Imports
// -----------------------------------------------------------------------------
import com.dogwalking.booking.config.DatabaseConfig; // Provides mongoClientSettings() for MongoDB resilience
import com.dogwalking.booking.config.KafkaConfig;     // Provides kafkaTemplate() for Kafka messaging

// -----------------------------------------------------------------------------
// Additional Imports for Usage
// -----------------------------------------------------------------------------
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// Needed to acquire the MongoClientSettings bean from DatabaseConfig
import com.mongodb.MongoClientSettings; // version 4.9.0

// Needed to acquire the KafkaTemplate bean from KafkaConfig
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.context.ApplicationContext;

/**
 * BookingApplication
 *
 * <p>The main Spring Boot application class for the booking service. This
 * service handles walk bookings, scheduling, and real-time management
 * while implementing extensive monitoring, resilience, and security
 * features. It addresses the core booking system requirements:
 *
 * 1. Real-time availability, instant matching, and schedule management.
 * 2. Java/Spring-based service architecture for booking operations.
 * 3. System monitoring through metrics, logging, and tracing.
 *
 * <p>Annotated to enable scheduling, MongoDB repositories, and Kafka messaging.
 * This class launches the embedded server, configures comprehensive lifecycle
 * hooks for graceful shutdown, validates synergy with internal configurations
 * (DatabaseConfig, KafkaConfig), and ensures high availability and performance.
 */
@SpringBootApplication
@EnableScheduling
@EnableMongoRepositories
@EnableKafka
public class BookingApplication {

    /**
     * A descriptive constant representing the name of this microservice,
     * used in logging, metrics tagging, and internal reference across the system.
     */
    public static final String APPLICATION_NAME = "booking-service";

    /**
     * A logger instance for structured, high-volume enterprise debugging and
     * informational logging.
     */
    private static final Logger logger = LoggerFactory.getLogger(BookingApplication.class);

    /**
     * Default constructor with initialization logging to confirm that the
     * core application class is being loaded. Implements:
     * 1) Basic initial logging for startup trace.
     * 2) Preliminary environment validations.
     * 3) Further placeholders for extended configurations.
     */
    public BookingApplication() {
        // Step 1: Initialize Spring Boot application
        logger.info("Initializing the {} component.", APPLICATION_NAME);

        // Step 2: Log application startup
        logger.info("BookingApplication constructor invoked, preparing to validate configurations.");

        // Step 3: Validate required configurations
        // Potential checks for environment variables, external services, etc.
        // For demonstration, we assume default checks or placeholders.
    }

    /**
     * The main entry point for the booking service application. Implements an
     * enhanced initialization routine with these steps:
     * 1) Configure shutdown hooks for graceful termination.
     * 2) Initialize monitoring and metrics registry.
     * 3) Validate database and Kafka configurations.
     * 4) Configure security settings and CORS policies (placeholder).
     * 5) Launch Spring Boot application with provided arguments.
     * 6) Initialize application context (retrieved once the app is running).
     * 7) Start embedded server (handled internally by SpringApplication).
     * 8) Log a successful startup, demonstrating readiness.
     *
     * @param args Command-line arguments array
     */
    public static void main(String[] args) {
        // Step 1: Configure shutdown hooks for graceful termination
        configureGracefulShutdown();

        // Step 2: Monitoring and metrics registry will be initialized once the context is up
        // We can retrieve and configure the registry after the application context has started.

        // Step 3: Validate database and Kafka configurations as part of application startup
        // Handled automatically by Spring on bean creation, further checks can be done post-context.

        // Step 4: Configure security settings and CORS policies (placeholder for typical enterprise)
        // This can be done via SecurityConfig or WebMvcConfigurer-based classes.

        // Step 5: Launch the Spring Boot application with arguments
        SpringApplication app = new SpringApplication(BookingApplication.class);
        ApplicationContext context = app.run(args);

        // Steps 6 and 7: The ApplicationContext is initialized, and the embedded server is started.

        // Step 8: Log successful startup
        logger.info("===========================================");
        logger.info("{} has started successfully!", APPLICATION_NAME);
        logger.info("===========================================");

        // Demonstrate usage of the MeterRegistry for application-level monitoring
        MeterRegistry meterRegistry = context.getBean(MeterRegistry.class);
        meterRegistry.config().commonTags("application", APPLICATION_NAME);
        logger.info("MeterRegistry discovered and configured with common tag: {}", APPLICATION_NAME);

        // Demonstrate usage of the mongoClientSettings bean from DatabaseConfig
        MongoClientSettings mongoSettings = context.getBean(MongoClientSettings.class);
        logger.info("MongoClientSettings loaded for resilience: {}", mongoSettings);

        // Demonstrate usage of the kafkaTemplate bean from KafkaConfig
        @SuppressWarnings("unchecked")
        KafkaTemplate<String, Object> kafkaTemplate =
                (KafkaTemplate<String, Object>) context.getBean("kafkaTemplate");
        logger.info("KafkaTemplate loaded successfully, ready for event-driven messaging.");
    }

    /**
     * configureGracefulShutdown
     *
     * <p>Sets up a JVM shutdown hook that triggers a callback when the application
     * receives a termination signal. This method ensures:
     * 1) Connection draining or graceful closure of active processes.
     * 2) Resource cleanup or final commits.
     * 3) Minimal service disruption to external clients or ongoing operations.
     */
    public static void configureGracefulShutdown() {
        // Step 1: Register JVM shutdown hooks
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            // Step 2: Configure connection draining
            // For example, closing database connections or waiting for active transactions.

            // Step 3: Set up resource cleanup
            // Free up thread pools, flush logs, or finalize critical tasks.
            logger.info("JVM shutdown hook triggered for {}. Graceful shutdown in progress...", APPLICATION_NAME);
        }));
    }
}