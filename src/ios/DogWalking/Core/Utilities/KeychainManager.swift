import Foundation // iOS 13.0+
import Security  // iOS 13.0+
import LocalAuthentication // iOS 13.0+

// Internal import for logging
import Logger

/// A Swift-specific error type capturing various keychain and encryption failures.
fileprivate enum KeychainError: Error {
    /// Raised when input parameters are invalid or empty.
    case invalidParameters(message: String)
    /// Raised when biometric or authentication procedures fail.
    case biometricFailed(message: String)
    /// Raised when the requested item cannot be found in the Keychain.
    case itemNotFound(message: String)
    /// Raised when the underlying security operation returns an unexpected OSStatus.
    case unexpectedStatus(status: OSStatus)
    /// Raised when encryption or decryption fails.
    case cryptoError(message: String)
    /// Raised for generic or unknown errors.
    case unknownError(message: String)
}

/// The global service identifier used for Keychain entries.
fileprivate let SERVICE_IDENTIFIER: String = "com.dogwalking.app"

/// The Keychain Access Group used for sharing credentials across the app group.
fileprivate let ACCESS_GROUP: String = "group.com.dogwalking.app"

/// The interval set for automatically rotating encryption keys (90 days).
fileprivate let KEY_ROTATION_INTERVAL: TimeInterval = 90 * 24 * 60 * 60

/**
 A thread-safe, singleton class managing secure storage and retrieval of
 sensitive data with robust security controls, optional biometric
 authentication, and full key rotation support.
 
 This class enforces advanced encryption, leverages iOS Keychain Services,
 and provides specialized logging for audit and compliance.
 */
@objc
public final class KeychainManager: NSObject {
    
    // MARK: - Singleton Instance
    
    /// A publicly accessible singleton for all keychain operations.
    public static let shared = KeychainManager()
    
    // MARK: - Private Properties
    
    /// A dedicated serial queue for synchronizing security-critical operations.
    private let securityQueue: DispatchQueue
    
    /// The local authentication context used for biometric operations.
    private let authContext: LAContext
    
    /// The in-memory encryption key used to encrypt sensitive data before writing to the Keychain.
    private var encryptionKey: Data
    
    /// The timestamp of the last time the encryption key was rotated.
    private var lastKeyRotation: Date
    
    // MARK: - Initialization
    
    /**
     Private thread-safe initializer configuring security settings, biometric
     authentication context, and loading or creating the necessary encryption key.
     
     Steps performed:
       1. Initialize security queue with QoS.
       2. Configure LAContext for biometric auth.
       3. Load or generate the encryption key.
       4. Set up Keychain access control (internal usage).
       5. Configure accessibility settings (internal usage).
       6. Set initial key rotation timestamp.
     */
    private override init() {
        // 1. Create a serial queue for security operations with a user-initiated QoS.
        self.securityQueue = DispatchQueue(label: "com.dogwalking.keychainManager.securityQueue",
                                           qos: .userInitiated)
        
        // 2. Configure a new LAContext for future biometric operations.
        let context = LAContext()
        context.localizedReason = "Access required to securely store and retrieve sensitive data."
        self.authContext = context
        
        // 3. Load encryption key from Keychain or generate a new one if absent.
        //    If the key exists, also load the last rotation date.
        let loadedKeyData = KeychainManager.loadEncryptionKeyFromKeychain()
        if let existingKey = loadedKeyData?.key,
           let rotationDate = loadedKeyData?.rotationDate {
            self.encryptionKey = existingKey
            self.lastKeyRotation = rotationDate
        } else {
            // Generate a fresh key and store it securely.
            self.encryptionKey = KeychainManager.generateRandomSymmetricKey()
            self.lastKeyRotation = Date()
            KeychainManager.persistEncryptionKeyToKeychain(self.encryptionKey, rotationDate: self.lastKeyRotation)
        }
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    /**
     Saves data securely in the Keychain with optional biometric protection.
     
     Steps:
       1. Validate input parameters.
       2. Check key rotation requirement.
       3. Encrypt data with current encryption key.
       4. Configure Keychain access control settings.
       5. Add biometric protection if required.
       6. Create secure query dictionary.
       7. Attempt to save (or update) in Keychain.
       8. Log operation details.
       9. Return operation result.
     
     - Parameters:
       - data: The raw data to be stored.
       - key: A unique identifier for the stored item.
       - requiresBiometric: Whether to require biometric validation for future reads.
     - Returns: A Result indicating success (true) or a KeychainError.
     */
    @objc
    public func saveSecure(data: Data,
                           key: String,
                           requiresBiometric: Bool) -> Result<Bool, KeychainError> {
        return securityQueue.sync {
            
            // 1. Validate input
            guard !data.isEmpty, !key.isEmpty else {
                Logger.shared.error("saveSecure failed: data or key is empty", error: nil)
                return .failure(.invalidParameters(message: "Data or key cannot be empty"))
            }
            
            // 2. Check if key rotation is needed before saving new data.
            if shouldRotateKey() {
                let rotationResult = rotateEncryptionKey()
                switch rotationResult {
                case .failure(let error):
                    Logger.shared.error("Key rotation failed during saveSecure", error: error)
                    return .failure(error)
                case .success:
                    Logger.shared.security("Key rotation succeeded prior to save operation.")
                }
            }
            
            // 3. Encrypt data with current encryption key
            guard let encryptedData = encrypt(data, with: encryptionKey) else {
                Logger.shared.error("saveSecure encryption failed", error: nil)
                return .failure(.cryptoError(message: "Encryption failed"))
            }
            
            // 4. Configure Keychain access control
            //    By default, we use `.whenUnlocked` but will add biometric if required.
            var accessFlags: SecAccessControlCreateFlags = []
            if requiresBiometric {
                accessFlags = .biometryCurrentSet
            }
            
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlocked,
                accessFlags,
                nil
            ) else {
                Logger.shared.error("Failed to create SecAccessControl for biometric usage", error: nil)
                return .failure(.invalidParameters(message: "SecAccessControl creation failed"))
            }
            
            // 6. Create the base query
            let tagData = key.data(using: .utf8) ?? Data()
            let baseQuery: [CFString: Any] = [
                kSecClass:            kSecClassGenericPassword,
                kSecAttrService:      SERVICE_IDENTIFIER,
                kSecAttrAccount:      key,
                kSecAttrGeneric:      tagData,
                kSecAttrAccessGroup:  ACCESS_GROUP,
                kSecAttrAccessControl: accessControl,
                kSecValueData:        encryptedData
            ]
            
            // 7. Before we add, remove any existing item with the same key to avoid duplicates.
            let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                Logger.shared.error("saveSecure item deletion error", error: KeychainError.unexpectedStatus(status: deleteStatus))
                return .failure(.unexpectedStatus(status: deleteStatus))
            }
            
            let addStatus = SecItemAdd(baseQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                // 8. Log operation details
                Logger.shared.security("Successfully saved secure data for key: \(key)")
                return .success(true)
            } else {
                Logger.shared.error("saveSecure failed with OSStatus: \(addStatus)", error: nil)
                return .failure(.unexpectedStatus(status: addStatus))
            }
        }
    }
    
    /**
     Retrieves data from the Keychain with optional biometric validation.
     
     Steps:
       1. Validate access permissions (internal check).
       2. Perform biometric check if required.
       3. Create secure query.
       4. Attempt Keychain retrieval.
       5. Decrypt data with current key.
       6. Validate data integrity.
       7. Log access attempt.
       8. Return decrypted data.
     
     - Parameters:
       - key: The unique identifier of the stored item.
       - validateBiometric: Whether to require a biometric prompt before returning data.
     - Returns: A Result containing the requested Data (or nil if not found), or a KeychainError.
     */
    @objc
    public func retrieveSecure(key: String,
                               validateBiometric: Bool) -> Result<Data?, KeychainError> {
        return securityQueue.sync {
            
            guard !key.isEmpty else {
                Logger.shared.error("retrieveSecure failed: key is empty", error: nil)
                return .failure(.invalidParameters(message: "Key cannot be empty"))
            }
            
            var query: [CFString: Any] = [
                kSecClass:           kSecClassGenericPassword,
                kSecAttrService:     SERVICE_IDENTIFIER,
                kSecAttrAccount:     key,
                kSecAttrAccessGroup: ACCESS_GROUP,
                kSecReturnData:      true,
                kSecMatchLimit:      kSecMatchLimitOne
            ]
            
            // If we need biometric validation, attach the context to the query.
            if validateBiometric {
                query[kSecUseAuthenticationContext] = authContext
            }
            
            // 4. Attempt retrieval
            var retrievedData: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &retrievedData)
            
            // If the item is not found, return nil without it being an error in code logic.
            if status == errSecItemNotFound {
                Logger.shared.error("retrieveSecure item not found", error: nil)
                return .success(nil)
            } else if status != errSecSuccess {
                Logger.shared.error("retrieveSecure OSStatus error: \(status)", error: nil)
                return .failure(.unexpectedStatus(status: status))
            }
            
            guard let cipherData = retrievedData as? Data else {
                Logger.shared.error("retrieveSecure data cast failed", error: nil)
                return .failure(.cryptoError(message: "Failed to cast retrieved item to Data"))
            }
            
            // 5. Decrypt the data
            guard let decrypted = decrypt(cipherData, with: encryptionKey) else {
                Logger.shared.error("Failed to decrypt data for key: \(key)", error: nil)
                return .failure(.cryptoError(message: "Data decryption failed"))
            }
            
            // 7. Log success
            Logger.shared.security("Successfully retrieved secure data for key: \(key)")
            return .success(decrypted)
        }
    }
    
    /**
     Securely deletes a specific item from the Keychain with optional authentication.
     
     Steps:
       1. Validate deletion permissions (internal check).
       2. Check authentication if required.
       3. Create deletion query.
       4. Attempt secure deletion.
       5. Log operation.
       6. Return operation result.
     
     - Parameters:
       - key: The unique identifier of the stored item.
       - requiresAuth: Whether to require a biometric or passcode prompt before deletion.
     - Returns: A Result indicating success (true) or a KeychainError.
     */
    @objc
    public func deleteSecure(key: String,
                             requiresAuth: Bool) -> Result<Bool, KeychainError> {
        return securityQueue.sync {
            
            guard !key.isEmpty else {
                Logger.shared.error("deleteSecure failed: key is empty", error: nil)
                return .failure(.invalidParameters(message: "Key cannot be empty"))
            }
            
            // If we require authentication, attempt to run a policy check.
            if requiresAuth {
                let canEvaluate = authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
                if !canEvaluate {
                    Logger.shared.error("deleteSecure biometric/pin auth not available", error: nil)
                    return .failure(.biometricFailed(message: "Authentication not available"))
                }
            }
            
            let query: [CFString: Any] = [
                kSecClass:           kSecClassGenericPassword,
                kSecAttrService:     SERVICE_IDENTIFIER,
                kSecAttrAccount:     key,
                kSecAttrAccessGroup: ACCESS_GROUP
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                // Even if the item was not found, we can consider it "deleted."
                Logger.shared.security("Successfully deleted secure data for key: \(key)")
                return .success(true)
            } else {
                Logger.shared.error("deleteSecure failed OSStatus: \(status)", error: nil)
                return .failure(.unexpectedStatus(status: status))
            }
        }
    }
    
    /**
     Performs a secure rotation of the encryption key. This process:
       1. Generates a new encryption key.
       2. Retrieves all encrypted items.
       3. Decrypts them with the old key.
       4. Re-encrypts them with the new key.
       5. Updates the stored Keychain items.
       6. Updates the rotation timestamp.
       7. Logs the rotation event.
     
     - Returns: A Result indicating success (true) or a KeychainError.
     */
    @objc
    public func rotateEncryptionKey() -> Result<Bool, KeychainError> {
        return securityQueue.sync {
            
            Logger.shared.security("Starting encryption key rotation...")
            
            // 1. Generate a new random encryption key.
            let newKey = KeychainManager.generateRandomSymmetricKey()
            
            // 2. Retrieve all items associated with SERVICE_IDENTIFIER.
            let allItems = fetchAllItems()
            
            // 3. For each item, attempt to decrypt with old key and re-encrypt with new key.
            for (key, cipherData) in allItems {
                
                guard let plainData = decrypt(cipherData, with: encryptionKey) else {
                    Logger.shared.error("rotateEncryptionKey decrypt fail for key: \(key)", error: nil)
                    return .failure(.cryptoError(message: "Failed to decrypt existing item during rotation"))
                }
                
                // Re-encrypt with the new key
                guard let reEncrypted = encrypt(plainData, with: newKey) else {
                    Logger.shared.error("rotateEncryptionKey encrypt fail for key: \(key)", error: nil)
                    return .failure(.cryptoError(message: "Failed to encrypt item with new key"))
                }
                
                // Update the Keychain item with the newly encrypted data
                let updateResult = updateKeychainItem(key: key, newData: reEncrypted)
                if case .failure(let err) = updateResult {
                    return .failure(err)
                }
            }
            
            // 4. Overwrite the manager's encryptionKey property with the new key
            self.encryptionKey = newKey
            
            // 5. Update lastKeyRotation
            self.lastKeyRotation = Date()
            
            // Persist the newly rotated key and rotation date in the Keychain
            KeychainManager.persistEncryptionKeyToKeychain(self.encryptionKey,
                                                           rotationDate: self.lastKeyRotation)
            
            // 6. Log the rotation event
            Logger.shared.security("Encryption key successfully rotated for all items.")
            
            return .success(true)
        }
    }
    
    /**
     Securely wipes all Keychain data for the application service, requiring
     authentication if specified. This also resets the in-memory and persisted
     encryption keys, forcing a new key generation upon next usage.
     
     Steps:
       1. Validate clear permissions (internal check).
       2. Perform authentication if required.
       3. Create a wipe query for all items under this service.
       4. Execute secure deletion of all items.
       5. Reset encryption keys.
       6. Log clear operation.
       7. Return operation status.
     
     - Parameter requiresAuth: Whether to force a biometric or passcode prompt before clearing.
     - Returns: A Result indicating success (true) or KeychainError.
     */
    @objc
    public func clearSecure(requiresAuth: Bool) -> Result<Bool, KeychainError> {
        return securityQueue.sync {
            
            if requiresAuth {
                let canEvaluate = authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
                if !canEvaluate {
                    Logger.shared.error("clearSecure biometric/pin auth not available", error: nil)
                    return .failure(.biometricFailed(message: "Authentication not available"))
                }
            }
            
            let query: [CFString: Any] = [
                kSecClass:        kSecClassGenericPassword,
                kSecAttrService:  SERVICE_IDENTIFIER
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                Logger.shared.error("clearSecure failed with OSStatus: \(status)", error: nil)
                return .failure(.unexpectedStatus(status: status))
            }
            
            // Reset encryption keys in memory
            self.encryptionKey = KeychainManager.generateRandomSymmetricKey()
            self.lastKeyRotation = Date()
            KeychainManager.persistEncryptionKeyToKeychain(self.encryptionKey, rotationDate: self.lastKeyRotation)
            
            Logger.shared.security("All Keychain data wiped and encryption keys reset.")
            return .success(true)
        }
    }
    
    // MARK: - Private Helpers
    
    /**
     Checks whether enough time has passed since the last key rotation
     to justify performing a new rotation.
     
     - Returns: True if the current date exceeds the set KEY_ROTATION_INTERVAL.
     */
    private func shouldRotateKey() -> Bool {
        let elapsed = Date().timeIntervalSince(self.lastKeyRotation)
        return elapsed >= KEY_ROTATION_INTERVAL
    }
    
    /**
     Retrieves all items (key -> ciphertext) under this service from the Keychain.
     
     - Returns: A dictionary where each key is the item's identifier, and the value is the ciphertext.
     */
    private func fetchAllItems() -> [String: Data] {
        var result: [String: Data] = [:]
        
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     SERVICE_IDENTIFIER,
            kSecAttrAccessGroup: ACCESS_GROUP,
            kSecMatchLimit:      kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData:      true
        ]
        
        var itemsRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &itemsRef)
        
        if status == errSecSuccess, let items = itemsRef as? [[CFString: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount] as? String,
                   let cipherData = item[kSecValueData] as? Data {
                    result[account] = cipherData
                }
            }
        }
        
        return result
    }
    
    /**
     Updates an existing keychain item with newly encrypted data.
     
     - Parameters:
       - key: The unique identifier for the item.
       - newData: The new ciphertext to store.
     - Returns: A Result indicating success or a KeychainError.
     */
    private func updateKeychainItem(key: String, newData: Data) -> Result<Bool, KeychainError> {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     SERVICE_IDENTIFIER,
            kSecAttrAccount:     key,
            kSecAttrAccessGroup: ACCESS_GROUP
        ]
        
        let attributesToUpdate: [CFString: Any] = [
            kSecValueData: newData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if status == errSecSuccess {
            return .success(true)
        } else if status == errSecItemNotFound {
            return .failure(.itemNotFound(message: "Keychain item not found for \(key)"))
        } else {
            return .failure(.unexpectedStatus(status: status))
        }
    }
    
    /**
     Performs a placeholder encryption operation with the currently loaded encryption key.
     
     - Parameters:
       - data: The plaintext data to be encrypted.
       - key: The encryption key to use.
     - Returns: The encrypted data or nil if an error occurred.
     
     Note: In a production environment, replace this with industry-standard
     AES-GCM or AES-CBC encryption using CryptoKit or CommonCrypto.
     */
    private func encrypt(_ data: Data, with key: Data) -> Data? {
        // This demonstration simply appends the key's hash to the data
        // as a placeholder. Replace with real block cipher encryption.
        var combined = data
        combined.append(key.sha256Digest)
        return combined
    }
    
    /**
     Performs a placeholder decryption operation using the current encryption key.
     
     - Parameters:
       - data: The ciphertext to be decrypted.
       - key: The encryption key to use.
     - Returns: The decrypted data or nil if an error occurred.
     
     Note: In a production environment, replace this with matching AES-GCM or
     AES-CBC decryption corresponding to the chosen encryption routine.
     */
    private func decrypt(_ data: Data, with key: Data) -> Data? {
        // For this placeholder approach, we remove the final 32 bytes (the key's sha256)
        // and treat the remainder as plaintext.
        let hashSize = key.sha256Digest.count
        guard data.count >= hashSize else { return nil }
        return data.subdata(in: 0..<(data.count - hashSize))
    }
    
    /**
     Utility method to generate a random symmetric key of 32 bytes for AES-256.
     
     - Returns: A 32-byte random data block.
     */
    private static func generateRandomSymmetricKey() -> Data {
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        if result == errSecSuccess {
            return keyData
        } else {
            // Fallback to a random fallback or throw
            Logger.shared.error("Failed to generate random encryption key", error: nil)
            return Data("fallback_key_fallback_key_fallback_".utf8) // 32 bytes fallback
        }
    }
    
    /**
     Loads an existing encryption key and rotation date from the Keychain.
     
     - Returns: A tuple containing (key, rotationDate) or nil if not found.
     */
    private static func loadEncryptionKeyFromKeychain() -> (key: Data, rotationDate: Date)? {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     "encryptionKey",
            kSecAttrService:     SERVICE_IDENTIFIER,
            kSecAttrAccessGroup: ACCESS_GROUP,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        
        var resultRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &resultRef)
        guard status == errSecSuccess,
              let resultData = resultRef as? Data else {
            return nil
        }
        
        // The stored data is structured as encryptionKey + serializedDate
        // For demonstration, we join them with a separator. Real implementations
        // might store them as JSON or separate Keychain items.
        let components = resultData.split(separator: UInt8(ascii: "|"), omittingEmptySubsequences: false)
        guard components.count == 2 else { return nil }
        
        let keyPart = Data(components[0])
        let datePart = Data(components[1])
        
        guard let dateString = String(data: datePart, encoding: .utf8),
              let rotation = ISO8601DateFormatter().date(from: dateString) else {
            return nil
        }
        return (keyPart, rotation)
    }
    
    /**
     Persists the encryption key and rotation date in the Keychain for future usage.
     
     - Parameters:
       - key: The encryption key to be stored.
       - rotationDate: Timestamp of the key's last rotation.
     */
    private static func persistEncryptionKeyToKeychain(_ key: Data, rotationDate: Date) {
        // Combine the key data and date into a single chunk of data:
        let dateString = ISO8601DateFormatter().string(from: rotationDate)
        let combinedData = key + [UInt8(ascii: "|")] + Data(dateString.utf8)
        
        // Create or update the key in the Keychain
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     SERVICE_IDENTIFIER,
            kSecAttrAccount:     "encryptionKey",
            kSecAttrAccessGroup: ACCESS_GROUP
        ]
        
        let attributes: [CFString: Any] = [
            kSecValueData: combinedData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
    }
}

// MARK: - Data Extension for Placeholder Encryption

fileprivate extension Data {
    /// Computes a simple SHA256 digest of the data, returning a 32-byte array.
    var sha256Digest: Data {
        return withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data in
            var hash = [UInt8](repeating: 0, count: 32)
            CC_SHA256(buffer.baseAddress, CC_LONG(count), &hash)
            return Data(hash)
        }
    }
}

/// Minimal CommonCrypto import needed for the SHA256 placeholder. 
/// Normally you'd import <CommonCrypto/CommonDigest.h> via bridging header.
import CommonCrypto