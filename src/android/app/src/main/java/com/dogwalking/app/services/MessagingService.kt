package com.dogwalking.app.services

// -------------------------------------------------------------------------------------------------
// External Imports with Version Comments
// -------------------------------------------------------------------------------------------------
// Firebase Messaging (com.google.firebase.messaging:23.2.1)
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

// AndroidX Core (androidx.core.app:1.7.0)
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationChannelCompat.DEFAULT_LIGHTS
import androidx.core.app.NotificationChannelCompat.DEFAULT_SOUND
import androidx.core.app.NotificationChannelCompat.IncomingCallStyle
import androidx.core.app.NotificationManagerCompat.IMPORTANCE_HIGH
import androidx.core.app.NotificationManagerCompat.IMPORTANCE_LOW
import androidx.core.app.NotificationManagerCompat.IMPORTANCE_DEFAULT

// Kotlin Coroutines (org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3) - For retry logic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

// Android Platform Imports
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.util.Log

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import com.dogwalking.app.utils.Constants.WEBSOCKET_RECONNECT_ATTEMPTS
import com.dogwalking.app.utils.Constants.WEBSOCKET_RECONNECT_INTERVAL
import com.dogwalking.app.utils.Constants.NOTIFICATION_CHANNEL_EMERGENCY
import com.dogwalking.app.utils.Constants.NOTIFICATION_CHANNEL_WALK_UPDATES
import com.dogwalking.app.utils.Constants.NOTIFICATION_CHANNEL_GENERAL

// Dagger/Hilt Annotation (if used for service injection)
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * Interface reference for storing and synchronizing FCM tokens. Assumes operations
 * for saving, retrieving, and updating tokens within a repository.
 */
interface TokenRepository {
    fun saveToken(token: String)
    suspend fun syncTokenWithServer(token: String): Boolean
}

/**
 * Interface reference for querying user notification preferences (like enabling or
 * disabling certain notification types, controlling sound/vibration, etc.).
 */
interface NotificationPreferences {
    fun isEmergencyEnabled(): Boolean
    fun isWalkUpdateEnabled(): Boolean
    fun isGeneralEnabled(): Boolean
    // Other preference-based methods as needed
}

/**
 * Data class modeling the structure of notification data transmitted via FCM.
 */
data class NotificationData(
    val title: String,
    val message: String,
    val type: String,
    val priority: Int = 3, // Lower number means higher urgency: 0 => P0, 3 => P3
    val additionalInfo: Map<String, String> = emptyMap()
)

/**
 * MessagingService extends FirebaseMessagingService to handle push notifications
 * with full compliance to the dog walking application's design specifications.
 * Priority-based message handling is implemented for emergency, walk updates,
 * and general notifications. The service also updates the FCM token on the server.
 */
@AndroidEntryPoint
class MessagingService @Inject constructor() : FirebaseMessagingService() {

    /**
     * Android-specific notification manager used to display notification content
     * to the user in real time.
     */
    private lateinit var notificationManager: NotificationManagerCompat

    /**
     * Stores the most recently generated FCM token for this device instance.
     */
    private var currentToken: String = ""

    /**
     * Repository for persisting and synchronizing the FCM token and related data.
     */
    @Inject
    lateinit var tokenRepository: TokenRepository

    /**
     * Handles user preferences regarding notifications, including toggling
     * emergency alerts, walk updates, and general notifications.
     */
    @Inject
    lateinit var notificationPreferences: NotificationPreferences

    /**
     * Called when the service is first created. Handles initialization of
     * the NotificationManager, sets up required notification channels with
     * distinct priority levels, and loads any necessary dependencies.
     */
    override fun onCreate() {
        super.onCreate()
        notificationManager = NotificationManagerCompat.from(this)
        setupNotificationChannels()
    }

    /**
     * Sets up the various notification channels used by the application:
     * 1. Emergency Notifications
     * 2. Walk Update Notifications
     * 3. General Notifications
     *
     * Each channel is assigned a unique importance level and optional features
     * like lights and sounds.
     */
    private fun setupNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Emergency channel with highest priority
            val emergencyChannel = NotificationChannelCompat
                .Builder(NOTIFICATION_CHANNEL_EMERGENCY, IMPORTANCE_HIGH)
                .setName("Emergency Alerts")
                .setDescription("High-priority notifications for emergencies")
                .setLightsEnabled(true)
                .setVibrationEnabled(true)
                .setImportance(IMPORTANCE_HIGH)
                .build()

            // Walk updates channel with default priority
            val walkUpdatesChannel = NotificationChannelCompat
                .Builder(NOTIFICATION_CHANNEL_WALK_UPDATES, IMPORTANCE_DEFAULT)
                .setName("Walk Updates")
                .setDescription("Notifications for ongoing or upcoming dog walks")
                .setLightsEnabled(true)
                .setVibrationEnabled(true)
                .setImportance(IMPORTANCE_DEFAULT)
                .build()

            // General channel for normal updates
            val generalChannel = NotificationChannelCompat
                .Builder(NOTIFICATION_CHANNEL_GENERAL, IMPORTANCE_LOW)
                .setName("General Notifications")
                .setDescription("Non-critical informational updates")
                .setLightsEnabled(false)
                .setVibrationEnabled(false)
                .build()

            // Register channels with the system
            notificationManager.createNotificationChannel(emergencyChannel)
            notificationManager.createNotificationChannel(walkUpdatesChannel)
            notificationManager.createNotificationChannel(generalChannel)
        }
    }

    /**
     * Called when a new FCM token is generated for this device. This method
     * stores the new token locally and attempts to synchronize it with the
     * server using retry logic limited by WEBSOCKET_RECONNECT_ATTEMPTS and
     * spaced by WEBSOCKET_RECONNECT_INTERVAL.
     *
     * @param token New FCM registration token.
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        currentToken = token
        tokenRepository.saveToken(token)

        // Attempt server synchronization with retry logic in a coroutine
        CoroutineScope(Dispatchers.IO).launch {
            var syncSuccess = false
            var attemptCount = 0
            while (attemptCount < WEBSOCKET_RECONNECT_ATTEMPTS && !syncSuccess) {
                attemptCount++
                try {
                    val result = tokenRepository.syncTokenWithServer(token)
                    if (result) {
                        syncSuccess = true
                    } else {
                        delay(WEBSOCKET_RECONNECT_INTERVAL)
                    }
                } catch (ex: Exception) {
                    // Synchronization failure: log and retry
                    Log.e("MessagingService", "Token sync attempt $attemptCount failed.", ex)
                    delay(WEBSOCKET_RECONNECT_INTERVAL)
                }
            }

            if (syncSuccess) {
                Log.d("MessagingService", "FCM token successfully synced with server.")
                // Optionally update notification subscriptions if needed
                updateNotificationSubscriptions()
            } else {
                Log.e("MessagingService", "FCM token synchronization failed after max attempts.")
            }
        }

        // Log token refresh event for debugging
        Log.d("MessagingService", "New FCM token received: $token")
    }

    /**
     * Stub method to demonstrate how the application might update notification
     * subscriptions or topics based on user roles or preferences after a new
     * token is successfully set.
     */
    private fun updateNotificationSubscriptions() {
        // Implementation for subscribing/unsubscribing from FCM topics or
        // adjusting current notification channels based on user role,
        // location, preferences, etc.
        Log.d("MessagingService", "Updating FCM subscriptions based on user preferences.")
    }

    /**
     * Called when an FCM message is received. This method parses the message payload,
     * determines the notification type (emergency, walk update, or general),
     * identifies priority level (P0-P3), and invokes the corresponding handler.
     *
     * @param message The incoming FCM RemoteMessage containing notification data.
     */
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Extract notification data from the message payload
        val dataMap = message.data
        if (dataMap.isNullOrEmpty()) {
            Log.w("MessagingService", "Received an FCM message with empty data payload.")
            return
        }

        val type = dataMap["type"] ?: "general"
        val title = dataMap["title"] ?: "Dog Walking Update"
        val msgBody = dataMap["message"] ?: "No message content"
        val priority = dataMap["priority"]?.toIntOrNull() ?: 3

        // Validate user preferences before proceeding
        val notificationData = NotificationData(
            title = title,
            message = msgBody,
            type = type,
            priority = priority,
            additionalInfo = dataMap
        )

        // Determine type and route to appropriate handler
        when (type.lowercase()) {
            "emergency" -> {
                if (notificationPreferences.isEmergencyEnabled()) {
                    handleEmergencyNotification(notificationData, priority)
                } else {
                    Log.d("MessagingService", "Emergency notifications are disabled by preference.")
                }
            }
            "walk_update" -> {
                if (notificationPreferences.isWalkUpdateEnabled()) {
                    handleWalkUpdate(notificationData, priority)
                } else {
                    Log.d("MessagingService", "Walk update notifications are disabled by preference.")
                }
            }
            else -> {
                if (notificationPreferences.isGeneralEnabled()) {
                    handleGeneralNotification(notificationData, priority)
                } else {
                    Log.d("MessagingService", "General notifications are disabled by preference.")
                }
            }
        }

        // Example of tracking notification delivery metrics or background logic
        Log.d("MessagingService", "Notification processed for type: $type, priority: $priority")
    }

    /**
     * Handles high-priority emergency notifications (P0-P1). Emergency alerts may involve
     * a full-screen notification, a wake lock to ensure the device is alerted, and
     * specialized styling for immediate user attention.
     *
     * @param data The parsed notification data relevant to the emergency.
     * @param priority The urgency level from 0 to 3; 0 indicates the highest urgency (P0).
     */
    private fun handleEmergencyNotification(data: NotificationData, priority: Int) {
        // Basic validation
        if (data.title.isBlank() || data.message.isBlank()) {
            Log.e("MessagingService", "Invalid emergency notification data. Missing title/message.")
            return
        }

        // Create an intent that opens an emergency activity or alerts the user in full screen
        val intent = Intent(this, EmergencyAlertActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Construct the notification
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_EMERGENCY)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(data.title)
            .setContentText(data.message)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setFullScreenIntent(pendingIntent, true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        // Optionally apply a call style for incoming call look & feel on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setStyle(IncomingCallStyle(pendingIntent, data.title))
        }

        // Display the emergency notification
        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, builder.build())

        // Log the emergency event
        Log.w("MessagingService", "Emergency notification displayed with priority $priority.")
    }

    /**
     * Handles notifications related to dog walks (schedule updates, started or ended status,
     * etc.). May add relevant actions (like viewing walk details or contacting the walker).
     *
     * @param data The parsed notification data for a walk update.
     * @param priority The urgency level from 0 to 3; 0 indicates the highest urgency (P0).
     */
    private fun handleWalkUpdate(data: NotificationData, priority: Int) {
        // Basic check for walk update
        if (data.title.isBlank() || data.message.isBlank()) {
            Log.e("MessagingService", "Invalid walk update notification. Missing title/message.")
            return
        }

        // Example deep link or explicit activity that shows walk details
        val intent = Intent(this, WalkDetailsActivity::class.java).apply {
            // Additional info for showing correct walk session
            putExtra("walkId", data.additionalInfo["walkId"] ?: "")
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 1, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Build the notification
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_WALK_UPDATES)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentTitle(data.title)
            .setContentText(data.message)
            .setPriority(
                if (priority <= 1) NotificationCompat.PRIORITY_HIGH
                else NotificationCompat.PRIORITY_DEFAULT
            )
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        // Add custom actions if relevant for the walk scenario
        builder.addAction(
            android.R.drawable.ic_dialog_info,
            "View Details",
            pendingIntent
        )

        // Display the walk update notification
        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, builder.build())

        // Log the walk update event
        Log.d("MessagingService", "Walk update notification displayed, priority $priority.")
    }

    /**
     * Handles general notifications that are neither emergency nor walk-related.
     * These might include promotional messages, announcements, or other low-urgency
     * system updates.
     *
     * @param data The parsed notification data for a general message.
     * @param priority The urgency level from 0 to 3; 0 indicates the highest urgency (P0).
     */
    private fun handleGeneralNotification(data: NotificationData, priority: Int) {
        if (data.title.isBlank() || data.message.isBlank()) {
            Log.e("MessagingService", "Invalid general notification. Missing title/message.")
            return
        }

        // Simple approach for general notifications
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_GENERAL)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle(data.title)
            .setContentText(data.message)
            .setPriority(
                if (priority == 0) NotificationCompat.PRIORITY_MAX
                else NotificationCompat.PRIORITY_LOW
            )
            .setAutoCancel(true)

        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, builder.build())

        Log.d("MessagingService", "General notification displayed with priority $priority.")
    }
}

/**
 * EmergencyAlertActivity is the placeholder activity used to display a full-screen
 * emergency alert. This class can be replaced or customized to show user instructions
 * or additional critical information.
 */
class EmergencyAlertActivity : BaseActivity() {
    // Implementation details for user interaction when an emergency notification arrives
}

/**
 * WalkDetailsActivity is a placeholder activity demonstrating how to display and
 * manage walk-specific details. This class can be replaced or customized with
 * your own walk detail screen logic.
 */
class WalkDetailsActivity : BaseActivity() {
    // Implementation details for presenting detailed walk info to the user
}

/**
 * BaseActivity is a placeholder for your app's activity base class that might handle
 * theming, analytics, or shared logic. Replace with your actual base if applicable.
 */
open class BaseActivity : android.app.Activity()
```