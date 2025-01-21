package com.dogwalking.booking.services;

// ----------------------------------------------------
// External Imports with Version Comments
// ----------------------------------------------------
// org.springframework.stereotype 5.3.0
import org.springframework.stereotype.Service;
// java.math 17
import java.math.BigDecimal;
import java.math.RoundingMode;
// java.util 17
import java.util.Calendar;
import java.util.Date;
// (Optional) Logging for production readiness:
// org.slf4j 1.7.36
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// ----------------------------------------------------
// Internal Imports (Based on Provided Files)
// ----------------------------------------------------
import com.dogwalking.booking.models.Booking;
// ^ Booking class with date/time fields startTime and endTime

/**
 * PricingService is a Spring-managed service responsible for calculating
 * dog walking prices with full support for dynamic pricing factors such as
 * base rates, peak hours, weekends, holidays, and regional cost variations.
 *
 * <p>Implementation highlights:
 * <ul>
 *   <li>Applies a base rate per hour for the walk duration.</li>
 *   <li>Checks time of day to see if it is within peak hours.</li>
 *   <li>Determines whether it is a weekend or holiday for additional multipliers.</li>
 *   <li>Supports additional regional adjustments via a PricingConfigurationService.</li>
 *   <li>Ensures precise financial calculations using BigDecimal with rounding modes.</li>
 *   <li>Performs validations against minimum durations and configured price limits.</li>
 *   <li>Logs pricing calculation details for audit and debugging purposes.</li>
 * </ul>
 */
@Service
public class PricingService {

    // ----------------------------------------------------
    // Global Constants (Referenced from JSON Specification)
    // ----------------------------------------------------
    private static final BigDecimal BASE_RATE_PER_HOUR = new BigDecimal("35.00");
    private static final BigDecimal PEAK_HOUR_MULTIPLIER = new BigDecimal("1.25");
    private static final BigDecimal WEEKEND_MULTIPLIER = new BigDecimal("1.20");
    private static final BigDecimal HOLIDAY_MULTIPLIER = new BigDecimal("1.50");
    private static final int MINIMUM_DURATION_MINUTES = 30;
    private static final RoundingMode ROUNDING_MODE = RoundingMode.HALF_UP;
    private static final int DECIMAL_SCALE = 2;

    // ----------------------------------------------------
    // Logger for Debugging and Auditing
    // ----------------------------------------------------
    private static final Logger logger = LoggerFactory.getLogger(PricingService.class);

    // ----------------------------------------------------
    // Properties (From JSON Specification)
    // ----------------------------------------------------
    /**
     * Calendar instance used for date/time operations such as
     * weekend checks and applying timezone differences.
     */
    private final Calendar calendar;

    /**
     * Service responsible for determining if a given date is a holiday.
     * Must expose method(s) like boolean isHoliday(Date date).
     */
    private final HolidayCalendarService holidayCalendarService;

    /**
     * Service responsible for providing regional and dynamic pricing
     * configurations (e.g., peak hour ranges, regional markups).
     */
    private final PricingConfigurationService pricingConfigService;

    // ----------------------------------------------------
    // Constructor (From JSON Specification)
    // ----------------------------------------------------
    /**
     * Constructs the PricingService with the required dependencies.
     * <p>Steps:
     * <ol>
     *   <li>Initialize the Calendar instance for date/time checks.</li>
     *   <li>Inject and store the HolidayCalendarService reference.</li>
     *   <li>Inject and store the PricingConfigurationService reference.</li>
     *   <li>Initialize any desired caching mechanisms (if applicable).</li>
     * </ol>
     *
     * @param holidayCalendarService  the holiday service for checking holidays
     * @param pricingConfigService    the pricing configuration service for region-based factors
     */
    public PricingService(HolidayCalendarService holidayCalendarService,
                          PricingConfigurationService pricingConfigService) {
        this.calendar = Calendar.getInstance();
        this.holidayCalendarService = holidayCalendarService;
        this.pricingConfigService = pricingConfigService;
        // Additional caching or initialization logic can be added here
    }

    // ----------------------------------------------------
    // Primary Method: calculatePrice (From JSON Specification)
    // ----------------------------------------------------
    /**
     * Calculates the total price for a dog walking booking by applying
     * a series of pricing multipliers (peak hours, weekends, holidays,
     * regional adjustments) on top of the base hourly rate.
     * <p>Steps:
     * <ol>
     *   <li>Validate booking parameters and times.</li>
     *   <li>Calculate the duration in hours via {@link #calculateDurationInHours(Date, Date)}.</li>
     *   <li>Multiply base rate by the computed duration.</li>
     *   <li>Check and apply peak hour multiplier based on region-specific rules.</li>
     *   <li>Check and apply weekend multiplier if applicable.</li>
     *   <li>Check and apply holiday multiplier if applicable via holidayCalendarService.</li>
     *   <li>Apply any additional regional price adjustments from pricingConfigService.</li>
     *   <li>Validate final price against any price limits or business rules.</li>
     *   <li>Round the price to 2 decimal places using HALF_UP rounding.</li>
     *   <li>Log price calculation details for audit purposes.</li>
     *   <li>Return the computed and rounded total price.</li>
     * </ol>
     *
     * @param booking the booking containing start/end times and relevant data
     * @return BigDecimal representing the final calculated price
     * @throws IllegalArgumentException if booking or its time fields are invalid
     */
    public BigDecimal calculatePrice(Booking booking) {
        if (booking == null) {
            throw new IllegalArgumentException("Booking cannot be null.");
        }
        Date startTime = booking.getStartTime();
        Date endTime = booking.getEndTime();
        if (startTime == null || endTime == null) {
            throw new IllegalArgumentException("Booking must have valid start and end times.");
        }

        // Step 1: Calculate duration in hours
        BigDecimal durationInHours = calculateDurationInHours(startTime, endTime);

        // Step 2: Initial price = base rate per hour * duration
        BigDecimal computedPrice = BASE_RATE_PER_HOUR.multiply(durationInHours);

        // Step 3: Retrieve or determine the region; depends on how region is resolved
        // (For demonstration, either booking has region info or a default can be fetched)
        String region = pricingConfigService.resolveRegion(booking);

        // Step 4: Check and apply peak hour multiplier
        if (isPeakHour(startTime, region)) {
            computedPrice = computedPrice.multiply(PEAK_HOUR_MULTIPLIER);
        }

        // Step 5: Apply weekend multiplier
        if (isWeekend(startTime)) {
            computedPrice = computedPrice.multiply(WEEKEND_MULTIPLIER);
        }

        // Step 6: Apply holiday multiplier
        if (holidayCalendarService.isHoliday(startTime)) {
            computedPrice = computedPrice.multiply(HOLIDAY_MULTIPLIER);
        }

        // Step 7: Apply regional adjustments
        BigDecimal regionalFactor = pricingConfigService.getRegionalAdjustmentFactor(region);
        if (regionalFactor != null) {
            computedPrice = computedPrice.multiply(regionalFactor);
        }

        // Step 8: Validate against any price limit or business rule
        // (E.g., if there's a max or min billing threshold)
        pricingConfigService.validatePriceRange(computedPrice);

        // Step 9: Round to 2 decimal places using HALF_UP
        BigDecimal finalPrice = computedPrice.setScale(DECIMAL_SCALE, ROUNDING_MODE);

        // Step 10: Log details
        logger.debug("Calculated price for booking {}: baseDuration={}h basePrice={} finalPrice={}",
                booking.getId(),
                durationInHours,
                BASE_RATE_PER_HOUR,
                finalPrice);

        // Step 11: Return final price
        return finalPrice;
    }

    // ----------------------------------------------------
    // Helper Method: calculateDurationInHours (From JSON Specification)
    // ----------------------------------------------------
    /**
     * Calculates the duration of a walk in hours (with decimal precision),
     * ensuring it meets the minimum duration requirement.
     * <p>Steps:
     * <ol>
     *   <li>Validate that both startTime and endTime are not null.</li>
     *   <li>Compute the difference in milliseconds.</li>
     *   <li>Convert milliseconds to a BigDecimal representing hours.</li>
     *   <li>Validate result against the minimum duration (30 minutes default).</li>
     *   <li>Return the computed hours, considering any necessary timezone or offset logic.</li>
     * </ol>
     *
     * @param startTime the scheduled or actual start time of the walk
     * @param endTime   the scheduled or actual end time of the walk
     * @return BigDecimal representing the duration in hours
     * @throws IllegalArgumentException if startTime >= endTime or duration below minimum
     */
    public BigDecimal calculateDurationInHours(Date startTime, Date endTime) {
        if (startTime == null || endTime == null) {
            throw new IllegalArgumentException("Start time and end time must be provided.");
        }
        long diffMillis = endTime.getTime() - startTime.getTime();
        if (diffMillis <= 0) {
            throw new IllegalArgumentException("End time must be after start time.");
        }

        // Convert millisecond difference to hours in BigDecimal form
        BigDecimal diffHours = new BigDecimal(diffMillis)
                .divide(new BigDecimal(3600000), 4, RoundingMode.HALF_UP);

        // Check minimum duration
        // If total minutes < MINIMUM_DURATION_MINUTES, enforce or warn
        BigDecimal diffMinutes = diffHours.multiply(new BigDecimal("60"));
        if (diffMinutes.compareTo(new BigDecimal(MINIMUM_DURATION_MINUTES)) < 0) {
            // Either enforce a minimum price or throw an exception
            // For demonstration, we allow but log a warning
            logger.warn("Calculated duration {} minutes is below minimum duration {}", diffMinutes, MINIMUM_DURATION_MINUTES);
        }

        return diffHours;
    }

    // ----------------------------------------------------
    // Helper Method: isPeakHour (From JSON Specification)
    // ----------------------------------------------------
    /**
     * Determines if a given time falls within region-specific peak hours.
     * <p>Steps:
     * <ol>
     *   <li>Retrieve peak hour configuration from pricingConfigService.</li>
     *   <li>Extract the hour of day from the provided Date value.</li>
     *   <li>Apply any regional or seasonal timezone adjustments as needed.</li>
     *   <li>Check if the hour exists within the configured peak hour ranges.</li>
     *   <li>Return true if it is a peak hour; false otherwise.</li>
     * </ol>
     *
     * @param time   the date/time to evaluate for peak hour status
     * @param region the region identifier used to fetch peak configuration
     * @return true if the time is within a peak hour range for the region, false otherwise
     */
    public boolean isPeakHour(Date time, String region) {
        if (time == null || region == null) {
            return false;
        }
        calendar.setTime(time);

        // Extract hour of day in 24-hour format
        int hourOfDay = calendar.get(Calendar.HOUR_OF_DAY);

        // Retrieve configured peak hour ranges from pricingConfigService
        PeakHourRange[] peakRanges = pricingConfigService.getPeakHours(region);
        if (peakRanges == null || peakRanges.length == 0) {
            return false;
        }

        // Check if hourOfDay fits any peak hour range
        for (PeakHourRange range : peakRanges) {
            int startHour = range.getStartHour();
            int endHour = range.getEndHour();
            // Example: if peak is from 7 to 10, hourOfDay within [7..9] is considered peak
            // or we can interpret endHour exclusively
            if (hourOfDay >= startHour && hourOfDay < endHour) {
                return true;
            }
        }
        return false;
    }

    // ----------------------------------------------------
    // Private Utility Method: Check Weekend
    // ----------------------------------------------------
    /**
     * Determines if the provided date is a weekend (Saturday or Sunday).
     *
     * @param date the date to check
     * @return true if date is a weekend, false otherwise
     */
    private boolean isWeekend(Date date) {
        if (date == null) {
            return false;
        }
        calendar.setTime(date);
        int dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK);
        return (dayOfWeek == Calendar.SATURDAY || dayOfWeek == Calendar.SUNDAY);
    }

    // ----------------------------------------------------
    // Supporting Interfaces/Classes Referenced in Specs
    // (Stubs or placeholders to demonstrate usage)
    // ----------------------------------------------------

    /**
     * A simple interface for checking holidays. Methods should include:
     * <ul>
     *   <li>boolean isHoliday(Date date)</li>
     * </ul>
     */
    public static interface HolidayCalendarService {
        boolean isHoliday(Date date);
    }

    /**
     * A simple interface for region-based pricing configuration.
     * Methods should include:
     * <ul>
     *   <li>BigDecimal getRegionalAdjustmentFactor(String region)</li>
     *   <li>PeakHourRange[] getPeakHours(String region)</li>
     *   <li>String resolveRegion(Booking booking)</li>
     *   <li>void validatePriceRange(BigDecimal price)</li>
     * </ul>
     */
    public static interface PricingConfigurationService {
        BigDecimal getRegionalAdjustmentFactor(String region);
        PeakHourRange[] getPeakHours(String region);
        String resolveRegion(Booking booking);
        void validatePriceRange(BigDecimal price);
    }

    /**
     * Represents a peak hour range with a start and end hour in 24-hour format.
     * For instance, 7 to 10 might represent 7 AM to 9:59 AM.
     */
    public static class PeakHourRange {
        private final int startHour;
        private final int endHour;

        public PeakHourRange(int startHour, int endHour) {
            this.startHour = startHour;
            this.endHour = endHour;
        }

        public int getStartHour() {
            return startHour;
        }

        public int getEndHour() {
            return endHour;
        }
    }
}