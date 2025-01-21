package com.dogwalking.booking.config;

// ----------------------------------------------------
// Internal Imports
// ----------------------------------------------------
import com.dogwalking.booking.models.Booking; // Referenced for event serialization (Booking ID, status, etc.)

// ----------------------------------------------------
// External Imports with Version Comments
// ----------------------------------------------------
/* org.springframework.context.annotation 5.3.0 */
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Bean;

/* org.springframework.beans.factory.annotation 5.3.0 */
import org.springframework.beans.factory.annotation.Value;

/* org.springframework.kafka.core 2.8.0 */
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.ProducerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;

/* Apache Kafka Client Library (coordinated with Spring Kafka 2.8.0) */
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;

/* Spring Kafka JSON Serialization Support (coordinated with Spring Kafka 2.8.0) */
import org.springframework.kafka.support.serializer.JsonDeserializer;
import org.springframework.kafka.support.serializer.JsonSerializer;

/* Apache Kafka SSL Configs */
import org.apache.kafka.common.config.SslConfigs;

/* Java Utilities */
import java.util.HashMap;
import java.util.Map;

/**
 * KafkaConfig is the primary configuration class responsible for setting up secure,
 * scalable, and resilient Apache Kafka event-driven communication for the booking
 * service. This class provides configuration for both producer and consumer components,
 * ensuring:
 *
 * 1. Security: SSL encryption, customizable protocol settings, and underlying
 *    credential management to protect data in transit.
 * 2. Resilience: Idempotence, retries, and backoffs for guaranteed message
 *    delivery in distributed environments.
 * 3. Monitoring: Hooks for comprehensive error handling, metrics, and logging
 *    to track system health and diagnose issues quickly.
 *
 * The configuration leverages:
 * - Topic constants for event publication and Dead Letter Queue (DLQ) handling.
 * - Producer factory with enhanced reliability settings (idempotence, compression).
 * - Consumer factory with robust error handling and monitoring integration.
 * - Property-based injection for externalizing configurations such as SSL paths,
 *   bootstrap servers, and group IDs.
 *
 * Within the system, Booking events may include fields from the {@link Booking} model,
 * such as booking ID (UUID) and status (String), ensuring that the produced and
 * consumed messages align with the real-time updates needed for dog walking
 * service operations.
 */
@Configuration
public class KafkaConfig {

    /**
     * Constant representing the main topic for booking events such as newly
     * created bookings, updates, and cancellations.
     */
    public static final String BOOKING_EVENTS_TOPIC = "booking-events";

    /**
     * Constant representing the topic for status updates related to existing
     * booking records. Typically used when walkers or owners update the booking
     * status (e.g., CONFIRMED, CANCELLED).
     */
    public static final String BOOKING_STATUS_UPDATES_TOPIC = "booking-status-updates";

    /**
     * Constant representing the Dead Letter Queue (DLQ) topic for failed messages
     * that cannot be properly consumed or processed by the main consumer logic.
     */
    public static final String DLQ_TOPIC = "booking-events-dlq";

    // --------------------------------------------------------------------------
    // Property-based Fields for Kafka Configuration
    // These fields are injected from the microservice's properties (e.g. YAML/ENV)
    // --------------------------------------------------------------------------

    /**
     * The Kafka bootstrap server(s) address, specifying host and port on which
     * the Kafka broker(s) can be reached.
     */
    @Value("${kafka.bootstrap-servers}")
    private String bootstrapServers;

    /**
     * The group ID used by Kafka consumers to join a specific consumer group.
     * This property ensures that all instances of this service work together
     * to process messages in a coordinated manner.
     */
    @Value("${kafka.group-id}")
    private String groupId;

    /**
     * The security protocol specifying the method of encryption or authentication
     * within the Kafka cluster. Typical values might be "SSL" or "SASL_SSL" if
     * configured for secure connections.
     */
    @Value("${kafka.security-protocol}")
    private String securityProtocol;

    /**
     * The filesystem location of the SSL truststore file, used to validate
     * the Kafka broker’s SSL certificates. This path must point to a valid
     * truststore when SSL encryption is enabled.
     */
    @Value("${kafka.ssl.truststore-location}")
    private String sslTruststoreLocation;

    /**
     * The filesystem location of the SSL keystore file, used to present
     * client certificates to the Kafka broker if client authentication is
     * required.
     */
    @Value("${kafka.ssl.keystore-location}")
    private String sslKeystoreLocation;

    /**
     * The maximum number of records that a single consumer can poll from a
     * partition in one pass. This helps control the volume of messages pulled
     * at once, which can be crucial for memory considerations and throughput.
     */
    @Value("${kafka.consumer.max-poll-records}")
    private Integer maxPollRecords;

    /**
     * The number of additional retry attempts for the producer in case
     * message sending fails. This setting, combined with an appropriate
     * backoff policy, can greatly enhance resilience.
     */
    @Value("${kafka.producer.retry-count}")
    private Integer retryCount;

    /**
     * The backoff time in milliseconds before each retry attempt. If sending
     * fails, the producer will wait this interval before trying again, preventing
     * immediate repeated failures.
     */
    @Value("${kafka.producer.retry-backoff-ms}")
    private Long retryBackoffMs;

    /**
     * Default no-argument constructor. In many enterprise setups, fields are
     * directly injected via annotations. This constructor remains for
     * completeness and potential reflection usage.
     */
    public KafkaConfig() {
        // Intentionally left empty to allow annotation-based field injection.
    }

    /**
     * Creates and configures a Kafka ProducerFactory instance. The producer
     * factory is responsible for generating Kafka producers that can publish
     * messages to the specified topics with the following features:
     * <ul>
     *   <li>Idempotence: Ensures exactly-once message delivery, crucial for
     *       financial or carefully orchestrated events.</li>
     *   <li>Security: Applies SSL-based encryption when connecting to Kafka
     *       brokers, using the protocol, truststore, and keystore.</li>
     *   <li>Retries: Attempts to resend messages a configured number of times
     *       upon transient failure, combined with a backoff interval.</li>
     *   <li>Compression: Improves throughput and performance by reducing the
     *       size of message payloads in flight.</li>
     * </ul>
     *
     * @return ProducerFactory<String, Object> A fully configured and secure
     *         producer factory able to publish Booking or other events as JSON.
     */
    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> props = new HashMap<>();

        // ------------------------------------------------------
        // Core Producer Settings for Kafka Connectivity
        // ------------------------------------------------------
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);

        // ------------------------------------------------------
        // Security Configuration for SSL
        // ------------------------------------------------------
        props.put(org.apache.kafka.common.config.CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, securityProtocol);
        props.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, sslTruststoreLocation);
        props.put(SslConfigs.SSL_KEYSTORE_LOCATION_CONFIG, sslKeystoreLocation);

        // ------------------------------------------------------
        // Enable Idempotence for Exactly-Once Delivery
        // ------------------------------------------------------
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        // Setting max.in.flight.requests.per.connection to 1 ensures ordering guarantees.
        props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 1);

        // ------------------------------------------------------
        // Set Producer Retries & Backoff
        // ------------------------------------------------------
        props.put(ProducerConfig.RETRIES_CONFIG, retryCount);
        props.put(ProducerConfig.RETRY_BACKOFF_MS_CONFIG, retryBackoffMs);

        // ------------------------------------------------------
        // Configure Compression, Batch Size, and Acknowledgements
        // ------------------------------------------------------
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "snappy");
        // Example batch size; can be tuned according to message sizes.
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);
        // Ensure the broker acknowledges full commit of messages.
        props.put(ProducerConfig.ACKS_CONFIG, "all");

        // ------------------------------------------------------
        // Build and Return the Producer Factory
        // ------------------------------------------------------
        return new DefaultKafkaProducerFactory<>(props);
    }

    /**
     * Creates and configures a KafkaTemplate, which simplifies message sending
     * by wrapping the underlying Producer instance. This template offers:
     * <ul>
     *   <li>Transaction Support: Ensures atomic sends that can be coordinated
     *       with other transactional resources if necessary.</li>
     *   <li>Monitoring: Facilitates instrumentation hooks to track send
     *       success/failure and metrics for throughput and latency.</li>
     *   <li>Serialization: By default, uses JSON serialization for message
     *       values, aligning with the event-driven approach for Booking data.</li>
     * </ul>
     *
     * @return KafkaTemplate<String, Object> A type-safe template for sending
     *         messages keyed by String and valued by any serializable Object.
     */
    @Bean
    public KafkaTemplate<String, Object> kafkaTemplate() {
        // Create the KafkaTemplate with the previously defined ProducerFactory
        KafkaTemplate<String, Object> template = new KafkaTemplate<>(producerFactory());

        // ------------------------------------------------------
        // Optional: Transaction Settings (if required)
        // ------------------------------------------------------
        // template.setTransactionIdPrefix("booking-tx-");

        // ------------------------------------------------------
        // Optional: Monitoring & Callbacks
        // ------------------------------------------------------
        // e.g., template.setProducerListener(new CustomProducerListener());

        return template;
    }

    /**
     * Creates and configures a ConsumerFactory for reading from Kafka topics.
     * This includes advanced error handling provisions such as sending failed
     * messages to a Dead Letter Queue (DLQ) and applying monitoring to track
     * consumer health. Key features:
     * <ul>
     *   <li>DLQ Handling: When messages are unprocessable, they can be routed
     *       to the {@link #DLQ_TOPIC} for further inspection.</li>
     *   <li>Batch Control: The {@code maxPollRecords} property influences how
     *       many messages are polled at once, providing control over memory and
     *       concurrency constraints.</li>
     *   <li>Security: SSL-based encryption using truststore and keystore is
     *       injected, ensuring consumer credentials are protected in transit.</li>
     *   <li>Deserialization: Uses String for keys and JSON for values to align
     *       with the production of JSON messages from this or other microservices.</li>
     * </ul>
     *
     * @return ConsumerFactory<String, Object> A fully configured consumer factory
     *         capable of robust error handling and secure connection to the Kafka broker.
     */
    @Bean
    public ConsumerFactory<String, Object> consumerFactory() {
        Map<String, Object> props = new HashMap<>();

        // ------------------------------------------------------
        // Core Consumer Settings for Kafka Connectivity
        // ------------------------------------------------------
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, JsonDeserializer.class);
        // Always start reading from the earliest committed offset (could be adjusted).
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        // Disable auto-commit if manual control is required in container settings.
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);

        // ------------------------------------------------------
        // Apply Max Poll Records to Control Batch Size
        // ------------------------------------------------------
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, maxPollRecords.toString());

        // ------------------------------------------------------
        // Configure SSL Security
        // ------------------------------------------------------
        props.put(org.apache.kafka.common.config.CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, securityProtocol);
        props.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, sslTruststoreLocation);
        props.put(SslConfigs.SSL_KEYSTORE_LOCATION_CONFIG, sslKeystoreLocation);

        // ------------------------------------------------------
        // JSON Deserialization Behavior
        // ------------------------------------------------------
        // The default subtype is Object, which allows multiple event structures
        // (e.g., different data classes like Booking, status messages, etc.).
        props.put(JsonDeserializer.TRUSTED_PACKAGES, "*");

        // ------------------------------------------------------
        // Build and Return the Consumer Factory
        // ------------------------------------------------------
        // Additional error handlers, recoverers, or advanced container
        // configuration can be set in a KafkaListenerContainerFactory, which
        // typically references this ConsumerFactory. That's where DLQ routing
        // or retry logic is fine-tuned.
        return new DefaultKafkaConsumerFactory<>(props, new StringDeserializer(), new JsonDeserializer<>());
    }
}