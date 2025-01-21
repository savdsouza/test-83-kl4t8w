import Foundation // iOS 13.0+
/*
  ------------------------------------------------------------------------------
  FILE DESCRIPTION:
  This file extends the Swift Date class with specialized methods for the
  DogWalking application. These methods address scheduling logic, formatted
  output for UI, operating hours checks, walk duration calculation, and
  ensuring that time intervals meet the dog walking domain requirements.

  INTERNAL IMPORTS:
  - References "MapConstants.LOCATION_UPDATE_INTERVAL" from the internal file
    "src/ios/DogWalking/Core/Constants/AppConstants.swift".
    This constant is used to validate location update intervals for
    time-sensitive operations.

  EXTERNAL IMPORTS:
  - Foundation (iOS 13.0+): Provides Date, TimeZone, Locale, and DateFormatter
    functionalities used extensively throughout this extension.

  ------------------------------------------------------------------------------
*/

/**
 Extension providing dog-walking-specific functionality for the Date type,
 exposing methods necessary to handle real-time booking availability checks,
 scheduling constraints, domain-specific date/time formatting, and more.
 This extension is designed with an enterprise-level coding approach: it uses
 robust error-checking, thorough documentation, and well-commented logic to
 support reliability in a production environment.
 */
public extension Date {
    // MARK: - 1) Check if a Date is Available for Booking

    /**
     Determines if the current Date instance is viable for creating a new walk
     booking. A date is considered available if:

       1. It is strictly in the future (cannot book a same-moment or past time).
       2. It respects the specified minimum notice period.
       3. It falls within defined operating hours.
       4. No existing bookings conflict with this time.
       5. It aligns with any regional or location-based availability rules.

     - Parameter minimumNotice: The minimum time interval (in seconds) that must
       elapse from the current moment (now) until this date, to accommodate
       short-notice bookings and operational overhead.
     - Returns: A Boolean indicating whether this date is available for booking.
     */
    func isAvailableForBooking(minimumNotice: TimeInterval) -> Bool {
        // STEP 1: Check if date is in the future (no same–moment or past bookings).
        //         The walk must start strictly after the current time to be valid.
        if self <= Date() {
            return false
        }

        // STEP 2: Verify that the date respects the minimum lead time (notice period).
        //         This ensures that a booking cannot be made too soon, giving the
        //         walker/owner adequate buffer to prepare.
        let earliestAllowedStart = Date().addingTimeInterval(minimumNotice)
        if self < earliestAllowedStart {
            return false
        }

        // STEP 3: Validate that this date does not fall outside standard operating hours.
        //         If the business is closed, or the date is outside the recognized window,
        //         we cannot allow a walk booking.
        if !isWithinOperatingHours() {
            return false
        }

        // STEP 4: Check for any existing booking conflicts.
        //         In a real implementation, this might query a data source to see if a
        //         walk is already scheduled for this date/time, or if the walker is busy.
        if isDateBooked(self) {
            return false
        }

        // STEP 5: Apply any additional regional availability rules, such as holidays,
        //         local laws about dog-walking times, special closures, etc.
        if !isRegionallyAvailable(self) {
            return false
        }

        // If all checks pass, the date is considered available for booking.
        return true
    }

    /**
     Private helper function that simulates a check against existing bookings.
     A typical production implementation would query a persistent store or API.
     - Parameter date: The date to check for conflicts.
     - Returns: A Boolean indicating whether this date is already booked.
     */
    private func isDateBooked(_ date: Date) -> Bool {
        // For demonstration purposes, assume no existing bookings conflict.
        // In a real system, you'd query a BookingService, local DB, or remote API.
        return false
    }

    /**
     Private helper function that simulates the evaluation of region-specific
     rules for booking availability. These could include local ordinances,
     special events, or holiday restrictions that are location-based.
     - Parameter date: The date to validate against regional constraints.
     - Returns: A Boolean indicating whether regional rules permit booking.
     */
    private func isRegionallyAvailable(_ date: Date) -> Bool {
        // For demonstration, all regions are assumed open/available.
        // Implement region-specific checks here if applicable.
        return true
    }

    // MARK: - 2) Format the Date for Walk Time Display

    /**
     Generates a locale- and timezone-appropriate string representing the
     Date instance, intended for usage in walk-related UI elements, such
     as booking confirmations or active walk screens.

     This method:
       1. Applies optional user-specified locale for regional formatting nuances.
       2. Converts to an optional specified time zone if provided, else uses
          the system or device setting.
       3. Chooses a medium date style with a short time style for clarity in displays.
       4. Automatically handles daylight saving transitions if the parameter
          `timeZone` observes DST.

     - Parameters:
       - timeZone: The desired timezone context. Defaults to `nil`, meaning
                   the system timezone is used.
       - locale: The desired locale context for date formatting. Defaults to
                 `nil`, meaning the system locale is used.
     - Returns: A string containing the formatted date/time intended for
                display in the dog walking application.
     */
    func formattedWalkTime(timeZone: TimeZone? = nil,
                           locale: Locale? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        if let tz = timeZone {
            dateFormatter.timeZone = tz
        }
        if let loc = locale {
            dateFormatter.locale = loc
        }

        return dateFormatter.string(from: self)
    }

    // MARK: - 3) Calculate Time Elapsed since Last Update

    /**
     Calculates the time interval (in seconds) since a given last update time.
     This method can be crucial for verifying how frequently location updates,
     status updates, or other real-time data refreshes are occurring.

     Steps:
       1. Compute the absolute time difference between `self` and `lastUpdateTime`.
       2. While time zones do not directly affect the raw difference in seconds,
          acknowledge that bridging from absolute time to localized displays
          may require further adjustment in downstream usage.
       3. Validate this difference against `MapConstants.LOCATION_UPDATE_INTERVAL`
          if you wish to impose constraints on how quickly subsequent updates occur.
       4. For a neater integer-like value, the result is rounded to the nearest
          whole second.

     - Parameter lastUpdateTime: The date/time stamp of the previous update event.
     - Returns: A TimeInterval representing the number of seconds between the
                last update time and this date, rounded to a whole number.
     */
    func timeIntervalSinceLastUpdate(lastUpdateTime: Date) -> TimeInterval {
        // STEP 1: Pure difference in absolute time (in seconds).
        let difference = self.timeIntervalSince(lastUpdateTime)

        // STEP 2: Note on time zone transitions. Even if the device timezone changes,
        //         the raw difference in seconds remains the same. Additional
        //         adjustments for displaying time could be performed as needed.
        //         Here, we simply compute the absolute difference.

        // STEP 3: Validate or compare with MapConstants.LOCATION_UPDATE_INTERVAL.
        //         Example usage: you might check if difference < LOCATION_UPDATE_INTERVAL
        //         to see if an update is happening too soon.
        //         if difference < MapConstants.LOCATION_UPDATE_INTERVAL { ... }

        // STEP 4: Apply a simple rounding operation for clarity.
        let intervalRounded = difference.rounded()

        return intervalRounded
    }

    // MARK: - 4) Check if a Date falls within Operating Hours

    /**
     Determines whether the current Date instance is within the recognized
     business operating hours for dog walking. Includes logic to handle
     region-specific holidays or special closures if needed.

     Steps:
       1. Retrieve the local start of the walking day (e.g., 8:00 AM).
       2. Retrieve the local end of the walking day (e.g., 8:00 PM).
       3. Confirm the date/time is after the start but before the end.
       4. Exclude holidays or special closure days, if any apply.
       5. Return a Boolean reflecting whether the time is permissible for walks.

     - Returns: A Boolean indicating if this date/time is within established
                business hours (not on a holiday or outside operating windows).
     */
    func isWithinOperatingHours() -> Bool {
        let start = startOfWalkingDay()
        let end = endOfWalkingDay()

        // Must fall between start and end time inclusively.
        guard self >= start, self <= end else {
            return false
        }

        // Check additional holiday or special closure logic here.
        // If a holiday is detected, return false. For demonstration,
        // assume no holiday applies.
        if isHoliday(self) {
            return false
        }

        // If none of the constraints are violated, the date is valid.
        return true
    }

    /**
     Private helper that determines if a given date is a recognized holiday.
     In production, this might consult a holiday calendar or external system.
     - Parameter date: The date/time to check against known holidays.
     - Returns: A Boolean indicating whether it is a holiday.
     */
    private func isHoliday(_ date: Date) -> Bool {
        // For demonstration, assume no recognized holidays block dog walking.
        return false
    }

    // MARK: - 5) Format the Date for Booking Display

    /**
     Formats the current Date instance as a booking date, typically used
     in contexts where only the full date is required (e.g., "October 15, 2023")
     without the time of day. Respects optional time zone and locale inputs.

     - Parameters:
       - timeZone: An optional TimeZone for specification if different from system.
       - locale: An optional Locale for language, region, or scripting preferences.
     - Returns: A String representing the booking date in a more descriptive,
                long format.
     */
    func formattedBookingDate(timeZone: TimeZone? = nil,
                              locale: Locale? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none

        if let tz = timeZone {
            formatter.timeZone = tz
        }
        if let loc = locale {
            formatter.locale = loc
        }

        return formatter.string(from: self)
    }

    // MARK: - 6) Add a Walk Duration to a Date

    /**
     Adds a specified duration (in seconds) to the current Date instance,
     returning a new Date that can be used to represent the end time of
     a dog walking session. This method is particularly useful for scheduling
     logic and records.

     - Parameter duration: The TimeInterval (in seconds) to add to the date.
     - Returns: A new Date instance offset by the specified duration.
     */
    func addWalkDuration(_ duration: TimeInterval) -> Date {
        return self.addingTimeInterval(duration)
    }

    // MARK: - 7) Retrieve the Start of the Walking Day

    /**
     Calculates the start of the walking day for the given Date, typically
     setting the time to 8:00 AM local time. This function helps define the
     earliest point at which dog walkers can begin their daily operations,
     ensuring consistency in scheduling logic.

     - Returns: A Date instance representing the start of the dog walking day.
     */
    func startOfWalkingDay() -> Date {
        var calendar = Calendar.current
        // For precise local scheduling, you can explicitly set:
        // calendar.timeZone = TimeZone.current
        // if you need to enforce a particular region/time zone.

        // Example: 8:00 AM local time
        if let dayStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: self) {
            return dayStart
        }
        // If date creation fails, return self as a fallback. This scenario is rare.
        return self
    }

    // MARK: - 8) Retrieve the End of the Walking Day

    /**
     Calculates the end of the walking day for the given Date, typically
     setting the time to 8:00 PM local time. This function helps define the
     latest point at which dog walking services can be offered, establishing
     consistent constraints across the system.

     - Returns: A Date instance representing the end of the dog walking day.
     */
    func endOfWalkingDay() -> Date {
        var calendar = Calendar.current
        // As above, you could explicitly set:
        // calendar.timeZone = TimeZone.current
        // for region-specific scheduling.

        // Example: 8:00 PM local time
        if let dayEnd = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: self) {
            return dayEnd
        }
        // If date creation fails, return self as a fallback.
        return self
    }
}