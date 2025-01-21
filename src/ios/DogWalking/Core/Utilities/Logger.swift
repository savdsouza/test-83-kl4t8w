//
//  Logger.swift
//  DogWalking
//
//  This file provides a comprehensive, production-ready logging utility
//  for the iOS dog walking application, supporting structured logging,
//  security monitoring, and performance optimization.
//
//  Created by DogWalking Mobile Team
//  © 2023 DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+ (Core iOS framework for date formatting and string manipulation)
import os.log     // iOS 13.0+ (Native iOS logging system integration for secure system-level logging)

// MARK: - Internal Import
// Accesses app metadata for enhanced log context (subsystem, version tracking)
import struct DogWalking.AppConstants

/// The global date format used when tagging log messages with timestamps.
public let LOG_DATE_FORMAT: String = "yyyy-MM-dd HH:mm:ss.SSS"

/// A collection of privacy patterns (regex) used to sanitize sensitive data
/// such as credit card numbers, SSNs, or email addresses.
public let LOG_PRIVACY_PATTERNS: [String] = [
    "\\d{4}-\\d{4}-\\d{4}-\\d{4}",
    "\\d{3}-\\d{2}-\\d{4}",
    "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
]

/// A thread-safe logging class that provides structured logging capabilities
/// with enhanced security features, privacy protection, and performance optimizations.
public final class Logger {
    
    // MARK: - Properties
    
    /// Represents the logging subsystem, often set to a reverse-DNS string
    /// that identifies the main app or module (e.g., "com.dogwalking.ios").
    private let subsystem: String
    
    /// Represents a specific category within the subsystem for more granular organization
    /// of logs (e.g., "Networking", "UI", "Security").
    private let category: String
    
    /// An OSLog instance, allowing integration with the unified logging system on iOS.
    private let osLog: OSLog
    
    /// A lock to ensure thread safety when modifying shared resources in logging.
    private let logLock = NSLock()
    
    /// A simple cache used to store and quickly retrieve pre-formatted or sanitized messages.
    /// This helps optimize performance, reducing repeated computations for identical messages.
    private let messageCache = NSCache<NSString, NSString>()
    
    /// An array of regex patterns used to identify and sanitize sensitive data.
    private let privacyPatterns: [String] = LOG_PRIVACY_PATTERNS
    
    // MARK: - Initialization
    
    /// Initializes a new logger instance with specified subsystem and category.
    /// This constructor configures a thread-safe logging environment and
    /// prepares a cache for performance optimizations.
    ///
    /// - Parameter subsystem: A string representing the logging subsystem.
    /// - Parameter category: A string representing the logging category.
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        
        // Create an OSLog instance referencing the provided subsystem and category,
        // enriched with current app metadata like AppConstants.APP_NAME and BUILD_VERSION.
        self.osLog = OSLog(
            subsystem: "\(subsystem).\(AppConstants.APP_NAME).\(AppConstants.BUILD_VERSION)",
            category: category
        )
        
        // NSLock and NSCache are already instantiated above;
        // here we can perform additional setup if needed.
        // For instance, we could enforce a maximum cost or count limit on the cache.
        messageCache.countLimit = 200
        
        // Additional security or privacy-related initializations can be performed here.
        // For example, integrating further patterns or advanced data redaction strategies.
    }
    
    // MARK: - Public Methods
    
    /// Logs a debug-level message with performance optimization and thread safety.
    /// This function leverages an internal cache to avoid re-sanitizing or re-formatting
    /// identical messages, thereby reducing overhead in development or verbose logging scenarios.
    ///
    /// - Parameters:
    ///   - message: The log message to be recorded.
    ///   - file: Optionally captures the filename from which this log is called.
    ///   - line: Optionally captures the line number in the source file.
    ///   - function: Optionally captures the function name or context.
    public func debug(
        _ message: String,
        file: String? = #file,
        line: Int = #line,
        function: String = #function
    ) {
        // 1. Check if the message already exists in the cache to reduce repeated processing.
        let originalKey = message as NSString
        var finalMessage: String
        
        if let cachedMessage = messageCache.object(forKey: originalKey) {
            // If a sanitized and formatted version is already cached, we reuse it.
            finalMessage = cachedMessage as String
        } else {
            // 2. Acquire the thread lock before performing formatting and sanitization.
            logLock.lock()
            defer { logLock.unlock() }
            
            // Prepare a timestamp for structured logging output.
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = LOG_DATE_FORMAT
            let timestamp = dateFormatter.string(from: Date())
            
            // 3. Format the message with app context and source context.
            var formattedMsg = "[\(timestamp)] [DEBUG]"
            formattedMsg += " [App: \(AppConstants.APP_NAME)]"
            formattedMsg += " [Build: \(AppConstants.BUILD_VERSION)]"
            
            // Include file, line, and function for full debugging context.
            formattedMsg += " (File: \(file ?? "Unknown"), Line: \(line), Func: \(function)) "
            formattedMsg += message
            
            // 4. Sanitize the message by removing or masking sensitive data.
            finalMessage = sanitizeMessage(formattedMsg)
            
            // 5. Store the sanitized, formatted result in the cache for performance gains.
            messageCache.setObject(finalMessage as NSString, forKey: originalKey)
        }
        
        // 6. Log via os_log at the debug level.
        // Use `%{public}@` or `%{private}@` to manage the log privacy setting.
        os_log("%{public}@", log: osLog, type: .debug, finalMessage)
    }
    
    /// Logs error messages with additional security context and a stack trace capture.
    /// This function is useful for identifying and diagnosing issues, while protecting
    /// or masking sensitive data before it is recorded.
    ///
    /// - Parameters:
    ///   - message: A human-readable message describing the error or incident.
    ///   - error: An optional `Error` object providing additional details.
    ///   - file: Optionally captures the filename from which this log is called.
    ///   - line: Optionally captures the line number in the source file.
    ///   - function: Optionally captures the function name or context.
    public func error(
        _ message: String,
        error: Error? = nil,
        file: String? = #file,
        line: Int = #line,
        function: String = #function
    ) {
        // 1. Acquire the thread lock for safe access to shared resources.
        logLock.lock()
        defer { logLock.unlock() }
        
        // 2. Capture stack trace to help with diagnosing issues.
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        
        // 3. Format the error message with relevant context.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = LOG_DATE_FORMAT
        let timestamp = dateFormatter.string(from: Date())
        
        var formattedMsg = "[\(timestamp)] [ERROR]"
        formattedMsg += " [App: \(AppConstants.APP_NAME)]"
        formattedMsg += " [Build: \(AppConstants.BUILD_VERSION)]"
        formattedMsg += " (File: \(file ?? "Unknown"), Line: \(line), Func: \(function)) "
        
        // Append the main error message.
        formattedMsg += message
        
        // If an actual Error instance is provided, append localizedDescription.
        if let err = error {
            formattedMsg += " | Error Details: \(err.localizedDescription)"
        }
        
        // 4. Append security context (user ID, session ID, or placeholders if unavailable).
        // For demonstration, we attach placeholders to show where these would be included.
        let userID = "UserID: UNKNOWN"
        let sessionID = "SessionID: UNKNOWN"
        formattedMsg += " | SecurityContext: [\(userID), \(sessionID)]"
        
        // 5. Append the captured stack trace for deeper debugging capabilities.
        formattedMsg += " | StackTrace: \(stackTrace)"
        
        // 6. Sanitize any sensitive information before logging.
        let finalMessage = sanitizeMessage(formattedMsg)
        
        // 7. Log via os_log using error-level severity.
        os_log("%{public}@", log: osLog, type: .error, finalMessage)
        
        // 8. Optionally trigger a security alert or further handling if needed.
        // In a production system, you might integrate with a monitoring or alerting backend here.
        // triggerSecurityAlertIfNeeded(for: finalMessage)
    }
    
    // MARK: - Private Helpers
    
    /// Sanitizes a given message by applying privacy patterns to mask or remove data
    /// deemed sensitive. This process typically removes PII such as credit card numbers,
    /// SSNs, or email addresses based on patterns provided by `LOG_PRIVACY_PATTERNS`.
    ///
    /// - Parameter message: The original, possibly sensitive message.
    /// - Returns: A sanitized message with sensitive data masked or removed.
    private func sanitizeMessage(_ message: String) -> String {
        var sanitized = message
        
        // For each pattern, replace all matches with asterisks or a safe placeholder.
        for pattern in privacyPatterns {
            let regexOptions: NSRegularExpression.Options = []
            let matchingOptions: NSRegularExpression.MatchingOptions = []
            if let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    options: matchingOptions,
                    range: NSRange(location: 0, length: sanitized.count),
                    withTemplate: "****"
                )
            }
        }
        
        // Additional checks or advanced data redaction routines can be performed here.
        return sanitized
    }
}