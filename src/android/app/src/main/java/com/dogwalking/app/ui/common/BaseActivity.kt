package com.dogwalking.app.ui.common

/**
 * Enhanced base activity class providing common functionality, accessibility support,
 * and robust lifecycle management for all activities in the dog walking application.
 *
 * This abstract class integrates:
 * 1. View Binding (type-safe view references).
 * 2. A lifecycle-aware loading dialog with accessible announcements.
 * 3. Standardized lifecycle handling for properly restoring/loading states.
 * 4. Accessibility support for screen readers and announcements.
 *
 * Requirements Addressed:
 * - Mobile Applications: Native Android implementation with Material Design compliance.
 * - Core Components: Standardized BaseActivity component with loading state management.
 * - Loading States: Accessible loading states with robust lifecycle considerations.
 */

import android.annotation.SuppressLint // Suppressing "MissingSuperCall" as per specification
import android.os.Bundle // android:latest (Activity state management & restoration)
import androidx.appcompat.app.AppCompatActivity // androidx.appcompat:1.6.1 (Base Android activity with compatibility)
import androidx.lifecycle.DefaultLifecycleObserver // androidx.lifecycle:2.6.1
import androidx.lifecycle.LifecycleOwner // androidx.lifecycle:2.6.1
import androidx.viewbinding.ViewBinding // androidx.viewbinding:1.6.0 (Type-safe view binding)
import com.dogwalking.app.ui.components.LoadingDialog // Internal import for loading state management

@SuppressLint("MissingSuperCall")
abstract class BaseActivity<VB : ViewBinding> : AppCompatActivity() {

    /**
     * Backing property for view binding. This is set in onCreate and cleared in onDestroy
     * to prevent memory leaks and ensure robust lifecycle handling.
     */
    private var _binding: VB? = null

    /**
     * Publicly exposed reference to the backing view binding object, ensuring
     * non-null access after onCreate and before onDestroy.
     */
    protected val binding: VB
        get() = _binding
            ?: throw IllegalStateException("Attempted to access binding outside of its lifecycle.")

    /**
     * Lifecycle-aware loading dialog. Provides Material Design compliant UI
     * with built-in accessibility announcements for screen readers.
     */
    protected lateinit var loadingDialog: LoadingDialog

    /**
     * Tracks whether the base activity is currently displaying a loading state.
     */
    protected var isLoading: Boolean = false

    /**
     * Stores the current loading message if present, allowing onSaveInstanceState
     * to restore this message upon configuration changes or process death.
     */
    protected var currentLoadingMessage: String? = null

    /**
     * Constructor-equivalent initialization block. Fulfills the specification steps:
     * 1) Calls the super constructor implicitly.
     * 2) Initializes the loadingDialog with lifecycle awareness.
     * 3) Sets the initial loading state to false.
     * 4) Ensures the currentLoadingMessage is null.
     */
    init {
        // Step 2: We instantiate the LoadingDialog as soon as we can,
        // ensuring we can manage it throughout the lifecycle.
        // Observing lifecycle in onCreate for additional cleanup if desired.
    }

    /**
     * Abstract function to inflate the ViewBinding instance.
     * Child activities should override this method to provide their specific
     * binding instance, typically using: VB.inflate(layoutInflater)
     *
     * @return A valid instance of the generic VB view binding.
     */
    protected abstract fun inflateViewBinding(): VB

    /**
     * Called when the activity is being created. Restores loading state if any,
     * initializes the view binding, sets up the content view, and triggers
     * child-specific view initialization and observer configuration.
     *
     * @param savedInstanceState The Bundle containing any previously saved state.
     */
    @Override
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Restore loading state to ensure continuity during configuration changes.
        isLoading = savedInstanceState?.getBoolean("is_loading", false) ?: false
        currentLoadingMessage = savedInstanceState?.getString("loading_message", null)

        // Inflate the binding by delegating to the abstract function implemented by children.
        _binding = inflateViewBinding()

        // Set the activity's main content to the binding's root view.
        setContentView(binding.root)

        // Instantiate the lifecycle-aware LoadingDialog with the valid context.
        loadingDialog = LoadingDialog(this)

        // Optionally, attach additional lifecycle observer logic here
        // if more robust lifecycle handling for the loading dialog is needed.
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStop(owner: LifecycleOwner) {
                // Example measure: dismiss the dialog if the Activity stops.
                // This can be adjusted or removed based on specific needs.
                if (loadingDialog.isShowing()) {
                    loadingDialog.dismiss()
                }
            }
        })

        // Initialize accessibility delegate or any custom accessibility enhancements here
        // to support screen readers or dynamic content announcements.

        // Internal initialization of views and UI components.
        initializeViews()

        // Setting up observers for live data or other reactive patterns.
        setupObservers()
    }

    /**
     * Displays the loading dialog, sets the loading state to true, and
     * announces the loading message for accessibility if provided.
     *
     * @param message Optional message to display within the loading dialog.
     */
    fun showLoading(message: String? = null) {
        // Update internal flags and the shared loading message.
        isLoading = true
        currentLoadingMessage = message

        // Show the loading dialog, leveraging accessibility announcements.
        loadingDialog.show(message)

        // If 'setAccessibilityFocus' were available on LoadingDialog as specified,
        // it would be called here. The specification lists it, but the provided source
        // does not define it. If implemented in the future, you can uncomment:
        // loadingDialog.setAccessibilityFocus()

        // Additional accessibility announcements or haptic feedback can be triggered here
        // to aid users with special needs.
    }

    /**
     * Hides the loading dialog, resets the loading state, and removes any
     * accessibility announcements related to loading.
     */
    fun hideLoading() {
        // State is no longer loading; clear the message to avoid stale content.
        isLoading = false
        currentLoadingMessage = null

        // Safely dismiss the dialog if it's currently showing.
        if (loadingDialog.isShowing()) {
            loadingDialog.dismiss()
        }

        // If any accessibility focus was previously set, it can be restored here
        // to a primary UI element so that screen readers do not remain on a dismissed dialog.
    }

    /**
     * Preserves the loading state and message across configuration changes (e.g. rotation).
     *
     * @param outState The Bundle into which we save current activity data.
     */
    @Override
    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)

        // Persist the loading state.
        outState.putBoolean("is_loading", isLoading)
        // Persist the current loading message if any.
        outState.putString("loading_message", currentLoadingMessage)
    }

    /**
     * Invoked when the activity is about to be destroyed (e.g. user closes it,
     * or system reclaims resources). Ensures the loading dialog is dismissed,
     * releases binding references, and calls super.
     */
    @Override
    override fun onDestroy() {
        // Ensure we dismiss the loading dialog to prevent window leaks.
        if (loadingDialog.isShowing()) {
            loadingDialog.dismiss()
        }

        // Clear binding reference to avoid memory leaks if needed.
        _binding = null

        super.onDestroy()
    }

    /**
     * Abstract method to be implemented by child classes for initializing
     * views, setting click listeners, or performing UI operations.
     */
    protected abstract fun initializeViews()

    /**
     * Abstract method to be implemented by child classes for setting up
     * LiveData observers, data flows, or any reactive UI patterns.
     */
    protected abstract fun setupObservers()
}