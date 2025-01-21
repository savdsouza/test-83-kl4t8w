package com.dogwalking.booking.config;

// -----------------------------------------------------------------------------
// External Imports with explicit version comments for clarity
// -----------------------------------------------------------------------------
import org.springframework.context.annotation.Configuration; // version 6.0.0
import org.springframework.context.annotation.Bean; // version 6.0.0
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories; // version 3.1.0
import org.springframework.boot.autoconfigure.mongo.MongoProperties; // version 3.1.0
import org.springframework.data.mongodb.core.convert.MongoCustomConversions; // version 3.1.0
import org.springframework.data.mongodb.core.MongoTemplate; // version 3.1.0
import org.springframework.context.ApplicationListener; // version 6.0.0
import org.springframework.context.event.ContextRefreshedEvent; // version 6.0.0

import com.mongodb.MongoClientSettings; // version 4.9.0
import com.mongodb.connection.ConnectionPoolSettings; // version 4.9.0

// Converters for custom UUID handling within MongoDB
import org.springframework.core.convert.converter.Converter; // version 6.0.0
import org.springframework.data.convert.ReadingConverter; // version 3.1.0
import org.springframework.data.convert.WritingConverter; // version 3.1.0

import org.springframework.data.mongodb.core.index.Index; // version 3.1.0
import org.springframework.data.mongodb.core.index.IndexOperations; // version 3.1.0
import org.springframework.data.mongodb.core.query.Sort; // version 3.1.0

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

// -----------------------------------------------------------------------------
// Configuration and Repository Enabling Annotations
// -----------------------------------------------------------------------------

/**
 * DatabaseConfig
 *
 * <p>An enterprise-grade configuration class for MongoDB database settings
 * in the Booking Service. Includes optimized connection pool settings,
 * custom type conversions, and indexing strategies to handle
 * the high-load demands of dog walking bookings.
 */
@Configuration // Marks this class as a Spring configuration
@EnableMongoRepositories(basePackages = "com.dogwalking.booking.repositories") // Enables MongoDB repositories
public class DatabaseConfig {

    /**
     * MongoDB properties automatically mapped from application configuration
     * (e.g., application.yml or application.properties). These properties
     * include connection URI, database name, and other relevant settings.
     */
    private final MongoProperties mongoProperties;

    /**
     * Primary constructor that initializes the DatabaseConfig with
     * MongoDB-specific properties provided by Spring Boot. Ensures that
     * all required properties (e.g., host, port, database) are available.
     *
     * @param mongoProperties the injected MongoDB configuration properties
     */
    public DatabaseConfig(MongoProperties mongoProperties) {
        // Validate and set up the provided MongoDB properties.
        // In a production environment, additional checks or validations
        // can be applied here to ensure consistency and security.
        this.mongoProperties = mongoProperties;
    }

    /**
     * mongoClientSettings
     *
     * <p>Bean definition that creates and configures a {@link MongoClientSettings}
     * object with optimized connection pooling parameters for simultaneous,
     * high-volume booking requests. This method ensures the booking service
     * can handle a large number of open connections while maintaining good
     * performance and responsiveness.
     *
     * @return A fully built {@link MongoClientSettings} instance with
     *         optimized connection pool configuration for MongoDB
     */
    @Bean
    public MongoClientSettings mongoClientSettings() {
        // Build connection pool settings for high concurrency
        ConnectionPoolSettings connectionPoolSettings = ConnectionPoolSettings.builder()
                // Maximum number of connections in the pool (tunable per environment)
                .maxSize(50)
                // Minimum number of idle connections the pool will maintain
                .minSize(5)
                // Time to wait for a connection before timing out
                .maxWaitTime(5000, TimeUnit.MILLISECONDS)
                // Maximum time a connection can live in the pool
                .maxConnectionLifeTime(30000, TimeUnit.MILLISECONDS)
                .build();

        // Construct the final MongoClientSettings using the connection pool settings
        // and additional cluster settings such as server selection timeout.
        return MongoClientSettings.builder()
                .applyConnectionString(mongoProperties.getUri() != null
                        ? new com.mongodb.ConnectionString(mongoProperties.getUri())
                        : new com.mongodb.ConnectionString("mongodb://localhost:27017"))
                .applyToConnectionPoolSettings(builder -> builder.applySettings(connectionPoolSettings))
                .applyToClusterSettings(builder ->
                        // Server selection timeout ensures queries fail fast if MongoDB instances are unreachable
                        builder.serverSelectionTimeout(10000, TimeUnit.MILLISECONDS)
                )
                .build();
    }

    /**
     * customConversions
     *
     * <p>Bean definition for custom conversions between Java types and
     * MongoDB-native types. Specifically includes converters for handling
     * {@link UUID} as a string field within the MongoDB documents, ensuring
     * easy retrieval and storage without losing fidelity.
     *
     * @return A {@link MongoCustomConversions} object that holds the list of
     *         registered converters for the booking service.
     */
    @Bean
    public MongoCustomConversions customConversions() {
        List<Converter<?, ?>> converters = new ArrayList<>();
        // Converter for writing Java UUID to MongoDB String
        converters.add(new UuidToStringConverter());
        // Converter for reading MongoDB String to Java UUID
        converters.add(new StringToUuidConverter());
        return new MongoCustomConversions(converters);
    }

    /**
     * ensureIndexes
     *
     * <p>Defines and creates MongoDB indexes for critical Booking domain documents.
     * Ensuring indexes help accelerate queries that filter or sort by fields
     * commonly used in booking searches (e.g., ownerId, walkerId, status).
     *
     * @param mongoTemplate the {@link MongoTemplate} used for index operations
     * @return An ApplicationListener that triggers index creation after
     *         the application context is fully initialized.
     */
    @Bean
    public ApplicationListener<ContextRefreshedEvent> ensureIndexes(MongoTemplate mongoTemplate) {
        return event -> {
            // Index operations for booking collection
            // This assumes a domain class "BookingDocument" in the package "com.dogwalking.booking.models"
            IndexOperations bookingIndexOps
                    = mongoTemplate.indexOps("BookingDocument");

            // Index on ownerId (ascending)
            bookingIndexOps.ensureIndex(
                    new Index().on("ownerId", Sort.Direction.ASC).background()
            );

            // Index on walkerId (ascending)
            bookingIndexOps.ensureIndex(
                    new Index().on("walkerId", Sort.Direction.ASC).background()
            );

            // Index on status (ascending)
            bookingIndexOps.ensureIndex(
                    new Index().on("status", Sort.Direction.ASC).background()
            );

            // Index on startTime (ascending) for queries sorting or filtering by walk start times
            bookingIndexOps.ensureIndex(
                    new Index().on("startTime", Sort.Direction.ASC).background()
            );
        };
    }

    // -----------------------------------------------------------------------------
    // Inner converter classes to handle UUID <-> String conversions
    // -----------------------------------------------------------------------------

    /**
     * UuidToStringConverter
     *
     * <p>Writes a UUID object to a plain string for storage in MongoDB fields.
     */
    @WritingConverter
    public static class UuidToStringConverter implements Converter<UUID, String> {
        @Override
        public String convert(UUID source) {
            return (source == null) ? null : source.toString();
        }
    }

    /**
     * StringToUuidConverter
     *
     * <p>Reads a string from MongoDB documents and converts it back to a UUID.
     */
    @ReadingConverter
    public static class StringToUuidConverter implements Converter<String, UUID> {
        @Override
        public UUID convert(String source) {
            return (source == null) ? null : UUID.fromString(source);
        }
    }
}