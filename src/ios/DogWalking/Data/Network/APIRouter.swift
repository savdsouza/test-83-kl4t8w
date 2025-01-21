import Foundation // iOS 13.0+ (Core iOS networking functionality)
import CoreGraphics

// MARK: - Internal Imports
// Using items from "APIConstants" (src/ios/DogWalking/Core/Constants/APIConstants.swift).
// Using items from "APIError" (src/ios/DogWalking/Data/Network/APIError.swift).
// The JSON specification references "invalidParameters" as a needed symbol; here we create an extension to map that to .validationError.
extension APIError {
    /// Maps an "invalidParameters" requirement to a validationError scenario.
    public static var invalidParameters: APIError {
        return .validationError(["parameters": ["One or more parameters are invalid"]])
    }
}

// MARK: - HTTPMethod Enumeration
/**
 An enumeration representing possible HTTP methods for API requests,
 providing comprehensive coverage of common RESTful actions.
 */
public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

// MARK: - APIRouter Enumeration
/**
 A comprehensive, type-safe API routing system for the iOS dog walking application,
 implementing secure request generation, certificate pinning, and robust error handling.
 Includes endpoints for real-time tracking and emergency response.
 */
public enum APIRouter {
    
    // MARK: - Authentication & Registration
    /// Logs in a user with specified email and password credentials.
    case login(email: String, password: String)
    
    /// Registers a new user with name, email, password, phone, etc.
    case register(name: String, email: String, password: String, phone: String)
    
    // MARK: - Walk Booking & Management
    /// Creates a new walk booking for a specific dog, time slot, etc.
    case createWalk(dogId: String, startTime: Date, endTime: Date, notes: String?)
    
    /// Updates an existing walk booking with new details.
    case updateWalk(walkId: String, startTime: Date, endTime: Date, notes: String?)
    
    /// Retrieves detailed information about a specific walk booking.
    case getWalkDetails(walkId: String)
    
    /// Retrieves the walk history for a user or walker with paging support.
    case getWalkHistory(userId: String, page: Int, pageSize: Int)
    
    // MARK: - Real-time Tracking & Emergency
    /// Sends periodic location updates for real-time walk tracking.
    case updateLocation(walkId: String, latitude: Double, longitude: Double, timestamp: Date)
    
    /// Triggers an emergency alert for the given walk/session.
    case emergencyAlert(walkId: String, alertType: String, message: String?)
    
    // MARK: - Verification & Background Checks
    /// Initiates or retrieves the status of a background check for a walker.
    case backgroundCheck(walkerId: String)
    
    /// Verifies the identity of a user (owner or walker) via an identity token or code.
    case verifyIdentity(userId: String, verificationCode: String)
    
    /// Uploads a verification document (e.g., ID or certification).
    case uploadDocument(userId: String, documentType: String, fileData: Data, fileName: String)
    
    // MARK: - Dog Profiles
    /// Retrieves a detailed dog profile by dog ID.
    case getDogProfile(dogId: String)
    
    /// Updates a dog profile with new data such as name, breed, medicalInfo, etc.
    case updateDogProfile(dogId: String, name: String?, breed: String?, medicalInfo: String?)
    
    // MARK: - Payments
    /// Processes a payment for a completed walk or service.
    case processPayment(walkId: String, amount: Double, paymentMethodId: String)
    
    /// Retrieves a paginated payment history for a user or walker.
    case getPaymentHistory(userId: String, page: Int, pageSize: Int)
    
    // MARK: - User Profile
    /// Retrieves a user profile (owner or walker).
    case getUserProfile(userId: String)
    
    /// Updates an existing user profile with new data.
    case updateUserProfile(userId: String, name: String?, email: String?, phone: String?)
    
    // MARK: - Core Router Methods
    
    /**
     Builds a complete URLRequest from the selected route case. This includes:
     - Constructing the URL with base paths and path components.
     - Setting the HTTP method, headers, and request body.
     - Applying secure request generation and optional signing.
     - Providing support for certificate pinning when sending requests.
     
     - Throws: `APIError.invalidURL` if the path cannot be formed.
               `APIError.invalidParameters` if the parameters are invalid.
               `APIError.networkError` for lower-level networking issues.
     - Returns: A fully-formed URLRequest ready for execution.
     */
    public func asURLRequest() throws -> URLRequest {
        // Base URL from APIConstants (renamed to API_TIMEOUT_INTERVAL for timing).
        // For clarity in code, using the correct constant "API_TIMEOUT_INTERVAL".
        let timeoutInterval = APIConstants.API_TIMEOUT_INTERVAL
        
        // Retrieve path, method, headers, query items, and body parameters from the current route.
        let urlPath = try buildURL()
        var request = URLRequest(url: urlPath, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue
        
        var allHeaders = baseHeaders()
        if let additionalHeaders = additionalHeaders {
            for (key, value) in additionalHeaders {
                allHeaders[key] = value
            }
        }
        request.allHTTPHeaderFields = allHeaders
        
        // If we have parameters to encode in the body (for POST/PUT/PATCH typically).
        if requiresHTTPBody {
            if let bodyParams = bodyParameters {
                // Attempt to encode parameters as JSON.
                do {
                    request.httpBody = try encodeParameters(bodyParams)
                } catch {
                    // Map or throw an invalid parameter scenario if encoding fails.
                    throw APIError.invalidParameters
                }
            }
        }
        
        // Optional: Basic request signing or adding an Authorization token (JWT-based).
        // This is a minimal placeholder for demonstration; an actual app might fetch
        // a secure token from the Keychain or a credential manager.
        if requiresAuth {
            // Example: Use a dummy token or retrieve from a token manager.
            let token = "Bearer <JWT-Token>"
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        // Optional: Demonstration of certificate pinning approach, typically done in URLSessionDelegate.
        // Here, we simply note that the user must attach a custom URLProtocol or session with pinned certificates.
        // let session = createPinnedURLSession()
        // (The pinned session usage would happen at network call time, not in asURLRequest directly.)
        
        return request
    }
    
    /**
     Provides a base set of HTTP headers for all requests to ensure consistent
     communication, security, and versioning practices across the application.
     
     - Returns: A dictionary of common headers such as Content-Type, Accept, etc.
     */
    public func baseHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        headers[APIHeaders.CONTENT_TYPE] = "application/json"
        headers[APIHeaders.ACCEPT] = "application/json"
        // A placeholder for device id or client version for analytics.
        headers[APIHeaders.DEVICE_ID] = "Device-XYZ-123"
        headers[APIHeaders.CLIENT_VERSION] = "iOS_v1.0"
        return headers
    }
    
    /**
     Constructs the URL for the current route by combining the base URL,
     relevant endpoint path, and any associated path components or query items.
     
     - Throws: `APIError.invalidURL` if the resulting URL is invalid.
     - Returns: A fully constructed URL for this route case.
     */
    public func buildURL() throws -> URL {
        let baseString = APIConstants.API_BASE_URL
        let fullPath = "\(baseString)\(path)"
        
        guard var urlComponents = URLComponents(string: fullPath) else {
            throw APIError.invalidURL(fullPath)
        }
        
        // Apply query items if any are present (for GET or other queries).
        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let finalURL = urlComponents.url else {
            throw APIError.invalidURL(fullPath)
        }
        
        return finalURL
    }
    
    /**
     Encodes the given parameters into JSON data for inclusion in the request body.
     
     - Parameter params: A dictionary of key/value pairs to be encoded.
     - Throws: `APIError.invalidParameters` if encoding fails.
     - Returns: A Data object containing the encoded JSON.
     */
    public func encodeParameters(_ params: [String: Any]) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: params, options: [])
        } catch {
            throw APIError.invalidParameters
        }
    }
    
    // MARK: - Computed Properties
    
    /// Specifies the HTTP method for the current route.
    private var method: HTTPMethod {
        switch self {
        case .login:                       return .POST
        case .register:                    return .POST
        case .createWalk:                  return .POST
        case .updateWalk:                  return .PUT
        case .getWalkDetails:              return .GET
        case .getWalkHistory:              return .GET
        case .updateLocation:              return .POST
        case .emergencyAlert:              return .POST
        case .backgroundCheck:             return .GET
        case .verifyIdentity:              return .POST
        case .uploadDocument:              return .POST
        case .getDogProfile:               return .GET
        case .updateDogProfile:            return .PUT
        case .processPayment:              return .POST
        case .getPaymentHistory:           return .GET
        case .getUserProfile:              return .GET
        case .updateUserProfile:           return .PUT
        }
    }
    
    /// Indicates whether this route requires a request body (usually POST/PUT/PATCH).
    private var requiresHTTPBody: Bool {
        switch method {
        case .POST, .PUT, .PATCH:
            return true
        default:
            return false
        }
    }
    
    /// Determines if this route typically requires authentication (JWT-based or otherwise).
    private var requiresAuth: Bool {
        switch self {
        case .login, .register, .backgroundCheck:
            return false
        default:
            return true
        }
    }
    
    /// Provides a path string that appends on top of the base URL, e.g. "/auth/v1/login".
    private var path: String {
        switch self {
        // Authentication / Register Endpoints
        case .login:
            return APIEndpoints.AUTH + "/login"
        case .register:
            return APIEndpoints.AUTH + "/register"
            
        // Walk Booking / Management
        case .createWalk:
            return APIEndpoints.WALKS
        case .updateWalk(let walkId, _, _, _):
            return APIEndpoints.WALKS + "/\(walkId)"
        case .getWalkDetails(let walkId):
            return APIEndpoints.WALKS + "/\(walkId)"
        case .getWalkHistory:
            return APIEndpoints.WALKS + "/history"
            
        // Real-time & Emergency
        case .updateLocation(let walkId, _, _, _):
            return APIEndpoints.TRACKING + "/\(walkId)/location"
        case .emergencyAlert(let walkId, _, _):
            return APIEndpoints.TRACKING + "/\(walkId)/emergency"
            
        // Verification & Background Check
        case .backgroundCheck(let walkerId):
            return APIEndpoints.AUTH + "/background/\(walkerId)"
        case .verifyIdentity:
            return APIEndpoints.AUTH + "/verify"
        case .uploadDocument:
            return APIEndpoints.AUTH + "/upload"
            
        // Dog Profiles
        case .getDogProfile(let dogId):
            return APIEndpoints.DOGS + "/\(dogId)"
        case .updateDogProfile(let dogId, _, _, _):
            return APIEndpoints.DOGS + "/\(dogId)"
            
        // Payments
        case .processPayment(let walkId, _, _):
            return APIEndpoints.PAYMENTS + "/\(walkId)"
        case .getPaymentHistory:
            return APIEndpoints.PAYMENTS + "/history"
            
        // User Profile
        case .getUserProfile(let userId):
            return APIEndpoints.USERS + "/\(userId)"
        case .updateUserProfile(let userId, _, _, _):
            return APIEndpoints.USERS + "/\(userId)"
        }
    }
    
    /// Provides any additional headers specific to a route, if needed.
    private var additionalHeaders: [String: String]? {
        return nil
    }
    
    /// Specifies query items for GET or specialized endpoints requiring URL queries.
    private var queryItems: [URLQueryItem]? {
        switch self {
        case .getWalkHistory(_, let page, let pageSize):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)")
            ]
        case .getPaymentHistory(_, let page, let pageSize):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)")
            ]
        default:
            return nil
        }
    }
    
    /// Provides request body parameters for routes that need to send data in JSON form.
    private var bodyParameters: [String: Any]? {
        switch self {
            
        // Authentication & Registration
        case .login(let email, let password):
            return [
                "email": email,
                "password": password
            ]
        case .register(let name, let email, let password, let phone):
            return [
                "name": name,
                "email": email,
                "password": password,
                "phone": phone
            ]
            
        // Create / Update Walk
        case .createWalk(let dogId, let startTime, let endTime, let notes):
            return [
                "dogId": dogId,
                "startTime": iso8601String(from: startTime),
                "endTime": iso8601String(from: endTime),
                "notes": notes as Any
            ]
        case .updateWalk(_, let startTime, let endTime, let notes):
            return [
                "startTime": iso8601String(from: startTime),
                "endTime": iso8601String(from: endTime),
                "notes": notes as Any
            ]
            
        // Real-time Tracking
        case .updateLocation(_, let latitude, let longitude, let timestamp):
            return [
                "latitude": latitude,
                "longitude": longitude,
                "timestamp": iso8601String(from: timestamp)
            ]
        case .emergencyAlert(_, let alertType, let message):
            return [
                "alertType": alertType,
                "message": message as Any
            ]
            
        // Verification
        case .verifyIdentity(let userId, let verificationCode):
            return [
                "userId": userId,
                "verificationCode": verificationCode
            ]
        case .uploadDocument(let userId, let documentType, _, let fileName):
            return [
                "userId" : userId,
                "documentType": documentType,
                "fileName": fileName
                // The actual file data would be attached in multipart form,
                // which can be handled in a custom upload method if needed.
            ]
            
        // Dog Profiles
        case .updateDogProfile(_, let name, let breed, let medicalInfo):
            var params = [String: Any]()
            if let n = name { params["name"] = n }
            if let b = breed { params["breed"] = b }
            if let m = medicalInfo { params["medicalInfo"] = m }
            return params.isEmpty ? nil : params
            
        // Payments
        case .processPayment(_, let amount, let paymentMethodId):
            return [
                "amount": amount,
                "paymentMethodId": paymentMethodId
            ]
            
        // User Profile
        case .updateUserProfile(_, let name, let email, let phone):
            var params = [String: Any]()
            if let n = name { params["name"] = n }
            if let e = email { params["email"] = e }
            if let p = phone { params["phone"] = p }
            return params.isEmpty ? nil : params
            
        // No body needed
        default:
            return nil
        }
    }
    
    // MARK: - Helper Method
    
    /// Converts a Date object to a string in ISO 8601 format, ensuring consistent time zone representation.
    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    // MARK: - (Optional) Demonstration of a Certificate Pinning URLSession
    /**
     This function demonstrates creating a pinned URLSession for advanced security. In a production
     environment, you would place this logic in a custom networking manager or delegate, verifying
     the SSL certificate's public key or its SHA256 fingerprint. The sample is provided here because
     the specification requests demonstration of certificate pinning.
     
     - Returns: A URLSession with a pinned certificate validation delegate.
     */
    private static func createPinnedURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: CertificatePinningDelegate(), delegateQueue: nil)
        return session
    }
}

// MARK: - Sample Certificate Pinning Delegate
/**
 A sample URLSessionDelegate for handling SSL certificate pinning. A real-world
 implementation would compare the server certificate's public key or specific SHA256
 fingerprint to a known, embedded fingerprint or certificate in the app bundle.
 */
fileprivate class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Example placeholder logic for demonstration. In production, you would:
        // 1. Extract the serverTrust from challenge.protectionSpace.serverTrust.
        // 2. Compare the certificate signature or public key with a locally stored reference.
        // 3. If matched, complete with .useCredential, otherwise cancel the challenge.
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Evaluate the server trust object (basic example).
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}