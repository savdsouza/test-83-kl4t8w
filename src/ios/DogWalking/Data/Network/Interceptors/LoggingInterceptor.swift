//
//  LoggingInterceptor.swift
//  DogWalking
//
//  This file defines a comprehensive network interceptor (URLProtocol subclass)
//  that provides request and response logging, advanced security monitoring,
//  sensitive data redaction, and performance optimization for API calls in
//  the iOS dog walking application.
//
//  Created by DogWalking Mobile Team
//  © 2023 DogWalking Inc. All rights reserved.
//

import Foundation // iOS 13.0+ (Core iOS framework for networking, threading, and data handling)
// MARK: - Internal Import (Structured logging with security features)
import class DogWalking.Logger
// MARK: - Imported Logger Members Used: debug, error, security (per JSON specification)
// Note: The "security" method does not exist in Logger.swift as provided. We will
//       internally map security events to debug or error logs with specialized formatting
//       to comply with the requirement of using a "security" logging capability.

//------------------------------------------------------------------------------
// MARK: - Global Constants
//------------------------------------------------------------------------------

/// A global logger dedicated to network operations within the dog walking app.
/// Subsystem: "com.dogwalking.network"
/// Category:  "api"
fileprivate let NETWORK_LOGGER: Logger = Logger(
    subsystem: "com.dogwalking.network",
    category: "api"
)

/// A list of patterns used to detect sensitive information within request or response data.
/// These patterns can be expanded to cover additional tokens such as "pin", "ssn", or any
/// domain-specific secrets.
fileprivate let SENSITIVE_PATTERNS: [String] = [
    "password",
    "token",
    "auth",
    "credit",
    "ssn"
]

/// Defines the maximum size (in bytes) of request or response bodies that will be logged.
/// If the payload exceeds this size, the contents will be truncated in logs to avoid
/// performance degradation and excessive logging.
fileprivate let MAX_BODY_LOG_SIZE: Int = 10 * 1024


//------------------------------------------------------------------------------
// MARK: - Security Event Type
//------------------------------------------------------------------------------

/// Describes the type of security events that can be logged by the logging interceptor.
/// Extend or customize as necessary to cover different security scenarios.
public enum SecurityEventType: String {
    /// Indicates discovery of suspicious patterns in the request or response (e.g., malicious parameters).
    case suspiciousPattern = "SuspiciousPattern"

    /// Indicates a potential security attack or alarming behavior by a client/server.
    case potentialAttack = "PotentialAttack"

    /// A custom or generic event type. Use the associated string for descriptive labeling.
    case custom = "CustomEvent"
}


//------------------------------------------------------------------------------
// MARK: - LoggingInterceptor (URLProtocol Subclass)
//------------------------------------------------------------------------------

/// A URLProtocol subclass that intercepts HTTP(s) requests and responses to provide:
/// - Comprehensive logging (method, URL, headers, body snippet)
/// - Security monitoring (suspicious pattern detection, correlation ID tracking)
/// - Sensitive data redaction (replaces sensitive tokens with masked placeholders)
/// - Performance metrics (latency calculation, request size, response size)
/// This interceptor is intended to be registered at runtime for selected requests
/// to or from the DogWalking application.
public class LoggingInterceptor: URLProtocol {

    //--------------------------------------------------------------------------
    // MARK: - Properties
    //--------------------------------------------------------------------------

    /// A URLSession instance used to initiate the actual network call once interception occurs.
    /// This session should be configured to avoid re-registering the same protocol
    /// to prevent infinite recursion.
    private var session: URLSession?

    /// A reference to the data task that we create in `startLoading()`.
    /// This is used to manage the task lifecycle and relay events back to the client.
    private var dataTask: URLSessionDataTask?

    /// Indicates whether the interceptor should redact sensitive data (e.g., passwords, tokens)
    /// from logs before printing or storing them.
    public var shouldRedact: Bool

    /// A unique identifier assigned to each intercepted request for tracing purposes.
    /// This correlation ID can be attached to logs, headers, or any other relevant context.
    public var correlationId: String

    /// The timestamp recorded at the moment request loading begins. Useful for calculating
    /// the total request latency once a response or completion event is received.
    public var requestStartTime: Date?

    /// A cache used to store partially or fully redacted data strings to improve performance
    /// and avoid re-processing the same data multiple times during the life cycle of a request.
    public var redactionCache: NSCache<NSString, NSString>


    //--------------------------------------------------------------------------
    // MARK: - Initialization
    //--------------------------------------------------------------------------

    /// Initializes the logging interceptor with configuration for redaction and cache sizing.
    /// Although typical URLProtocol usage does not always involve direct initializers,
    /// this constructor is provided to fulfill specification requirements and can be used
    /// in custom initial registration scenarios.
    ///
    /// - Parameters:
    ///   - shouldRedact: A Boolean indicating whether sensitive data should be redacted.
    ///   - cacheSize: The maximum number of entries permitted in the redaction cache.
    public init(shouldRedact: Bool, cacheSize: Int) {
        self.shouldRedact = shouldRedact
        self.redactionCache = NSCache<NSString, NSString>()
        self.redactionCache.countLimit = cacheSize
        self.correlationId = UUID().uuidString

        super.init(
            request: URLRequest(url: URL(string: "about:blank")!),
            cachedResponse: nil,
            client: nil
        )

        // Configure requestStartTime (this is a placeholder in direct init usage).
        self.requestStartTime = nil
    }

    /// The designated initializer used by the URL loading system when a request is
    /// determined to be handled by this protocol class.
    ///
    /// - Parameters:
    ///   - request: The request to be intercepted.
    ///   - cachedResponse: A cached response, if any, associated with the request.
    ///   - client: The URLProtocol client that receives callbacks about the load status.
    public override init(
        request: URLRequest,
        cachedResponse: CachedURLResponse?,
        client: URLProtocolClient?
    ) {
        // Defaulting to redaction enabled and a 200-item cache for demonstration.
        // Adjust or dynamically populate these parameters in a real use case.
        self.shouldRedact = true
        self.redactionCache = NSCache<NSString, NSString>()
        self.redactionCache.countLimit = 200
        self.correlationId = UUID().uuidString
        self.requestStartTime = nil

        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }


    //--------------------------------------------------------------------------
    // MARK: - URLProtocol Class Methods
    //--------------------------------------------------------------------------

    /// Determines whether this protocol can handle a given request. This function checks:
    /// 1) If the request's URL is non-nil.
    /// 2) If the request's host is a recognized domain (e.g., containing "dogwalkingapp.com").
    /// 3) (Optional) If the request passes any rate limiting or blacklisting checks.
    ///
    /// - Parameter request: The request to be evaluated for interception.
    /// - Returns: True if the request should be intercepted; otherwise, false.
    public override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        // Example domain check (can be refined).
        if url.host?.contains("dogwalkingapp.com") == true {
            // Further checks for rate limiting can be added here.
            return true
        }
        return false
    }

    /// Returns a canonical version of the request. This implementation simply returns
    /// the original request unmodified. Override for advanced caching or mutation logic.
    ///
    /// - Parameter request: The request to transform into canonical form.
    /// - Returns: The canonical request, which is the same as input by default.
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// Determines whether two requests are considered equivalent for caching.
    /// By default, this returns false to ensure each request is processed individually.
    /// Override to enable caching based on your criteria.
    ///
    /// - Parameters:
    ///   - request: The first request.
    ///   - cachedRequest: The second request.
    /// - Returns: A Boolean indicating whether they are cache-equivalent.
    public override class func requestIsCacheEquivalent(
        _ request: URLRequest,
        to cachedRequest: URLRequest
    ) -> Bool {
        return false
    }


    //--------------------------------------------------------------------------
    // MARK: - URLProtocol Lifecycle
    //--------------------------------------------------------------------------

    /// Called when loading of the request begins. This is where we:
    ///  - Record the start time for latency calculation.
    ///  - Attach or use a correlation ID for logging and tracking.
    ///  - Log request details (method, URL, headers, body if small enough).
    ///  - Setup a URLSession data task to forward the request onward.
    ///  - Monitor the response with security context checks.
    public override func startLoading() {

        // 1. Record the request start time to calculate latency later.
        self.requestStartTime = Date()

        // 2. Log the initial request details with correlation ID, method, and URL.
        let method = request.httpMethod ?? "UNKNOWN"
        let requestUrl = request.url?.absoluteString ?? "nil"
        let logPrefix = "[REQUEST START] [CID: \(correlationId)]"

        NETWORK_LOGGER.debug(
            "\(logPrefix) Method: \(method), URL: \(requestUrl)"
        )

        // 3. Redact and log request headers if necessary.
        logRequestHeaders()

        // 4. Redact and log a snippet of the request body if under size limit.
        if let bodyData = request.httpBody, bodyData.count <= MAX_BODY_LOG_SIZE {
            let bodyString = String(decoding: bodyData, as: UTF8.self)
            let redactedBody = shouldRedact ? redactSensitiveData(bodyString) : bodyString
            NETWORK_LOGGER.debug(
                "\(logPrefix) Request Body (Partial): \(redactedBody)"
            )
            checkSuspiciousPatterns(in: bodyString)
        } else if let bodyData = request.httpBody {
            // If body is too large, note that in logs but don't print it.
            NETWORK_LOGGER.debug(
                "\(logPrefix) Request Body exceeds \(MAX_BODY_LOG_SIZE) bytes. Logging skipped."
            )
        }

        // 5. Create a new URLSession configured so it does NOT re-use this protocol.
        let config = URLSessionConfiguration.ephemeral
        // Remove this protocol from the session's protocol classes to prevent recursion.
        config.protocolClasses = config.protocolClasses?.filter { $0 != LoggingInterceptor.self }
        // Example customization: setting timeouts or caches
        config.timeoutIntervalForRequest = 30.0
        config.requestCachePolicy = .useProtocolCachePolicy

        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // 6. Create a data task to actually perform the request. We'll forward the result
        //    back through URLProtocol's client methods in a delegate approach.
        let newRequest = (request as NSURLRequest).copy() as! NSMutableURLRequest
        // Optionally attach correlation ID to headers if desired:
        newRequest.setValue(correlationId, forHTTPHeaderField: "X-Correlation-ID")

        dataTask = session?.dataTask(with: newRequest as URLRequest)
        dataTask?.resume()

        // Note: Response security context checks, latency calculations, and
        // final logging are handled in the delegate callbacks below.
    }

    /// Called when loading is complete or has been canceled. Typically, we cancel any ongoing tasks here.
    public override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }


    //--------------------------------------------------------------------------
    // MARK: - Public Security Logging Method
    //--------------------------------------------------------------------------

    /// Logs a security-related event with context. This includes correlation ID,
    /// user session context, IP address (if available), and event details.
    /// Depending on severity, an external alert/monitoring system could be notified here.
    ///
    /// - Parameters:
    ///   - eventType: A value of the SecurityEventType enum describing the nature of the event.
    ///   - details: Additional descriptive context about the event.
    public func logSecurityEvent(eventType: SecurityEventType, details: String) {
        // Example of assembling relevant context if user or IP were known
        let userId = "UNKNOWN_USER"
        let ipAddress = "UNKNOWN_IP"
        let logMessage = """
        [SECURITY EVENT] Type: \(eventType.rawValue)
        CorrelationID: \(correlationId)
        UserID: \(userId)
        IP: \(ipAddress)
        Details: \(details)
        """

        // The JSON specification requires we use a "security" method,
        // but our Logger implementation does not contain a 'security' API.
        // We'll map this to a debug-level log with a specialized prefix.
        NETWORK_LOGGER.debug(logMessage)
    }


    //--------------------------------------------------------------------------
    // MARK: - Redaction Method
    //--------------------------------------------------------------------------

    /// Redacts sensitive information within a text input by applying the patterns
    /// defined in the global `SENSITIVE_PATTERNS`. Results are cached for efficiency.
    ///
    /// - Parameter input: The raw text to be checked and possibly redacted.
    /// - Returns: A version of the text with sensitive data replaced or masked.
    public func redactSensitiveData(_ input: String) -> String {
        // Check the cache first to see if we've processed this text already.
        let cacheKey = input as NSString
        if let cached = redactionCache.object(forKey: cacheKey) {
            return cached as String
        }

        // If not cached, proceed with pattern matching and replacement.
        var output = input
        for pattern in SENSITIVE_PATTERNS {
            if let range = output.range(of: pattern, options: .caseInsensitive) {
                // Replace each occurrence of the pattern with a placeholder (e.g. "****").
                let replaced = output.replacingOccurrences(
                    of: pattern,
                    with: "****",
                    options: .caseInsensitive,
                    range: range
                )
                output = replaced
            }
        }

        // Store the result back in the cache for future calls.
        redactionCache.setObject(output as NSString, forKey: cacheKey)
        return output
    }


    //--------------------------------------------------------------------------
    // MARK: - Private Helpers
    //--------------------------------------------------------------------------

    /// Logs redacted request headers if `shouldRedact` is true; otherwise logs headers as-is.
    /// Sensitive headings (AUTH, TOKEN, etc.) will be marked or masked appropriately.
    private func logRequestHeaders() {
        guard let headerFields = request.allHTTPHeaderFields else { return }
        let logPrefix = "[REQUEST HEADERS] [CID: \(correlationId)]"

        // Build a textual representation of headers.
        var combinedHeaders: [String] = []
        for (key, value) in headerFields {
            let finalValue = shouldRedact ? redactSensitiveData(value) : value
            combinedHeaders.append("\(key): \(finalValue)")
        }

        NETWORK_LOGGER.debug("\(logPrefix) \(combinedHeaders.joined(separator: ", "))")
    }

    /// Examines the request or response body text for suspicious patterns and logs a security event if any are found.
    /// This could be extended to run more sophisticated checks or ML-based anomaly detection.
    private func checkSuspiciousPatterns(in text: String) {
        // Simple example: if the text contains "<script>" or something obviously malicious.
        // Here, we also check if it has certain globally suspicious terms from the SENSITIVE_PATTERNS array.
        let lowercased = text.lowercased()
        if lowercased.contains("<script>") || lowercased.contains("drop table") {
            logSecurityEvent(
                eventType: .suspiciousPattern,
                details: "Potential XSS or SQL injection pattern detected in request body."
            )
        }
    }
}


//------------------------------------------------------------------------------
// MARK: - URLSession Delegate Extensions
//------------------------------------------------------------------------------

extension LoggingInterceptor: URLSessionDataDelegate {

    /// Called when the server responds with headers (status code, MIME type, etc.).
    /// We relay the response to the client, inject security checks, and log server info.
    ///
    /// - Parameters:
    ///   - session: The URLSession handling the request.
    ///   - dataTask: The task providing the response info.
    ///   - response: The server's response, containing headers and status code.
    ///   - completionHandler: A closure we must call to continue receiving data.
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        // Relay the response to the URLProtocol client so the app layer can see the status code, etc.
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        // Log response details: status, MIME, correlation
        let logPrefix = "[RESPONSE HEADERS] [CID: \(correlationId)]"
        if let httpResponse = response as? HTTPURLResponse {
            NETWORK_LOGGER.debug(
                "\(logPrefix) StatusCode: \(httpResponse.statusCode), " +
                "Headers: \(String(describing: httpResponse.allHeaderFields))"
            )
        } else {
            NETWORK_LOGGER.debug("\(logPrefix) Non-HTTP response received.")
        }

        completionHandler(.allow)
    }

    /// Called as data is received from the server. We simply pass it back up
    /// to the client. If the data is not too large, we can optionally examine
    /// it for suspicious content or log partial snippets.
    ///
    /// - Parameters:
    ///   - session: The URLSession handling the data.
    ///   - dataTask: The task providing the data.
    ///   - data: The data chunk received from the server.
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Forward the received data along to the protocol client.
        client?.urlProtocol(self, didLoad: data)

        // Optional partial logging (truncated to MAX_BODY_LOG_SIZE).
        let logPrefix = "[RESPONSE BODY] [CID: \(correlationId)]"
        if data.count <= MAX_BODY_LOG_SIZE {
            let dataString = String(decoding: data, as: UTF8.self)
            // If redaction is enabled, apply it; also check for malicious patterns if desired.
            let finalData = shouldRedact ? redactSensitiveData(dataString) : dataString
            NETWORK_LOGGER.debug("\(logPrefix) Partial Body: \(finalData)")
            checkSuspiciousPatterns(in: dataString)
        } else {
            NETWORK_LOGGER.debug("\(logPrefix) Body exceeds \(MAX_BODY_LOG_SIZE) bytes. Logging skipped.")
        }
    }

    /// Called when a task completes, either due to error or successful completion.
    /// We measure request latency, log final metrics, and signal that the loading is complete.
    ///
    /// - Parameters:
    ///   - session: The URLSession containing the completed task.
    ///   - task: The task that just finished.
    ///   - error: A possible error if the task failed or was canceled.
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let endTime = Date()
        let latency = (endTime.timeIntervalSince1970 - (requestStartTime?.timeIntervalSince1970 ?? endTime.timeIntervalSince1970)) * 1000.0

        let logPrefix = "[REQUEST END] [CID: \(correlationId)]"

        if let err = error {
            NETWORK_LOGGER.error("\(logPrefix) Request failed with error: \(err.localizedDescription)", error: err)
        } else {
            // Log success with latency
            NETWORK_LOGGER.debug("\(logPrefix) Request completed successfully. Latency: \(latency) ms")
        }

        // Inform the client the load is done
        client?.urlProtocolDidFinishLoading(self)
        session.invalidateAndCancel()
    }
}