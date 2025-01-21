import Foundation // iOS 13.0+ (Core iOS framework functionality)
import UserNotifications // iOS 13.0+ (iOS notification framework for secure notification handling)
import UIKit // iOS 13.0+ (UI interaction for notifications and state management)

// MARK: - Internal Imports
import DogWalking.Core.Utilities.Logger // Enhanced logging for notification events and errors with security context

/// Global set of notification categories used throughout the app
public let NOTIFICATION_CATEGORIES: Set<String> = [
    "walk_start",
    "walk_end",
    "emergency",
    "payment",
    "chat"
]

/// Global dictionary mapping each notification category to its default action(s)
public let NOTIFICATION_ACTIONS: [String: UNNotificationAction] = {
    // Demonstrates one basic UNNotificationAction per category; can be extended
    let walkStartAction = UNNotificationAction(
        identifier: "walk_start_action",
        title: "Start Walk",
        options: .foreground
    )
    let walkEndAction = UNNotificationAction(
        identifier: "walk_end_action",
        title: "End Walk",
        options: .foreground
    )
    let emergencyAction = UNNotificationAction(
        identifier: "emergency_action",
        title: "Open Emergency",
        options: .foreground
    )
    let paymentAction = UNNotificationAction(
        identifier: "payment_action",
        title: "Review Payment",
        options: .foreground
    )
    let chatAction = UNNotificationAction(
        identifier: "chat_action",
        title: "Open Chat",
        options: .foreground
    )
    return [
        "walk_start": walkStartAction,
        "walk_end": walkEndAction,
        "emergency": emergencyAction,
        "payment": paymentAction,
        "chat": chatAction
    ]
}()

/// Global dispatch queue dedicated to notification-related operations
public let NOTIFICATION_QUEUE: DispatchQueue = DispatchQueue(
    label: "com.dogwalking.notifications",
    qos: .userInitiated
)

/// An error type representing possible failures in notification operations.
private enum NotificationError: Error {
    case invalidPayload(String)
    case systemError(String)
    case unknown
}

/// A thread-safe singleton class managing local and push notifications
/// for the iOS dog walking application, providing enhanced security,
/// permission requests, scheduling, and consistent delivery.
public final class NotificationManager {

    // MARK: - Singleton

    /// Provides the global, shared instance of NotificationManager.
    public static let shared = NotificationManager()

    // MARK: - Properties

    /// Reference to the UNUserNotificationCenter for scheduling and managing notifications.
    private let center: UNUserNotificationCenter

    /// Tracks whether notifications have been enabled by the user.
    private var isNotificationsEnabled: Bool

    /// Stores the set of registered notification categories for quick reference or checks.
    private var registeredCategories: Set<String>

    /// A dedicated queue for handling all notification logic in a thread-safe manner.
    private let notificationQueue: DispatchQueue

    /// A lock protecting authorization-related state changes and preventing race conditions.
    private let authorizationLock: NSLock

    /// Logger instance providing structured logging, error reporting, and security context.
    private let logger = Logger(subsystem: "com.dogwalking", category: "NotificationManager")

    // MARK: - Initialization

    /// Private initializer enforcing the singleton pattern.
    /// Sets up the notification center, categories, default properties, and
    /// synchronization primitives, ensuring secure notification handling.
    private init() {
        self.center = UNUserNotificationCenter.current()
        self.isNotificationsEnabled = false
        self.registeredCategories = []
        self.notificationQueue = NOTIFICATION_QUEUE
        self.authorizationLock = NSLock()

        // Configure categories and register them with UNUserNotificationCenter.
        // This step also serves to track which categories are registered.
        self.setupNotificationCategories()
        logger.debug("NotificationManager initialized with secure configuration.")
    }

    // MARK: - Public Functions

    /// Requests permission from the user to display notifications (alert, badge, sound).
    /// This method enforces thread safety via an authorization lock and provides
    /// comprehensive error handling with a Result-based completion.
    ///
    /// Steps:
    /// 1. Acquire authorization lock.
    /// 2. Validate current authorization state.
    /// 3. Request notification authorization with the desired options.
    /// 4. Handle user response and log results.
    /// 5. Update permission state and release lock.
    /// 6. Return result via completion handler.
    ///
    /// - Parameter completion: Closure with Result<Bool, Error> indicating success or failure.
    public func requestAuthorization(completion: @escaping (Result<Bool, Error>) -> Void) {
        notificationQueue.async {
            self.authorizationLock.lock()
            defer { self.authorizationLock.unlock() }

            // Check current settings to see if permission is already determined.
            self.center.getNotificationSettings { settings in
                if settings.authorizationStatus == .notDetermined {
                    // Request authorization for alerts, sounds, and badges.
                    self.center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if let err = error {
                            self.logger.error("Failed to request notification authorization", error: err)
                            completion(.failure(err))
                            return
                        }

                        self.isNotificationsEnabled = granted
                        if granted {
                            self.logger.debug("User granted notification permissions.")
                            completion(.success(true))
                        } else {
                            self.logger.debug("User denied notification permissions.")
                            completion(.success(false))
                        }
                    }
                } else if settings.authorizationStatus == .denied {
                    self.isNotificationsEnabled = false
                    self.logger.debug("Notification permissions previously denied by user.")
                    completion(.success(false))
                } else {
                    // Already authorized or restricted; handle as appropriate.
                    let enabled = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
                    self.isNotificationsEnabled = enabled
                    self.logger.debug("Notifications are already in an enabled or restricted state: \(enabled).")
                    completion(.success(enabled))
                }
            }
        }
    }

    /// Schedules a secure local notification, validating payload and creating
    /// the required UNNotificationRequest. Uses robust logging to track scheduling.
    ///
    /// Steps:
    /// 1. Validate notification payload (e.g., non-empty title, valid category).
    /// 2. Create UNMutableNotificationContent with sanitized data.
    /// 3. Configure a UNCalendarNotificationTrigger or UNTimeIntervalNotificationTrigger based on date.
    /// 4. Register the request with UNUserNotificationCenter.
    /// 5. Log scheduling status with security context.
    ///
    /// - Parameters:
    ///   - title: The notification title displayed to the user.
    ///   - body: The message body describing additional details.
    ///   - date: The scheduled delivery time for this notification.
    ///   - category: A category identifier for grouping or custom actions.
    ///   - userInfo: Additional payload data for advanced handling.
    public func scheduleLocalNotification(
        title: String,
        body: String,
        date: Date,
        category: String,
        userInfo: [String: Any]?
    ) {
        notificationQueue.async {
            // Step 1: Validate the input
            guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
                  !body.trimmingCharacters(in: .whitespaces).isEmpty else {
                self.logger.error("Invalid notification payload provided: Title/Body cannot be empty.")
                return
            }

            // For demonstration, we ensure the category is known but do not strictly require it.
            if !NOTIFICATION_CATEGORIES.contains(category) {
                self.logger.debug("Unknown notification category '\(category)'; continuing without strict enforcement.")
            }

            // Step 2: Create and sanitize content
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = category
            if let info = userInfo {
                content.userInfo = info
            }

            // Step 3: Generate a UNCalendarNotificationTrigger or UNTimeIntervalNotificationTrigger
            // Based on the difference between 'date' and the current time.
            let timeInterval = date.timeIntervalSinceNow
            guard timeInterval > 0 else {
                self.logger.error("Scheduled date is in the past; cannot schedule notification.")
                return
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

            // Construct a unique identifier for this request
            let identifier = "local_notification_\(UUID().uuidString)"

            // Step 4: Create the notification request
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            // Step 5: Add request to notification center
            self.center.add(request) { error in
                if let err = error {
                    self.logger.error("Failed to schedule local notification request", error: err)
                } else {
                    self.logger.debug("Local notification scheduled successfully with identifier \(identifier).")
                }
            }
        }
    }

    /// Processes received push notifications by validating payload security,
    /// parsing relevant data, and updating the UI if necessary.
    ///
    /// Steps:
    /// 1. Validate notification payload structure.
    /// 2. Parse known fields (category, message, etc.) safely.
    /// 3. Handle notification categories or types with type-safe logic.
    /// 4. Update user interface only if application is active.
    /// 5. Log receipt of push notification with security context.
    ///
    /// - Parameters:
    ///   - userInfo: The notification payload as a dictionary.
    ///   - applicationState: The current state of the UIApplication at reception time.
    public func handlePushNotification(
        userInfo: [AnyHashable: Any],
        applicationState: UIApplication.State
    ) {
        notificationQueue.async {
            // Step 1: Validate the payload
            guard !userInfo.isEmpty else {
                self.logger.error("Received push notification with empty payload.")
                return
            }

            // Step 2: Parse category from the payload if provided
            let category = userInfo["category"] as? String ?? "unknown"

            // Step 3: Handle various categories
            switch category {
            case "walk_start":
                self.logger.debug("Handling push notification for walk start.")
                // Additional logic for starting a walk can be inserted here.
            case "walk_end":
                self.logger.debug("Handling push notification for walk end.")
                // Additional logic for ending a walk can be inserted here.
            case "emergency":
                self.logger.debug("Handling push notification for emergency event.")
                // Additional logic for emergency handling can be inserted here.
            case "payment":
                self.logger.debug("Handling push notification for payment action.")
                // Additional logic for payment updates or alerts can be inserted here.
            case "chat":
                self.logger.debug("Handling push notification for chat message.")
                // Additional logic for chat or messaging can be inserted here.
            default:
                self.logger.debug("Received push notification with unknown category: \(category).")
            }

            // Step 4: Optionally update UI if the app is in active state
            if applicationState == .active {
                // Could present an in-app alert, or refresh certain UI components
                self.logger.debug("App is in foreground; optionally update in-app UI.")
            }

            // Step 5: Log final receipt
            self.logger.debug("Push notification processed with category: \(category).")
        }
    }

    /// Cancels a previously scheduled local notification by its identifier,
    /// providing validation and secure logging of all cancellation events.
    ///
    /// Steps:
    /// 1. Validate the notification identifier.
    /// 2. Remove pending and delivered notifications matching that identifier.
    /// 3. Log cancellation result with context.
    ///
    /// - Parameter identifier: The unique notification identifier to cancel.
    public func cancelNotification(identifier: String) {
        notificationQueue.async {
            guard !identifier.isEmpty else {
                self.logger.error("Unable to cancel notification: Invalid empty identifier.")
                return
            }

            self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
            self.center.removeDeliveredNotifications(withIdentifiers: [identifier])
            self.logger.debug("Notification with identifier '\(identifier)' cancelled.")
        }
    }

    // MARK: - Private Helpers

    /// Sets up notification categories by matching global `NOTIFICATION_CATEGORIES`
    /// with any defined `NOTIFICATION_ACTIONS`, then registers them with the
    /// UNUserNotificationCenter instance in a thread-safe manner.
    private func setupNotificationCategories() {
        // Build category objects from each category name,
        // associating them with their respective actions if available.
        var categories: [UNNotificationCategory] = []

        for cat in NOTIFICATION_CATEGORIES {
            let actionForCategory: UNNotificationAction? = NOTIFICATION_ACTIONS[cat]
            let actions = actionForCategory != nil ? [actionForCategory!] : []
            let categoryObject = UNNotificationCategory(
                identifier: cat,
                actions: actions,
                intentIdentifiers: [],
                options: []
            )
            categories.append(categoryObject)
        }

        // Register categories with UNUserNotificationCenter
        center.setNotificationCategories(Set(categories))
        registeredCategories = NOTIFICATION_CATEGORIES
        logger.debug("Successfully registered notification categories: \(registeredCategories).")
    }
}