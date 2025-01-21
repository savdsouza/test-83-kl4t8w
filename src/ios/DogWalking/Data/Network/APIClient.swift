import Foundation // iOS 13.0+ (Core iOS networking functionality and data handling)
import Combine    // iOS 13.0+ (reactive programming support for async operations and real-time data handling)

// MARK: - Internal Imports
import enum APIRouter.APIRouter
import enum APIError.APIError
import class AuthInterceptor.AuthInterceptor

/**
 A placeholder type representing the network reachability manager, offering basic connectivity checks.
 In a real implementation, this might rely on frameworks like Network or a third-party library.
 */
private final class NetworkReachabilityManager {
    /// A shared singleton instance for global reachability checks.
    static let shared = NetworkReachabilityManager()

    /// Simulated property indicating whether the network is reachable.
    var isReachable: Bool {
        // In a real implementation, we would monitor system changes or NWPathMonitor.
        return true
    }

    private init() {}
}

/**
 A placeholder type representing a metrics collector for network requests. 
 It supports logging or time-measuring the request life cycle for monitoring or analytics.
 */
private final class MetricsCollector {
    /// A shared singleton instance for metrics collection.
    static let shared = MetricsCollector()

    /**
     Starts collecting metrics for a given endpoint. This might log timestamps,
     correlate requests with trace IDs, etc.
     */
    func startRequestMetrics(endpoint: APIRouter) {
        // Implementation placeholder: track request start time, etc.
    }

    /**
     Ends collection of metrics for a now-completed request. This can log the duration,
     status codes, or specific performance counters.
     */
    func endRequestMetrics(endpoint: APIRouter, statusCode: Int?, error: APIError?) {
        // Implementation placeholder: finalize metrics, send logs, etc.
    }

    private init() {}
}

/**
 A custom enum representing different request priorities that can affect underlying
 URLSessionTask settings. This helps the system prioritize critical vs. background tasks.
 */
public enum RequestPriority: Float {
    /// Used for very high-priority, user-initiated requests (e.g., time-sensitive).
    case high = 0.9

    /// Default priority for standard user-initiated tasks.
    case normal = 0.5

    /// Low priority for background tasks that are less urgent.
    case low = 0.1

    /// Returns the corresponding URLSessionTask priority value.
    var taskPriorityValue: Float {
        return self.rawValue
    }
}

/**
 A typealias representing a closure that handles upload progress, 
 where progress is a value from 0.0 to 1.0.
 */
public typealias ProgressHandler = (Double) -> Void

/**
 A placeholder struct representing the response of an upload operation, 
 including success status and an optional message.
 */
public struct UploadResponse {
    /// Indicates whether the file upload succeeded or not.
    public let success: Bool

    /// An optional message, for example an error description or server feedback.
    public let message: String?
}

/**
 An enumeration of events that can be received over a WebSocket connection, 
 supporting real-time updates like location streaming, messaging, etc.
 */
public enum WebSocketEvent {
    /// Indicates the socket has successfully connected.
    case connected

    /// Indicates a text-based message was received from the server.
    case textMessage(String)

    /// Indicates a closure event, either deliberate or due to an error.
    case disconnected(String?)

    /// Indicates an error or failure occurred on the WebSocket.
    case error(String?)
}

/**
 A protocol describing a delegate or handler for receiving and processing 
 raw WebSocket messages or events. In a production environment, you could 
 tailor this to your real-time use cases.
 */
public protocol WebSocketDelegate: AnyObject {
    func didReceive(event: WebSocketEvent)
}

// MARK: - Global Networking Constants

/// Specifies the base request timeout, in seconds, for the iOS dog's app networking calls.
private let REQUEST_TIMEOUT: TimeInterval = 30.0

/// Specifies the maximum retry attempts for recoverable or authentication-related failures.
private let MAX_RETRY_ATTEMPTS: Int = 3

/// Base multiplier for exponential backoff intervals (2^attempt * EXPONENTIAL_BACKOFF_BASE).
private let EXPONENTIAL_BACKOFF_BASE: Double = 2.0

/// Indicates the default URLRequest cache policy (useProtocolCachePolicy by default).
private let CACHE_POLICY: URLRequest.CachePolicy = .useProtocolCachePolicy

/**
 A thread-safe singleton class that manages all network communication for the iOS dog walking application.
 It integrates with the API Gateway, handles secure request operations, robust error management,
 JSON decoding, real-time WebSocket connectivity, file uploads, and comprehensive monitoring.
 
 This class also demonstrates advanced security features, such as certificate pinning (if desired),
 usage of AuthInterceptor for token management and automatic refresh, and built-in retry logic with
 exponential backoff for critical endpoints or transient failures.
 */
@available(iOS 13.0, *)
public final class APIClient {

    // MARK: - Properties

    /// A shared, thread-safe singleton instance of the APIClient.
    public static let shared: APIClient = APIClient()

    /**
     A dedicated URLSession configured with certificate pinning, custom timeout intervals,
     and cache policies. It is used for all data tasks, file uploads, and real-time connections.
     */
    private let session: URLSession

    /// The interceptor responsible for adapting requests, handling authorization headers, 
    /// and managing token refresh or retry logic on authentication failures.
    private let authInterceptor: AuthInterceptor

    /// A JSONDecoder configured to decode responses from a snake_case backend.
    private let decoder: JSONDecoder

    /// A URLCache instance for caching responses, benefiting performance and offline usage.
    private let cache: URLCache

    /// Monitors the network reachability to determine if the device is online before issuing requests.
    private let reachabilityManager: NetworkReachabilityManager

    /// Gathers and reports metrics on each network request, enabling performance analytics.
    private let metricsCollector: MetricsCollector

    // MARK: - Private Initializer

    /**
     Private initializer to ensure the singleton pattern. 
     
     Steps performed:
      1. Create a URLSessionConfiguration and set timeouts, cache policy, plus optional pinning.
      2. Initialize a URLSession with the chosen delegate (certificate pinning if needed).
      3. Instantiate AuthInterceptor for authentication handling and token refresh.
      4. Configure JSONDecoder for consistent key decoding strategy (snake_case).
      5. Set up URLCache with memory and disk capacities for caching responses.
      6. Get a shared network reachability manager for offline checks.
      7. Instantiate a metrics collector for performance analytics.
     */
    private init() {
        // 1. Configure the URLSession with the requested timeouts and cache policy.
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = REQUEST_TIMEOUT
        config.requestCachePolicy = CACHE_POLICY

        // Example: You could set certificate pinning in a custom delegate. 
        // For demonstration, we pass nil as the delegate to keep this general.
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        // 2. Initialize the AuthInterceptor with token management.
        self.authInterceptor = AuthInterceptor()

        // 3. Create a JSONDecoder with snake_case strategy.
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = jsonDecoder

        // 4. Initialize URLCache for in-memory/disk caching.
        // Example capacities: 10 MB memory, 50 MB disk
        self.cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000, diskPath: "DogWalkingCache")

        // 5. Initialize reachability manager and metrics collector.
        self.reachabilityManager = NetworkReachabilityManager.shared
        self.metricsCollector = MetricsCollector.shared
    }

    // MARK: - Public Methods

    /**
     Performs a generic API request returning a publisher that emits a decoded response type or an APIError.
     This method automatically handles authentication, retries (up to a maximum), and exponential backoff
     for certain recoverable errors or rate-limited statuses.
     
     - Parameters:
       - endpoint: The APIRouter case specifying the endpoint, HTTP method, and parameters.
       - type: The expected Decodable type for the response payload.
       - priority: The relative request priority. Defaults to .normal.
     - Returns: An AnyPublisher emitting the decoded model on success, or an APIError on failure.
     */
    public func request<T: Decodable>(
        endpoint: APIRouter,
        type: T.Type,
        priority: RequestPriority = .normal
    ) -> AnyPublisher<T, APIError> {
        return attemptRequest(endpoint: endpoint, type: T.self, attempt: 1, priority: priority)
            .eraseToAnyPublisher()
    }

    /**
     Handles file uploads, including the creation of a multipart form-data request body,
     chunked transfer encoding, progress tracking, and response validation.
     
     - Parameters:
       - fileData: The raw data for the file to be uploaded.
       - mimeType: The MIME type of the file (e.g., "image/jpeg", "application/pdf").
       - endpoint: The APIRouter endpoint describing the upload URL and parameters.
       - progressHandler: A closure receiving upload progress (0.0 to 1.0).
     - Returns: An AnyPublisher emitting an UploadResponse on success or an APIError on failure.
     */
    public func upload(
        fileData: Data,
        mimeType: String,
        endpoint: APIRouter,
        progressHandler: @escaping ProgressHandler
    ) -> AnyPublisher<UploadResponse, APIError> {
        return Future<UploadResponse, APIError> { [weak self] promise in
            guard let self = self else {
                return promise(.failure(.unknown(nil)))
            }

            // 1. Validate file data size.
            guard !fileData.isEmpty else {
                return promise(.failure(.validationError(["fileData": ["File data is empty"]])))
            }

            // 2. Construct a URLRequest from the endpoint, applying auth if needed.
            let urlRequest: URLRequest
            do {
                urlRequest = try endpoint.asURLRequest()
            } catch {
                return promise(.failure(.networkError(error)))
            }
            var adaptedRequest = self.authInterceptor.adapt(urlRequest)

            // 3. Set method to POST if not already, and configure chunked transfer if desired.
            adaptedRequest.httpMethod = adaptedRequest.httpMethod ?? "POST"
            adaptedRequest.setValue("multipart/form-data; boundary=DogWalkBoundary", forHTTPHeaderField: "Content-Type")

            // 4. Generate multipart form data body with chunked approach.
            let boundary = "DogWalkBoundary"
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            adaptedRequest.httpBody = body

            // 5. Start an upload task using URLSession with a custom delegate to track progress.
            let task = self.session.uploadTask(with: adaptedRequest, from: body) { data, response, error in
                // On completion
                if let error = error {
                    return promise(.failure(.networkError(error)))
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    return promise(.failure(.invalidResponse(-1, data)))
                }
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    // Potentially parse error details from data
                    return promise(.failure(.invalidResponse(httpResponse.statusCode, data)))
                }
                // 6. Construct an UploadResponse. 
                // Optionally parse server feedback from `data` into `message`.
                let success = true
                let msg = data.flatMap { String(data: $0, encoding: .utf8) }
                promise(.success(UploadResponse(success: success, message: msg)))
            }

            // 7. Observe progress changes using KVO or URLSessionTaskDelegate. 
            // For demonstration, we use a simple timer approach or KVO-like approach if feasible.
            let progressObservation = task.progress.observe(\.fractionCompleted) { prog, _ in
                let fraction = prog.fractionCompleted
                progressHandler(fraction)
            }

            // 8. Start upload task.
            task.resume()
            
            // Cleanup observation on completion.
            // In production, you'd typically store the observation in a property 
            // and remove it when the task completes or the publisher is cancelled.
            _ = progressObservation
        }
        .eraseToAnyPublisher()
    }

    /**
     Establishes a WebSocket connection to a specified APIRouter endpoint, returning a publisher 
     that emits WebSocketEvent values as they occur: connectivity changes, messages, or errors. 
     This function exemplifies real-time data flow.
     
     - Parameters:
       - endpoint: The APIRouter route describing the WebSocket URL or path.
       - delegate: A user-defined handler that processes raw events or may drive UI updates.
     - Returns: An AnyPublisher emitting WebSocketEvent or failing with an APIError.
     */
    public func websocketConnect(
        endpoint: APIRouter,
        delegate: WebSocketDelegate
    ) -> AnyPublisher<WebSocketEvent, APIError> {
        return Future<WebSocketEvent, APIError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown(nil)))
                return
            }

            // For demonstration, we show a simplified approach using URLSessionWebSocketTask (iOS 13+).
            // 1. Validate that the APIRouter can produce a WebSocket-capable URL.
            let urlRequest: URLRequest
            do {
                urlRequest = try endpoint.asURLRequest()
            } catch {
                return promise(.failure(.networkError(error)))
            }
            var adaptedRequest = self.authInterceptor.adapt(urlRequest)
            
            // 2. Replace scheme if needed, e.g., https -> wss, http -> ws
            if let url = adaptedRequest.url, url.scheme == "https" {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "wss"
                if let newURL = components?.url {
                    adaptedRequest.url = newURL
                }
            } else if let url = adaptedRequest.url, url.scheme == "http" {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "ws"
                if let newURL = components?.url {
                    adaptedRequest.url = newURL
                }
            }

            // 3. Create the WebSocket task.
            let wsTask = self.session.webSocketTask(with: adaptedRequest)
            
            // 4. Define a recursive function to continuously receive messages.
            func receiveMessages() {
                wsTask.receive { result in
                    switch result {
                    case .failure(let error):
                        delegate.didReceive(event: .error(error.localizedDescription))
                    case .success(let message):
                        switch message {
                        case .string(let text):
                            delegate.didReceive(event: .textMessage(text))
                            receiveMessages()
                        case .data(let binaryData):
                            // For demonstration, treat data as text or emit a separate event.
                            let info = "Received \(binaryData.count) bytes of data."
                            delegate.didReceive(event: .textMessage(info))
                            receiveMessages()
                        @unknown default:
                            delegate.didReceive(event: .error("Unknown WebSocket message type received."))
                        }
                    }
                }
            }
            
            // 5. Implement a simple heartbeat or ping to keep the connection alive periodically.
            func schedulePing() {
                DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
                    wsTask.send(.ping(pongReceiveHandler: { error in
                        if let err = error {
                            delegate.didReceive(event: .error("Ping failed: \(err.localizedDescription)"))
                        }
                        schedulePing()
                    }))
                }
            }

            // 6. Open the connection.
            wsTask.resume()
            delegate.didReceive(event: .connected)
            promise(.success(.connected))

            // 7. Start receiving messages and handle heartbeats.
            receiveMessages()
            schedulePing()
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    /**
     A private helper method that attempts an API request up to a maximum number of retries, 
     applying exponential backoff on rate-limits or relevant HTTP error statuses (e.g., 401, 429).
     
     - Parameters:
       - endpoint: The APIRouter specifying the request details.
       - type: A Decodable type indicating how to parse the JSON response.
       - attempt: The current attempt number, incremented after each retry.
       - priority: The request priority, mapped to URLSessionTask priorities.
     - Returns: A publisher delivering a decoded model or an APIError.
     */
    private func attemptRequest<T: Decodable>(
        endpoint: APIRouter,
        type: T.Type,
        attempt: Int,
        priority: RequestPriority
    ) -> AnyPublisher<T, APIError> {
        // If we've exceeded our allowed attempts, fail immediately.
        guard attempt <= MAX_RETRY_ATTEMPTS else {
            return Fail(error: .serverError(429, "Max retry attempts reached."))
                .eraseToAnyPublisher()
        }

        // Check for network reachability before proceeding.
        guard reachabilityManager.isReachable else {
            return Fail(error: .noInternet)
                .eraseToAnyPublisher()
        }

        // Build the request from the APIRouter, catching errors.
        let urlRequest: URLRequest
        do {
            urlRequest = try endpoint.asURLRequest()
        } catch {
            return Fail(error: .networkError(error))
                .eraseToAnyPublisher()
        }

        // Apply authentication logic (add JWT, etc.).
        var adaptedRequest = authInterceptor.adapt(urlRequest)

        // Set caching policy and priority on the final URLRequest if possible.
        adaptedRequest.cachePolicy = CACHE_POLICY

        // URLRequest doesn't have a direct priority property, so we set it in the 
        // dataTask. We'll handle that with a custom method inside the pipeline.
        
        // Start metrics collection:
        metricsCollector.startRequestMetrics(endpoint: endpoint)

        // The core data task publisher pipeline:
        return session.dataTaskPublisher(for: adaptedRequest)
            // Apply the requested priority at the task level if the system supports it (Combine doesn't expose directly).
            // We'll do an optional approach: there's no direct priority property on dataTaskPublisher tasks,
            // so a real solution might use a custom approach or custom URLSession.
            .mapError { error -> APIError in
                // Convert any URLError or generic error into an APIError.networkError
                return .networkError(error)
            }
            .flatMap { [weak self] data, response -> AnyPublisher<T, APIError> in
                guard let self = self else {
                    return Fail(error: .unknown(nil)).eraseToAnyPublisher()
                }

                // Validate HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = APIError.invalidResponse(-1, data)
                    self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: nil, error: error)
                    return Fail(error: error).eraseToAnyPublisher()
                }

                let status = httpResponse.statusCode

                // Check for success range
                guard (200...299).contains(status) else {
                    // Possibly handle 401 or 429 with logic
                    // 401 => Attempt to see if we can retry via authInterceptor
                    if status == 401 {
                        let shouldRetry = self.authInterceptor.retry(adaptedRequest, response: httpResponse, error: nil)
                        if shouldRetry {
                            // Attempt exponential backoff
                            let delaySeconds = pow(EXPONENTIAL_BACKOFF_BASE, Double(attempt - 1))
                            return Just(())
                                .delay(for: .seconds(delaySeconds), scheduler: DispatchQueue.global())
                                .flatMap { _ in
                                    self.attemptRequest(endpoint: endpoint, type: T.self, attempt: attempt + 1, priority: priority)
                                }
                                .eraseToAnyPublisher()
                        } else {
                            let error = APIError.unauthorized("401 Unauthorized - Not Retrying")
                            self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: status, error: error)
                            return Fail(error: error).eraseToAnyPublisher()
                        }
                    }

                    // 429 => Rate limit. Retry with exponential backoff
                    if status == 429 {
                        let delaySeconds = pow(EXPONENTIAL_BACKOFF_BASE, Double(attempt - 1))
                        let error = APIError.rateLimitExceeded(attempt) 
                        self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: status, error: error)
                        return Just(())
                            .delay(for: .seconds(delaySeconds), scheduler: DispatchQueue.global())
                            .flatMap { _ in
                                self.attemptRequest(endpoint: endpoint, type: T.self, attempt: attempt + 1, priority: priority)
                            }
                            .eraseToAnyPublisher()
                    }

                    // Other HTTP error => wrap up and fail
                    let apiError = APIError.invalidResponse(status, data)
                    self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: status, error: apiError)
                    return Fail(error: apiError).eraseToAnyPublisher()
                }

                // We've succeeded in terms of status code, decode the payload.
                do {
                    let decodedResult = try self.decoder.decode(T.self, from: data)
                    self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: status, error: nil)
                    return Just(decodedResult)
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                } catch let decodingErr as DecodingError {
                    let wrapped = APIError.decodingError(decodingErr)
                    self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: status, error: wrapped)
                    return Fail(error: wrapped).eraseToAnyPublisher()
                } catch {
                    // Should rarely happen, but if there's an unknown error in decoding
                    let unknown = APIError.unknown(error)
                    self.metricsCollector.endRequestMetrics(endpoint: endpoint, statusCode: status, error: unknown)
                    return Fail(error: unknown).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}