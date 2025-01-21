import Foundation // Foundation iOS 13.0+ (Core iOS framework functionality for network operations)
import Network   // Network iOS 13.0+ (Native iOS network monitoring with NWPathMonitor integration)
import Combine   // Combine iOS 13.0+ (Reactive programming support for network status updates and subscription management)

// MARK: - Internal Import
// Enhanced logging with security context and detailed network status tracking
import Logger

/// A global CurrentValueSubject that holds and broadcasts any changes
/// in the overall network status for the iOS dog walking application.
/// It initializes with an `.unknown` status and updates as reachability changes occur.
public let networkStatusSubject = CurrentValueSubject<NetworkStatus, Never>(.unknown)

/// An enumeration representing a comprehensive set of network connectivity states.
/// Each case describes a distinct status that the application may encounter
/// during reachability monitoring.
public enum NetworkStatus {
    /// Indicates that the network status could not be determined or has not been initialized.
    case unknown
    
    /// Indicates that the device currently has a fully operational data connection.
    case connected
    
    /// Indicates that the device is offline or the network cannot be reached.
    case disconnected
    
    /// Indicates that the device is in the process of establishing a connection.
    case connecting
    
    /// Indicates that the device is connected with limited or constrained capabilities,
    /// such as low data mode or restricted bandwidth.
    case limited
}

/// An enumeration representing a detailed set of network connection types,
/// including various interface modes like Wi-Fi, cellular data, or Ethernet.
public enum NetworkType {
    /// Connection is established via a Wi-Fi network interface.
    case wifi
    
    /// Connection is established via a cellular data interface.
    case cellular
    
    /// Connection is established via a wired Ethernet interface.
    case ethernet
    
    /// Connection is established via a loopback interface, typically used for local testing.
    case loopback
    
    /// Connection is of an unknown or unspecified interface type.
    case other
}

/// A thread-safe singleton class that provides reactive network connectivity monitoring
/// with comprehensive status tracking and connection type detection.
/// It utilizes `NWPathMonitor` to observe real-time network conditions and publishes
/// updates through Combine whenever changes are detected.
public final class NetworkReachability {
    
    // MARK: - Singleton Instance
    
    /// Provides a globally accessible shared instance for the `NetworkReachability` singleton.
    /// This ensures a single point of network monitoring throughout the application lifecycle.
    public static let shared = NetworkReachability()
    
    // MARK: - Properties
    
    /// An `NWPathMonitor` instance responsible for monitoring the current network path state.
    private let monitor: NWPathMonitor
    
    /// A dedicated serial `DispatchQueue` on which the network monitor will run its callbacks,
    /// ensuring minimal disruption to the main thread.
    private let monitorQueue: DispatchQueue
    
    /// A thread-safe indicator that tracks whether monitoring is currently active.
    private var isMonitoring: Bool
    
    /// Provides external access to reactive network status updates via a `CurrentValueSubject`.
    /// Internally references the global `networkStatusSubject` to unify all connectivity streams.
    public var networkStatusPublisher: CurrentValueSubject<NetworkStatus, Never> {
        return networkStatusSubject
    }
    
    /// A logger instance configured with relevant subsystem and category information
    /// for structured, secure, and efficient logging of network reachability events.
    private let logger = Logger(subsystem: "com.dogwalking.ios", category: "NetworkReachability")
    
    // MARK: - Initializer
    
    /// A thread-safe private initializer to enforce the singleton pattern.
    /// Configures a default `NWPathMonitor`, a background dispatch queue, and
    /// initializes the monitoring state to false. Also sets the network status
    /// to `.unknown` as a starting point.
    private init() {
        // Step 1: Initialize NWPathMonitor with the default interface
        self.monitor = NWPathMonitor()
        
        // Step 2: Create dedicated serial dispatch queue for monitoring,
        // configured for background operations to minimize impact on the main thread.
        self.monitorQueue = DispatchQueue(label: "com.dogwalking.networkreachability", qos: .background)
        
        // Step 3: Network status is initially `.unknown` as published globally.
        //         CurrentValueSubject default value is set outside in the global definition.
        
        // Step 4: Set initial monitoring state to false.
        self.isMonitoring = false
        
        // Step 5: The monitor queue is already configured for background operation.
    }
    
    // MARK: - Start Monitoring
    
    /// Begins network reachability monitoring if it is not already active.
    /// Configures the `NWPathMonitor` to publish status updates whenever network conditions change.
    /// Once started, relevant status transitions are logged, and any potential issues
    /// are captured via the internal logging mechanism.
    public func startMonitoring() {
        // 1. Check if monitoring is already active to prevent double starts.
        guard !isMonitoring else {
            logger.debug("startMonitoring called, but network monitoring is already active.")
            return
        }
        
        // 2. Configure the path update handler to process network changes.
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateNetworkStatus(path)
        }
        
        // 3. Start the NWPathMonitor on the dedicated queue.
        monitor.start(queue: monitorQueue)
        
        // 4. Update the internal state to reflect active monitoring.
        isMonitoring = true
        
        // 5. Log the initiation of the monitoring process for audit.
        logger.debug("Network monitoring has started successfully.")
        
        // 6. Handle potential monitoring failures.
        //    NWPathMonitor does not throw errors directly, but if the state is unsatisfied,
        //    it may indicate no connectivity has been established yet.
        let initialPath = monitor.currentPath
        if initialPath.status == .unsatisfied {
            logger.debug("Network is currently unsatisfied at the start of monitoring.")
        }
    }
    
    // MARK: - Stop Monitoring
    
    /// Safely stops network monitoring if it is currently active, cancelling the `NWPathMonitor`
    /// and resetting the network status to `.unknown`. Logs all relevant actions for audit.
    public func stopMonitoring() {
        // 1. Check if monitoring is active to avoid redundant stopping.
        guard isMonitoring else {
            logger.debug("stopMonitoring called, but network monitoring was not active.")
            return
        }
        
        // 2. Cancel the NWPathMonitor to cease receiving network updates.
        monitor.cancel()
        
        // 3. Reset the network status to `.unknown` to indicate no ongoing monitoring.
        networkStatusSubject.send(.unknown)
        
        // 4. Reset the monitoring state flag.
        isMonitoring = false
        
        // 5. Log the termination of the monitoring process for audit.
        logger.debug("Network monitoring has been stopped and network status set to unknown.")
        
        // 6. Perform additional cleanup operations if needed (e.g., pathUpdateHandler = nil).
        monitor.pathUpdateHandler = nil
    }
    
    // MARK: - Check Connectivity
    
    /// Returns a Boolean indicating whether the device is currently connected to a network
    /// with a status of `.satisfied`. This check is performed synchronously by reading
    /// the monitor’s current path status.
    ///
    /// - Returns: `true` if the device is connected with a `satisfied` network status; otherwise, `false`.
    public func isConnected() -> Bool {
        let path = monitor.currentPath
        return (path.status == .satisfied)
    }
    
    // MARK: - Get Connection Type
    
    /// Determines the primary network interface type (e.g., Wi-Fi, cellular, Ethernet)
    /// based on the current path. This method can be used to inform advanced behaviors
    /// such as limiting data usage on cellular networks or providing warnings when on
    /// expensive connections.
    ///
    /// - Returns: A `NetworkType` value indicating the identified interface type.
    public func getConnectionType() -> NetworkType {
        let path = monitor.currentPath
        
        // Check for specific interface types in order of recognized priority.
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else {
            return .other
        }
    }
    
    // MARK: - Private Update Logic
    
    /// A private helper method that evaluates the network path and updates
    /// `networkStatusSubject` to reflect the newly detected connectivity state.
    /// This method also logs changes, aiding in debugging and system monitoring.
    ///
    /// - Parameter path: The latest `NWPath` indicating the current state of network connectivity.
    private func updateNetworkStatus(_ path: NWPath) {
        var newStatus: NetworkStatus
        
        switch path.status {
        case .satisfied:
            // A satisfied path is connected, but we must check if it is constrained.
            if path.isConstrained {
                newStatus = .limited
            } else {
                newStatus = .connected
            }
        case .unsatisfied:
            newStatus = .disconnected
        case .requiresConnection:
            newStatus = .connecting
        @unknown default:
            newStatus = .unknown
        }
        
        // Publish the resulting status via the global subject.
        networkStatusSubject.send(newStatus)
        
        // Log the transition for transparency.
        logger.debug("Network status updated to \(newStatus).")
    }
}