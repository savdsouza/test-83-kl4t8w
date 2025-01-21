//
//  UserDefaultsManager.swift
//  DogWalking
//
//  Created by DogWalking Mobile Team
//  © 2023 DogWalking Inc. All rights reserved.
//
//  A thread-safe, singleton manager class providing secure, type-safe
//  access to UserDefaults for storing non-sensitive user preferences
//  and app settings. This implementation ensures data classification
//  validation, comprehensive logging, and robust error handling.
//
//  References:
//  - 7. SECURITY CONSIDERATIONS / 7.2 Data Security / 7.2.1 Data Classification
//  - 5. SYSTEM DESIGN / 5.2 Database Design / 5.2.2 Data Storage Strategy
//  - Internal Imports: AppConstants (StorageKeys, DataClassification), Logger
//  - External Import: Foundation (iOS 13.0+)
//

import Foundation // iOS 13.0+ (System framework for UserDefaults and core iOS functionalities)

// MARK: - Internal Imports
import struct DogWalking.AppConstants
import enum DogWalking.AppConstants.StorageKeys
import enum DogWalking.AppConstants.DataClassification
import class DogWalking.Logger

/// A specialized error enumeration covering invalid classification usage,
/// type mismatches, or underlying storage failures within UserDefaults.
public enum UserDefaultsManagerError: Error {
    /// Thrown when attempting to store a value with an unsupported data classification.
    case invalidClassification(String)
    /// Thrown when a type mismatch occurs while retrieving a value.
    case typeMismatch(String)
    /// Thrown when a UserDefaults operation fails due to an unexpected error.
    case storageFailure(String)
}

/**
 A thread-safe, singleton manager that provides:
 - Secure, type-safe access to UserDefaults (for non-sensitive data).
 - Comprehensive logging with the Logger class.
 - Data classification validation (only non-sensitive data is allowed).
 - Error handling returning Result types, ensuring robust failure details.
 */
public final class UserDefaultsManager {
    // MARK: - Public Singleton Access

    /// Provides global access to the singleton instance of UserDefaultsManager.
    public static let shared: UserDefaultsManager = UserDefaultsManager()

    // MARK: - Private Properties

    /// The underlying UserDefaults instance used for storing small amounts of non-sensitive data.
    private let defaults: UserDefaults

    /// A reference to the shared Logger instance, enabling debug and error logs with privacy handling.
    private let logger: Logger

    /**
     A dedicated serial dispatch queue ensuring that all read/write
     operations on UserDefaults occur in a thread-safe manner.
     */
    private let serialQueue: DispatchQueue

    /**
     A dictionary of default values registered on initialization to
     guarantee baseline data presence and consistent app behavior.
    */
    private let defaultValues: [String: Any]

    // MARK: - Private Initializer

    /**
     A private initializer enforcing singleton usage and performing:
     1. Serial queue allocation for thread-safety.
     2. Instantiation of UserDefaults.standard.
     3. Logger configuration using a subsystem/category string.
     4. Registration of default values.
     5. Initial synchronization.
     6. Setup of notification observers for potential backup/restore.
     */
    private init() {
        // 1. Create the serial queue for exclusive read/write operations.
        self.serialQueue = DispatchQueue(label: "com.dogwalking.UserDefaultsManager.serialQueue")

        // 2. Use the system-standard UserDefaults for storing non-sensitive data.
        self.defaults = UserDefaults.standard

        // 3. Initialize a privacy-aware logger for debugging and error tracking.
        //    The subsystem and category help isolate logs for this manager.
        self.logger = Logger(
            subsystem: "com.dogwalking.UserDefaultsManager",
            category: "UserDefaults"
        )

        // 4. Define optional default values to register upon creation.
        //    Adjust or expand as needed for your application’s baseline settings.
        self.defaultValues = [
            StorageKeys.APP_SETTINGS: [:]
        ]

        // Register defaults and synchronize so they are immediately available.
        self.defaults.register(defaults: self.defaultValues)
        self.defaults.synchronize()

        // 5. Perform any initial synchronization or housekeeping.
        //    For demonstration, we explicitly log a debug message here.
        self.logger.debug("UserDefaultsManager initialized and default values registered.")

        // 6. Optionally, set up notification observers if the app needs to handle
        //    backup or restore events, or if specialized sync logic is required.
        //    (Below is a simple placeholder for demonstration.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDefaultsNotification(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    // MARK: - Notification Handling

    /**
     A sample handler invoked whenever the UserDefaults storage values change.
     This can be extended to trigger backups or audits of changed data.
     */
    @objc
    private func handleUserDefaultsNotification(_ notification: Notification) {
        // For demonstration, we log a debug message whenever changes are detected.
        logger.debug("UserDefaults values have changed; potential sync or backup process may be triggered here.")
    }

    // MARK: - Public Methods

    /**
     Stores a type-safe value in UserDefaults, validating that we only handle
     non-sensitive classifications and logging relevant details.

     - Parameters:
       - value: The value to store. Must conform to a type that UserDefaults supports natively or can be archived.
       - key: A StorageKeys constant defining the unique key under which this value is stored.
       - classification: The data classification enum specifying sensitivity level.
     - Returns: A Result indicating success (true) or an error explaining the failure.
     */
    public func setValue<T>(
        _ value: T,
        for key: StorageKeys,
        classification: DataClassification
    ) -> Result<Bool, Error> {
        // Dispatch the set operation on the serial queue to ensure thread safety.
        return serialQueue.sync {
            do {
                // 1. Verify that the data classification is appropriate for UserDefaults.
                //    Only non-sensitive data is permitted here.
                guard classification == .nonSensitive else {
                    logger.error(
                        "Attempted to store a value with classification '\(classification)' in UserDefaults, which is not allowed.",
                        error: UserDefaultsManagerError.invalidClassification("Only nonSensitive is permitted.")
                    )
                    return .failure(UserDefaultsManagerError.invalidClassification("Classification not supported in UserDefaults."))
                }

                // 2. Attempt to store the value in UserDefaults. If the value is not natively supported,
                //    you may need to encode it (e.g., using PropertyListEncoder or NSKeyedArchiver).
                defaults.set(value, forKey: key)

                // 3. Log the operation with the debug-level logging.
                logger.debug("Successfully stored value for key '\(key)' in UserDefaults.")

                // 4. Return a success result if no exceptions occurred.
                return .success(true)
            } catch {
                // 5. Catch any unexpected errors during the set operation.
                logger.error(
                    "Unexpected error while setting value in UserDefaults for key '\(key)'",
                    error: UserDefaultsManagerError.storageFailure(error.localizedDescription)
                )
                return .failure(UserDefaultsManagerError.storageFailure("Set operation failed: \(error.localizedDescription)"))
            }
        }
    }

    /**
     Retrieves a type-safe value from UserDefaults, performing optional type validation
     and returning a typed result or detailed error.

     - Parameters:
       - key: A StorageKeys constant defining the unique key under which the value is expected.
     - Returns: A Result containing either the retrieved value (optional if not found) or an error if a type mismatch or other failure occurred.
     */
    public func getValue<T>(
        for key: StorageKeys
    ) -> Result<T?, Error> {
        // Dispatch the get operation on the serial queue for thread safety.
        return serialQueue.sync {
            do {
                // 1. Retrieve the raw value from UserDefaults. It may be nil if not set.
                let rawValue = defaults.object(forKey: key)

                // 2. If rawValue is nil, simply return .success(nil).
                guard let existingValue = rawValue else {
                    logger.debug("No value found in UserDefaults for key '\(key)'; returning nil.")
                    return .success(nil)
                }

                // 3. Attempt to cast to the desired type T.
                guard let typedValue = existingValue as? T else {
                    // Log an error indicating a type mismatch.
                    logger.error(
                        "Type mismatch retrieving value for key '\(key)'; expected \(T.self), got \(type(of: existingValue)).",
                        error: UserDefaultsManagerError.typeMismatch("Expected type \(T.self)")
                    )
                    return .failure(UserDefaultsManagerError.typeMismatch("Could not cast value to \(T.self)"))
                }

                // 4. Log a successful retrieval. The actual data is masked automatically by the logger's privacy patterns if needed.
                logger.debug("Successfully retrieved value for key '\(key)' from UserDefaults.")

                // 5. Return the typed value.
                return .success(typedValue)
            } catch {
                // 6. Catch any unexpected error and log it.
                logger.error(
                    "Unexpected error while retrieving value for key '\(key)'",
                    error: UserDefaultsManagerError.storageFailure(error.localizedDescription)
                )
                return .failure(UserDefaultsManagerError.storageFailure("Get operation failed: \(error.localizedDescription)"))
            }
        }
    }

    /**
     Removes a value from UserDefaults under the given StorageKeys identifier,
     ensuring thread safety and comprehensive error logging.

     - Parameters:
       - key: A StorageKeys constant defining the unique key to remove.
     - Returns: A Result indicating success (true) or an error explaining the failure.
     */
    public func removeValue(
        for key: StorageKeys
    ) -> Result<Bool, Error> {
        // Dispatch the removal operation on the serial queue.
        return serialQueue.sync {
            do {
                // 1. Check if the key already has an associated value.
                if defaults.object(forKey: key) == nil {
                    logger.debug("Value for key '\(key)' does not exist, no removal necessary.")
                    return .success(true)
                }

                // 2. Remove the value for the specified key.
                defaults.removeObject(forKey: key)

                // 3. Log the removal operation.
                logger.debug("Successfully removed value from UserDefaults for key '\(key)'.")

                // 4. Return a success result.
                return .success(true)
            } catch {
                // 5. Log any potential storage failure.
                logger.error(
                    "Unexpected error removing value for key '\(key)'",
                    error: UserDefaultsManagerError.storageFailure(error.localizedDescription)
                )
                return .failure(UserDefaultsManagerError.storageFailure("Remove operation failed: \(error.localizedDescription)"))
            }
        }
    }

    /**
     Clears all stored values in UserDefaults, optionally preserving the initially
     registered defaults. This method can be used to reset the application state.

     - Parameters:
       - preserveDefaults: A Boolean indicating whether the default values should
         be immediately re-registered after clearing the domain.
     - Returns: A Result indicating success (true) or an error explaining the failure.
     */
    public func clearAll(
        preserveDefaults: Bool
    ) -> Result<Bool, Error> {
        // Execute the clear operation within the serial queue.
        return serialQueue.sync {
            do {
                // 1. Optionally create a backup or archive if needed (omitted here for brevity).
                //    Log the start of the clear operation.
                logger.debug("Beginning clearAll operation on UserDefaults with preserveDefaults = \(preserveDefaults).")

                // 2. Remove the entire persistent domain associated with the app's bundle identifier.
                guard let domainName = Bundle.main.bundleIdentifier else {
                    logger.error(
                        "Failed to retrieve bundle identifier for clearing UserDefaults domain.",
                        error: UserDefaultsManagerError.storageFailure("Missing bundle identifier")
                    )
                    return .failure(UserDefaultsManagerError.storageFailure("Bundle identifier is nil; cannot clear defaults."))
                }
                defaults.removePersistentDomain(forName: domainName)

                // 3. If preserveDefaults is true, re-register the original default values.
                if preserveDefaults {
                    defaults.register(defaults: self.defaultValues)
                    logger.debug("Re-registered default values after clearing UserDefaults.")
                }

                // 4. Log the successful completion of the clear operation.
                logger.debug("Successfully cleared UserDefaults domain data.")

                // 5. Return a success result.
                return .success(true)
            } catch {
                // 6. Log and return any encountered error.
                logger.error(
                    "Unexpected error clearing all values in UserDefaults",
                    error: UserDefaultsManagerError.storageFailure(error.localizedDescription)
                )
                return .failure(UserDefaultsManagerError.storageFailure("ClearAll operation failed: \(error.localizedDescription)"))
            }
        }
    }
}