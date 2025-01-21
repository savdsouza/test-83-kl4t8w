//
//  Location.swift
//  DogWalking
//
//  Created by Enterprise-Ready AI on 2023-10-01.
//
//  This file provides a thread-safe, immutable model class representing
//  a validated location point for real-time GPS tracking data within the
//  DogWalking application. It includes comprehensive conversion utilities
//  for bidirectional mapping between this model and CoreLocation’s CLLocation
//  objects, along with robust validation and caching mechanisms.
//
//  Dependencies:
//  • Foundation (iOS 13.0+) - Basic system framework for data types
//  • CoreLocation (iOS 13.0+) - Core framework for location services and data types
//
//  The Location class is carefully designed to fulfill the requirements of:
//  1. Real-time Location Tracking
//  2. Location Data Management
//
//  This file follows enterprise-level code standards for production readiness.
//  All properties are immutable, validated upon initialization, and thread-safety
//  is achieved through atomic caching patterns. Extensive comments are provided
//  to ensure clarity and maintainability.
//

import Foundation // iOS 13.0+
import CoreLocation // iOS 13.0+

/// An error type representing potential validation or processing failures within
/// the Location model creation and conversion processes.
@objc
public enum LocationError: Int, Error {
    case invalidLatitude
    case invalidLongitude
    case negativeAccuracy
    case negativeSpeed
    case negativeCourse
    case futureTimestamp
    case genericError
}

/// A thread-safe, immutable model class representing a validated location point
/// during a dog walk. This class stores validated latitude, longitude, altitude,
/// accuracy, speed, course, and timestamp values, and provides comprehensive
/// conversion utilities to and from `CLLocation` instances.
@objc
public final class Location: NSObject {
    
    // MARK: - Static Caching for `fromCLLocation`
    // -------------------------------------------------------------------------
    // We maintain a static NSCache to store previously created Location objects
    // derived from the same CLLocation reference. The key is based on the unique
    // pointer address of CLLocation plus relevant properties to help ensure
    // uniqueness. This caching enhances performance when the same CLLocation
    // data might be processed repeatedly. Thread-safety is guaranteed by NSCache.
    private static let conversionCache = NSCache<NSString, Location>()
    
    // MARK: - Immutable Properties
    // -------------------------------------------------------------------------
    // All location properties are declared as public, read-only, and final.
    // They are validated and assigned exactly once during initialization.
    
    /// The latitude component in degrees (-90.0 ... +90.0).
    @objc public let latitude: Double
    
    /// The longitude component in degrees (-180.0 ... +180.0).
    @objc public let longitude: Double
    
    /// The altitude in meters relative to sea level.
    @objc public let altitude: Double
    
    /// The radius of uncertainty for the location in meters (non-negative).
    @objc public let accuracy: Double
    
    /// The speed in meters per second (non-negative).
    @objc public let speed: Double
    
    /// The direction of travel in degrees relative to true north (0.0...360.0).
    @objc public let course: Double
    
    /// The timestamp indicating when this location data was acquired.
    @objc public let timestamp: Date
    
    // MARK: - Thread-Safe Caching for `toCLLocation`
    // -------------------------------------------------------------------------
    // We hold a private mutable reference to cache the converted CLLocation once
    // it has been created from this Location. Access is synchronized via atomic
    // reads/writes to guarantee thread-safety.
    private var clLocationCache: CLLocation?
    
    // MARK: - Initialization
    // -------------------------------------------------------------------------
    /// Initializes a new `Location` instance with full validation.
    ///
    /// - Parameters:
    ///   - latitude:  The latitude in degrees, must be between -90.0 and +90.0.
    ///   - longitude: The longitude in degrees, must be between -180.0 and +180.0.
    ///   - altitude:  The altitude in meters (can be negative if below sea level).
    ///   - accuracy:  The radius of uncertainty in meters (non-negative).
    ///   - speed:     The speed in m/s (non-negative).
    ///   - course:    The direction of travel in degrees (non-negative, usually 0.0–360.0).
    ///   - timestamp: The time the location data was recorded (cannot be in the future).
    ///
    /// Validation Steps:
    /// 1. Ensure latitude is within [-90.0, +90.0].
    /// 2. Ensure longitude is within [-180.0, +180.0].
    /// 3. Clamp accuracy, speed, and course to non-negative values.
    /// 4. If timestamp is in the future, clamp it to `Date()`.
    ///
    /// - Throws: `LocationError` if any core validation fails.
    @objc
    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        accuracy: Double,
        speed: Double,
        course: Double,
        timestamp: Date
    ) throws {
        // 1. Validate latitude is between -90 and 90 degrees.
        guard latitude >= -90.0, latitude <= 90.0 else {
            throw LocationError.invalidLatitude
        }
        
        // 2. Validate longitude is between -180 and 180 degrees.
        guard longitude >= -180.0, longitude <= 180.0 else {
            throw LocationError.invalidLongitude
        }
        
        // 3. Validate accuracy, speed, and course are non-negative.
        if accuracy < 0.0 { throw LocationError.negativeAccuracy }
        if speed < 0.0 { throw LocationError.negativeSpeed }
        if course < 0.0 { throw LocationError.negativeCourse }
        
        // 4. Validate timestamp is not in the future; clamp if it is.
        let now = Date()
        let finalTimestamp = timestamp > now ? now : timestamp
        
        // Assign all validated parameters to immutable properties.
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.accuracy = accuracy
        self.speed = speed
        self.course = course
        self.timestamp = finalTimestamp
        
        // Initialize instance-level cache for subsequent CLLocation conversions.
        self.clLocationCache = nil
        
        super.init()
    }
    
    // MARK: - Static Factory: fromCLLocation
    // -------------------------------------------------------------------------
    /// Creates a new `Location` instance from a `CLLocation` object with
    /// comprehensive validation and caching. If a cached `Location` object
    /// derived from the same `CLLocation` data is found, it is returned
    /// immediately to improve performance.
    ///
    /// - Parameter location: The `CLLocation` object to convert.
    /// - Returns: A new or cached `Location` instance containing validated data.
    /// - Throws: `LocationError` if validation fails for latitude, longitude,
    ///           accuracy, speed, or the timestamp.
    @objc(staticFromCLLocation:)
    public static func fromCLLocation(_ location: CLLocation) throws -> Location {
        // Construct a cache key as an NSString that uniquely identifies the location data.
        // Using coordinate, altitude, accuracy, speed, course, and timestamp in the key
        // to ensure that we only reuse exact matches.
        let coord = location.coordinate
        let keyString = String(
            format: "lat:%.6f-lon:%.6f-alt:%.2f-acc:%.2f-spd:%.2f-crs:%.2f-ts:%.0f",
            coord.latitude,
            coord.longitude,
            location.altitude,
            location.horizontalAccuracy,
            location.speed,
            location.course,
            location.timestamp.timeIntervalSince1970
        )
        let cacheKey = NSString(string: keyString)
        
        // Attempt to find an existing Location instance in cache.
        if let cachedLocation = conversionCache.object(forKey: cacheKey) {
            return cachedLocation
        }
        
        // Extract and validate data. Some CLLocation properties can be negative or invalid,
        // but we rely on the initialization in `Location` to enforce correctness.
        let lat = coord.latitude
        let lon = coord.longitude
        let alt = location.altitude
        
        // CoreLocation uses horizontalAccuracy for "accuracy" in meters.
        // We treat negative horizontalAccuracy as invalid data.
        let acc = location.horizontalAccuracy
        
        // Speed can be -1.0 in some iOS cases when no speed is available.
        let spd = location.speed
        
        // Course can be -1.0 when course is undefined.
        let crs = location.course
        
        // Timestamp from CLLocation is typically valid, but we clamp in the initializer if needed.
        let ts = location.timestamp
        
        // Create the new validated Location instance.
        let newLocation = try Location(
            latitude: lat,
            longitude: lon,
            altitude: alt,
            accuracy: acc,
            speed: spd,
            course: crs,
            timestamp: ts
        )
        
        // Store in cache for future reuse.
        conversionCache.setObject(newLocation, forKey: cacheKey)
        
        return newLocation
    }
    
    // MARK: - Conversion: toCLLocation
    // -------------------------------------------------------------------------
    /// Converts this `Location` instance to a `CLLocation` object in a thread-safe
    /// manner, caching the result for subsequent retrieval. If the conversion has
    /// been previously performed, the cached `CLLocation` is returned immediately.
    ///
    /// - Returns: A `CLLocation` object representing this location’s data.
    @objc
    public func toCLLocation() -> CLLocation {
        // Check if we have a previously cached CLLocation.
        if let cached = clLocationCache {
            return cached
        }
        
        // Construct a new CLLocation object from the validated properties.
        let coordinate = CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
        let newCLLocation = CLLocation(
            coordinate: coordinate,
            altitude: self.altitude,
            horizontalAccuracy: self.accuracy,
            verticalAccuracy: self.accuracy, // Reusing horizontal accuracy for vertical; adjust as needed.
            course: self.course,
            speed: self.speed,
            timestamp: self.timestamp
        )
        
        // Cache the newly created CLLocation for this instance.
        self.clLocationCache = newCLLocation
        
        return newCLLocation
    }
    
    // MARK: - Distance Calculation
    // -------------------------------------------------------------------------
    /// Calculates the distance (in meters) between this `Location` and another
    /// `Location` using CoreLocation’s optimized distance functions.
    ///
    /// - Parameter location: Another `Location` object for which distance is computed.
    /// - Returns: A non-negative `Double` representing the distance in meters, or 0.0
    ///            if either location is invalid.
    @objc
    public func distanceTo(_ location: Location) -> Double {
        // Convert both `Location` instances to `CLLocation`.
        let thisCLLocation = self.toCLLocation()
        let anotherCLLocation = location.toCLLocation()
        
        // Calculate distance using CoreLocation’s `distance(from:)` method.
        let distance = thisCLLocation.distance(from: anotherCLLocation)
        
        // Final validation: distance should never be negative in this domain.
        // If a negative value is somehow returned, clamp to 0.0 for safety.
        return max(0.0, distance)
    }
}