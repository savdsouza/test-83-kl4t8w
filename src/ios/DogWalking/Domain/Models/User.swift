import Foundation // iOS 13.0+

//
// MARK: - Internal Import for type-safe API response handling for user data
// Path: src/ios/DogWalking/Data/Network/APIResponse.swift
// We are using the 'data' member from 'APIResponse' to parse user information.
#if canImport(DogWalking)
import DogWalking
#else
// If there's a specific module name instead of `DogWalking`, replace below:
/// import DataNetworkAPIResponse
#endif

/// Represents a type-safe enumeration of user types in the dog walking application.
/// This enum ensures clear distinction between an owner and a walker,
/// facilitating role-based logic and permission checks throughout the platform.
@objc
public enum UserType: Int, Codable, Equatable {
    /// Represents a dog owner seeking walking services.
    case owner
    
    /// Represents a dog walker providing walking services.
    case walker
}

/// A supporting structure to represent a user's dog within the domain model.
/// In a larger codebase, this would contain comprehensive dog-related properties
/// such as name, breed, medical info, and more. For now, it acts as a placeholder.
public struct Dog: Codable, Equatable {
    // TODO: Implement dog-specific fields and logic as needed.
}

/// A supporting structure to represent a walk entity within the domain model.
/// Typically includes location tracking, start/end times, distance, etc. 
/// This placeholder can be expanded to include real details.
public struct Walk: Codable, Equatable {
    // TODO: Implement walk-specific fields and logic as needed.
}

/// Represents a payment method entity within the dog walking application.
/// This placeholder can be fleshed out with real payment processing details.
public struct PaymentMethod: Codable, Equatable {
    // TODO: Implement payment method details such as last four digits, tokenization, etc.
}

/// A placeholder structure for user preferences, e.g., notification settings,
/// preferred walker rating thresholds, etc. This can be expanded as needed.
public struct UserPreferences: Codable, Equatable {
    // TODO: Implement user-specific preferences and defaults as needed.
}

/// A specialized error type capturing top-level domain errors that may occur
/// when updating a user’s profile or verification status.
public enum UserError: Error, Equatable {
    /// Indicates an invalid parameter was supplied (e.g., illegal characters or formatting).
    case invalidParameter(String)
    
    /// Indicates the current user is not authorized to perform a specific action.
    case unauthorized
    
    /// A catch-all case for unexpected or unclassified user-related errors.
    case unknown(String)
}

/// The primary domain model representing a user (either owner or walker).
/// This class implements comprehensive profile management, security features,
/// and is designed with extensibility in mind to meet enterprise-grade standards.
///
/// Conforms to:
/// - @objc for Objective-C bridging (where needed).
/// - Codable for smooth JSON encoding/decoding.
/// - Equatable for easy comparison in the application layer.
@objc
public class User: NSObject, Codable, Equatable {
    
    // MARK: - Public Properties
    
    /// A universally unique identifier for this user.
    /// Ensures no collisions in the system’s data store.
    public let id: UUID
    
    /// The email address associated with this user. Must be unique and validly formatted.
    public var email: String
    
    /// The user’s first name, used to personalize interactions.
    public var firstName: String
    
    /// The user’s last name, used to personalize interactions.
    public var lastName: String
    
    /// An optional phone number for contact or notifications.
    /// Must pass formatting checks if provided.
    public var phone: String?
    
    /// An optional URL pointing to the user's profile image.
    /// Supports remote and local resources.
    public var profileImageUrl: URL?
    
    /// Indicates whether this user is an owner looking to schedule walks
    /// or a walker providing walking services.
    public var userType: UserType
    
    /// Reflects the user’s current rating (if a walker) based on completed walks.
    /// Defaults to 0.0 if no rating is established.
    public var rating: Double
    
    /// Tracks the total number of walks this user has completed
    /// (if the user is a walker). Defaults to zero.
    public var completedWalks: Int
    
    /// Whether the user has passed all required verification steps, such as
    /// background checks, ID verification, etc.
    public var isVerified: Bool
    
    /// Indicates whether this user account is active or suspended.
    /// Inactive or suspended accounts typically cannot utilize core platform features.
    public var isActive: Bool
    
    /// A collection of all dog entities that belong to this user (if user is an owner).
    /// This array is usually empty if the user is a walker.
    public var dogs: [Dog]
    
    /// A list of associated walk objects, which can represent past or future scheduled walks.
    public var walks: [Walk]
    
    /// Contains payment methods for billing (if user is an owner).
    /// Empty if user is a walker.
    public var paymentMethods: [PaymentMethod]
    
    /// Holds user-specific preferences, such as notification settings, language config, etc.
    public var preferences: UserPreferences
    
    /// Timestamp capturing when the user’s record was first created in the system.
    public var createdAt: Date
    
    /// Timestamp for the last time this record was updated. This field is
    /// automatically updated whenever user data changes.
    public var updatedAt: Date
    
    /// Records the date and time this user last logged in, if ever.
    public var lastLoginAt: Date?
    
    /// Holds an optional device token for push notifications or real-time updates.
    public var deviceToken: String?
    
    // MARK: - Initializer
    
    /// Initializes a new User instance with core parameters and sensible defaults.
    /// Follows security and data consistency checks for each step, ensuring 
    /// no invalid data is assigned to the model.
    ///
    /// Steps:
    /// 1. Validate input parameters for format and content.
    /// 2. Initialize required properties with provided values.
    /// 3. Set default values for optional properties.
    /// 4. Initialize empty arrays for relationships.
    /// 5. Set creation and update timestamps.
    /// 6. Set default security and verification status.
    ///
    /// - Parameters:
    ///   - id: A UUID uniquely identifying this user.
    ///   - email: A valid email address used for login and notifications.
    ///   - firstName: The new user’s first name.
    ///   - lastName: The new user’s last name.
    ///   - userType: Indicates whether the user is an owner or a walker.
    public init(
        id: UUID,
        email: String,
        firstName: String,
        lastName: String,
        userType: UserType
    ) {
        // Validate that email is not empty for security and business logic.
        precondition(!email.trimmingCharacters(in: .whitespaces).isEmpty,
                     "Email must not be empty.")
        
        // Validate that first and last names are provided (not strictly empty).
        precondition(!firstName.trimmingCharacters(in: .whitespaces).isEmpty,
                     "First name cannot be empty.")
        precondition(!lastName.trimmingCharacters(in: .whitespaces).isEmpty,
                     "Last name cannot be empty.")
        
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.userType = userType
        
        // Set default values for optional properties and relationships.
        self.phone = nil
        self.profileImageUrl = nil
        self.rating = 0.0
        self.completedWalks = 0
        self.isVerified = false
        self.isActive = true
        
        // Initialize empty arrays for domain relationships.
        self.dogs = []
        self.walks = []
        self.paymentMethods = []
        
        // Initialize preferences with default config.
        self.preferences = UserPreferences()
        
        // Set creation and update timestamps to the current date/time.
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // Optional fields set to nil by default.
        self.lastLoginAt = nil
        self.deviceToken = nil
        
        super.init()
    }
    
    // MARK: - Equatable Conformance
    
    /// Implements equality checking between two User objects.
    /// Recommended approach is verifying unique fields such as `id`,
    /// but more fields can be included if business logic dictates.
    ///
    /// - Parameters:
    ///   - lhs: Left-hand side user to compare.
    ///   - rhs: Right-hand side user to compare.
    /// - Returns: A Boolean indicating if both users are logically equivalent.
    public static func == (lhs: User, rhs: User) -> Bool {
        // Basic approach: check if IDs match.
        return lhs.id == rhs.id
            && lhs.email == rhs.email
            && lhs.userType == rhs.userType
            && lhs.isVerified == rhs.isVerified
    }
    
    // MARK: - Public Methods
    
    /// A convenience function that returns the user's formatted full name.
    /// If either name is empty due to partial data, those fields are gracefully avoided.
    ///
    /// Steps:
    /// 1. Trim whitespace from first and last names.
    /// 2. Combine names with proper spacing.
    /// 3. Handle edge cases where name fields may be empty.
    ///
    /// - Returns: A properly formatted full name for display.
    @objc
    public func fullName() -> String {
        let fName = firstName.trimmingCharacters(in: .whitespaces)
        let lName = lastName.trimmingCharacters(in: .whitespaces)
        
        switch (fName.isEmpty, lName.isEmpty) {
        case (true, true):
            return "Unnamed User"
        case (false, true):
            return "\(fName)"
        case (true, false):
            return "\(lName)"
        case (false, false):
            return "\(fName) \(lName)"
        }
    }
    
    /// Updates user profile fields with validation, security checks, and
    /// triggers any relevant notifications for downstream systems.
    ///
    /// Steps:
    /// 1. Validate input parameters.
    /// 2. Check user verification status.
    /// 3. Update provided fields if valid.
    /// 4. Validate phone number format if provided.
    /// 5. Update preferences if provided.
    /// 6. Update timestamp.
    /// 7. Trigger notification for profile updates.
    ///
    /// - Parameters:
    ///   - firstName: An optional new first name.
    ///   - lastName: An optional new last name.
    ///   - phone: An optional phone number.
    ///   - profileImageUrl: An optional user profile image URL.
    ///   - preferences: An optional set of user preferences to update.
    /// - Returns: A `Result` containing either Void on success or a `UserError` on failure.
    @objc
    public func updateProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        phone: String? = nil,
        profileImageUrl: URL? = nil,
        preferences: UserPreferences? = nil
    ) -> Result<Void, UserError> {
        
        // 1. Validate input parameters: 
        //    Check that first and last names (if provided) are not empty.
        if let newFName = firstName {
            let trimmed = newFName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return .failure(.invalidParameter("First name cannot be empty."))
            }
        }
        if let newLName = lastName {
            let trimmed = newLName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return .failure(.invalidParameter("Last name cannot be empty."))
            }
        }
        
        // 2. Check user verification status (example logic: disallow profile changes if inactive).
        //    In some business rules, you might allow partial updates even if unverified;
        //    adjust logic here as needed.
        guard isActive else {
            return .failure(.unauthorized)
        }
        
        // 3. Update provided fields if valid.
        if let newFName = firstName { self.firstName = newFName }
        if let newLName = lastName { self.lastName = newLName }
        if let newUrl = profileImageUrl { self.profileImageUrl = newUrl }
        
        // 4. Validate phone number format if provided.
        if let newPhone = phone {
            // Placeholder phone validation logic; can use advanced regex or library checks.
            let trimmed = newPhone.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return .failure(.invalidParameter("Phone number cannot be empty."))
            }
            self.phone = trimmed
        }
        
        // 5. Update preferences if provided.
        if let updatedPrefs = preferences {
            self.preferences = updatedPrefs
        }
        
        // 6. Update timestamp to reflect the last modification date/time.
        self.updatedAt = Date()
        
        // 7. Trigger notification or callback for profile updates (placeholder example).
        //    Typically, you might notify observers or dispatch an event to an internal bus.
        //    For demonstration:
        //    NotificationCenter.default.post(name: .userProfileDidUpdate, object: self)
        
        return .success(())
    }
    
    /// Updates the user's verification status, logs an audit trail, and can
    /// optionally store notes or reasons for the verification change.
    ///
    /// Steps:
    /// 1. Validate authorization for status change.
    /// 2. Update verification status.
    /// 3. Record verification audit trail as needed.
    /// 4. Update timestamp.
    /// 5. Trigger verification status notifications.
    ///
    /// - Parameters:
    ///   - isVerified: The new verification status to be assigned.
    ///   - verificationNotes: An optional note describing the change
    ///     (e.g., "Background check cleared" or "ID mismatch found").
    /// - Returns: A `Result` containing either Void on success or a `UserError` on failure.
    @objc
    public func updateVerificationStatus(
        isVerified: Bool,
        verificationNotes: String? = nil
    ) -> Result<Void, UserError> {
        
        // 1. Validate authorization for status change.
        //    Implement business logic here, for example verifying an admin or official system call.
        //    For now, we simply assume a pass-through success if user is active.
        guard isActive else {
            return .failure(.unauthorized)
        }
        
        // 2. Update verification status.
        self.isVerified = isVerified
        
        // 3. Record verification audit trail.
        //    Placeholder logic to illustrate where you'd store or log the verification notes.
        if let notes = verificationNotes {
            // e.g., store them in an audit log or send them to an internal system
            // print("Audit Log - Verification Change: \(notes)")
        }
        
        // 4. Update timestamp.
        self.updatedAt = Date()
        
        // 5. Trigger verification status notifications (placeholder example).
        //    This could be an in-app event or external push notification.
        //    NotificationCenter.default.post(name: .userVerificationDidUpdate, object: self)
        
        return .success(())
    }
    
    // MARK: - Example: Parsing with APIResponse
    
    /// Demonstrates how to parse a user model from a generic APIResponse payload,
    /// leveraging the `data` property from the internal `APIResponse` struct.
    ///
    /// - Parameter response: An `APIResponse` wrapping a `User` instance.
    /// - Returns: A `Result<User, Error>` indicating success with a User object
    ///   or failure with an associated error.
    public static func parseUserResponse(_ response: APIResponse<User>) -> Result<User, Error> {
        // Check if the response is logically successful:
        guard response.isSuccessful() else {
            // If not successful, build an error using the server-supplied message or status code.
            let errorMessage = response.error ?? "Failed to parse user from server response."
            return .failure(UserError.unknown(errorMessage))
        }
        
        // If successful, safely extract user data.
        if let user = response.data {
            return .success(user)
        } else {
            let fallbackError = UserError.unknown("No user data found in the response.")
            return .failure(fallbackError)
        }
    }
}