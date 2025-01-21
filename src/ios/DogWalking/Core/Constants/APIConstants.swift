//
//  APIConstants.swift
//  DogWalking
//
//  Created by DogWalking Mobile Team
//  This file defines API-related constants including base URLs, endpoints,
//  timeouts, and configuration values for the iOS dog walking application's
//  network layer, supporting multiple environments and versioning.
//

import Foundation // iOS 13.0+ (Core iOS framework for essential types)

/**
 An enumeration that holds core API configuration constants.
 These constants include environment-specific values, request
 timeout settings, and retry logic thresholds for robust
 communication with the AWS API Gateway or any other endpoint.
 */
public enum APIConstants {
    
    /// Specifies the base URL for API requests. This value can be changed or
    /// readjusted based on the current environment (development, staging, production).
    public static let API_BASE_URL: String = {
        #if DEBUG
        return "https://dev-api.dogwalkingapp.com"
        #elseif STAGING
        return "https://staging-api.dogwalkingapp.com"
        #else
        return "https://prod-api.dogwalkingapp.com"
        #endif
    }()
    
    /// Defines the version string appended to endpoint paths to allow
    /// for versioned API calls and backward compatibility.
    public static let API_VERSION: String = "v1"
    
    /**
     Specifies the default timeout interval (in seconds) for API requests,
     ensuring that stalled connections are terminated gracefully to
     maintain app responsiveness.
     */
    public static let API_TIMEOUT_INTERVAL: TimeInterval = 30.0
    
    /**
     Sets the maximum number of retry attempts allowed for requests in the event
     of transient network failures or certain recoverable error conditions.
     */
    public static let API_MAX_RETRY_ATTEMPTS: Int = 3
    
    /**
     Represents the environment name (e.g., "development", "staging", "production").
     Can be used for logging or dynamic configuration checks.
     */
    public static let API_ENVIRONMENT: String = {
        #if DEBUG
        return "development"
        #elseif STAGING
        return "staging"
        #else
        return "production"
        #endif
    }()
    
    /**
     Specifies the socket timeout interval (in seconds) for network streams, which is
     particularly relevant for gRPC or WebSocket connections that may remain open.
     */
    public static let API_SOCKET_TIMEOUT: TimeInterval = 15.0
}

/**
 An enumeration that defines comprehensive endpoint paths for
 interactions with the Authentication, Booking, and related
 microservices. Integrates with the current API version from `APIConstants`.
 */
public enum APIEndpoints {
    
    /// Endpoint for user authentication-related requests.
    public static let AUTH: String = "/auth/\(APIConstants.API_VERSION)"
    
    /// Endpoint for creating, retrieving, or managing walk bookings.
    public static let WALKS: String = "/walks/\(APIConstants.API_VERSION)"
    
    /// Endpoint for dog-specific operations (e.g., adding, editing, listing).
    public static let DOGS: String = "/dogs/\(APIConstants.API_VERSION)"
    
    /// Endpoint for payment-related requests to handle billing and transactions.
    public static let PAYMENTS: String = "/payments/\(APIConstants.API_VERSION)"
    
    /// Endpoint for real-time tracking of walks or user location data.
    public static let TRACKING: String = "/track/\(APIConstants.API_VERSION)"
    
    /// Endpoint for user resource management (profiles, settings, etc.).
    public static let USERS: String = "/users/\(APIConstants.API_VERSION)"
    
    /// Endpoint for creating, viewing, or managing user and walker reviews.
    public static let REVIEWS: String = "/reviews/\(APIConstants.API_VERSION)"
    
    /// Endpoint for sending or receiving notifications (push messages, alerts, etc.).
    public static let NOTIFICATIONS: String = "/notifications/\(APIConstants.API_VERSION)"
}

/**
 An enumeration that defines comprehensive HTTP header keys
 for the application, ensuring consistent naming conventions,
 security protocol compliance, and request traceability.
 */
public enum APIHeaders {
    
    /// Indicates the format of the request or response payload (e.g., "application/json").
    public static let CONTENT_TYPE: String = "Content-Type"
    
    /// Used for including JWT or other tokens to authorize requests.
    public static let AUTHORIZATION: String = "Authorization"
    
    /**
     Identifies acceptable response media types from the server
     (e.g., "application/json").
     */
    public static let ACCEPT: String = "Accept"
    
    /**
     Unique identifier for the current device, used in analytics
     and certain forms of request validation.
     */
    public static let DEVICE_ID: String = "X-Device-Id"
    
    /**
     API key header for services that might require an additional
     static or dynamic key in conjunction with JWT-based authorization.
     */
    public static let API_KEY: String = "X-API-Key"
    
    /**
     Specifies the version of encryption or cryptographic protocols
     to be used by the client when sending or receiving sensitive data.
     */
    public static let ENCRYPTION_VERSION: String = "X-Encryption-Version"
    
    /**
     Indicates the client app version, helpful for server-side logging,
     feature toggles, or forced upgrade logic.
     */
    public static let CLIENT_VERSION: String = "X-Client-Version"
}

/**
 An enumeration that defines HTTP status codes (and custom codes),
 providing a comprehensive set of response statuses to handle
 success cases, errors, and specific network failures.
 */
public enum APIStatusCodes {
    
    /// Standard HTTP 200 success response
    public static let SUCCESS: Int = 200
    
    /// Standard HTTP 201 created response
    public static let CREATED: Int = 201
    
    /// Standard HTTP 400 bad request error
    public static let BAD_REQUEST: Int = 400
    
    /// Standard HTTP 401 unauthorized error
    public static let UNAUTHORIZED: Int = 401
    
    /// Standard HTTP 404 not found error
    public static let NOT_FOUND: Int = 404
    
    /// Standard HTTP 500 internal server error
    public static let SERVER_ERROR: Int = 500
    
    /// Standard HTTP 503 service unavailable error
    public static let SERVICE_UNAVAILABLE: Int = 503
    
    /**
     Custom status code representing a network error
     such as connection issues or DNS failures where
     we cannot reach the server at all.
     */
    public static let NETWORK_ERROR: Int = -1
    
    /**
     Custom status code representing a client or server timeout,
     indicating that a request or response took too long.
     */
    public static let TIMEOUT_ERROR: Int = -2
}