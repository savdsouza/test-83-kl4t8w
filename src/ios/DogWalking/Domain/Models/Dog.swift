//
//  Dog.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-05.
//
//  This file defines the core domain model class representing a dog in the dog walking application.
//  It includes robust validation, offline-first data management considerations, and full data
//  transformation capabilities to meet the project's technical specification requirements.
//

import Foundation // iOS 13.0+

/// A comprehensive, enterprise-grade domain model representing a dog within the application.
/// This class provides enhanced data validation, synchronization tracking, and rich profile management
/// aligned with the project's technical specifications for Pet Profile Management and Data Management Strategy.
public final class Dog {
    
    // MARK: - Public Properties
    
    /// A globally unique identifier for the dog.
    public var id: UUID
    
    /// A globally unique identifier referencing the dog's owner.
    public var ownerId: UUID
    
    /// The name of the dog, as provided by the owner.
    public var name: String
    
    /// The breed of the dog (e.g., "Golden Retriever").
    public var breed: String
    
    /// The birth date of the dog for age-related data and scheduling.
    public var birthDate: Date
    
    /// A dictionary containing medical information (e.g., allergies, medications).
    /// According to the data management strategy, this is stored as a key-value structure
    /// for flexible expansion over time.
    public var medicalInfo: [String: String]
    
    /// A Boolean indicating whether the dog's profile is active.
    /// Inactive profiles may be hidden or excluded from booking flows.
    public var active: Bool
    
    /// An optional URL string (possibly referencing a remote location) for the dog's profile image.
    public var profileImageUrl: String?
    
    /// The dog's weight, validated to ensure it remains in the acceptable range (0.5 – 200.0 kg).
    public var weight: Double
    
    /// A list of special instructions, such as care notes or behavioral considerations.
    public var specialInstructions: [String]
    
    /// A timestamp indicating the last time this dog's profile was updated or synchronized.
    /// This helps support offline-first synchronization tracking and ensures data freshness.
    public var lastUpdated: Date
    
    
    // MARK: - Initializer
    
    /**
     Initializes a new `Dog` instance with required and optional properties.
     
     - Parameters:
       - id: A UUID representing the dog’s unique identifier.
       - ownerId: A UUID linking the dog to its owner.
       - name: The dog’s name as a `String`.
       - breed: The dog’s breed as a `String`.
       - birthDate: The dog’s birth date as a `Date`.
       - medicalInfo: A dictionary of medical details `[String: String]`.
       - active: A `Bool` indicating if the dog's profile is active.
       - profileImageUrl: An optional `String` for the dog's profile image URL.
       - weight: The dog’s weight in kilograms; must be between 0.5 and 200.0.
       - specialInstructions: An array of additional notes, warnings, or special directions.
     
     This initializer validates the weight range and ensures the `medicalInfo` is not empty.
     If any required fields fail validation, a runtime error is triggered. Once validated,
     the properties are assigned, and `lastUpdated` is set to the current date/time in ISO8601 format.
     */
    public init(
        id: UUID,
        ownerId: UUID,
        name: String,
        breed: String,
        birthDate: Date,
        medicalInfo: [String: String],
        active: Bool,
        profileImageUrl: String?,
        weight: Double,
        specialInstructions: [String]
    ) {
        // Validate weight range per project's requirement (0.5 - 200.0 kg)
        precondition(
            weight >= 0.5 && weight <= 200.0,
            "Weight must be between 0.5 kg and 200.0 kg"
        )
        
        // Ensure medical info is not empty (or meets any declared requirements)
        precondition(
            !medicalInfo.isEmpty,
            "Medical info dictionary cannot be empty; at least one entry is required"
        )
        
        // Assign properties
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.breed = breed
        self.birthDate = birthDate
        self.medicalInfo = medicalInfo
        self.active = active
        self.profileImageUrl = profileImageUrl
        self.weight = weight
        
        // Initialize special instructions array if empty (per data management strategy)
        if specialInstructions.isEmpty {
            self.specialInstructions = []
        } else {
            self.specialInstructions = specialInstructions
        }
        
        // Set lastUpdated to the current date/time using ISO8601 format
        // This is mostly informational; we store the raw `Date` type for future conversions
        self.lastUpdated = Date()
    }
    
    
    // MARK: - Public Methods
    
    /**
     Converts this `Dog` instance into a JSON-compatible dictionary for serialization.
     
     - Returns: A `[String: Any]` dictionary containing all of the dog's data, with
       ISO8601 formatted dates, validated fields, and properly typed values.
     */
    public func toJSON() -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        var result: [String: Any] = [:]
        
        // Core UUID properties as strings
        result["id"] = id.uuidString
        result["ownerId"] = ownerId.uuidString
        
        // Basic fields
        result["name"] = name
        result["breed"] = breed
        result["active"] = active
        
        // Dates (converted to ISO8601 string)
        result["birthDate"] = isoFormatter.string(from: birthDate)
        result["lastUpdated"] = isoFormatter.string(from: lastUpdated)
        
        // Optional image URL
        if let url = profileImageUrl {
            result["profileImageUrl"] = url
        }
        
        // Weight formatted to two decimal places
        result["weight"] = String(format: "%.2f", weight)
        
        // Medical info
        result["medicalInfo"] = medicalInfo
        
        // Special instructions
        result["specialInstructions"] = specialInstructions
        
        return result
    }
    
    /**
     Creates and returns a new `Dog` instance from a JSON dictionary, parsing and validating
     all required fields. If any required field is missing or invalid, the creation fails, and
     `nil` is returned.
     
     - Parameter json: A `[String: Any]` dictionary containing the data necessary
       to initialize a Dog.
     - Returns: An optional `Dog` instance if parsing and validation succeed.
     */
    public static func fromJSON(_ json: [String: Any]) -> Dog? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        
        // Parse and validate required UUID fields
        guard
            let idString = json["id"] as? String,
            let idUUID = UUID(uuidString: idString),
            let ownerIdString = json["ownerId"] as? String,
            let ownerIdUUID = UUID(uuidString: ownerIdString)
        else {
            return nil
        }
        
        // Parse required string fields
        guard
            let name = json["name"] as? String,
            let breed = json["breed"] as? String
        else {
            return nil
        }
        
        // Parse and validate boolean
        guard let active = json["active"] as? Bool else {
            return nil
        }
        
        // Parse date fields (birthDate)
        guard
            let birthDateString = json["birthDate"] as? String,
            let birthDate = isoFormatter.date(from: birthDateString)
        else {
            return nil
        }
        
        // Parse lastUpdated if provided; otherwise set current time
        let lastUpdatedDate: Date
        if let luStr = json["lastUpdated"] as? String, let luDate = isoFormatter.date(from: luStr) {
            lastUpdatedDate = luDate
        } else {
            lastUpdatedDate = Date()
        }
        
        // Parse and validate medical info
        guard let medicalInfo = json["medicalInfo"] as? [String: String], !medicalInfo.isEmpty else {
            return nil
        }
        
        // Parse optional profile image URL
        let profileImageUrl = json["profileImageUrl"] as? String
        
        // Parse and validate weight
        guard
            let weightString = json["weight"] as? String,
            let weightValue = Double(weightString),
            weightValue >= 0.5, weightValue <= 200.0
        else {
            return nil
        }
        
        // Parse special instructions
        let instructions = json["specialInstructions"] as? [String] ?? []
        
        // Construct Dog instance
        let dog = Dog(
            id: idUUID,
            ownerId: ownerIdUUID,
            name: name,
            breed: breed,
            birthDate: birthDate,
            medicalInfo: medicalInfo,
            active: active,
            profileImageUrl: profileImageUrl,
            weight: weightValue,
            specialInstructions: instructions
        )
        
        // Overwrite the lastUpdated property to reflect the parsed or fallback date
        dog.lastUpdated = lastUpdatedDate
        
        return dog
    }
}