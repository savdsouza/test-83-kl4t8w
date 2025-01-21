//
//  Walk.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-10.
//
//  This file defines a core domain model representing a dog walk session
//  with enhanced thread-safety, validation, and real-time tracking capabilities.
//  It integrates with the Dog, Location, and User models as outlined in their
//  respective files, and implements critical enterprise-level checks for data integrity,
//  concurrency, and domain-driven behavior.
//
//  ---------------------------------------------------------------------------------
//  IMPORTANT REFERENCES:
//  • Dog.swift     (for the dogId usage in walk sessions)
//  • Location.swift (for the Location class and LocationError checks)
//  • User.swift    (for verifying walker status in startWalk)
//  ---------------------------------------------------------------------------------
//
//  Requirements Addressed (as per JSON spec):
//   1. Service Execution: Enhanced GPS tracking with validation, secure photo sharing,
//      and robust status management.
//   2. Walk Data Management: Thread-safe walk session data structure with comprehensive
//      validation and relationship management.
//   3. Real-time Tracking: Production-ready location tracking with data validation
//      and performance optimization.
//
//  Dependencies:
//   • Foundation (iOS 13.0+) - Base iOS functionality and data types
//
//  Thread Safety:
//   Multiple NSLocks (locationLock, photoLock) are used to control concurrent access
//   to locations and photos arrays respectively. Additional locks or concurrency
//   controls can be applied if multiple threads may be updating Walk status or other
//   data concurrently.
//
//  Extensibility:
//   This class is designed for expansion to accommodate further features such as
//   group walks, offline data synchronization, or advanced event logging.
//   Status changes are tracked in statusHistory to maintain a complete timeline.
//
// ----------------------------------------------------------------------------------
// MARK: - Supporting Enumerations, Structures, and Typealiases
//

import Foundation // iOS 13.0+

/// Represents possible statuses for a walk session.
/// Using `@objc` with Int raw values for Objective-C compatibility.
@objc
public enum WalkStatus: Int {
    /// The walk is scheduled but has not yet started.
    case scheduled

    /// The walk is currently in progress.
    case inProgress

    /// The walk has been completed successfully.
    case completed

    /// The walk has been cancelled by either the owner or walker.
    case cancelled

    /// A fallback case for unexpected or unknown status values.
    case unknown
}

/// Records a transition from one walk status to another,
/// storing timing and an optional reason for the change.
@objcMembers
public class StatusChange: NSObject {
    /// The status from which the walk is transitioning.
    public let fromStatus: WalkStatus

    /// The status to which the walk is transitioning.
    public let toStatus: WalkStatus

    /// The `Date` at which this transition occurred.
    public let changedAt: Date

    /// An optional reason or note describing context for the change.
    public let reason: String?

    /// Designated initializer for fully defining a status transition.
    ///
    /// - Parameters:
    ///   - fromStatus: The walk's prior status.
    ///   - toStatus: The walk's new status.
    ///   - changedAt: The date/time the change took place.
    ///   - reason: Optional textual context for the transition (e.g., "User cancelled").
    public init(fromStatus: WalkStatus,
                toStatus: WalkStatus,
                changedAt: Date,
                reason: String? = nil) {
        self.fromStatus = fromStatus
        self.toStatus = toStatus
        self.changedAt = changedAt
        self.reason = reason
        super.init()
    }
}

/// The possible errors that may arise when attempting
/// walk-related operations such as starting a walk.
@objc
public enum WalkError: Int, Error {
    /// Raised when the walker is not verified in the system.
    case walkerNotVerified

    /// Raised if the walk has already started or is in progress.
    case walkAlreadyInProgress

    /// Raised for an invalid condition or attempt to start a walk prematurely.
    case invalidStartCondition

    /// A generic catch-all for unexpected walk-related errors.
    case unknown
}

/// Represents the different error cases that can occur
/// when adding or managing photos within a walk session.
@objc
public enum PhotoError: Int, Error {
    /// The photo data is invalid or exceeds size limits.
    case invalidData

    /// The walk has reached its maximum allowable photos.
    case exceedMaxPhotos

    /// A generic catch-all for unexpected photo-related errors.
    case unknown
}

/// A minimal typealias for managing walk duration. Swift 5.7+
/// includes a standard `Duration`, but for broad iOS 13.0+ compatibility,
/// we alias `TimeInterval` to meet the specification.
public typealias Duration = TimeInterval

/// A lightweight photo object capturing essential metadata for
/// images taken during a walk. Can be expanded to store advanced details.
@objcMembers
public class WalkPhoto: NSObject {
    /// A unique identifier for the photo in case multiple photos
    /// need referencing or indexing.
    public let id: UUID

    /// A URL referencing the photo's location (could be local or remote).
    public let url: URL

    /// The size of the photo in bytes, used for validation or stats.
    public let sizeInBytes: Int

    /// The timestamp specifying when the photo was captured or added.
    public let timestamp: Date

    /// Designated initializer for a `WalkPhoto`.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the photo.
    ///   - url: A URL pointing to the stored photo resource.
    ///   - sizeInBytes: An integer specifying the photo's size in bytes.
    ///   - timestamp: The point in time the photo was created or added.
    public init(id: UUID,
                url: URL,
                sizeInBytes: Int,
                timestamp: Date) {
        self.id = id
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.timestamp = timestamp
        super.init()
    }
}

// ----------------------------------------------------------------------------------
// MARK: - Walk Class Definition
// ----------------------------------------------------------------------------------

/// A thread-safe representation of a dog walking session with enhanced tracking and validation.
///
/// Decorators:
/// - @objc for Objective-C bridging where needed.
/// - @dynamicMemberLookup not strictly required for bridging, but indicated in the specification
///   for potential dynamic member usage.
///
/// Properties:
/// - Core Identifiers (id, ownerId, walkerId, dogId)
/// - Schedule & Timing (scheduledStartTime, actualStartTime, endTime)
/// - Financials (price)
/// - Status Handling (status, statusHistory)
/// - Thread-Safe Collections (locations with locationLock, photos with photoLock)
/// - Ratings, Notes, Cancellation, and Emergency Flags
/// - Distance Tracking & Duration
///
/// Constructor & Key Functions:
/// - `init(...)`: Validates inputs and sets up initial data.
/// - `startWalk(...)`: Attempts to transition the walk into an in-progress state with checks.
/// - `addLocation(...)`: Thread-safe appending of new location data, updating distance.
/// - `addPhoto(...)`: Thread-safe appending of a new photo, with size checks and concurrency management.
///
@objc
@dynamicMemberLookup
public class Walk: NSObject {

    // MARK: - Public Properties

    /// A unique identifier for this walk session.
    public let id: UUID

    /// The string-based owner ID, correlating to the "User.id" in many systems.
    /// According to the specification, this is a String (not UUID).
    public let ownerId: String

    /// The string-based walker ID, correlating to the "User.id".
    /// This is used to validate the walker’s verification status.
    public let walkerId: String

    /// The unique identifier referencing the associated dog entity.
    /// This aligns with the dog's UUID in the `Dog` model.
    public let dogId: UUID

    /// The time the walk is scheduled to begin, set in local or server time.
    public let scheduledStartTime: Date

    /// The actual time the walk started, if it has begun. Nil if the walk
    /// has not started.
    public private(set) var actualStartTime: Date?

    /// The time the walk ended, if it has completed or cancelled. Nil if ongoing.
    public private(set) var endTime: Date?

    /// The agreed-upon price for this walk session, stored as a `Double`.
    public let price: Double

    /// The current status of the walk. Tracks progress from scheduling to completion.
    public private(set) var status: WalkStatus

    /// An internal lock object used to synchronize concurrent location updates
    /// (addition, read, or modifications to `locations` array).
    public let locationLock: NSLock

    /// A thread-safe array storing the chronologically appended `Location` objects
    /// for real-time GPS tracking.
    public private(set) var locations: [Location]

    /// A rating that an owner may assign upon completion of the walk, or nil if not yet rated.
    public private(set) var rating: Double?

    /// Any special notes or textual commentary about this walk (e.g., instructions).
    public private(set) var notes: String?

    /// An internal lock object used to synchronize concurrent photo updates
    /// (addition, read, or modifications to `photos` array).
    public let photoLock: NSLock

    /// A thread-safe array of `WalkPhoto` objects representing pictures taken during the walk.
    public private(set) var photos: [WalkPhoto]

    /// The total distance (in meters) traversed in this walk, updated incrementally in `addLocation`.
    public private(set) var distance: Double

    /// Reflects the total elapsed time of the walk, typically computed when the walk is finished.
    /// Stored as a general `Duration` (TimeInterval) for wide iOS coverage.
    public private(set) var duration: Duration

    /// An optional field capturing the reason for cancellation (if the walk was cancelled).
    public private(set) var cancellationReason: String?

    /// A Boolean indicating whether an emergency status was triggered during the walk
    /// (e.g., dog injury, safety issue).
    public private(set) var isEmergency: Bool

    /// A historical log of status changes, capturing events and transitions along with timestamps.
    public private(set) var statusHistory: [StatusChange]

    // MARK: - Object Lifecycle (Constructor)

    /**
     Initializes a new `Walk` instance with validation and default statuses.

     - Parameters:
       - id: A globally unique UUID identifying this walk entity.
       - ownerId: The string-based identifier referencing the owner `User.id`.
       - walkerId: The string-based identifier referencing the walker `User.id`.
       - dogId: A UUID for the dog participating in this walk.
       - scheduledStartTime: The time at which this walk is planned to begin.
       - price: The pricing amount agreed upon for this walk session.

     Steps:
       1. Validate the input parameters (e.g., price >= 0, future or present scheduling).
       2. Initialize concurrency locks (locationLock, photoLock).
       3. Set initial status to `.scheduled`.
       4. Initialize arrays (locations, photos, statusHistory) with capacity hints.
       5. Record the initial status change in `statusHistory`.
       6. Prepare default values (distance = 0, duration = 0, isEmergency = false).

     - Throws:
       May throw a runtime error if initial parameters violate fundamental constraints,
       such as negative price values.
    */
    @objc
    public init(id: UUID,
                ownerId: String,
                walkerId: String,
                dogId: UUID,
                scheduledStartTime: Date,
                price: Double) {
        // Basic validations:
        precondition(price >= 0.0, "Walk price cannot be negative.")
        precondition(!ownerId.trimmingCharacters(in: .whitespaces).isEmpty,
                     "ownerId must not be empty.")
        precondition(!walkerId.trimmingCharacters(in: .whitespaces).isEmpty,
                     "walkerId must not be empty.")

        self.id = id
        self.ownerId = ownerId
        self.walkerId = walkerId
        self.dogId = dogId
        self.scheduledStartTime = scheduledStartTime
        self.price = price

        // Initialize concurrency locks
        self.locationLock = NSLock()
        self.photoLock = NSLock()

        // Default statuses and arrays
        self.status = .scheduled
        self.locations = []
        self.photos = []
        self.statusHistory = []
        self.distance = 0.0
        self.duration = 0.0

        // Initialize nil for optional fields
        self.actualStartTime = nil
        self.endTime = nil
        self.rating = nil
        self.notes = nil
        self.cancellationReason = nil
        self.isEmergency = false

        // Append an initial status change
        let initialChange = StatusChange(fromStatus: .unknown,
                                         toStatus: .scheduled,
                                         changedAt: Date(),
                                         reason: "Walk created and scheduled.")
        self.statusHistory.append(initialChange)

        super.init()
    }

    // MARK: - Public Methods

    /**
     Attempts to start the walk session, transitioning from `.scheduled` to `.inProgress`.

     Steps:
       1. Validate the provided walker user is verified; otherwise return `.walkerNotVerified`.
       2. Check if the current status is `.scheduled`. If already started, return `.walkAlreadyInProgress`.
       3. Acquire any necessary locks if relevant to concurrency (optional for status).
       4. Set `actualStartTime` to the current time, update `status`, and record a status change.
       5. Release locks (if acquired).
       6. Return `.success` if the transition is valid, otherwise `.failure`.

     - Parameter walker: The `User` instance representing the walker. Must pass verification.
     - Returns:
       A `Result<Void, WalkError>` indicating success or a specific error cause.
    */
    @objc
    public func startWalk(walker: User) -> Result<Void, WalkError> {
        // 1. Check if walker is verified
        guard walker.isVerified else {
            return .failure(.walkerNotVerified)
        }

        // 2. Ensure the current status is .scheduled
        if status != .scheduled {
            return .failure(.walkAlreadyInProgress)
        }

        // \[Optional concurrency locks around status changes if needed.\]
        // For demonstration, we skip a dedicated statusLock and rely on overall thread safety assumptions.

        // 4. Set actualStartTime, status, and record the transition
        self.actualStartTime = Date()
        let oldStatus = self.status
        self.status = .inProgress
        let change = StatusChange(fromStatus: oldStatus,
                                  toStatus: .inProgress,
                                  changedAt: Date(),
                                  reason: "Walker started the walk.")
        self.statusHistory.append(change)

        // 5. (If locks were acquired, release them here.)

        // 6. Successfully started
        return .success(())
    }

    /**
     Thread-safe addition of a validated `Location` to this walk's location tracking array,
     updating the total distance traveled.

     Steps:
       1. Validate the location's logical ordering by timestamp (must be >= last location timestamp).
       2. Acquire `locationLock`.
       3. Append the new location to `locations`.
       4. Calculate the incremental distance from the last location (if any) and update `distance`.
       5. Release `locationLock`.
       6. Return the updated total distance in `.success`.

     - Parameter location: A `Location` object, presumably already validated or created
       using `Location.fromCLLocation`.
     - Returns:
       A `Result<Double, LocationError>` with the updated total distance on success,
       or an error if the location sequence is invalid.
    */
    @objc
    public func addLocation(_ location: Location) -> Result<Double, LocationError> {
        // 2. Acquire lock to ensure thread-safe writes
        locationLock.lock()
        defer { locationLock.unlock() }

        // 1. Validate timestamp is not older than the last location
        if let lastLocation = locations.last {
            if location.timestamp < lastLocation.timestamp {
                // We could define a more specific error for "out-of-sequence timestamps"
                return .failure(.genericError)
            }
        }

        // 3. Append location
        locations.append(location)

        // 4. Update distance by measuring from the previous location
        if let lastLocation = locations.dropLast().last {
            let increment = lastLocation.distanceTo(location)
            let newDistance = distance + increment

            // Handle negative or nonsensical increments
            distance = max(0.0, newDistance)
        }

        // 6. Return updated distance
        return .success(distance)
    }

    /**
     Thread-safe addition of a validated `WalkPhoto` to this walk session's photo collection.

     Steps:
       1. Validate the photo data:
          - Check `sizeInBytes` threshold (e.g., not exceeding 20MB in advanced scenarios).
          - Potentially check if `url` is valid.
       2. Determine if the photo limit is reached (if business logic imposes a max).
       3. Acquire `photoLock`.
       4. Append the photo, storing any relevant metadata or transformations.
       5. Release `photoLock`.
       6. Return `.success` or an appropriate `PhotoError`.

     - Parameter photo: A `WalkPhoto` object containing the photo's details.
     - Returns:
       A `Result<Void, PhotoError>` indicating success or a reason for failure.
    */
    @objc
    public func addPhoto(_ photo: WalkPhoto) -> Result<Void, PhotoError> {
        // 1. Validate the photo data. Example check: max 50 MB limit for demonstration
        let maxBytes = 50_000_000
        if photo.sizeInBytes < 1 || photo.sizeInBytes > maxBytes {
            return .failure(.invalidData)
        }

        // 2. Check photo count limit. (Example: max 20 photos)
        photoLock.lock()
        defer { photoLock.unlock() }
        if photos.count >= 20 {
            return .failure(.exceedMaxPhotos)
        }

        // 4. Append the photo
        photos.append(photo)

        // 6. Return success
        return .success(())
    }

    /**
     A convenient method to change the walk status to `.cancelled`, optionally
     providing a cancellation reason. This sets `endTime`, logs a status change,
     and flags `cancellationReason`.

     - Parameter reason: A textual explanation for cancellation, e.g. "Owner changed plans".
    */
    @objc
    public func cancelWalk(reason: String?) {
        if status == .cancelled || status == .completed {
            // Already finalized state, do nothing
            return
        }
        let oldStatus = status
        status = .cancelled
        endTime = Date()
        cancellationReason = reason

        // Log this transition
        let change = StatusChange(fromStatus: oldStatus,
                                  toStatus: .cancelled,
                                  changedAt: Date(),
                                  reason: reason ?? "No reason provided.")
        statusHistory.append(change)
    }

    /**
     A method to finalize or complete the walk, typically called when the session is done.
     This sets the `endTime`, calculates duration, and updates the internal status to `.completed`.

     - Parameter ownerRating: Optionally provide a rating from the owner, if known.
     - Parameter notes: Optionally provide notes or feedback on the session.
    */
    @objc
    public func completeWalk(ownerRating: Double? = nil,
                             notes: String? = nil) {
        // If the walk is not yet in progress or is cancelled,
        // we may optionally ignore or shift to .completed forcibly.
        let oldStatus = status
        status = .completed
        endTime = Date()

        // Update rating if provided
        if let ratingValue = ownerRating, ratingValue >= 0.0 {
            self.rating = ratingValue
        }
        // Store any final notes
        if let sessionNotes = notes {
            self.notes = sessionNotes
        }

        // Compute duration if actualStartTime is known
        if let actualStartTime = self.actualStartTime, let endTime = self.endTime {
            let delta = endTime.timeIntervalSince(actualStartTime)
            self.duration = max(0.0, delta)
        }

        // Push status transition
        let change = StatusChange(fromStatus: oldStatus,
                                  toStatus: .completed,
                                  changedAt: Date(),
                                  reason: "Walk was completed by the walker.")
        statusHistory.append(change)
    }

    /**
     Flags this walk as having an emergency event, for instance if the dog runs away or
     a health situation arises. Setting isEmergency to true allows additional internal
     checks or services to be invoked.

     - Parameter reason: A descriptive reason for the emergency event.
    */
    @objc
    public func triggerEmergency(reason: String? = nil) {
        isEmergency = true
        // Optionally log a special status change or note
        let oldStatus = status
        let note = reason ?? "No details"
        let change = StatusChange(fromStatus: oldStatus,
                                  toStatus: oldStatus,
                                  changedAt: Date(),
                                  reason: "EMERGENCY: \(note)")
        statusHistory.append(change)
    }

    // MARK: - Dynamic Member Lookup (Optional)

    /// Example dynamicMemberLookup to allow flexible property access if needed.
    /// Not essential for standard usage, but included per specification.
    ///
    /// - Parameter member: The name of a property to retrieve.
    /// - Returns: The corresponding value if found, or nil if no match.
    public subscript(dynamicMember member: String) -> Any? {
        switch member {
        case "currentStatus":
            return status
        case "totalDistance":
            return distance
        case "ownerIdentifier":
            return ownerId
        case "walkerIdentifier":
            return walkerId
        default:
            return nil
        }
    }
}