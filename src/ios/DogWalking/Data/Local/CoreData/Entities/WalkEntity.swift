//
//  WalkEntity.swift
//  DogWalking
//
//  Created by Elite Software Architect on 2023-10-15.
//
//  This file defines a thread-safe NSManagedObject subclass (WalkEntity)
//  responsible for persisting and managing dog walk sessions with extensive
//  validation, data compression, and secure handling of domain-critical fields.
//  Its methods facilitate robust data transformations between the CoreData
//  entity layer and the Walk domain model for offline-first, enterprise-grade
//  usage.
//
//  ---------------------------------------------------------------------------------
//  Requirements Addressed (as per JSON spec):
//    1. Data Management Strategy (Technical Specifications/3.2.2):
//       - Implements secure local persistence with data compression for offline-first.
//       - Validates essential fields and ensures thread safety via NSManagedObjectContext.
//    2. Walk Data Management (Technical Specifications/3.2.1):
//       - Robust CoreData schema with typed properties (UUID, Date, Double, etc.).
//       - Proper data validation and concurrency controls to maintain consistent state.
//    3. Service Execution (Technical Specifications/1.3 Scope/Core Features):
//       - Efficient storage and compression of GPS/Fitness-like data (locations).
//       - Photo storage through URLs, version history in statusHistory if needed.
//       - Real-time update readiness with syncStatus and lastModified.
//
//  ---------------------------------------------------------------------------------
//  Dependencies & Imports:
//    • Foundation // iOS 13.0+
//    • CoreData   // iOS 13.0+
//    • Compression // iOS 13.0+ (for data compression/decompression)
//    • Domain Model "Walk" (from Domain/Models/Walk.swift), ensuring thread safety
//
//  ---------------------------------------------------------------------------------
//  Usage Notes:
//    • The WalkEntity class is designed for code generation in Xcode,
//      typically paired with a matching .xcdatamodeld entry referencing
//      these properties.
//    • The compress/decompress methods use Apple's Compression framework
//      for demonstration. Production code should handle edge cases
//      (e.g., corrupted data) more gracefully.
//    • For best concurrency practices, calls to toDomainModel() and
//      update(:) wrap their logic in NSManagedObjectContext performAndWait().
//
//  ---------------------------------------------------------------------------------
//  Disclaimer:
//    This is an enterprise-grade example that includes verbose validation,
//    error handling, thread safety details, and data compression techniques.
//    Adapt the logic to your real-world app environment and security policies.
//

import Foundation // iOS 13.0+
import CoreData   // iOS 13.0+
import Compression // iOS 13.0+

// Importing the domain model "Walk" and all necessary types (WalkStatus, Location, etc.).
// Adjust this import statement or module name as appropriate for your project setup.
import DogWalking

/// An error type capturing possible failures within WalkEntity operations.
enum WalkEntityError: Error {
    /// Context unavailable or invalid, preventing thread-safe CoreData operations.
    case missingManagedObjectContext

    /// A generic error for invalid or corrupt compressed data fields.
    case decompressionFailed(String)

    /// A generic error for unencodable or uncompressible data during updates.
    case compressionFailed(String)

    /// A generic error indicating a missing or invalid domain property.
    case invalidProperty(String)

    /// A fallback for unexpected issues within the entity's logic.
    case unknown(String)
}

/// Represents a thread-safe NSManagedObject subclass for walk session persistence.
/// This class implements comprehensive validation, compression, and domain mapping
/// to fulfill the robust data management requirements in the Dog Walking application.
///
/// Decorators and Metadata:
/// - @objc(WalkEntity) for Objective-C bridging if needed.
/// - NSManaged properties for implicit dynamic dispatch from the CoreData runtime.
///   Must match the .xcdatamodeld configuration.
@objc(WalkEntity)
public class WalkEntity: NSManagedObject {

    // MARK: - CoreData Properties

    /// Uniquely identifies the walk session. Typically stored as a UUID attribute in CoreData.
    @NSManaged public var id: UUID

    /// String-based owner identifier (maps to `User.id`, typically).
    @NSManaged public var ownerId: String

    /// String-based walker identifier (maps to `User.id`, typically).
    @NSManaged public var walkerId: String

    /// Dog reference ID, correlating to the dog's UUID (see Dog model).
    @NSManaged public var dogId: UUID

    /// The scheduled start date/time for this walk, as decided by the owner.
    @NSManaged public var scheduledStartTime: Date

    /// The actual time the walk began, if in progress or completed.
    @NSManaged public var actualStartTime: Date?

    /// The ending time for the walk if completed or canceled.
    @NSManaged public var endTime: Date?

    /// The agreed-upon price for this walk session.
    @NSManaged public var price: Double

    /// The walk's current status, stored as a 16-bit integer. Must map correctly to `WalkStatus`.
    @NSManaged public var status: Int16

    /// A Data blob containing compressed JSON for the array of location points.
    @NSManaged public var locationsData: Data

    /// An optional numeric rating set by the owner upon completion.
    @NSManaged public var rating: Double?

    /// A textual field for notes or instructions (optional).
    @NSManaged public var notes: String?

    /// A Data blob containing compressed JSON for an array of photo URLs.
    @NSManaged public var photoUrlsData: Data

    /// Total distance (in meters) covered during the walk, regularly updated.
    @NSManaged public var distance: Double

    /// Total duration of the walk in seconds, typically computed when completing.
    @NSManaged public var duration: Double

    /// Contains the compressed JSON data representing the walk's status transitions.
    @NSManaged public var statusHistory: Data?

    /// Tracks the last time this record was updated, used for synchronization logic.
    @NSManaged public var lastModified: Date

    /// An integer representing the local synchronization status of this record
    /// (e.g., 0 = pending, 1 = synced, 2 = conflict, etc.).
    @NSManaged public var syncStatus: Int16


    // MARK: - Public Methods

    /// Converts this CoreData entity into a domain-level `Walk` model with comprehensive
    /// validation, data decompression, and concurrency safeguards.
    ///
    /// Steps:
    ///  1. Perform thread-safe access via `performAndWait` on the entity's NSManagedObjectContext.
    ///  2. Validate mandatory fields and ensure data presence (e.g. `id`, `ownerId`).
    ///  3. Decompress and decode `locationsData` into `[Location]`.
    ///  4. Decompress and decode `photoUrlsData` into `[URL]`.
    ///  5. Map `status` (Int16) into the domain enum `WalkStatus`.
    ///  6. Decompress and decode `statusHistory` if present.
    ///  7. Instantiate a `Walk`, set optional fields (rating, notes, etc.), and return success.
    ///
    /// - Returns: A `Result<Walk, Error>` containing the domain model on success
    ///   or an error detailing the failure.
    public func toDomainModel() -> Result<Walk, Error> {
        guard let context = self.managedObjectContext else {
            return .failure(WalkEntityError.missingManagedObjectContext)
        }

        var operationResult: Result<Walk, Error> = .failure(WalkEntityError.unknown("Unknown error in toDomainModel."))

        context.performAndWait {
            do {
                // Validate essential properties.
                if ownerId.trimmingCharacters(in: .whitespaces).isEmpty {
                    throw WalkEntityError.invalidProperty("ownerId cannot be empty.")
                }
                if walkerId.trimmingCharacters(in: .whitespaces).isEmpty {
                    throw WalkEntityError.invalidProperty("walkerId cannot be empty.")
                }
                if price < 0 {
                    throw WalkEntityError.invalidProperty("price cannot be negative.")
                }

                // Decompress and decode location data.
                let rawLocations = try self.decompressData(self.locationsData)
                let locationsArray = try JSONDecoder().decode([Location].self, from: rawLocations)

                // Decompress and decode photo URLs.
                let rawPhotos = try self.decompressData(self.photoUrlsData)
                let urlStrings = try JSONDecoder().decode([String].self, from: rawPhotos)
                let photoUrls = urlStrings.compactMap { URL(string: $0) }

                // Map status from Int16 -> WalkStatus
                let resolvedStatus = WalkStatus(rawValue: Int(self.status)) ?? .unknown

                // If we have a statusHistory blob, decode it; otherwise use empty array.
                var decodedStatusChanges: [StatusChange] = []
                if let historyData = self.statusHistory {
                    let decompressedHistory = try self.decompressData(historyData)
                    decodedStatusChanges = try JSONDecoder().decode([StatusChange].self, from: decompressedHistory)
                }

                // Construct the domain Walk using the base initializer.
                // The domain model's initializer sets default concurrency locks & arrays.
                let domainWalk = Walk(
                    id: self.id,
                    ownerId: self.ownerId,
                    walkerId: self.walkerId,
                    dogId: self.dogId,
                    scheduledStartTime: self.scheduledStartTime,
                    price: self.price
                )

                // Optional fields assigned after init:
                domainWalk.actualStartTime = self.actualStartTime
                domainWalk.endTime = self.endTime
                domainWalk.notes = self.notes
                domainWalk.rating = self.rating
                domainWalk.distance = self.distance
                domainWalk.duration = self.duration
                domainWalk.status = resolvedStatus

                // Overwrite locations in a thread-safe manner:
                domainWalk.locationLock.lock()
                domainWalk.locations = locationsArray
                domainWalk.locationLock.unlock()

                // Overwrite photoUrls in a thread-safe manner:
                // For consistency with the JSON spec, we assume domainWalk has a photoUrls property.
                // If the real domain class differs, adapt accordingly.
                domainWalk.photoLock.lock()
                domainWalk.photoUrls = photoUrls
                domainWalk.photoLock.unlock()

                // Update statusHistory with decoded transitions:
                domainWalk.statusHistory.removeAll()
                domainWalk.statusHistory.append(contentsOf: decodedStatusChanges)

                // On success, produce a .success result.
                operationResult = .success(domainWalk)
            } catch {
                operationResult = .failure(error)
            }
        }

        return operationResult
    }

    /// Performs a thread-safe update of this CoreData entity with data from
    /// the given domain `Walk` model, applying validation, compression, and
    /// concurrency controls to keep local storage consistent and offline-safe.
    ///
    /// Steps:
    ///  1. Validate the incoming `Walk` object (e.g., non-negative price).
    ///  2. Perform thread-safe updates in `performAndWait`.
    ///  3. Convert and compress `walk.locations` -> JSON -> `locationsData`.
    ///  4. Convert and compress `walk.photoUrls` -> JSON -> `photoUrlsData`.
    ///  5. Update `status` if changed, appending a status transition to `statusHistory`.
    ///  6. Set `lastModified` to the current time, update `syncStatus` as needed.
    ///  7. Return `.success` or `.failure` with any encountered error.
    ///
    /// - Parameter walk: The domain model data used to update this entity.
    /// - Returns: A `Result<Void, Error>` indicating success or error details.
    public func update(walk: Walk) -> Result<Void, Error> {
        guard let context = self.managedObjectContext else {
            return .failure(WalkEntityError.missingManagedObjectContext)
        }

        var operationResult: Result<Void, Error> = .failure(WalkEntityError.unknown("Unknown error in update."))

        context.performAndWait {
            do {
                // Step 1: Validate input walk model.
                if walk.ownerId.trimmingCharacters(in: .whitespaces).isEmpty {
                    throw WalkEntityError.invalidProperty("ownerId cannot be empty.")
                }
                if walk.walkerId.trimmingCharacters(in: .whitespaces).isEmpty {
                    throw WalkEntityError.invalidProperty("walkerId cannot be empty.")
                }
                if walk.price < 0 {
                    throw WalkEntityError.invalidProperty("price cannot be negative.")
                }

                // Map domain status (WalkStatus) -> Int16
                let newStatusRaw = Int16(walk.status.rawValue)

                // Step 2: Basic scalar properties
                self.id = walk.id
                self.ownerId = walk.ownerId
                self.walkerId = walk.walkerId
                self.dogId = walk.dogId
                self.scheduledStartTime = walk.scheduledStartTime
                self.actualStartTime = walk.actualStartTime
                self.endTime = walk.endTime
                self.price = walk.price
                self.notes = walk.notes
                self.rating = walk.rating
                self.distance = walk.distance
                self.duration = walk.duration

                // Step 3: Compress and encode locations
                walk.locationLock.lock()
                let locData = try JSONEncoder().encode(walk.locations)
                walk.locationLock.unlock()
                self.locationsData = try self.compressData(locData)

                // Step 4: Compress and encode photo URLs (converted to string array).
                walk.photoLock.lock()
                let urlStrings = walk.photoUrls.map { $0.absoluteString }
                walk.photoLock.unlock()
                let urlData = try JSONEncoder().encode(urlStrings)
                self.photoUrlsData = try self.compressData(urlData)

                // Step 5: Update status with optional history tracking
                if self.status != newStatusRaw {
                    // Decode existing status history if any.
                    var existingHistory: [StatusChange] = []
                    if let currentHistoryData = self.statusHistory {
                        let decompressed = try self.decompressData(currentHistoryData)
                        existingHistory = try JSONDecoder().decode([StatusChange].self, from: decompressed)
                    }

                    let oldStatus = WalkStatus(rawValue: Int(self.status)) ?? .unknown
                    let newStatus = walk.status
                    let transition = StatusChange(
                        fromStatus: oldStatus,
                        toStatus: newStatus,
                        changedAt: Date(),
                        reason: "Automated status update in update(walk:)."
                    )
                    existingHistory.append(transition)

                    // Re-encode and compress updated status history.
                    let updatedHistoryData = try JSONEncoder().encode(existingHistory)
                    self.statusHistory = try self.compressData(updatedHistoryData)

                    // Persist the new status integer.
                    self.status = newStatusRaw
                }

                // Step 6: Update lastModified and syncStatus
                self.lastModified = Date()
                // For demonstration, increment syncStatus or assign a default
                // if not defined. Real usage might set 0 = dirty, 1 = synced, etc.
                self.syncStatus = 0

                // Step 7: Indicate success
                operationResult = .success(())
            } catch {
                operationResult = .failure(error)
            }
        }

        return operationResult
    }

    // MARK: - Private Compression & Decompression Utilities

    /// Compresses the given data using Apple's Compression framework with LZFSE.
    /// Can be substituted with zlib/lz4 as needed. This is a demonstration of
    /// a typical in-memory compression routine in Swift.
    ///
    /// - Parameter data: The raw uncompressed data to compress.
    /// - Throws: `WalkEntityError.compressionFailed` if compression fails.
    /// - Returns: Compressed `Data`.
    private func compressData(_ data: Data) throws -> Data {
        let destinationBufferSize = compress_bound(data.count)
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)

        let bytesWritten = data.withUnsafeBytes { (srcPointer: UnsafeRawBufferPointer) -> size_t in
            return compression_encode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                srcPointer.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard bytesWritten != 0 else {
            throw WalkEntityError.compressionFailed("Failed to compress data.")
        }

        return Data(bytes: destinationBuffer, count: bytesWritten)
    }

    /// Decompresses the given data using Apple's Compression framework with LZFSE.
    /// Throws an error if the compressed data is corrupt or decompression fails.
    ///
    /// - Parameter data: The compressed data to decompress.
    /// - Throws: `WalkEntityError.decompressionFailed` if no valid decompression occurs.
    /// - Returns: Decompressed `Data`.
    private func decompressData(_ data: Data) throws -> Data {
        // We attempt a small multiplier for buffer expansions in a loop if needed.
        // For demonstration, we rely on an expanding approach. Production code can refine.
        let initialBufferSize = max(data.count * 4, 1024)
        var destinationBuffer = [UInt8](repeating: 0, count: initialBufferSize)

        let count = data.withUnsafeBytes { (srcPointer: UnsafeRawBufferPointer) -> size_t in
            return compression_decode_buffer(
                &destinationBuffer,
                initialBufferSize,
                srcPointer.bindMemory(to: UInt8.self).baseAddress!,
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        if count == 0 {
            throw WalkEntityError.decompressionFailed("Failed to decompress data or data is corrupt.")
        }

        // If we suspect incomplete buffer usage, attempt to re-allocate a larger buffer and retry.
        if count == initialBufferSize {
            // Doubling approach is used for demonstration:
            var expandedBufferSize = initialBufferSize * 2
            var successfulDecompression = false
            var finalData: Data?

            repeat {
                var attemptBuffer = [UInt8](repeating: 0, count: expandedBufferSize)
                let attemptCount = data.withUnsafeBytes { (srcPointer: UnsafeRawBufferPointer) -> size_t in
                    return compression_decode_buffer(
                        &attemptBuffer,
                        expandedBufferSize,
                        srcPointer.bindMemory(to: UInt8.self).baseAddress!,
                        data.count,
                        nil,
                        COMPRESSION_LZFSE
                    )
                }

                if attemptCount < expandedBufferSize {
                    finalData = Data(bytes: attemptBuffer, count: attemptCount)
                    successfulDecompression = true
                } else {
                    expandedBufferSize *= 2
                }
            } while !successfulDecompression && expandedBufferSize <= (Int.max / 2)

            guard let validData = finalData else {
                throw WalkEntityError.decompressionFailed("Data too large or corrupt. Could not decompress fully.")
            }

            return validData
        }

        // Otherwise, if count < initialBufferSize, we have a valid range.
        return Data(bytes: destinationBuffer, count: count)
    }

    /// Helper function for compression_bound, approximating an upper bound on compressed data size.
    private func compress_bound(_ sourceCount: Int) -> Int {
        // LZFSE doesn't have a documented fixed expansion ratio, so we pick a safe upper bound.
        // For demonstration, multiply by ~1.05 and add a constant overhead.
        return Int(Double(sourceCount) * 1.05) + 64
    }
}