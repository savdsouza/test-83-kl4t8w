//
//  UserEntity.swift
//
//  This file defines a CoreData managed object subclass representing a user
//  in the local database. It includes comprehensive mapping to the domain
//  model, relationship management, and data validation suitable for
//  enterprise-grade applications.
//
//  Generated based on the following specification:
//  - File Path: src/ios/DogWalking/Data/Local/CoreData/Entities/UserEntity.swift
//  - Description: CoreData managed object subclass for user data persistence
//  - Imports: Foundation (iOS 13.0+), CoreData (iOS 13.0+), Domain/Models/User
//  - Implements robust local persistence with offline-first capabilities
//  - Maps to domain model “User” bidirectionally
//  - Author: Automated generation via Software Architect Agent
//

import Foundation // iOS 13.0+ version
import CoreData   // iOS 13.0+ version
import DogWalking // Domain model import, containing class User, enum UserType, etc.

/**
 A CoreData entity class for persisting user information locally,
 providing bidirectional mapping to and from the domain `User` model.

 This class supports the following features:
 - Managed attributes like email, phone, profile image, user type, and rating.
 - Relationship properties (dogs, walks) for future expansions.
 - Utility methods for updating and validating data.
 - Comprehensive bridging to the domain `User` model.
 */
@objc(UserEntity)
public class UserEntity: NSManagedObject {

    // MARK: - CoreData Properties

    /// A string-based unique identifier. Corresponds to `User.id` in the domain model as UUID.
    @NSManaged public var id: String

    /// The user’s email address. Must be non-empty and validly formatted.
    @NSManaged public var email: String

    /// The user's first name. Required for personalization.
    @NSManaged public var firstName: String

    /// The user's last name. Required for personalization.
    @NSManaged public var lastName: String

    /// An optional phone number for contact or notifications.
    @NSManaged public var phone: String?

    /// An optional string representing the user’s profile image URL.
    /// Should store absolute string form for domain-level usage.
    @NSManaged public var profileImageUrl: String?

    /// A raw integer value for the domain-level `UserType` enum.
    /// 0 represents `owner`, 1 represents `walker`.
    @NSManaged public var userType: Int16

    /// The user’s average rating (if walker).
    /// Defaults to 0 if no rating is established.
    @NSManaged public var rating: Double

    /// The total number of walks completed by this user (if walker).
    /// Defaults to 0 if user is an owner or no walks completed yet.
    @NSManaged public var completedWalks: Int32

    /// Indicates if the user has passed necessary verification steps.
    @NSManaged public var isVerified: Bool

    /// A CoreData relationship set pointing to the user’s dogs (if owner).
    @NSManaged public var dogs: NSSet?

    /// A CoreData relationship set pointing to the user’s walks (if walker or owner).
    @NSManaged public var walks: NSSet?

    /// Timestamp marking the creation date of this entity record.
    @NSManaged public var createdAt: Date

    /// Timestamp indicating the last time this entity record was updated.
    @NSManaged public var updatedAt: Date

    /// A boolean flag indicating if this record requires synchronization
    /// with the remote backend. Used in offline-first strategies.
    @NSManaged public var needsSync: Bool

    // MARK: - Initializers

    /**
     Creates a new `UserEntity` instance, inserting it into the given
     managed object context. Sets default values and flags to ensure
     consistency within an offline-first data model.

     Steps:
     1. Initialize via super with the appropriate entity description.
     2. Assign default values for string, numeric, and date properties.
     3. Initialize empty sets for relationships to avoid nil discrepancies.
     4. Mark `needsSync` as `true` for newly created local records.

     - Parameter context: The `NSManagedObjectContext` in which this
       `UserEntity` will be inserted.
     */
    public convenience init(context: NSManagedObjectContext) {
        guard let entityDesc = NSEntityDescription.entity(forEntityName: "UserEntity", in: context) else {
            fatalError("Failed to locate NSEntityDescription for UserEntity.")
        }
        self.init(entity: entityDesc, insertInto: context)

        // Initialize basic fields
        self.id = UUID().uuidString
        self.email = ""
        self.firstName = ""
        self.lastName = ""
        self.phone = nil
        self.profileImageUrl = nil
        self.userType = 0
        self.rating = 0.0
        self.completedWalks = 0
        self.isVerified = false

        // Set default timestamps
        let now = Date()
        self.createdAt = now
        self.updatedAt = now

        // Initialize placeholders for relationships
        self.dogs = NSSet()
        self.walks = NSSet()

        // Mark record as needing sync
        self.needsSync = true
    }

    // MARK: - Public Methods

    /**
     Converts the current CoreData entity into a fully qualified domain `User` object.

     Steps:
     1. Maps string-based `id` to a `UUID`, defaulting if conversion fails.
     2. Converts `userType` raw value to the domain’s `UserType` enum.
     3. Translates optional fields (`phone`, `profileImageUrl`) as appropriate.
     4. Initializes domain arrays (`dogs`, `walks`, `paymentMethods`) to empty
        or future-mappable values. This can be updated when the respective
        CoreData entities exist.
     5. Copies timestamps and relevant numeric fields.

     - Returns: A `User` instance reflecting the values stored in this entity.
     */
    public func toDomainModel() -> User {
        let defaultUUID = UUID() // fallback if invalid
        let resolvedUUID = UUID(uuidString: id) ?? defaultUUID

        let resolvedUserType = UserType(rawValue: Int(userType)) ?? .owner
        let domainUser = User(
            id: resolvedUUID,
            email: email,
            firstName: firstName,
            lastName: lastName,
            userType: resolvedUserType
        )

        // Map optional phone
        domainUser.phone = phone

        // Convert string-based profileImageUrl to URL if possible
        if let urlString = profileImageUrl, let parsedURL = URL(string: urlString) {
            domainUser.profileImageUrl = parsedURL
        } else {
            domainUser.profileImageUrl = nil
        }

        // Map numeric fields
        domainUser.rating = rating
        domainUser.completedWalks = Int(completedWalks)
        domainUser.isVerified = isVerified

        // The domain model has fields not stored here, like isActive, preferences, etc.
        // Provide sensible defaults or placeholders as needed:
        domainUser.isActive = true
        domainUser.preferences = UserPreferences()
        domainUser.paymentMethods = [] // Not stored locally
        domainUser.lastLoginAt = nil   // Not tracked locally

        // For dogs and walks, proper mapping would occur if there are corresponding CoreData entities.
        // This placeholder sets them to an empty array.
        domainUser.dogs = []
        domainUser.walks = []

        // Transfer timestamps
        domainUser.createdAt = createdAt
        domainUser.updatedAt = updatedAt

        return domainUser
    }

    /**
     Updates this CoreData entity with data from the provided domain `User` object,
     applying change tracking such as timestamp updates and `needsSync` toggling.

     Steps:
     1. Synchronizes all relevant stored properties (e.g., names, phone, rating).
     2. Converts domain enumerations (`UserType`) to raw integer fields.
     3. Updates the `updatedAt` timestamp to the current time.
     4. Sets `needsSync` to `true`, indicating pending remote synchronization.
     5. Placeholder for relationships update (dogs, walks) if relevant entities exist.

     - Parameter user: The domain `User` model whose data should be applied to this entity.
     */
    public func update(from user: User) {
        // Update base fields
        email = user.email
        firstName = user.firstName
        lastName = user.lastName
        phone = user.phone
        profileImageUrl = user.profileImageUrl?.absoluteString
        rating = user.rating
        completedWalks = Int32(user.completedWalks)
        isVerified = user.isVerified

        // Convert domain enum to raw value
        userType = Int16(user.userType.rawValue)

        // Update housekeeping fields
        updatedAt = Date()
        needsSync = true

        // Relationship syncing (dogs, walks) could be implemented when related entities exist.
        // For now, placeholders or logic to map domain objects can be added here as needed.
    }

    /**
     Validates this entity’s state to ensure all critical fields meet
     required constraints prior to saving or updating in CoreData.

     Checks performed:
     - Non-empty `id`, `email`, `firstName`, `lastName`
     - `userType` within valid range (0 or 1)
     - Any custom business checks if needed

     - Returns: A Boolean indicating whether validation passed.
       `true` if valid; `false` otherwise.
     */
    public func validateForUpdate() -> Bool {
        var isValid = true

        if id.trimmingCharacters(in: .whitespaces).isEmpty {
            // Log or handle as needed
            isValid = false
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            // Log or handle as needed
            isValid = false
        }
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            // Log or handle as needed
            isValid = false
        }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            // Log or handle as needed
            isValid = false
        }
        // Ensure userType matches 0 or 1 for our domain enum
        if userType < 0 || userType > 1 {
            // Log or handle as needed
            isValid = false
        }

        return isValid
    }
}

// MARK: - Fetch Request Extension
extension UserEntity {
    /**
     Provides a convenience method to create a typed `NSFetchRequest` for `UserEntity`.

     - Returns: A typed fetch request configured for `UserEntity`.
     */
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }
}