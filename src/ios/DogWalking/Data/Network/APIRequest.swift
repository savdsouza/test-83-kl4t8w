import Foundation // iOS 13.0+
import Combine    // iOS 13.0+

// Internal Imports (following IE1 guidelines)
import Data.Network.APIError
import Data.Network.APIResponse
import Data.Network.APIRouter

/// A generic, production-grade class for orchestrating API requests,
/// providing type-safe responses, comprehensive error handling, caching,
/// timeout and retry policies, and optional progress tracking for uploads.
/// This class leverages Combine to expose asynchronous publishers.
public final class APIRequest<ResponseType: Decodable> {
    
    // MARK: - Properties
    
    /// The URLSession instance used for network calls.
    /// Configured to enable certificate pinning and security policies.
    private let session: URLSession
    
    /// A JSONDecoder used to deserialize responses into strongly typed models.
    /// Configured with default or custom date decoding strategies as needed.
    private let decoder: JSONDecoder
    
    /// A timeout interval (in seconds) that governs how long requests should
    /// wait before failing with a timeout error.
    private let timeout: TimeInterval
    
    /// The maximum number of retry attempts permitted for recoverable network
    /// errors or specific HTTP response codes.
    private let maxRetries: Int
    
    /// A URLCache instance for storing and retrieving cached responses,
    /// facilitating offline support and performance optimizations.
    private let cache: URLCache
    
    // MARK: - Initialization
    
    /**
     Initializes the APIRequest with custom or default networking configurations.
     
     - Parameters:
       - session: A URLSession instance to manage the request lifecycle. If nil, a default pinned session is used.
       - decoder: A JSONDecoder for response decoding. If nil, a default decoder is initialized.
       - timeout: The time interval in seconds before the request is considered stale. Defaults to 30s.
       - maxRetries: The maximum number of retry attempts for intermittent failures. Defaults to 3.
     */
    public init(
        session: URLSession? = nil,
        decoder: JSONDecoder? = nil,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3
    ) {
        // Configure a pinned URLSession if none is provided,
        // ensuring certificate pinning and relevant security measures.
        if let customSession = session {
            self.session = customSession
        } else {
            // Use the APIRouter's example pinned session if desired,
            // or create a default ephemeral session for fallback.
            self.session = APIRouter.createPinnedURLSession()
        }
        
        // Configure the JSON decoder. If none is provided, set default date decoding strategies, etc.
        if let customDecoder = decoder {
            self.decoder = customDecoder
        } else {
            let defaultDecoder = JSONDecoder()
            defaultDecoder.dateDecodingStrategy = .iso8601
            self.decoder = defaultDecoder
        }
        
        // Assign the timeout and maxRetries based on provided configuration.
        self.timeout = timeout
        self.maxRetries = maxRetries
        
        // Initialize a custom URLCache for offline support and improved performance.
        // This configuration can be tuned for memory/disk capacity as needed.
        self.cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB
            diskCapacity:   100 * 1024 * 1024, // 100 MB
            diskPath:       "com.dogwalking.network.cache"
        )
        
        // Apply the cache to the session configuration if possible.
        self.session.configuration.urlCache = self.cache
    }
    
    // MARK: - Public Methods
    
    /**
     Executes an API request using the specified APIRouter configuration,
     then returns a publisher that emits a decoded ResponseType or an APIError.
     
     The workflow includes:
     1. Building a URLRequest from the router.
     2. Checking network reachability (placeholder example).
     3. Attempting to retrieve a cached response if offline.
     4. Executing the actual network request with Combine.
     5. Applying error handling, retry logic, and timeouts.
     6. Decoding the server response into an `APIResponse<ResponseType>` model
        and returning the internal `ResponseType` if successful.
     
     - Parameter router: The APIRouter enum case specifying endpoint, method, and body/query parameters.
     - Returns: A publisher emitting ResponseType on success, or APIError on failure.
     */
    public func execute(router: APIRouter) -> AnyPublisher<ResponseType, APIError> {
        
        // Step 1: Attempt to form the URL request from the router
        let request: URLRequest
        do {
            request = try router.asURLRequest()
        } catch APIError.invalidURL(let urlString) {
            return Fail(error: .invalidURL(urlString)).eraseToAnyPublisher()
        } catch APIError.invalidParameters {
            return Fail(error: .validationError(["parameters": ["Invalid parameters"]])).eraseToAnyPublisher()
        } catch {
            return Fail(error: .unknown(error)).eraseToAnyPublisher()
        }
        
        // Step 2: (Optional placeholder) Check or simulate network reachability
        // Replace this logic with a real reachability check or library if desired.
        let networkIsReachable = true // Placeholder
        if !networkIsReachable {
            // Attempt to fetch a cached response for offline support.
            if let cachedData = self.cachedResponseData(for: request) {
                // Attempt to decode the cached data
                return decodeResponseData(cachedData)
            } else {
                // Fallback: No cache available, return an offline error
                return Fail(error: .noInternet).eraseToAnyPublisher()
            }
        }
        
        // Step 3: Execute the data task publisher with built-in retry, mapping, and decoding.
        // We also wrap it with a Combine timeout operator if needed.
        return session.dataTaskPublisher(for: request)
            .timeout(self.timeout, scheduler: DispatchQueue.global(qos: .background), customError: { .timeout })
            .retry(self.maxRetries)
            .mapError { error -> APIError in
                // Try to map the underlying URLError to a specific APIError case.
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        return .timeout
                    case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                        return .networkError(urlError)
                    default:
                        return .networkError(urlError)
                    }
                }
                return .unknown(error)
            }
            .flatMap { [weak self] output -> AnyPublisher<ResponseType, APIError> in
                guard let self = self else {
                    return Fail(error: .unknown(nil)).eraseToAnyPublisher()
                }
                
                // Cache the response (if valid) for offline retrieval later.
                self.storeInCache(output.data, response: output.response, for: request)
                
                // Decode the data to a structured APIResponse<ResponseType>.
                return self.decodeResponseData(output.data)
            }
            .eraseToAnyPublisher()
    }
    
    /**
     Executes an API request while tracking upload progress, which is particularly
     useful for large payloads or background operations. Returns a publisher emitting
     the decoded ResponseType or an APIError. The provided progressHandler closure is
     invoked repeatedly with a progress fraction (0.0...1.0) throughout the upload.
     
     Additional tasks for memory optimization, background tasks, and request queueing
     can be placed here for robust enterprise-grade implementations.
     
     - Parameters:
       - router: The APIRouter enum specifying endpoint and HTTP parameters.
       - progressHandler: A closure receiving a progress value between 0 and 1.
     - Returns: A publisher emitting a decoded ResponseType or an APIError on failure.
     */
    public func executeWithProgress(
        router: APIRouter,
        progressHandler: @escaping (Double) -> Void
    ) -> AnyPublisher<ResponseType, APIError> {
        
        // Step 1: Build the request from the router with potential error handling.
        let request: URLRequest
        do {
            request = try router.asURLRequest()
        } catch APIError.invalidURL(let urlString) {
            return Fail(error: .invalidURL(urlString)).eraseToAnyPublisher()
        } catch APIError.invalidParameters {
            return Fail(error: .validationError(["parameters": ["Invalid parameters"]])).eraseToAnyPublisher()
        } catch {
            return Fail(error: .unknown(error)).eraseToAnyPublisher()
        }
        
        // Step 2: Create a dedicated subject to bridge URLSession delegate callbacks to Combine.
        let progressSubject = PassthroughSubject<Double, Never>()
        
        // Step 3: Wrap the upload task in a custom publisher to emit both progress updates and final data.
        // For demonstration, we are using a single call to 'uploadTask' with a random Data payload.
        // In a real scenario, you would build a multipart body or retrieve upload data from request.httpBody.
        
        let uploadData = request.httpBody ?? Data()
        
        // This custom publisher is responsible for bridging progress events via URLSessionTaskDelegate.
        // A robust enterprise solution would incorporate a custom session/delegate to handle progress fully.
        let uploadPublisher = Future<(data: Data, response: URLResponse), APIError> { [weak self] promise in
            
            guard let strongSelf = self else {
                promise(.failure(.unknown(nil)))
                return
            }
            
            // Build a custom URLSession with a delegate that reports progress.
            // A production scenario would set up certificate pinning as well.
            let config = strongSelf.session.configuration
            let progressDelegate = ProgressDelegate(progressSubject: progressSubject, progressHandler: progressHandler)
            
            let progressSession = URLSession(configuration: config, delegate: progressDelegate, delegateQueue: nil)
            
            let task = progressSession.uploadTask(with: request, from: uploadData) { data, response, error in
                guard let data = data, let response = response else {
                    if let err = error as? URLError {
                        switch err.code {
                        case .timedOut:
                            promise(.failure(.timeout))
                        case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                            promise(.failure(.networkError(err)))
                        default:
                            promise(.failure(.networkError(err)))
                        }
                    } else if let genericError = error {
                        promise(.failure(.unknown(genericError)))
                    } else {
                        promise(.failure(.unknown(nil)))
                    }
                    return
                }
                promise(.success((data, response)))
            }
            
            // Respect the request-level timeout manually, if desired:
            task.taskDescription = "ProgressUploadTask"
            task.resume()
        }
        
        return uploadPublisher
            .timeout(self.timeout, scheduler: DispatchQueue.global(qos: .background), customError: { .timeout })
            .retry(self.maxRetries)
            .flatMap { [weak self] output -> AnyPublisher<ResponseType, APIError> in
                guard let self = self else {
                    return Fail(error: .unknown(nil)).eraseToAnyPublisher()
                }
                
                // Store in cache if appropriate (mimicking offline support).
                self.storeInCache(output.data, response: output.response, for: request)
                
                // Decode the response data to the expected generic type.
                return self.decodeResponseData(output.data)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helpers
    
    /**
     Attempts to decode raw data into an `APIResponse<ResponseType>` and then
     extracts the typed `ResponseType`. If the API indicates success, the
     extracted type is published. Otherwise, an APIError is thrown.
     
     - Parameter data: The raw response data from the server or cache.
     - Returns: A publisher emitting the decoded `ResponseType` or an `APIError`.
     */
    private func decodeResponseData(_ data: Data) -> AnyPublisher<ResponseType, APIError> {
        return Just(data)
            .decode(type: APIResponse<ResponseType>.self, decoder: decoder)
            .mapError { decodingError -> APIError in
                // Convert any DecodingError to a standard APIError.decodingError
                if let decErr = decodingError as? DecodingError {
                    return .decodingError(decErr)
                }
                return .unknown(decodingError)
            }
            .tryMap { apiResponse in
                // If the response is not successful, throw an appropriate error.
                guard apiResponse.isSuccessful() else {
                    // Attempt to interpret based on statusCode or error fields.
                    let code = apiResponse.statusCode
                    if code == 401 {
                        throw APIError.unauthorized(apiResponse.error)
                    } else if code == 403 {
                        throw APIError.forbidden(apiResponse.error)
                    } else if code == 404 {
                        throw APIError.notFound(apiResponse.error)
                    } else if (500...599).contains(code) {
                        throw APIError.serverError(code, apiResponse.error)
                    } else if !apiResponse.success {
                        // If the server sets success=false but code is 2xx, treat as invalidResponse.
                        throw APIError.invalidResponse(code, data)
                    }
                }
                
                // On success, ensure the `data` field is non-nil. If nil, interpret as a decoding failure.
                guard let finalData = apiResponse.data else {
                    // We could treat a nil payload as a special error or fallback.
                    throw APIError.invalidResponse(apiResponse.statusCode, data)
                }
                
                return finalData
            }
            .mapError { error -> APIError in
                // Convert any thrown error into an APIError, preserving meaning where possible.
                if let apiError = error as? APIError {
                    return apiError
                }
                return .unknown(error)
            }
            .eraseToAnyPublisher()
    }
    
    /**
     Retrieves cached response data from the stored URLCache if available.
     This can facilitate offline support by returning previously fetched content
     when the network is not reachable.
     
     - Parameter request: The original URLRequest identifying the cached resource.
     - Returns: The raw Data object if a cached response entry is found, otherwise nil.
     */
    private func cachedResponseData(for request: URLRequest) -> Data? {
        guard let cachedResponse = self.cache.cachedResponse(for: request) else {
            return nil
        }
        return cachedResponse.data
    }
    
    /**
     Stores the provided response data in the local URLCache for offline access
     and performance benefits.
     
     - Parameters:
       - data: The raw response data to cache.
       - response: The URLResponse associated with the request.
       - request: The original URLRequest that this data corresponds to.
     */
    private func storeInCache(_ data: Data, response: URLResponse, for request: URLRequest) {
        let cached = CachedURLResponse(response: response, data: data)
        self.cache.storeCachedResponse(cached, for: request)
    }
}

/// A specialized URLSessionDelegate or Task Delegate to relay progress updates.
/// It reports upload progress via a Publisher and an external handler for real-time UI updates.
private class ProgressDelegate: NSObject, URLSessionTaskDelegate {
    
    /// A subject that receives progress updates, for any pieces of Combine-based processing.
    private let progressSubject: PassthroughSubject<Double, Never>
    
    /// A closure that the APIRequest user supplied to handle progress (0.0...1.0).
    private let progressHandler: (Double) -> Void
    
    /**
     Initializes the delegate with a passthrough subject for deeper Combine usage
     and a direct closure for simpler real-time progress handling.
     
     - Parameters:
       - progressSubject: A Combine subject feeding progress values to downstream publishers.
       - progressHandler: A closure invoked whenever there's a progress update.
     */
    init(progressSubject: PassthroughSubject<Double, Never>,
         progressHandler: @escaping (Double) -> Void) {
        self.progressSubject = progressSubject
        self.progressHandler = progressHandler
    }
    
    /**
     URLSessionTaskDelegate callback that provides periodic updates on the
     number of bytes written and total bytes expected for an upload task.
     
     - Parameters:
       - session: The URLSession handling the task.
       - task: The URLSessionTask whose progress is being reported.
       - bytesSent: The number of bytes sent in the latest update.
       - totalBytesSent: The total number of bytes sent so far.
       - totalBytesExpectedToSend: The total upload size, or -1 if unknown.
     */
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        
        guard totalBytesExpectedToSend > 0 else {
            // If total upload size is unknown (-1), we cannot calculate a progress fraction.
            return
        }
        
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        // Send the progress value to both the subject and the direct closure.
        progressSubject.send(progress)
        progressHandler(progress)
    }
}