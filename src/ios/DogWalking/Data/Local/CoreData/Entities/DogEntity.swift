//
//  DogEntity.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-05.
//
//  CoreData entity class representing a dog in local storage, implementing
//  comprehensive data validation, integrity checks, and transformation methods
//  to interoperate with the domain-model-level Dog class.
//
//  This file strictly adheres to the project’s technical specification,
//  addressing Pet Profile Management (local persistent storage for pet profiles)
//  and Data Management Strategy (offline-first architecture, synchronization
//  with lastUpdated, etc.).
//

import Foundation // iOS 13.0+
import CoreData   // iOS 13.0+

// NOTE: Referencing the domain model "Dog" defined in:
//       src/ios/DogWalking/Domain/Models/Dog.swift
//       for bidirectional data transformations and validation.
//       The domain model includes robust constructors and method implementations.
@objc(DogEntity)
public class DogEntity: NSManagedObject {

    // MARK: - Core Data Properties

    /// A globally unique identifier for this dog entity.
    @NSManaged public var id: UUID

    /// The owner’s unique UUID for relating to the user’s profile.
    @NSManaged public var ownerId: UUID

    /// The dog’s name.
    @NSManaged public var name: String

    /// The dog’s breed (e.g., "Golden Retriever").
    @NSManaged public var breed: String

    /// The birth date of the dog for age tracking.
    @NSManaged public var birthDate: Date

    /// An NSObject intended to store a dictionary ([String: String]) of medical details.
    @NSManaged public var medicalInfo: NSObject

    /// A Boolean flag indicating whether this dog profile is active.
    @NSManaged public var active: Bool

    /// An optional string referencing the dog's profile image URL.
    @NSManaged public var profileImageUrl: String?

    /// The dog’s weight in kilograms.
    @NSManaged public var weight: Double

    /// An NSObject intended to store an array ([String]) of special instructions.
    @NSManaged public var specialInstructions: NSObject

    /// A timestamp marking the last time this record was updated.
    @NSManaged public var lastUpdated: Date


    // MARK: - Conversion to Domain Model

    /**
     Converts this CoreData entity into a fully validated `Dog` domain model instance.

     Steps Performed:
     1. Validates required properties are non-empty (e.g., name, breed).
     2. Converts `medicalInfo` from NSObject to `[String: String]`.
     3. Converts `specialInstructions` from NSObject to `[String]`.
     4. Ensures `weight` is within 0.1...200.0 for local entity constraints.
     5. Constructs and returns a `Dog` instance with validated data.

     - Returns: A validated `Dog` instance representing this entity’s data.
     - Warning: This method will terminate execution (via `fatalError`) if any critical validation fails.
     */
    public func toDomainModel() -> Dog {
        // Validate 'medicalInfo' cast to [String: String]
        guard let medicalDict = medicalInfo as? [String: String] else {
            fatalError("DogEntity: 'medicalInfo' must be a dictionary of type [String: String].")
        }

        // Validate 'specialInstructions' cast to [String]
        guard let instructions = specialInstructions as? [String] else {
            fatalError("DogEntity: 'specialInstructions' must be an array of strings.")
        }

        // Validate 'name' and 'breed' are not empty
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            fatalError("DogEntity: 'name' cannot be empty.")
        }
        guard !breed.trimmingCharacters(in: .whitespaces).isEmpty else {
            fatalError("DogEntity: 'breed' cannot be empty.")
        }

        // Validate weight range (0.1...200.0) as specified in JSON specification
        guard weight >= 0.1 && weight <= 200.0 else {
            fatalError("DogEntity: 'weight' must be between 0.1 kg and 200.0 kg.")
        }

        // All validations successful, construct a domain model
        // Note: The domain model enforces its own range checks (0.5...200.0).
        //       If weight < 0.5, a precondition failure will occur in Dog’s initializer.
        let dog = Dog(
            id: id,
            ownerId: ownerId,
            name: name,
            breed: breed,
            birthDate: birthDate,
            medicalInfo: medicalDict,
            active: active,
            profileImageUrl: profileImageUrl,
            weight: weight,
            specialInstructions: instructions
        )

        // Overwrite the lastUpdated of the newly created model to match the entity’s property
        dog.lastUpdated = lastUpdated
        return dog
    }


    // MARK: - Update from Domain Model

    /**
     Updates this `DogEntity` with data from a given `Dog` domain model,
     ensuring data integrity and setting the `lastUpdated` to the current timestamp.

     Steps Performed:
     1. Validates incoming `dog` model data (e.g., checks completeness).
     2. Updates fundamental properties (id, ownerId, name, breed, etc.).
     3. Converts `dog.medicalInfo` into NSObject and assigns to `medicalInfo`.
     4. Converts `dog.specialInstructions` into NSObject and assigns to `specialInstructions`.
     5. Validates `dog.weight` is within 0.1...200.0 before assignment.
     6. Sets the entity’s `lastUpdated` to the current date/time.

     - Parameter dog: The domain model to pull updated field values from.
     - Note: This method does not save or persist contexts automatically; the caller must handle context saves.
     */
    public func update(from dog: Dog) {
        // Basic validation for name, breed, etc., on the incoming model
        guard !dog.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            fatalError("DogEntity.update: Incoming dog model has an empty name.")
        }
        guard !dog.breed.trimmingCharacters(in: .whitespaces).isEmpty else {
            fatalError("DogEntity.update: Incoming dog model has an empty breed.")
        }

        // Validate weight is in the 0.1...200.0 range for local entity
        guard dog.weight >= 0.1 && dog.weight <= 200.0 else {
            fatalError("DogEntity.update: 'weight' must be between 0.1 kg and 200.0 kg.")
        }

        // Update primary identifiers and basic fields
        self.id = dog.id
        self.ownerId = dog.ownerId
        self.name = dog.name
        self.breed = dog.breed
        self.birthDate = dog.birthDate
        self.active = dog.active
        self.profileImageUrl = dog.profileImageUrl
        self.weight = dog.weight

        // Convert and assign medicalInfo
        // The domain model uses [String: String], so cast to NSObject for CoreData
        let medicalAsNSObject = dog.medicalInfo as NSDictionary
        self.medicalInfo = medicalAsNSObject

        // Convert and assign specialInstructions
        // The domain model uses [String], so cast to NSObject for CoreData
        let instructionsAsNSObject = dog.specialInstructions as NSArray
        self.specialInstructions = instructionsAsNSObject

        // Set lastUpdated to the current time for synchronization reference
        self.lastUpdated = Date()
    }
}