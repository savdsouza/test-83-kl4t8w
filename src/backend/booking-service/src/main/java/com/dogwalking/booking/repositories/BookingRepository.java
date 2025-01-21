package com.dogwalking.booking.repositories;

// --------------------------------------------------
// Internal Imports
// --------------------------------------------------
import com.dogwalking.booking.models.Booking; // Entity model for dog walking bookings

// --------------------------------------------------
// External Imports with Version Comments
// --------------------------------------------------
import org.springframework.data.mongodb.repository.MongoRepository; // version 3.1.0
import org.springframework.data.mongodb.repository.Query; // version 3.1.0
import java.util.UUID; // version 17
import java.util.Date; // version 17
import org.springframework.data.domain.Pageable; // version 3.1.0
import org.springframework.data.domain.Page; // version 3.1.0

/**
 * BookingRepository
 *
 * <p>This interface provides Spring Data MongoDB access to Booking entities, enabling
 * comprehensive CRUD and custom query operations. Leveraging time-based queries and
 * sharding-friendly indexing strategies, it ensures efficient data lookups for the
 * booking system, supporting real-time availability checks and schedule management.
 *
 * <p>Core Responsibilities:
 * <ul>
 *   <li>CRUD operations for booking documents.</li>
 *   <li>Custom queries for retrieving bookings by owner or walker.</li>
 *   <li>Detailed time-based queries to handle future or active bookings and status-based lookups.</li>
 *   <li>Integration with Paginated results for large data sets.</li>
 * </ul>
 *
 * <p>Refer to the technical specification for further details on data partitioning,
 * indexing, and performance optimization. This repository aligns with the architecture's
 * requirement to store walk records in MongoDB with efficient querying and time-based
 * sharding. The derived and custom query methods ensure high-performance data access
 * and meet the real-time booking system's needs.
 */
public interface BookingRepository extends MongoRepository<Booking, UUID> {

    /**
     * Retrieves all bookings belonging to a specific owner, returned as a paginated
     * result. Supports efficient lookups by ownerId and leverages any relevant MongoDB
     * indexes for optimized query performance.
     *
     * Steps:
     * <ol>
     *   <li>Validate the ownerId parameter.</li>
     *   <li>Apply pagination via the provided Pageable object.</li>
     *   <li>Query MongoDB documents where the field 'ownerId' matches the given UUID.</li>
     *   <li>Return a {@code Page<Booking>} containing the results.</li>
     * </ol>
     *
     * @param ownerId  the unique owner identifier (UUID) for which bookings are requested
     * @param pageable the paging parameters for the query
     * @return a paginated list of bookings that match the ownerId
     */
    Page<Booking> findByOwnerId(UUID ownerId, Pageable pageable);

    /**
     * Retrieves all future bookings for a particular walker that match a specified
     * booking status and occur after a given start time. Returned as a paginated result
     * to handle potentially large data sets efficiently.
     *
     * Steps:
     * <ol>
     *   <li>Validate walkerId, status, and startTime.</li>
     *   <li>Apply pagination via the provided Pageable object.</li>
     *   <li>Query MongoDB using a compound condition where 'walkerId' and 'status' match,
     *       and 'startTime' is strictly greater than the specified date.</li>
     *   <li>Return a {@code Page<Booking>} containing all matching future bookings.</li>
     * </ol>
     *
     * @param walkerId  the unique walker identifier (UUID)
     * @param status    the booking status to match (e.g., "CONFIRMED")
     * @param startTime the date from which future bookings should be retrieved
     * @param pageable  the paging parameters for the query
     * @return a paginated list of future bookings for the specified walker and status
     */
    @Query("{ 'walkerId': ?0, 'status': ?1, 'startTime': { '$gt': ?2 } }")
    Page<Booking> findByWalkerIdAndStatusAndStartTimeAfter(UUID walkerId, String status, Date startTime, Pageable pageable);

    /**
     * Finds all bookings of a given status within a specified startTime range, returned
     * as a paginated result. Intended for time-based data filtering, enabling easy
     * retrieval of bookings in a certain window for analytics or operational needs.
     *
     * Steps:
     * <ol>
     *   <li>Validate the status, startDate, and endDate parameters.</li>
     *   <li>Apply pagination via the provided Pageable object.</li>
     *   <li>Query MongoDB using a compound condition matching the 'status', and ensuring
     *       the 'startTime' is between startDate (inclusive) and endDate (inclusive).</li>
     *   <li>Return a {@code Page<Booking>} containing the results.</li>
     * </ol>
     *
     * @param status    the booking status to filter by (e.g., "COMPLETED")
     * @param startDate the start of the time range (inclusive)
     * @param endDate   the end of the time range (inclusive)
     * @param pageable  the paging parameters for query results
     * @return a paginated list of bookings matching the status within the given range
     */
    @Query("{ 'status': ?0, 'startTime': { '$gte': ?1, '$lte': ?2 } }")
    Page<Booking> findByStatusAndStartTimeBetween(String status, Date startDate, Date endDate, Pageable pageable);

}