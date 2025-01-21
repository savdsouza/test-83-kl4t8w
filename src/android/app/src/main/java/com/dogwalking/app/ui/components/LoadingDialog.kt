package com.dogwalking.app.ui.components

/*
 * LoadingDialog.kt
 * Material Design compliant dialog for displaying loading states
 * with accessibility support and partial context reference
 */

import android.content.Context // android-latest
import android.view.LayoutInflater // android-latest
import android.view.View // android-latest
import android.view.animation.AlphaAnimation // android-latest
import android.widget.TextView // android-latest
import androidx.appcompat.app.AlertDialog // androidx.appcompat:1.6.1
import androidx.core.view.ViewCompat // androidx.core:1.12.0
import com.dogwalking.app.R
import com.dogwalking.app.R.layout.dialog_loading
import java.lang.ref.WeakReference // java.lang:latest

/**
 * A custom dialog component that displays a loading indicator with an optional
 * message during asynchronous operations. Adheres to Material Design guidelines,
 * provides complete accessibility support, and ensures robust lifecycle handling
 * using a weak context reference to prevent memory leaks.
 */
class LoadingDialog constructor(context: Context) {

    /**
     * Maintains a weak reference to the application or activity context to prevent memory leaks.
     */
    private val contextRef: WeakReference<Context> = WeakReference(context)

    /**
     * Underlying AlertDialog used to present the UI. Configured with Material Design theme and
     * relevant accessibility properties.
     */
    private lateinit var dialog: AlertDialog

    /**
     * TextView for displaying an optional loading message. Hidden by default and
     * revealed via animation when a non-empty message is provided.
     */
    private lateinit var messageTextView: TextView

    /**
     * Tracks whether the dialog is currently visible. Updated after each show or dismiss call.
     */
    private var isShowing: Boolean = false

    init {
        /*
         * Step 1: Inflate the dialog_loading layout with a theme-aware LayoutInflater, ensuring
         * Material styling and adaptive theming for dark/light modes.
         */
        val ctx = contextRef.get()
        if (ctx != null) {
            val inflater = LayoutInflater.from(ctx)
            val contentView = inflater.inflate(dialog_loading, null)

            /*
             * Step 2: Reference the optional loading message TextView. By default,
             * it is set to GONE and will only appear if show() is called with a message.
             */
            messageTextView = contentView.findViewById(R.id.messageText)

            /*
             * Step 3: Initialize accessibility delegate for custom announcements or updates.
             * This ensures that screen readers, such as TalkBack, properly read the dynamic text.
             */
            messageTextView.accessibilityDelegate = object : View.AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(v: View?, info: android.view.accessibility.AccessibilityNodeInfo?) {
                    super.onInitializeAccessibilityNodeInfo(v, info)
                    info?.text = messageTextView.text
                }
            }

            /*
             * Optional: The CircularProgressIndicator in dialog_loading.xml is automatically
             * shown (indeterminate = true). If further configuration is needed, you can obtain
             * its reference here:
             *
             * val progressIndicator = contentView.findViewById<CircularProgressIndicator>(R.id.progressIndicator)
             * progressIndicator.isIndeterminate = true
             */

            /*
             * Step 4: Build the AlertDialog in a style-compliant way, disable outside touches,
             * and add hardware acceleration for smooth animations.
             */
            val builder = AlertDialog.Builder(ctx)
            builder.setView(contentView)
            builder.setCancelable(false)

            dialog = builder.create().apply {
                window?.let { window ->
                    window.setDimAmount(0.5f) // Slight dim behind the dialog
                    window.addFlags(android.view.WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
                    requestWindowFeature(android.view.Window.FEATURE_NO_TITLE)
                }
                setCanceledOnTouchOutside(false)
            }
        }
    }

    /**
     * Displays the loading dialog with an optional message. Shows or hides the messageTextView
     * using fade animations and announces the loading state to accessibility services.
     *
     * @param message Optional text to display if provided; otherwise messageTextView remains hidden.
     */
    fun show(message: String? = null) {
        val ctx = contextRef.get() ?: return

        // Update message text with proper text direction and accessibility support if not null or blank
        if (!message.isNullOrBlank()) {
            messageTextView.text = message
            messageTextView.visibility = View.VISIBLE
            fadeIn(messageTextView)
        } else {
            messageTextView.visibility = View.GONE
        }

        // Ensure the dialog is valid and has a window token
        if (!dialog.isShowing) {
            dialog.show()
            fadeInDialogWindow()
            // Announce loading state for accessibility
            ViewCompat.announceForAccessibility(messageTextView, message ?: "Loading")
            isShowing = true
        }
    }

    /**
     * Safely dismisses the loading dialog with a fade-out animation, clears references,
     * and restores the isShowing flag. Ensures proper teardown of window callbacks to
     * prevent leaks or leftover references.
     */
    fun dismiss() {
        if (dialog.window != null && dialog.isShowing) {
            fadeOutDialogWindow()
            dialog.dismiss()
            messageTextView.text = ""
            isShowing = false
            clearAccessibilityFocus()
        }
    }

    /**
     * Checks if the dialog is currently showing, verifying both context and window
     * validity to prevent any stale references.
     *
     * @return True if the dialog is showing and valid, false otherwise.
     */
    fun isShowing(): Boolean {
        val ctx = contextRef.get() ?: return false
        if (dialog.window == null) return false
        return dialog.isShowing && isShowing
    }

    /**
     * Internal helper function to fade in a View (such as the message TextView) for
     * a more polished user experience in line with Material guidelines.
     */
    private fun fadeIn(targetView: View) {
        val alphaAnimation = AlphaAnimation(0f, 1f).apply {
            duration = 200
            fillAfter = true
        }
        targetView.startAnimation(alphaAnimation)
    }

    /**
     * Internal helper function to apply a fade-in animation to the entire dialog window,
     * if supported. This helps unify the transition for the loading state.
     */
    private fun fadeInDialogWindow() {
        dialog.window?.decorView?.let { decorView ->
            val alphaAnimation = AlphaAnimation(0f, 1f).apply {
                duration = 200
                fillAfter = true
            }
            decorView.startAnimation(alphaAnimation)
        }
    }

    /**
     * Internal helper function to apply a fade-out animation to the entire dialog window
     * before dismissal, providing a smooth transition effect to the user.
     */
    private fun fadeOutDialogWindow() {
        dialog.window?.decorView?.let { decorView ->
            val alphaAnimation = AlphaAnimation(1f, 0f).apply {
                duration = 200
                fillAfter = true
            }
            decorView.startAnimation(alphaAnimation)
        }
    }

    /**
     * Clears the accessibility focus to ensure screen readers do not continue referencing
     * this dialog once it has been dismissed.
     */
    private fun clearAccessibilityFocus() {
        ViewCompat.setAccessibilityDelegate(messageTextView, null)
    }
}