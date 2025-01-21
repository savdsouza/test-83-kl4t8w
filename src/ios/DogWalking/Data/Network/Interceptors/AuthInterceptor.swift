//
//  AuthInterceptor.swift
//  DogWalking
//
//  This file implements an authentication interceptor that handles
//  JWT token management, request authentication, and enhanced security
//  logging for network requests in the iOS dog walking application.
//  It provides thread-safe operations, token validation, token refresh,
//  and comprehensive monitoring capabilities.
//
//  © 2023 DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+ (Core iOS framework, required for URLRequest, Date, etc.)

// MARK: - Internal Imports
import KeychainManager   // Local module import for secure token storage/retrieval
import Logger            // Local module import for security event logging

/**
 A global constant representing the key used to store or retrieve
 the main authentication token in Keychain.
 */
fileprivate let AUTH_TOKEN_KEY: String = "auth_token"

/**
 A global constant representing the key used to store or retrieve
 the refresh token in Keychain.
 */
fileprivate let REFRESH_TOKEN_KEY: String = "refresh_token"

/**
 A global constant indicating the buffer time (in seconds) before
 token expiration, used to proactively refresh tokens.
 */
fileprivate let TOKEN_EXPIRY_BUFFER: Int = 300

/**
 A global constant specifying the maximum number of attempts
 to retry an authentication-related request.
 */
fileprivate let MAX_RETRY_ATTEMPTS: Int = 3

/**
 A global constant representing the base multiplier for
 exponential backoff during retry intervals.
 */
fileprivate let RETRY_DELAY_BASE: Double = 2.0

/**
 A thread-safe class that intercepts network requests to handle
 JWT-based authentication. It adapts requests by adding security
 headers, verifies token expiry, and manages refresh logic
 with comprehensive security logging and concurrency controls.
 */
public final class AuthInterceptor {
    
    // MARK: - Properties
    
    /// Holds the current access token loaded from secure storage.
    private var currentToken: String?
    
    /// Holds the current refresh token loaded from secure storage.
    private var refreshToken: String?
    
    /**
     Tracks the date/time at which the currentToken will expire.
     This date is derived from parsing the token or from metadata
     stored after a refresh.
     */
    private var tokenExpiryDate: Date?
    
    /**
     A dedicated concurrent queue for all token-related read/write
     operations. Using a concurrent queue with barrier writes
     ensures thread safety in token management.
     */
    private let tokenQueue: DispatchQueue
    
    /**
     Guards the ongoing refresh process to avoid duplicate refresh
     calls in multiple threads.
     */
    private var isRefreshing: Bool
    
    /**
     Tracks the number of consecutive retry attempts, used to
     limit repeated authentication failures or infinite loops.
     */
    private var retryAttempts: Int
    
    // MARK: - Initialization
    
    /**
     Initializes the interceptor by creating a dedicated queue
     and loading existing token data from the Keychain. It also
     parses any relevant expiry information, logs startup status,
     and readies the interceptor for secure request adaptation.
     
     Steps Performed:
       1. Create a concurrent dispatch queue for token synchronization.
       2. Initialize `retryAttempts` to 0 and `isRefreshing` to false.
       3. Retrieve the auth token and refresh token from Keychain.
       4. If present and valid, parse or set token expiry date.
       5. Log initialization status with security context.
     */
    public init() {
        self.tokenQueue = DispatchQueue(label: "com.dogwalking.AuthInterceptor.tokenQueue",
                                        attributes: .concurrent)
        self.retryAttempts = 0
        self.isRefreshing = false
        
        // Load tokens and expiry date in a thread-safe manner
        self.tokenQueue.sync(flags: .barrier) {
            self.currentToken = Self.loadToken(key: AUTH_TOKEN_KEY)
            self.refreshToken = Self.loadToken(key: REFRESH_TOKEN_KEY)
            self.tokenExpiryDate = Self.deriveExpiryDate(from: self.currentToken)
        }
        
        Logger.shared.security("[AuthInterceptor] Initialization complete. Tokens loaded from Keychain.")
    }
    
    // MARK: - Public Methods
    
    /**
     Adapts the given URLRequest by adding authentication headers
     and security signatures, ensuring the token is valid or refreshed
     if nearing expiration. Thread-safe checks are performed to verify
     the token’s integrity.
     
     Steps:
       1. Determine if the request requires authentication.
       2. Perform a thread-safe token validation check.
       3. If token is expired or near expiry, attempt refresh.
       4. Add Authorization header (Bearer <token>).
       5. Optionally add security headers / request signatures.
       6. Log the adaptation process for monitoring.
       7. Return the modified request.
     
     - Parameter request: The original `URLRequest` before interception.
     - Returns: A new `URLRequest` with updated headers and authentication.
     */
    public func adapt(_ request: URLRequest) -> URLRequest {
        var newRequest = request
        
        // Simplistic check to see if authentication is needed:
        // Here, we assume all requests need authentication except
        // possibly requests to a public endpoint. This logic can be
        // extended if needed.
        guard let urlString = request.url?.absoluteString,
              !urlString.contains("/public/") else {
            // No changes required for public endpoints.
            Logger.shared.debug("AuthInterceptor adapt skipped for public endpoint: \(urlString)")
            return newRequest
        }
        
        // Thread-safe token retrieval & potential refresh
        tokenQueue.sync(flags: .barrier) {
            guard let token = self.currentToken else {
                Logger.shared.error("No current token available. Unable to adapt request.")
                return
            }
            
            // If token is nearing or past expiry, attempt refresh
            if self.isTokenExpiringSoon() {
                let refreshSuccess = self.refreshAuthToken()
                if !refreshSuccess {
                    Logger.shared.error("AuthInterceptor token refresh failed during adapt().")
                }
            }
            
            // Re-check the currentToken if it was just refreshed
            guard let updatedToken = self.currentToken else {
                Logger.shared.error("No current token after refresh attempt. Request may fail.")
                return
            }
            
            // Add the Authorization header
            newRequest.setValue("Bearer \(updatedToken)", forHTTPHeaderField: "Authorization")
            
            // Add any additional security headers or signatures as needed
            // Example: X-Request-Signature, X-Encryption-Version, etc.
            // newRequest.setValue("v1", forHTTPHeaderField: "X-Signature-Version")
            
            Logger.shared.security("Request adapted with Authorization header.")
        }
        return newRequest
    }
    
    /**
     Determines whether a failed request should be retried based on
     authentication status. If the HTTP response code suggests an
     authentication error (401), the interceptor attempts an exponential
     backoff strategy up to `MAX_RETRY_ATTEMPTS`.
     
     Steps:
       1. Check if the response is authentication-related (401).
       2. Check current retry attempts against max limit.
       3. Calculate exponential backoff delay using `pow(2, retryAttempts) * RETRY_DELAY_BASE`.
       4. Attempt thread-safe token refresh if feasible.
       5. Update retryAttempts counter.
       6. Log the retry attempt and decision.
       7. Return whether the request should be retried.
     
     - Parameters:
       - request: The original `URLRequest`.
       - response: The `HTTPURLResponse` received.
       - error: An optional `Error` that occurred.
     - Returns: A `Bool` indicating whether the network layer should retry the request.
     */
    public func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: Error?
    ) -> Bool {
        // Quick guard: if response code isn't available, or not 401, we won't retry for auth reasons
        guard let statusCode = response?.statusCode, statusCode == 401 else {
            // Not an auth-related error => do not retry
            return false
        }
        
        // Thread-safe check & update
        return tokenQueue.sync(flags: .barrier) {
            if self.retryAttempts >= MAX_RETRY_ATTEMPTS {
                Logger.shared.error("Max retry attempts (\(MAX_RETRY_ATTEMPTS)) reached for 401 error.")
                return false
            }
            
            // Attempt exponential backoff calculation
            let delay = pow(RETRY_DELAY_BASE, Double(self.retryAttempts)) 
            Logger.shared.security("AuthInterceptor is waiting \(delay) seconds before retry. Attempt #\(self.retryAttempts + 1).")
            
            // (This demonstration simply sleeps on the current thread. In a real scenario,
            //  you’d dispatch async or schedule the retry with your networking library.)
            Thread.sleep(forTimeInterval: delay)
            
            // Token refresh attempt
            let refreshSuccess = self.refreshAuthToken()
            if !refreshSuccess {
                Logger.shared.error("Token refresh failed during retry #\(self.retryAttempts + 1).")
                return false
            }
            
            self.retryAttempts += 1
            Logger.shared.security("401 retry authorized. Attempt #\(self.retryAttempts). Request will be retried.")
            return true
        }
    }
    
    /**
     Refreshes the currently stored auth token using the refresh token in
     a thread-safe manner. It simulates a secure network call to retrieve
     new tokens, validates them, updates Keychain, and sets internal state.
     
     Steps:
       1. Enter thread-safe refresh operation (guard isRefreshing to avoid duplicates).
       2. Validate refresh token; return false if none.
       3. Make secure token refresh request (placeholder logic).
       4. Validate received tokens (placeholder logic).
       5. Securely store new tokens in Keychain.
       6. Update currentToken, refreshToken, tokenExpiryDate.
       7. Log success or failure.
       8. Return the success status of the refresh.
     
     - Returns: `true` if a token refresh was successful, `false` otherwise.
     */
    public func refreshAuthToken() -> Bool {
        // We will do everything inside a barrier block for consistent writes
        return tokenQueue.sync(flags: .barrier) {
            // If already refreshing, skip parallel attempts
            if self.isRefreshing {
                Logger.shared.debug("Refresh request skipped. Another refresh is in progress.")
                return false
            }
            
            self.isRefreshing = true
            defer { self.isRefreshing = false }
            
            // 2. Check validity of existing refresh token
            guard let validRefresh = self.refreshToken, !validRefresh.isEmpty else {
                Logger.shared.error("No valid refresh token available. Cannot refresh access token.")
                return false
            }
            
            // 3. Simulate a secure token refresh request (placeholder).
            // In a real app, you'd call your backend's refresh endpoint.
            // Example: POST /auth/v1/refresh { refreshToken: validRefresh }
            let (newAccessToken, newRefreshToken, newExpiry) = self.simulateRefreshNetworkCall(refreshToken: validRefresh)
            
            if newAccessToken.isEmpty || newExpiry == nil {
                Logger.shared.error("Token refresh response invalid or incomplete.")
                return false
            }
            
            // 4. Validate the tokens. We do a placeholder check to ensure
            // they are well-formed. In a real scenario, decode the JWT,
            // verify signature, parse claims, etc.
            guard self.validateToken(newAccessToken) else {
                Logger.shared.error("Newly received token failed validation checks.")
                return false
            }
            
            // 5. Securely store in Keychain. We assume success if Keychain doesn't throw an error
            let accessData = Data(newAccessToken.utf8)
            let refreshData = Data((newRefreshToken ?? "").utf8)
            
            let accessSaveResult = KeychainManager.shared.saveSecure(data: accessData,
                                                                     key: AUTH_TOKEN_KEY,
                                                                     requiresBiometric: false)
            switch accessSaveResult {
            case .failure(let err):
                Logger.shared.error("Failed to store new access token in Keychain.", error: err)
                return false
            case .success:
                break
            }
            
            if let newlyRefreshed = newRefreshToken {
                let refreshSaveResult = KeychainManager.shared.saveSecure(data: refreshData,
                                                                          key: REFRESH_TOKEN_KEY,
                                                                          requiresBiometric: false)
                switch refreshSaveResult {
                case .failure(let err):
                    Logger.shared.error("Failed to store new refresh token in Keychain.", error: err)
                    return false
                case .success:
                    break
                }
            }
            
            // 6. Update in-memory properties
            self.currentToken = newAccessToken
            self.refreshToken = newRefreshToken
            self.tokenExpiryDate = newExpiry
            
            // 7. Log success
            Logger.shared.security("AuthInterceptor successfully refreshed access token.")
            
            return true
        }
    }
    
    /**
     Securely clears all stored authentication data and resets the
     token-related properties, ensuring no remnants remain in memory
     or Keychain.
     
     Steps:
       1. Perform thread-safe token clearing in a barrier block.
       2. Remove auth token from Keychain.
       3. Remove refresh token from Keychain.
       4. Reset internal token properties to nil.
       5. Clear token expiry date.
       6. Log the token clearing operation.
     */
    public func clearTokens() {
        tokenQueue.sync(flags: .barrier) {
            // Remove tokens from Keychain
            let _ = KeychainManager.shared.deleteSecure(key: AUTH_TOKEN_KEY, requiresAuth: false)
            let _ = KeychainManager.shared.deleteSecure(key: REFRESH_TOKEN_KEY, requiresAuth: false)
            
            // Reset in-memory data
            self.currentToken = nil
            self.refreshToken = nil
            self.tokenExpiryDate = nil
            self.retryAttempts = 0
            
            Logger.shared.security("AuthInterceptor has cleared all tokens from Keychain and memory.")
        }
    }
    
    /**
     Validates a given token’s format, claims, and expiration. In
     a production environment, this would involve decoding the JWT
     header/payload, verifying the signature, and checking the exp claim.
     
     Steps:
       1. Check the token format (placeholder logic).
       2. Check if the token is expired based on internal metadata.
       3. Validate token claims (placeholder).
       4. Log validation result.
       5. Return boolean status.
     
     - Parameter token: The JWT token string to validate.
     - Returns: Boolean indicating whether the token is considered valid.
     */
    public func validateToken(_ token: String) -> Bool {
        // 1. Basic format check (placeholder: e.g., ephemeral check if it “looks like” a JWT).
        guard token.contains(".") else {
            Logger.shared.error("Token format invalid. Missing JWT segments.")
            return false
        }
        
        // 2. If we have an expiry date in memory, check it. If it’s in the past, fail.
        if let expireDate = self.tokenExpiryDate {
            let now = Date().timeIntervalSince1970
            let exp = expireDate.timeIntervalSince1970
            if now >= exp {
                Logger.shared.error("Token expiry check failed. Token is already expired.")
                return false
            }
        }
        
        // 3. Claims validation placeholder. One might decode the token payload,
        // check the 'iss', 'aud', or 'sub' claims, etc.
        // For now, assume success if the token has at least 2 segments separated by periods.
        
        // 4. Log success
        Logger.shared.security("Token validated successfully (placeholder checks).")
        
        return true
    }
    
    // MARK: - Private Helpers
    
    /**
     Loads a stored token from the Keychain by key, returning its string
     representation if found.
     
     - Parameter key: The Keychain key (e.g., AUTH_TOKEN_KEY).
     - Returns: A string containing the token, or nil if not found.
     */
    private static func loadToken(key: String) -> String? {
        let result = KeychainManager.shared.retrieveSecure(key: key, validateBiometric: false)
        switch result {
        case .success(let data):
            guard let tokenData = data, !tokenData.isEmpty else {
                return nil
            }
            return String(decoding: tokenData, as: UTF8.self)
        case .failure:
            return nil
        }
    }
    
    /**
     Attempts to derive an expiry date from the token itself by parsing
     the JWT claims. In this placeholder, we simply return an approximate
     date 1 hour from now if the token is non-empty.
     
     - Parameter token: The raw token string (JWT).
     - Returns: An optional Date representing the expiry time.
     */
    private static func deriveExpiryDate(from token: String?) -> Date? {
        // In a real implementation, decode the `exp` claim from the token payload.
        // For demonstration, return an hour from now if a token is present.
        guard let t = token, !t.isEmpty else {
            return nil
        }
        return Date().addingTimeInterval(3600) // +1 hour
    }
    
    /**
     Determines if the current token is about to expire within the
     `TOKEN_EXPIRY_BUFFER` threshold. This helps in proactively refreshing
     the token before it becomes invalid.
     
     - Returns: `true` if the token is near expiration, otherwise `false`.
     */
    private func isTokenExpiringSoon() -> Bool {
        guard let expiry = self.tokenExpiryDate else {
            // If we have no known expiry, treat it as near expiry to force refresh
            return true
        }
        let remainSeconds = expiry.timeIntervalSince(Date())
        return remainSeconds <= Double(TOKEN_EXPIRY_BUFFER)
    }
    
    /**
     Simulates a network call to refresh the token using the refresh token.
     A production version of this would perform an actual API endpoint call.
     
     - Parameter refreshToken: The existing refresh token.
     - Returns: A tuple:
        - new access token as String
        - new refresh token as String? (nil if server doesn't provide one)
        - new expiry date as Date?
     */
    private func simulateRefreshNetworkCall(refreshToken: String) -> (String, String?, Date?) {
        // Placeholder logic:
        // Typically, you'd do a synchronous or asynchronous call to your auth service:
        // e.g., POST /auth/v1/refresh, pass the refreshToken, parse response JSON, etc.
        
        // For demonstration, just generate a new random token string and set the expiry to +1 hour.
        let newAccess = "eyJhbGci...newlyRefreshed\(Int.random(in: 1000..<9999))"
        let newRefresh = "ref_\(Int.random(in: 1000..<9999))"
        let newExpiry = Date().addingTimeInterval(3600) // +1 hour
        
        // Simulate a network delay
        Thread.sleep(forTimeInterval: 1.0)
        
        // Return placeholders as if it succeeded
        return (newAccess, newRefresh, newExpiry)
    }
}