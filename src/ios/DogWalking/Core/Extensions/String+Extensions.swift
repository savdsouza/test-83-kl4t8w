//
//  String+Extensions.swift
//  DogWalking
//
//  Extension methods for String class providing secure string manipulation,
//  validation, and formatting functionality with enhanced security measures
//  and comprehensive logging for the dog walking application.
//
//  Created by DogWalking Mobile Team
//  © 2023 DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+ (Core iOS framework for string operations, regular expressions, and locale-aware formatting)
import class DogWalking.Logger // Imported from Core/Utilities/Logger.swift

/**
 An extension on Swift's `String` to provide various utilities for secure handling
 of sensitive data, input validation, and domain-specific formatting. This includes
 verification of email, password, phone numbers, as well as trimming, masking,
 and specialized formatting methods. Logging operations are performed with the
 `Logger` class to capture validation attempts, successes, and failures.
 */
extension String {
    
    // MARK: - Private Static Logger
    
    /// A dedicated logger instance for the `String+Extensions` functionality.
    /// This logger will record validation errors, security issues, and
    /// input validation attempts in a secure and sanitized manner.
    private static let logger: Logger = {
        // The subsystem and category are arbitrarily set for detailed logs.
        return Logger(subsystem: "com.dogwalking.ios", category: "StringExtensions")
    }()
    
    // MARK: - Private Regex Constants
    
    /// Regex pattern for validating email addresses.
    private static let EMAIL_REGEX: String = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
    
    /// Regex pattern for validating password complexity.
    private static let PASSWORD_REGEX: String = "^(?=.*[A-Za-z])(?=.*\\d)(?=.*[@$!%*#?&])[A-Za-z\\d@$!%*#?&]{12,}$"
    
    /// Regex pattern for validating phone numbers, allowing optional '+' and up to 15 digits.
    private static let PHONE_REGEX: String = "^\\+?[1-9]\\d{1,14}$"
    
    // MARK: - Computed Properties for Validation
    
    /**
     Checks whether the current string matches a valid email format
     according to a predefined regex pattern. Logs both successful
     and failed validation attempts for security and audit.
     
     - Returns: A Boolean indicating whether the string is a valid email.
     */
    public var isValidEmail: Bool {
        let trimmedInput = self.trimmed
        let result = trimmedInput.range(of: String.EMAIL_REGEX,
                                        options: .regularExpression,
                                        range: nil,
                                        locale: nil) != nil
        if result {
            String.logger.debug("Email validation succeeded for input: \(trimmedInput)")
        } else {
            String.logger.error("Email validation failed for input: \(trimmedInput)")
        }
        return result
    }
    
    /**
     Checks whether the current string matches a valid password format
     per minimum complexity requirements (12+ characters, at least one letter,
     one digit, one special character). Logs success or failure for auditing.
     
     - Returns: A Boolean indicating whether the string meets password criteria.
     */
    public var isValidPassword: Bool {
        // Only log the length rather than the actual content to protect sensitive data.
        let length = self.count
        let result = self.range(of: String.PASSWORD_REGEX,
                                options: .regularExpression,
                                range: nil,
                                locale: nil) != nil
        if result {
            String.logger.debug("Password validation succeeded (length: \(length))")
        } else {
            String.logger.error("Password validation failed (length: \(length))")
        }
        return result
    }
    
    /**
     Checks whether the current string is a valid phone number according to an E.164-like
     format, with an optional '+' prefix and up to 15 digits. Logs success or failure.
     
     - Returns: A Boolean indicating whether the string is a valid phone number.
     */
    public var isValidPhoneNumber: Bool {
        let trimmedInput = self.trimmed
        let result = trimmedInput.range(of: String.PHONE_REGEX,
                                        options: .regularExpression,
                                        range: nil,
                                        locale: nil) != nil
        if result {
            String.logger.debug("Phone number validation succeeded for input: \(trimmedInput)")
        } else {
            String.logger.error("Phone number validation failed for input: \(trimmedInput)")
        }
        return result
    }
    
    /**
     Returns a version of the string trimmed of leading and trailing
     whitespace and newline characters. Logs a debug entry for reference.
     
     - Returns: A trimmed `String`.
     */
    public var trimmed: String {
        let trimmedVersion = self.trimmingCharacters(in: .whitespacesAndNewlines)
        String.logger.debug("Trimming operation performed. Original length: \(self.count), Trimmed length: \(trimmedVersion.count)")
        return trimmedVersion
    }
    
    // MARK: - Secure Masking and Phone Formatting
    
    /**
     Securely masks a credit card number while preserving only the last four digits.
     All other digits are replaced with 'X'. The resulting masked number can be
     segmented with a specified separator. Logs the masked result for auditing.
     
     Steps involved:
     1. Validate input for potential numeric content.
     2. Remove all non-digit characters.
     3. Preserve last 4 digits.
     4. Replace other digits with mask character ('X').
     5. Apply separator formatting if needed.
     6. Log the masked result.
     
     - Parameter separator: A string used to separate groups of digits.
     - Returns: A `String` with all but the last four digits masked.
     */
    public func maskCreditCard(separator: String) -> String {
        // 1. Initial validation for minimum length (>=4 if it's to be masked properly).
        let rawInput = self
        let digitsOnly = rawInput.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // 2. If there are fewer than 4 digits, we cannot properly mask it; just return as is.
        guard digitsOnly.count >= 4 else {
            String.logger.error("maskCreditCard failed: insufficient digits (\(digitsOnly.count)) in input: \(rawInput)")
            return rawInput
        }
        
        // 3. Split leading digits and last 4 digits.
        let endingRangeStart = digitsOnly.index(digitsOnly.endIndex, offsetBy: -4)
        let leadingPart = String(digitsOnly[digitsOnly.startIndex..<endingRangeStart])
        let lastFour = String(digitsOnly[endingRangeStart..<digitsOnly.endIndex])
        
        // 4. Replace all leading digits with 'X'.
        let maskedLeading = leadingPart.map { _ in "X" }.joined()
        
        // 5. Combine masked leading with the last 4 digits.
        let combined = maskedLeading + lastFour
        
        // 6. Optional grouping with separator (e.g., "XXXX-XXXX-XXXX-1234").
        //    Here, we create groups of 4 by default unless the user wants different logic.
        var groups: [String] = []
        let chunkSize = 4
        var index = combined.startIndex
        while index < combined.endIndex {
            let end = combined.index(index, offsetBy: chunkSize, limitedBy: combined.endIndex) ?? combined.endIndex
            groups.append(String(combined[index..<end]))
            index = end
        }
        let maskedResult = groups.joined(separator: separator)
        
        // 7. Log the masking operation with the final masked result (secure logging).
        String.logger.debug("maskCreditCard completed. Masked result: \(maskedResult)")
        return maskedResult
    }
    
    /**
     Formats a phone number according to regional standards with validation.
     This method:
     1. Validates the basic phone format.
     2. Removes all non-numeric characters.
     3. Applies region-based formatting logic (placeholder or stub).
     4. Validates the final format.
     5. Logs the operation for reference.
     
     - Parameter regionCode: A `String` representing regional standards (e.g., "US", "CA").
     - Returns: A newly formatted phone number or the original if formatting fails.
     */
    public func formatPhoneNumber(regionCode: String) -> String {
        let rawInput = self
        let trimmedInput = rawInput.trimmed
        if !trimmedInput.isValidPhoneNumber {
            String.logger.error("formatPhoneNumber failed: invalid phone number format for input: \(trimmedInput)")
            return trimmedInput
        }
        
        // 2. Extract digits only.
        let digitsOnly = trimmedInput.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // 3. Apply region-based formatting. For demonstration, we do a simple pattern:
        //    e.g., for "US", if 10 digits => (XXX) XXX-XXXX. For other regions, stub out.
        var formattedNumber: String = digitsOnly
        if regionCode.uppercased() == "US" || regionCode.uppercased() == "CA" {
            if digitsOnly.count == 10 {
                let areaCode = digitsOnly.prefix(3)
                let middle = digitsOnly[digitsOnly.index(digitsOnly.startIndex, offsetBy: 3)..<digitsOnly.index(digitsOnly.startIndex, offsetBy: 6)]
                let last4 = digitsOnly.suffix(4)
                formattedNumber = "(\(areaCode)) \(middle)-\(last4)"
            } else if digitsOnly.count == 11, digitsOnly.hasPrefix("1") {
                // For 11-digit numbers starting with "1".
                let newIndex = digitsOnly.index(digitsOnly.startIndex, offsetBy: 1)
                let areaCode = digitsOnly[newIndex..<digitsOnly.index(newIndex, offsetBy: 3)]
                let middle = digitsOnly[digitsOnly.index(newIndex, offsetBy: 3)..<digitsOnly.index(newIndex, offsetBy: 6)]
                let last4 = digitsOnly.suffix(4)
                formattedNumber = "+1 (\(areaCode)) \(middle)-\(last4)"
            }
        }
        
        // 4. Validate final format for non-empty.
        guard !formattedNumber.isEmpty else {
            String.logger.error("formatPhoneNumber failed: final formatting produced empty result for input: \(digitsOnly)")
            return trimmedInput
        }
        
        // 5. Log the completed formatting operation.
        String.logger.debug("formatPhoneNumber succeeded. Region: \(regionCode), Result: \(formattedNumber)")
        return formattedNumber
    }
    
    // MARK: - Additional Formatting
    
    /**
     Attempts to interpret the current string as a numeric value
     and formats it as a localized currency string. In case of
     parsing errors, the original string is returned and an error
     is logged. Otherwise, a formatted currency string is returned.
     
     - Returns: A currency-formatted `String`.
     */
    public func formatCurrency() -> String {
        let rawInput = self
        guard let numberValue = Double(rawInput) else {
            String.logger.error("formatCurrency failed: cannot parse numeric value from input: \(rawInput)")
            return rawInput
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        guard let formatted = formatter.string(from: NSNumber(value: numberValue)) else {
            String.logger.error("formatCurrency failed: NumberFormatter could not format value: \(numberValue)")
            return rawInput
        }
        String.logger.debug("formatCurrency succeeded. Input: \(rawInput), Result: \(formatted)")
        return formatted
    }
    
    /**
     Interprets the current string as a numeric value (e.g., distance in meters)
     and formats it as a human-readable distance. The default implementation
     returns kilometers with two decimal places. Logs success or error.
     
     - Returns: A distance-formatted `String`, e.g., "1.23 km".
     */
    public func formatDistance() -> String {
        let rawInput = self
        guard let distanceMeters = Double(rawInput) else {
            String.logger.error("formatDistance failed: cannot parse numeric value from input: \(rawInput)")
            return rawInput
        }
        // Convert meters to kilometers.
        let distanceKm = distanceMeters / 1000.0
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        guard let formatted = formatter.string(from: NSNumber(value: distanceKm)) else {
            String.logger.error("formatDistance failed: NumberFormatter could not format value: \(distanceKm)")
            return rawInput
        }
        let result = "\(formatted) km"
        String.logger.debug("formatDistance succeeded. Input: \(rawInput), Result: \(result)")
        return result
    }
    
    /**
     Interprets the current string as a numeric value representing a duration
     in seconds, then formats it into a more readable "HH:mm:ss" string.
     Logs success or error.
     
     - Returns: A duration-formatted `String`, e.g., "00:05:30" for 330 seconds.
     */
    public func formatDuration() -> String {
        let rawInput = self
        guard let totalSeconds = Double(rawInput) else {
            String.logger.error("formatDuration failed: cannot parse numeric value from input: \(rawInput)")
            return rawInput
        }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let formatted = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        String.logger.debug("formatDuration succeeded. Input: \(rawInput), Result: \(formatted)")
        return formatted
    }
}
```