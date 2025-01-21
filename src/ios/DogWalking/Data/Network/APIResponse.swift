import Foundation // iOS 13.0+

/// Provides a standardized structure for parsing and handling
/// API responses with robust error management within the dog walking
/// iOS application. Conforms to Codable for seamless JSON encoding
/// and decoding, and leverages APIError for comprehensive error reporting.
///
/// - Note:
///   This struct is intended to be used alongside network requests
///   that return a generic payload (T) within a consistent response schema.
public struct APIResponse<T: Codable>: Codable {
    
    // MARK: - Public Properties
    
    /// Indicates whether the API call was reported as successful by the server.
    /// Typically reflects a boolean flag in the JSON response.
    public let success: Bool
    
    /// Holds the generic data payload returned from the server,
    /// if any is provided. The type T must conform to Codable to
    /// ensure type-safe decoding.
    public let data: T?
    
    /// An optional textual message describing the result, often used for
    /// user-facing feedback or debugging.
    public let message: String?
    
    /// The HTTP status code received from the server. These codes are
    /// expected to fall within the 100–599 range.
    public let statusCode: Int
    
    /// An optional string describing any error encountered at the server level.
    /// Typically populated when the `success` flag is false.
    public let error: String?
    
    // MARK: - Coding Keys
    
    /// Enumerates the expected keys in the API response for JSON encoding/decoding.
    private enum CodingKeys: String, CodingKey {
        case success
        case data
        case message
        case statusCode
        case error
    }
    
    // MARK: - Initializers
    
    /// Initializes a new `APIResponse` object with the given properties and
    /// performs basic validation (range check) on the HTTP status code.
    ///
    /// - Parameters:
    ///   - success: A boolean indicating whether the server-processed request was successful.
    ///   - data: An optional generic data payload of type T.
    ///   - message: An optional message describing the result of the request.
    ///   - statusCode: An integer indicating the HTTP status code (100–599).
    ///   - error: An optional error string provided by the server for failed requests.
    ///
    /// - Throws: `APIError.invalidResponse` if the status code is out of the valid range.
    public init(
        success: Bool,
        data: T? = nil,
        message: String? = nil,
        statusCode: Int,
        error: String? = nil
    ) throws {
        guard (100...599).contains(statusCode) else {
            // Treat an out-of-range status code as an invalid response scenario
            throw APIError.invalidResponse(statusCode, nil)
        }
        
        self.success = success
        self.data = data
        self.message = message
        self.statusCode = statusCode
        self.error = error
    }
    
    /// Decodable initializer that attempts to parse a JSON payload into an
    /// `APIResponse` object. Throws relevant APIError cases if validation
    /// or decoding steps fail.
    ///
    /// - Parameter decoder: The decoder used to read data from JSON format.
    /// - Throws:
    ///   - `APIError.decodingError` if there's a problem parsing or mapping fields.
    ///   - `APIError.invalidResponse` if the status code is out of 100–599 range.
    ///   - `APIError.unknown` for other unspecified errors encountered during decoding.
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Decode basic fields
            let successValue = try container.decode(Bool.self, forKey: .success)
            let statusCodeValue = try container.decode(Int.self, forKey: .statusCode)
            let dataValue = try container.decodeIfPresent(T.self, forKey: .data)
            let messageValue = try container.decodeIfPresent(String.self, forKey: .message)
            let errorValue = try container.decodeIfPresent(String.self, forKey: .error)
            
            // Validate status code range using invalidResponse when out of scope
            guard (100...599).contains(statusCodeValue) else {
                throw APIError.invalidResponse(statusCodeValue, nil)
            }
            
            self.success = successValue
            self.statusCode = statusCodeValue
            self.data = dataValue
            self.message = messageValue
            self.error = errorValue
            
        } catch let decodingErr as DecodingError {
            // Wrap decoding-related failures in APIError.decodingError
            throw APIError.decodingError(decodingErr)
        } catch {
            // Any other unforeseen error gets wrapped into APIError.unknown
            throw APIError.unknown(error)
        }
    }
    
    // MARK: - Public Methods
    
    /// Examines this API response to verify logical integrity:
    /// 1. Status code must remain within the 100–599 range.
    /// 2. If `success` is true, the status code should ideally be 2xx.
    /// 3. Error field is expected to be present when `success` is false.
    /// 4. Data may optionally be present, but is typically relevant when successful.
    ///
    /// - Returns: A boolean indicating whether the response meets the expected criteria.
    public func validate() -> Bool {
        // Basic range check
        guard (100...599).contains(statusCode) else {
            return false
        }
        
        // Success scenario checks
        if success {
            // Ideally expect 2xx for success
            if !(200...299).contains(statusCode) {
                return false
            }
            // Optionally ensure there's no unexpected error field
            // (some APIs might still set this, so we skip strict checks)
        } else {
            // Failure scenario: typically expect 4xx or 5xx codes
            if (200...299).contains(statusCode) {
                return false
            }
            // If there's truly an error, the server should supply an error message
            // This is a best-practice check; real scenarios may differ
            if error == nil {
                return false
            }
        }
        
        return true
    }
    
    /// Determines if this response indicates an unequivocally successful API call.
    /// Checks both the success flag and a HTTP status code in the 2xx range.
    ///
    /// - Returns: True if the response is considered successful; false otherwise.
    public func isSuccessful() -> Bool {
        return success && (200...299).contains(statusCode)
    }
}