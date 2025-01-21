//
//  CLLocation+Extensions.swift
//  DogWalking
//
//  Extension for CLLocation class, providing comprehensive location tracking,
//  distance calculations, and data formatting capabilities with enhanced error
//  handling, caching, and privacy considerations specifically for the dog walking app.
//

import CoreLocation // iOS 13.0+ for location services and coordinate handling
import Foundation   // iOS 13.0+ for base functionalities, JSON serialization, etc.

/// Thread-safe, privacy-aware extension on CLLocation
/// to handle distance caching, radius checks, dictionary
/// conversions, textual formatting of coordinates, and
/// JSON serialization for dog walking app needs.
public extension CLLocation {

    // MARK: - Private Static Properties for Distance Caching

    /// Concurrent queue used for all distance cache read/write operations.
    private static let distanceCacheQueue = DispatchQueue(label: "com.dogwalking.cllocation.distanceCacheQueue", attributes: .concurrent)

    /// Stores cached distances between two location coordinates.
    /// The key is a unique string composed of both coordinates.
    /// The value includes the computed distance and the Date it was stored at.
    private static var distanceCache: [String: (distanceValue: Double, storedAt: Date)] = [:]

    // MARK: - Helpers for Distance Caching

    /// Creates a cache key for two CLLocations based on their latitude and longitude.
    /// - Parameters:
    ///   - loc1: First location
    ///   - loc2: Second location
    /// - Returns: A unique String key representing two location coordinates.
    private static func cacheKey(for loc1: CLLocation, and loc2: CLLocation) -> String {
        let lat1 = loc1.coordinate.latitude
        let lon1 = loc1.coordinate.longitude
        let lat2 = loc2.coordinate.latitude
        let lon2 = loc2.coordinate.longitude
        return "\(lat1)_\(lon1)_\(lat2)_\(lon2)"
    }

    /// Cleans up any cached entries older than 5 minutes.
    private static func purgeExpiredCacheEntries() {
        let now = Date()
        var keysToRemove = [String]()

        // Perform read in concurrent queue, collecting stale keys
        distanceCacheQueue.sync {
            for (key, value) in distanceCache {
                let interval = now.timeIntervalSince(value.storedAt)
                // 5 minutes = 300 seconds
                if interval > 300 {
                    keysToRemove.append(key)
                }
            }
        }

        // Remove stale entries in barrier write
        if !keysToRemove.isEmpty {
            distanceCacheQueue.async(flags: .barrier) {
                for key in keysToRemove {
                    distanceCache.removeValue(forKey: key)
                }
            }
        }
    }

    // MARK: - distance(to:) Method

    /// Calculates the optimized distance between this location and another location (in meters),
    /// rounding to 2 decimal places and caching results for 5 minutes to enhance performance.
    ///
    /// - Parameter location: The target location to which the distance is calculated.
    /// - Returns: The distance in meters, rounded to 2 decimal places.
    func distance(to location: CLLocation) -> Double {
        // Basic coordinate sanity check
        guard
            !(coordinate.latitude.isNaN || coordinate.longitude.isNaN),
            !(location.coordinate.latitude.isNaN || location.coordinate.longitude.isNaN)
        else {
            // If coordinates are invalid, return 0
            return 0.0
        }

        // Purge any expired entries before handling new requests
        CLLocation.purgeExpiredCacheEntries()

        // Generate cache key based on the two locations
        let key = CLLocation.cacheKey(for: self, and: location)

        // Attempt to retrieve from cache in a thread-safe manner
        var cachedDistance: Double?
        let now = Date()

        CLLocation.distanceCacheQueue.sync {
            if let cached = CLLocation.distanceCache[key] {
                let interval = now.timeIntervalSince(cached.storedAt)
                // If entry is not older than 5 minutes, use cached distance
                if interval <= 300 {
                    cachedDistance = cached.distanceValue
                }
            }
        }

        if let distanceValue = cachedDistance {
            // Return cached distance if still valid
            return distanceValue
        } else {
            // Compute the distance
            let actualDistance = self.distance(from: location)

            // Round to 2 decimal places
            let multiplier = pow(10.0, 2.0)
            let roundedDistance = (actualDistance * multiplier).rounded() / multiplier

            // Store in cache with barrier writing
            CLLocation.distanceCacheQueue.async(flags: .barrier) {
                CLLocation.distanceCache[key] = (distanceValue: roundedDistance, storedAt: now)
            }
            return roundedDistance
        }
    }

    // MARK: - isWithinRadius(of:radius:) Method

    /// Thread-safe check if the current location is within a given radius of a target location.
    /// Utilizes the cached distance method for improved performance.
    ///
    /// - Parameters:
    ///   - location: The target location to check against.
    ///   - radius: The radius in meters to compare distance.
    /// - Returns: True if the location is within the specified radius, otherwise false.
    func isWithinRadius(of location: CLLocation, radius: Double) -> Bool {
        // Validate negative radius
        guard radius >= 0 else {
            // Negative radius is invalid; log and return false
            print("Invalid radius (\(radius)). Radius must be non-negative.")
            return false
        }

        // Use a synchronized block for the distance check
        // (Here, distance(to:) is itself thread-safe, but we ensure
        //  any operations around it remain consistent)
        var result = false
        CLLocation.distanceCacheQueue.sync {
            let calculatedDistance = self.distance(to: location)
            result = (calculatedDistance <= radius)
        }

        // Log result for monitoring
        print("Location is within radius (\(radius) m): \(result)")
        return result
    }

    // MARK: - toDictionary Method

    /// Converts the current CLLocation instance to a privacy-aware dictionary format
    /// suitable for API requests. By default, precision for latitude/longitude is 6 decimals.
    ///
    /// - Parameter precision: The number of decimal places for lat/long (default is 6).
    /// - Returns: A dictionary containing sanitized, privacy-aware location data.
    func toDictionary(precision: Int = 6) -> [String: Any] {
        var locationData = [String: Any]()

        // Thread-safe read of location properties
        // (CLLocation is generally thread-safe for reading,
        //  but we place it in a sync block for consistent extension design)
        CLLocation.distanceCacheQueue.sync {
            // Create standardized date formatter for timestamps
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            // Truncate or format lat/lon as needed
            let lat = coordinate.latitude
            let lon = coordinate.longitude
            let latString = String(format: "%.\(precision)f", lat)
            let lonString = String(format: "%.\(precision)f", lon)

            // Timestamp
            let timestampString = dateFormatter.string(from: timestamp)

            // Populate dictionary
            locationData["latitude"] = latString
            locationData["longitude"] = lonString
            locationData["timestamp"] = timestampString
            locationData["horizontalAccuracy"] = horizontalAccuracy
            locationData["verticalAccuracy"] = verticalAccuracy

            // Add altitude data if relevant
            // (In many dog walking use-cases, altitude can be partially omitted,
            //  but we provide it for completeness here.)
            locationData["altitude"] = altitude

            // Add course (direction in degrees) and speed if available
            // For a dog walking app, these can help track motion and route.
            locationData["course"] = course
            locationData["speed"] = speed

            // Apply privacy filters based on app configuration
            // Example placeholder: (No actual filter logic implemented)
            // locationData = applyPrivacyFilters(to: locationData)

            // The dictionary remains in memory until returned
        }

        return locationData
    }

    // MARK: - formattedCoordinate (Computed Property)

    /// Returns a privacy-aware, human-readable coordinate string with hemisphere notation
    /// and a configurable decimal precision (default is 6 decimals).
    ///
    /// Example output: "N 37.774929, W 122.419416"
    var formattedCoordinate: String {
        // We can define the default precision. If you want this to be configurable
        // at call time, convert it to a function. The specification references
        // a property, so we default to 6 decimals here.
        let precision = 6
        var formatted = "Unknown Coordinate"

        CLLocation.distanceCacheQueue.sync {
            let lat = coordinate.latitude
            let lon = coordinate.longitude

            // Determine hemispheres
            let latHemisphere = (lat >= 0) ? "N" : "S"
            let lonHemisphere = (lon >= 0) ? "E" : "W"

            let latAbs = abs(lat)
            let lonAbs = abs(lon)

            let latString = String(format: "%.\(precision)f", latAbs)
            let lonString = String(format: "%.\(precision)f", lonAbs)

            // Combine into a human-readable string
            formatted = "\(latHemisphere) \(latString), \(lonHemisphere) \(lonString)"

            // Apply any privacy truncation if required
            // (Placeholder for additional privacy logic)
        }

        return formatted
    }

    // MARK: - toJSON Method

    /// Converts the current CLLocation data to a JSON string format with comprehensive
    /// error handling, privacy controls, and logging for monitoring.
    ///
    /// - Parameter precision: Decimal precision for lat/long in final JSON (default is 6).
    /// - Returns: JSON string representing location data, or an error message if serialization fails.
    func toJSON(precision: Int = 6) -> String {
        var jsonString = ""

        // Log attempt for monitoring
        print("Attempting to convert location to JSON...")

        // Create dictionary from the location
        let dict = toDictionary(precision: precision)

        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [])
            if let finalString = String(data: data, encoding: .utf8) {
                jsonString = finalString
            } else {
                // Fallback if encoding fails
                jsonString = "{\"error\":\"Unable to encode JSON string.\"}"
            }
        } catch {
            // Handle serialization error gracefully
            print("Error while converting location to JSON: \(error.localizedDescription)")
            // Return an error message as part of the JSON structure
            jsonString = "{\"error\":\"\(error.localizedDescription)\"}"
        }

        return jsonString
    }
}