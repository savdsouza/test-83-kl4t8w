import Foundation // iOS 13.0+

/// An exhaustive enumeration that represents all possible network and API-related errors for the dog walking application.
/// This type implements LocalizedError to provide human-readable messages and comprehensive error handling insights.
public enum APIError: LocalizedError {
    
    // MARK: - Enumerations

    /// Represents a low-level networking error encountered at the URL loading, connection, or transport layer.
    case networkError(Error)
    
    /// Thrown when an invalid URL string is provided.
    /// Contains an associated string depicting the invalid URL.
    case invalidURL(String)
    
    /// Indicates the HTTP response received from the server is invalid or unexpected.
    /// Contains associated data representing the status code and an optional response body.
    case invalidResponse(Int, Data?)
    
    /// Raised when there is an error decoding the server response into expected models.
    /// Contains the underlying DecodingError from the Swift standard library.
    case decodingError(DecodingError)
    
    /// Represents a server-side error typically identified by a 5xx HTTP status code.
    /// Contains the server status code and an optional message describing the error.
    case serverError(Int, String?)
    
    /// Denotes an unauthorized user or an expired/invalid token scenario.
    /// Contains an optional string indicating the reason or relevant context.
    case unauthorized(String?)
    
    /// Triggered when a user does not have permission to access a resource (HTTP 403).
    /// Contains an optional string providing additional explanation.
    case forbidden(String?)
    
    /// Returned when a requested resource could not be found (HTTP 404).
    /// Contains an optional string with further details about the missing resource.
    case notFound(String?)
    
    /// Signifies one or more field-level validation failures.
    /// Contains a dictionary where keys are field names and values are arrays of Field Error descriptions.
    case validationError([String: [String]])
    
    /// Indicates the application or user has exceeded allowable request limits, often known as a rate limit.
    /// Contains an integer specifying the limit or relevant threshold.
    case rateLimitExceeded(Int)
    
    /// Raised when an operation exceeds its maximum allowed time interval.
    case timeout
    
    /// Signifies that the device has no active internet connection.
    case noInternet
    
    /// A catch-all case for unexpected or unclassified errors.
    /// Contains an optional underlying Error for additional debug information.
    case unknown(Error?)
    
    
    // MARK: - Domain, Codes, and User Info

    /// Provides a default error domain for APIError instances.
    public var errorDomain: String {
        return "com.dogwalking.apierror"
    }
    
    /// Supplies an integer code that categorizes each specific error scenario, suitable for logging or monitoring systems.
    public var errorCode: Int {
        switch self {
        case .networkError:
            return 1000
        case .invalidURL:
            return 1001
        case .invalidResponse:
            return 1002
        case .decodingError:
            return 1003
        case .serverError:
            return 1004
        case .unauthorized:
            return 1005
        case .forbidden:
            return 1006
        case .notFound:
            return 1007
        case .validationError:
            return 1008
        case .rateLimitExceeded:
            return 1009
        case .timeout:
            return 1010
        case .noInternet:
            return 1011
        case .unknown:
            return 9999
        }
    }
    
    /// Returns a dictionary of user information, often used in bridging to NSError for detailed logging or system analytics.
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]
        userInfo[NSLocalizedDescriptionKey] = self.localizedDescription
        
        if let reason = self.failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason
        }
        if let suggestion = self.recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = suggestion
        }
        if let anchor = self.helpAnchor {
            userInfo[NSHelpAnchorErrorKey] = anchor
        }
        
        // Provide additional details based on case
        switch self {
        case .networkError(let underlyingError):
            userInfo["UnderlyingError"] = "\(underlyingError)"
        case .invalidURL(let urlString):
            userInfo["InvalidURL"] = urlString
        case .invalidResponse(let statusCode, let responseData):
            userInfo["StatusCode"] = statusCode
            if let data = responseData {
                userInfo["ResponseData"] = String(data: data, encoding: .utf8) ?? "N/A"
            }
        case .decodingError(let decodingError):
            userInfo["DecodingError"] = "\(decodingError)"
        case .serverError(let statusCode, let message):
            userInfo["StatusCode"] = statusCode
            if let msg = message {
                userInfo["ServerErrorMessage"] = msg
            }
        case .unauthorized(let reason):
            if let r = reason { userInfo["UnauthorizedReason"] = r }
        case .forbidden(let reason):
            if let r = reason { userInfo["ForbiddenReason"] = r }
        case .notFound(let resource):
            if let res = resource { userInfo["MissingResource"] = res }
        case .validationError(let errors):
            userInfo["ValidationErrors"] = errors
        case .rateLimitExceeded(let limit):
            userInfo["RateLimit"] = limit
        case .timeout:
            userInfo["Timeout"] = "The request timed out."
        case .noInternet:
            userInfo["NoInternet"] = "No active internet connection."
        case .unknown(let error):
            if let unwrapped = error {
                userInfo["UnknownError"] = "\(unwrapped)"
            } else {
                userInfo["UnknownError"] = "An unknown error occurred without additional context."
            }
        }
        
        return userInfo
    }
    
    
    // MARK: - LocalizedError Conformance

    /// Provides a user-friendly, localized description of the error suitable for display in the UI or logs.
    public var localizedDescription: String {
        // The localizedDescription bridging calls errorDescription if present. We can safely return or fall back to a default.
        return errorDescription ?? "An unknown error occurred."
    }
    
    /// Supplies a textual description of the error, commonly reflecting the primary cause or classification.
    public var errorDescription: String? {
        switch self {
        case .networkError:
            return "A network connection error occurred."
        case .invalidURL(let urlString):
            return "Invalid URL encountered: \(urlString)"
        case .invalidResponse(let statusCode, _):
            return "Invalid or unexpected response from server (HTTP \(statusCode))."
        case .decodingError:
            return "Failed to decode the server response into the expected format."
        case .serverError(let statusCode, _):
            return "Server error encountered (HTTP \(statusCode))."
        case .unauthorized:
            return "You are not authorized to perform this action."
        case .forbidden:
            return "Access to the requested resource is forbidden."
        case .notFound:
            return "The requested resource could not be found."
        case .validationError:
            return "One or more fields failed validation."
        case .rateLimitExceeded:
            return "Too many requests sent. Rate limit exceeded."
        case .timeout:
            return "The request took too long and has timed out."
        case .noInternet:
            return "No internet connection is available."
        case .unknown:
            return "An unknown error has occurred."
        }
    }
    
    /// Provides a more specific explanation of the failure, helping end users or developers understand the root cause.
    public var failureReason: String? {
        switch self {
        case .networkError(let error):
            return "Underlying networking error: \(error.localizedDescription)"
        case .invalidURL:
            return "The URL used in the request was malformed or empty."
        case .invalidResponse:
            return "The response data or status code did not match the expected criteria."
        case .decodingError(let decodingError):
            return "Decoding issue: \(decodingError.localizedDescription)"
        case .serverError(_, let message):
            return message ?? "Server responded with an error."
        case .unauthorized(let reason):
            return reason ?? "User credentials or tokens may be missing or expired."
        case .forbidden(let reason):
            return reason ?? "The user does not have permission to access the requested resource."
        case .notFound(let resource):
            return resource ?? "No resource found at the specified endpoint."
        case .validationError(_):
            return "Data provided failed server-side validation checks."
        case .rateLimitExceeded:
            return "The application or user has reached the request limit."
        case .timeout:
            return "The request did not complete within the required timeframe."
        case .noInternet:
            return "The device is offline or the connection is unstable."
        case .unknown(let error):
            return error?.localizedDescription ?? "No additional details are available."
        }
    }
    
    /// Suggests potential actions the user or system might take to recover from or work around the error.
    public var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your network or try again."
        case .invalidURL:
            return "Verify the URL and try the request again."
        case .invalidResponse:
            return "Attempt to reload the resource or contact support if the issue persists."
        case .decodingError:
            return "Check for updates or report the issue if it continues."
        case .serverError:
            return "Please wait or try again later, or contact support if the problem continues."
        case .unauthorized:
            return "Log in again or refresh your credentials."
        case .forbidden:
            return "Ensure you have proper permissions or request access from an administrator."
        case .notFound:
            return "Check that the requested resource exists or try a different request."
        case .validationError:
            return "Review the input fields and correct any mistakes."
        case .rateLimitExceeded:
            return "Limit your requests momentarily and retry after some time."
        case .timeout:
            return "Check network stability or increase the timeout interval."
        case .noInternet:
            return "Reconnect to the internet and try again."
        case .unknown:
            return "Restart the app, or contact support if the error persists."
        }
    }
    
    /// Provides a help anchor reference that can be displayed to assist the user with next-step guidance or online documentation.
    public var helpAnchor: String? {
        switch self {
        case .networkError:
            return "Network_Help_Anchor"
        case .invalidURL:
            return "URL_Validation_Help_Anchor"
        case .invalidResponse:
            return "Invalid_Response_Help_Anchor"
        case .decodingError:
            return "Decoding_Help_Anchor"
        case .serverError:
            return "Server_Error_Help_Anchor"
        case .unauthorized:
            return "Auth_Help_Anchor"
        case .forbidden:
            return "Permission_Help_Anchor"
        case .notFound:
            return "Resource_NotFound_Help_Anchor"
        case .validationError:
            return "Validation_Help_Anchor"
        case .rateLimitExceeded:
            return "RateLimit_Help_Anchor"
        case .timeout:
            return "Timeout_Help_Anchor"
        case .noInternet:
            return "NoInternet_Help_Anchor"
        case .unknown:
            return "Unknown_Error_Help_Anchor"
        }
    }
}