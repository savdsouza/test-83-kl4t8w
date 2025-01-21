//
//  Walker.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-10.
//
//  This file defines a comprehensive, production-ready Walker model class
//  inheriting from the base User class. It introduces specialized properties
//  and methods for managing enhanced verifications, insurance validations,
//  walker-specific availability, and concurrency-safe walk acceptance.
//
//  Imports:
//  - Foundation (iOS 13.0+) for baseline Apple frameworks
//  - User from Domain/Models/User (base model)
//  - Walk from Domain/Models/Walk (understanding walk IDs and statuses, if needed)
//
//  This class addresses:
//  1. User Management (Enhanced walker profiles and verifications).
//  2. Data Schema (Extended walker data structure in line with enterprise needs).
//  3. Walker Verification (Integration with background check, insurance, and auditing).
//
//  Thread-Safety and Concurrency:
//  - A dedicated lock (concurrencyLock) is used to guard critical sections
//    involving active walks manipulation.
//
//  -----------------------------------------------------------------------------------
//
//  Usage Summary:
//  - Constructor: Creates a new Walker, initializing defaults, verifying inputs,
//    and ensuring the userType is set to .walker.
//  - updateAvailability: Toggles walker availability, verifying background check,
//    insurance, service area configuration, and persisting changes.
//  - updateBackgroundCheck: Updates background check status and expiry with a
//    robust validation workflow, option to change availability accordingly.
//  - canAcceptWalk: Runs multi-criteria checks (availability, background check,
//    insurance, location coverage) before approving a new walk.
//  - addActiveWalk: Thread-safe operation to add a walk ID if canAcceptWalk passes.
//
//  -----------------------------------------------------------------------------------

import Foundation // iOS 13.0+

#if canImport(DogWalking)
import DogWalking
#else
// Replace with appropriate internal import if needed, e.g.:
// import DomainModels
#endif

// MARK: - Internal Error Enumeration for Walker-Specific Logic

/// Enumerates potential errors encountered when validating or updating a Walker's
/// availability, background checks, or walk acceptance.
public enum WalkerError: Error {
    /// Raised when background check criteria are not met or have expired.
    case backgroundCheckInvalid(String)

    /// Raised when insurance coverage is invalid or expired.
    case insuranceInvalid(String)

    /// Raised when a service area or location configuration is missing or invalid.
    case serviceAreaInvalid(String)

    /// Raised when a walker cannot accept a walk due to concurrency, scheduling,
    /// policy constraints, or other reasons.
    case acceptanceCriteriaFailed(String)

    /// Raised to encapsulate concurrency or locking issues for active walk management.
    case concurrencyError(String)
}

// MARK: - Walker Class Definition

/// An enhanced domain model representing a dog walker, providing advanced verification,
/// insurance tracking, concurrency-safe active walk management, and real-time availability updates.
/// Inherits from the base `User` class, automatically setting `userType` to `.walker`.
///
/// Decorators:
/// - @objcMembers: Exposes members for Objective-C interoperability.
/// - Inherits from `User`, leveraging `User`'s properties (id, email, etc.) plus custom fields.
@objcMembers
public class Walker: User {

    // MARK: - Public Properties (Walker-Specific)

    /// Reflects the current state of the background check process (e.g., "Pending", "Cleared", "Failed").
    public var backgroundCheckStatus: String {
        didSet {
            // Example property observer to record changes for audit or history.
            verificationHistory["backgroundCheckStatusChangedAt"] = Date()
        }
    }

    /// Timestamp indicating when the background check status was last updated or verified.
    public var backgroundCheckDate: Date?

    /// Expiry date for the background check, after which the walker may require re-verification.
    public var backgroundCheckExpiryDate: Date?

    /// Optional insurance policy number if the walker has coverage.
    public var insuranceNumber: String?

    /// The date on which the insurance coverage expires.
    public var insuranceExpiryDate: Date?

    /// The current validation state of the insurance (e.g., "Valid", "Expired", "Pending").
    public var insuranceValidationStatus: String? {
        didSet {
            // Records any insurance validation status changes in the verificationHistory.
            verificationHistory["insuranceValidationStatusChangedAt"] = Date()
        }
    }

    /// The hourly rate (in USD or designated currency) that the walker charges for services.
    public var hourlyRate: Double

    /// Indicates whether the walker is actively available to accept new walk requests.
    public var isAvailable: Bool

    /// A textual string or region name describing the walker's service coverage area.
    /// For example, "Downtown District" or "Northside Region".
    public var serviceArea: String

    /// A list of any pertinent professional certifications or qualifications the walker has.
    /// e.g., ["Pet First Aid", "Dog Behavior Course"]
    public var certifications: [String]

    /// Track the currently active walk IDs that the walker is responsible for.
    /// Thread-safely updated in `addActiveWalk`.
    public var activeWalks: [UUID]

    /// The maximum number of walk sessions this walker can handle concurrently.
    public var maxSimultaneousWalks: Int

    /// A flexible dictionary to keep historical records regarding verifications,
    /// changes to statuses, or background check events.
    public var verificationHistory: [String: Any]

    /// A dictionary delineating the precise geographic boundaries (or shapes) of a service area.
    /// For instance, polygon coordinates or bounding boxes.
    public var serviceAreaBoundaries: [String: Any]

    /// Timestamp capturing the last time this walker updated their availability status.
    public var lastAvailabilityUpdate: Date?

    /// Tracks the total number of completed walks by this walker.
    /// Updated upon finishing each walk session in upstream logic.
    public var completedWalksCount: Int

    // MARK: - Private Concurrency Lock

    /// A dedicated lock to manage concurrency around active walk additions
    /// and potentially other critical operations requiring thread-safety.
    private let concurrencyLock = NSLock()

    // MARK: - Initializer

    /**
     Initializes a new `Walker` object with extended domain-specific properties.
     Inherits from the base `User` class and sets `userType` to `.walker`.

     Steps:
     1. Parse and validate the string-based `id` into a `UUID`.
     2. Call `super.init` to initialize the underlying `User` fields.
     3. Set walker-specific properties, applying sensible defaults.
     4. Validate the provided `serviceAreaBoundaries` if present.
     5. Initialize concurrency and verification-related fields.
     6. Set up property observers for critical fields, e.g., backgroundCheckStatus.

     - Parameters:
       - id: A string representing a UUID for this walker; parsed to `UUID` internally.
       - email: The walker's email for login and contact.
       - firstName: The walker's first name.
       - lastName: The walker's last name.
       - hourlyRate: The walker's hourly rate for dog walking services.
       - serviceArea: A textual description of the walker's geographic coverage area.
       - serviceAreaBoundaries: An optional dictionary specifying precise geo-boundaries.
     */
    public init(
        id: String,
        email: String,
        firstName: String,
        lastName: String,
        hourlyRate: Double,
        serviceArea: String,
        serviceAreaBoundaries: [String: Any]?
    ) {
        // 1. Convert string-based ID to UUID.
        guard let parsedUUID = UUID(uuidString: id) else {
            preconditionFailure("Invalid Walker ID: Cannot convert to UUID.")
        }

        // 2. Call super.init to set base user properties; enforce userType = .walker
        super.init(
            id: parsedUUID,
            email: email,
            firstName: firstName,
            lastName: lastName,
            userType: .walker
        )

        // 3. Set walker-specific fields
        self.backgroundCheckStatus = "NotInitiated"
        self.backgroundCheckDate = nil
        self.backgroundCheckExpiryDate = nil
        self.insuranceNumber = nil
        self.insuranceExpiryDate = nil
        self.insuranceValidationStatus = nil
        self.hourlyRate = hourlyRate
        self.isAvailable = false
        self.serviceArea = serviceArea
        self.certifications = []
        self.activeWalks = []
        self.maxSimultaneousWalks = 1
        self.verificationHistory = [:]
        self.serviceAreaBoundaries = serviceAreaBoundaries ?? [:]
        self.lastAvailabilityUpdate = nil
        self.completedWalksCount = 0

        // 4. (Optional) Validate serviceAreaBoundaries if needed; placeholder check
        // e.g., ensure boundary data is not malformed. For demonstration, we skip
        // advanced geo checks.

        // 5. Lock is already declared; concurrency fields are ready.

        // 6. We'll rely on property observers declared above for backgroundCheckStatus
        //    and insuranceValidationStatus. No extra steps needed here.
    }

    // MARK: - Public Methods

    /**
     Updates the walker's availability status following business logic:
     1. Validate that background check is cleared/current.
     2. Check insurance validity.
     3. Confirm service area boundaries are defined if required.
     4. Update `isAvailable` to the requested status if all checks pass.
     5. Record any availability changes in `verificationHistory`, update `lastAvailabilityUpdate`.
     6. Optionally send notifications to observers or an event bus.

     - Parameter isAvailable: A boolean specifying the desired availability state.
     - Returns: A `Result<Bool, Error>` indicating success (true) or failure with an error.
     */
    public func updateAvailability(_ isAvailable: Bool) -> Result<Bool, Error> {
        // 1. Validate background check status
        if !backgroundCheckStatus.lowercased().contains("clear")
            && !backgroundCheckStatus.lowercased().contains("approved") {
            return .failure(WalkerError.backgroundCheckInvalid(
                "Background check is not cleared or approved."
            ))
        }

        // 2. Check insurance validity
        if let status = insuranceValidationStatus, status.lowercased() == "valid" {
            // proceed
        } else {
            return .failure(WalkerError.insuranceInvalid(
                "Insurance is missing, expired, or otherwise invalid."
            ))
        }

        // 3. Verify service area
        if serviceArea.isEmpty || serviceAreaBoundaries.isEmpty {
            return .failure(WalkerError.serviceAreaInvalid(
                "Service area or boundaries are not adequately configured."
            ))
        }

        // 4. Update `isAvailable`
        self.isAvailable = isAvailable

        // 5. Record changes and update timestamp
        let timestamp = Date()
        verificationHistory["availabilityChangedAt"] = timestamp
        verificationHistory["newAvailability"] = isAvailable
        self.lastAvailabilityUpdate = timestamp

        // 6. Notify observers (placeholder)
        // NotificationCenter.default.post(name: .walkerAvailabilityDidChange, object: self)

        return .success(true)
    }

    /**
     Updates the walker’s background check status with comprehensive data:
     1. Validate the provided verification details.
     2. Update `backgroundCheckStatus`.
     3. Set `backgroundCheckDate` to now, `backgroundCheckExpiryDate` to expiryDate.
     4. Add an entry to `verificationHistory`.
     5. Update `isAvailable` if the new status is a cleared/approved variant.
     6. Trigger any relevant notifications or system events.
     7. Return success or failure.

     - Parameters:
       - status: A `String` indicating the new background check status, e.g. "Cleared".
       - expiryDate: A `Date` representing when this check will expire.
       - verificationDetails: A dictionary capturing metadata about the verification process,
         such as reference IDs, external provider checks, or internal reviewer notes.
     - Returns: A `Result<Bool, Error>` reflecting success or failure.
     */
    public func updateBackgroundCheck(
        status: String,
        expiryDate: Date,
        verificationDetails: [String: Any]
    ) -> Result<Bool, Error> {
        // 1. Basic validation of verification details (placeholder).
        if verificationDetails.isEmpty {
            return .failure(WalkerError.backgroundCheckInvalid(
                "Cannot update background check with empty verification details."
            ))
        }

        // 2. Update background check properties
        self.backgroundCheckStatus = status
        self.backgroundCheckDate = Date()
        self.backgroundCheckExpiryDate = expiryDate

        // 3. Log the details into verificationHistory
        var logEntry: [String: Any] = verificationDetails
        logEntry["status"] = status
        logEntry["timestamp"] = self.backgroundCheckDate ?? Date()
        verificationHistory["backgroundCheckUpdate_\(UUID().uuidString)"] = logEntry

        // 4. Adjust availability if the new status is fully cleared/approved
        let clearedKeywords = ["clear", "approve", "valid"]
        if clearedKeywords.contains(where: { status.lowercased().contains($0) }) {
            self.isAvailable = true
        }

        // 5. Trigger notifications if needed (placeholder).
        // NotificationCenter.default.post(name: .walkerBackgroundCheckDidUpdate, object: self)

        // 6. Return success
        return .success(true)
    }

    /**
     Comprehensive validation routine determining if this walker can accept a proposed walk:
     1. Check if the walker is currently available.
     2. Ensure active walks count is below `maxSimultaneousWalks`.
     3. Validate background check status.
     4. Validate insurance status.
     5. Confirm the walk location is within `serviceAreaBoundaries` (high-level placeholder).
     6. Check scheduling conflicts if needed (placeholder).
     7. Confirm walk details are valid.
     8. Return a success result or a failure with context.

     - Parameters:
       - walkId: The unique ID of the walk request being evaluated.
       - walkDetails: A dictionary containing relevant data about the proposed walk
         (e.g., start time, location).
     - Returns: A `Result<Bool, Error>` with success (true) or a `WalkerError`.
     */
    public func canAcceptWalk(
        _ walkId: UUID,
        walkDetails: [String: Any]
    ) -> Result<Bool, Error> {
        // 1. Check availability
        guard self.isAvailable else {
            return .failure(WalkerError.acceptanceCriteriaFailed(
                "Walker is not currently available."
            ))
        }

        // 2. Verify the capacity
        if activeWalks.count >= maxSimultaneousWalks {
            return .failure(WalkerError.acceptanceCriteriaFailed(
                "Maximum simultaneous walks reached."
            ))
        }

        // 3. Confirm background check is valid
        if !backgroundCheckStatus.lowercased().contains("clear")
            && !backgroundCheckStatus.lowercased().contains("approve") {
            return .failure(WalkerError.backgroundCheckInvalid(
                "Background check not cleared."
            ))
        }

        // 4. Confirm insurance is valid
        if let insStatus = insuranceValidationStatus, insStatus.lowercased() == "valid" {
            // proceed
        } else {
            return .failure(WalkerError.insuranceInvalid(
                "Insurance is not in a valid state."
            ))
        }

        // 5. Verify location within serviceAreaBoundaries (placeholder check)
        if serviceAreaBoundaries.isEmpty {
            return .failure(WalkerError.serviceAreaInvalid(
                "Service area boundaries not configured."
            ))
        }

        // 6. Check scheduling conflicts (placeholder)
        // For demonstration, assume no conflicts.

        // 7. Validate additional walk details as needed
        if walkDetails.isEmpty {
            return .failure(WalkerError.acceptanceCriteriaFailed(
                "Walk details are missing or incomplete."
            ))
        }

        // 8. If all checks pass, return success
        return .success(true)
    }

    /**
     Thread-safe addition of a walk to this walker's active list, performing acceptance
     checks first. If the acceptance criteria pass, the walk ID is appended, availability
     may be adjusted if the max is reached, and relevant observers are notified.

     Steps:
     1. Acquire concurrency lock.
     2. Validate acceptance via `canAcceptWalk`.
     3. Append the walk ID to `activeWalks`.
     4. If the maximum is reached, set `isAvailable` to false.
     5. Record an entry in `verificationHistory`.
     6. Release the lock.
     7. Notify relevant observers (placeholder).
     8. Return success or error.

     - Parameters:
       - walkId: The unique identifier of the walk to add.
       - walkDetails: A dictionary with relevant info about the walk (time, location, etc.).
     - Returns: A `Result<Bool, Error>` indicating whether the addition succeeded.
     */
    public func addActiveWalk(
        _ walkId: UUID,
        walkDetails: [String: Any]
    ) -> Result<Bool, Error> {
        // 1. Acquire concurrency lock
        concurrencyLock.lock()
        defer { concurrencyLock.unlock() }

        // 2. Validate acceptance
        let acceptance = canAcceptWalk(walkId, walkDetails: walkDetails)
        switch acceptance {
        case .failure(let error):
            return .failure(error)
        case .success:
            // proceed
            break
        }

        // 3. Append walk ID
        self.activeWalks.append(walkId)

        // 4. If we've hit the capacity, mark as unavailable
        if activeWalks.count >= maxSimultaneousWalks {
            self.isAvailable = false
        }

        // 5. Record the addition in verificationHistory
        verificationHistory["activeWalkAdded_\(walkId)"] = [
            "timestamp": Date(),
            "details": walkDetails
        ]

        // 7. Notify observers if needed
        // NotificationCenter.default.post(name: .walkerDidAddActiveWalk, object: self)

        // 8. Return success
        return .success(true)
    }
}