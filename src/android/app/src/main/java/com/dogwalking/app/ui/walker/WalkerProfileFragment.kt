package com.dogwalking.app.ui.walker

// ----------------------------------------------------------------------------------------------
// External Imports with Specified Versions
// ----------------------------------------------------------------------------------------------
import android.content.Context // android-latest
import android.net.ConnectivityManager // android-latest
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Bundle // android-latest
import android.view.LayoutInflater // android-latest
import android.view.View // android-latest
import android.view.ViewGroup // android-latest
import androidx.annotation.StringRes // android-latest
import androidx.fragment.app.viewModels // androidx.fragment.app:1.6.1
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout // androidx.swiperefreshlayout:1.2.0

// ----------------------------------------------------------------------------------------------
// Internal Imports
// ----------------------------------------------------------------------------------------------
import com.dogwalking.app.ui.common.BaseFragment
import com.dogwalking.app.ui.walker.viewmodel.WalkerViewModel

// ----------------------------------------------------------------------------------------------
// Additional Imports for View Binding (with specified version)
// ----------------------------------------------------------------------------------------------
import androidx.viewbinding.ViewBinding // androidx.viewbinding:1.6.0

// ----------------------------------------------------------------------------------------------
// Material Components (with specified version)
// ----------------------------------------------------------------------------------------------
// We assume Material components might be used for UI design consistency.
// com.google.android.material:1.9.0
import com.google.android.material.snackbar.Snackbar

// ----------------------------------------------------------------------------------------------
// Domain Model
// ----------------------------------------------------------------------------------------------
import com.dogwalking.app.domain.models.User
import com.dogwalking.app.core.network.NetworkResult

// ----------------------------------------------------------------------------------------------
// Generated ViewBinding Class (Placeholder Import for demonstration)
// Typically generated automatically from "fragment_walker_profile.xml"
// ----------------------------------------------------------------------------------------------
import com.dogwalking.app.databinding.FragmentWalkerProfileBinding

// ----------------------------------------------------------------------------------------------
// WalkerProfileFragment - A Fragment Displaying Detailed Profile Information for a Dog Walker
// with Enhanced Offline Support, Accessibility Features, and Real-Time Updates.
// Addresses the following requirements from the technical specification:
//  1) User Management: Walker profile display & verification system (1.3 Scope/Core Features/User Management)
//  2) Core Features: Display walker stats, rating, completed walks, real-time updates, offline support
//    (1.3 Scope/Core Features/Service Execution)
// ----------------------------------------------------------------------------------------------
@androidx.annotation.OptIn(androidx.annotation.ExperimentalStdlibApi::class)
@dagger.hilt.android.AndroidEntryPoint
class WalkerProfileFragment :
    BaseFragment<FragmentWalkerProfileBinding>() {

    // ------------------------------------------------------------------------------------------
    // Properties
    // ------------------------------------------------------------------------------------------

    /**
     * Reference to the [WalkerViewModel], responsible for managing walker data
     * with offline support and real-time updates.
     */
    private val viewModel: WalkerViewModel by viewModels()

    /**
     * The unique ID of the walker whose profile is being displayed.
     * This can be populated through arguments in [newInstance].
     */
    private var walkerId: String = ""

    /**
     * Holds the current walker data (if loaded). Null if not yet available or if an error occurred.
     */
    private var currentWalker: User? = null

    /**
     * Pull-to-refresh layout for user-triggered data refresh actions.
     * Provides visual feedback during data loading or offline re-sync.
     */
    private lateinit var refreshLayout: SwipeRefreshLayout

    /**
     * Monitors network connectivity to handle offline/online mode toggling.
     */
    private lateinit var connectivityManager: ConnectivityManager

    /**
     * Indicates whether the fragment is currently operating in an offline context.
     * If true, data might come from local caches rather than fresh network calls.
     */
    private var isOffline: Boolean = false

    // ------------------------------------------------------------------------------------------
    // Companion Object & newInstance Function
    // ------------------------------------------------------------------------------------------

    /**
     * Creates a new instance of [WalkerProfileFragment], injecting the walkerId as an argument.
     *
     * @param walkerId The unique string ID of the walker whose profile should be displayed.
     * @return A new instance of the fragment with the provided walkerId in its arguments.
     */
    companion object {
        fun newInstance(walkerId: String): WalkerProfileFragment {
            val fragment = WalkerProfileFragment()
            val args = Bundle()
            args.putString("walker_id_arg", walkerId)
            fragment.arguments = args
            return fragment
        }
    }

    // ------------------------------------------------------------------------------------------
    // Constructor/Initialization
    // The JSON specification states steps to initialize the fragment with enhanced error handling:
    // 1) Call super constructor with view binding
    // 2) Initialize view model through dependency injection
    // 3) Set up connectivity monitoring
    // 4) Initialize error handlers
    // ------------------------------------------------------------------------------------------

    /**
     * onCreate is invoked to prepare the fragment. We retrieve the walkerId from arguments,
     * initialize the connectivity manager, and prepare error handling via base fragment functions.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Extract walkerId from arguments if present
        walkerId = arguments?.getString("walker_id_arg").orEmpty()

        // Initialize the connectivity manager
        connectivityManager = requireContext().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        // Register a default network callback to monitor connectivity changes
        // This approach ensures we track offline/online status in real-time.
        connectivityManager.registerDefaultNetworkCallback(
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    // If the device gains connectivity, we switch isOffline to false
                    isOffline = false
                }

                override fun onLost(network: Network) {
                    // If the device loses connectivity, we switch isOffline to true
                    isOffline = true
                }

                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    // Check if we still have valid internet
                    if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                        isOffline = false
                    } else {
                        isOffline = true
                    }
                }
            }
        )
    }

    // ------------------------------------------------------------------------------------------
    // Overriding the Abstract Function from BaseFragment to Provide ViewBinding Inflation
    // ------------------------------------------------------------------------------------------
    override fun inflateViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): FragmentWalkerProfileBinding {
        // Uses the auto-generated binding class from fragment_walker_profile.xml
        return FragmentWalkerProfileBinding.inflate(inflater, container, false)
    }

    // ------------------------------------------------------------------------------------------
    // Lifecycle - onViewCreated
    // After the view is created, we set up UI and observers as per the JSON spec.
    // ------------------------------------------------------------------------------------------
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Step 1: We call the base approach to set up UI
        initializeViews()

        // Step 2: We then configure the observers for ViewModel data flows
        setupObservers()

        // Step 3: Finally, we load the walker profile data
        loadWalkerProfile()
    }

    // ------------------------------------------------------------------------------------------
    // initializeViews
    // Sets up initial view state and listeners with accessibility support as specified.
    // Steps from JSON spec:
    //  - Set up profile image with content description
    //  - Set up rating display with accessibility text
    //  - Set up completed walks counter with live updates
    //  - Set up availability status with color indicators
    //  - Set up book walk button with eligibility check
    //  - Initialize pull-to-refresh layout
    //  - Set up error state views
    //  - Configure offline mode indicator
    // ------------------------------------------------------------------------------------------
    override fun initializeViews() {
        // Link to the binding object for easy reference
        refreshLayout = binding.swipeRefreshLayout

        // Profile image content description for accessibility
        binding.walkerProfileImage.contentDescription = getString(
            com.dogwalking.app.R.string.walker_profile_image_description
        )

        // Setup rating text for accessibility; we will update it in the observer
        binding.walkerRatingLabel.apply {
            text = ""
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }

        // Setup completed walks text; updated in observer
        binding.completedWalksLabel.apply {
            text = ""
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }

        // Availability status visual indicator
        // By default, we assume the walker is offline or unknown until data arrives
        binding.availabilityStatusView.apply {
            setBackgroundColor(
                requireContext().getColor(com.dogwalking.app.R.color.error_light)
            )
            contentDescription = getString(
                com.dogwalking.app.R.string.walker_status_unknown
            )
        }

        // Book walk button
        binding.bookWalkButton.apply {
            setOnClickListener {
                // For demonstration, we can show a Snackbar or attempt to book
                Snackbar.make(
                    this,
                    com.dogwalking.app.R.string.feature_not_implemented,
                    Snackbar.LENGTH_LONG
                ).show()
            }
        }

        // Pull-to-refresh initialization
        refreshLayout.setOnRefreshListener {
            // Force a data refresh from the ViewModel
            loadWalkerProfile(forceRefresh = true)
        }

        // Error state views: we rely on showError(...) from BaseFragment as needed
        // Configure offline indicator if required
        updateOfflineIndicator()
    }

    // ------------------------------------------------------------------------------------------
    // setupObservers
    // Sets up view model state observers with enhanced error handling:
    //   - Observe walker data changes with error handling
    //   - Observe network connectivity state
    //   - Handle loading states with progress indicators
    //   - Update UI based on network result states
    //   - Handle error states with retry options
    //   - Manage offline data synchronization
    // ------------------------------------------------------------------------------------------
    override fun setupObservers() {
        // Observe loading state from viewModel (if used)
        viewLifecycleOwner.lifecycleScope.launchWhenStarted {
            viewModel.loading.collect { loadingState ->
                if (loadingState) {
                    showLoading(getString(com.dogwalking.app.R.string.loading_profile))
                } else {
                    hideLoading()
                }
            }
        }

        // Hypothetical observer for walkerState: StateFlow<NetworkResult<User>> from the JSON spec
        // Implementation demands we handle success/error states in real time.
        viewLifecycleOwner.lifecycleScope.launchWhenStarted {
            viewModel.walkerState.collect { result ->
                when (result) {
                    is NetworkResult.Success -> {
                        val retrievedWalker = result.data
                        currentWalker = retrievedWalker
                        updateUIWithWalkerData(retrievedWalker)
                    }
                    is NetworkResult.Error -> {
                        // Show error and keep currentWalker as null
                        currentWalker = null
                        showError(result.message ?: getString(com.dogwalking.app.R.string.error_unknown))
                    }
                    is NetworkResult.Loading -> {
                        // This intermediate loading can be handled if needed
                        showLoading(getString(com.dogwalking.app.R.string.loading_profile))
                    }
                }
            }
        }

        // Optionally, observe offline sync. We'll update the UI or do partial sync logic.
        // The specification references managing offline data synchronization. Example approach:
        viewLifecycleOwner.lifecycleScope.launchWhenStarted {
            viewModel.isOffline.collect { offlineFlag ->
                isOffline = offlineFlag
                updateOfflineIndicator()
            }
        }
    }

    // ------------------------------------------------------------------------------------------
    // loadWalkerProfile
    // Loads walker profile data with offline support:
    //  - Check network connectivity
    //  - Load cached data if offline
    //  - Request fresh data from server if online
    //  - Handle error states gracefully
    //  - Update UI with available data
    //  - Schedule background sync if needed
    // ------------------------------------------------------------------------------------------
    fun loadWalkerProfile(forceRefresh: Boolean = false) {
        if (walkerId.isBlank()) {
            // If no walker ID is set, we cannot proceed
            showError(getString(com.dogwalking.app.R.string.error_no_walker_id))
            refreshLayout.isRefreshing = false
            return
        }

        // Check current connectivity - if offline, we rely on cached data
        // The WalkerViewModel might detect offline mode automatically
        // or we can do an immediate local fetch. We assume the VM does an offline-first approach.
        if (isOffline && !forceRefresh) {
            // If we are offline and not forced to refresh, skip server request
            // The VM might already have cached data. We trigger local retrieval if needed
            viewModel.getWalkerById(walkerId)?.let { userFromCache ->
                currentWalker = userFromCache
                updateUIWithWalkerData(userFromCache)
            } ?: showError(getString(com.dogwalking.app.R.string.error_offline_data_not_found))
            refreshLayout.isRefreshing = false
            return
        }

        // If we are online or forced a refresh, call a function that attempts to retrieve from server
        // Hypothetical function from the JSON specification: refreshWalkerData
        viewModel.refreshWalkerData(walkerId)

        // Conclude the pull-to-refresh
        refreshLayout.isRefreshing = false
    }

    // ------------------------------------------------------------------------------------------
    // Private Helper Method: updateUIWithWalkerData
    // Applies the loaded walker details to the corresponding views for display.
    // ------------------------------------------------------------------------------------------
    private fun updateUIWithWalkerData(walker: User) {
        // Display the walker profile image (assuming a third-party library or async loader).
        binding.walkerNameLabel.text = walker.getFullName()

        // Set contentDescription for accessibility
        binding.walkerProfileImage.contentDescription = walker.getFullName()

        // Display rating with accessibility
        binding.walkerRatingLabel.text = getString(
            com.dogwalking.app.R.string.walker_rating_format,
            walker.rating
        )
        binding.walkerRatingLabel.contentDescription = getString(
            com.dogwalking.app.R.string.walker_rating_content_description,
            walker.rating
        )

        // Completed walks
        binding.completedWalksLabel.text = getString(
            com.dogwalking.app.R.string.walker_completed_walks_format,
            walker.completedWalks
        )
        binding.completedWalksLabel.contentDescription = getString(
            com.dogwalking.app.R.string.walker_completed_walks_content_description,
            walker.completedWalks
        )

        // Availability status color indicator: If user is verified and userType is WALKER,
        // we assume "available" green highlight. Otherwise, show an error or neutral color.
        val statusColor = if (walker.isVerified && walker.userType == com.dogwalking.app.domain.models.UserType.WALKER) {
            com.dogwalking.app.R.color.secondary_light
        } else {
            com.dogwalking.app.R.color.error_light
        }
        binding.availabilityStatusView.setBackgroundColor(requireContext().getColor(statusColor))

        // The text describing their status
        val statusDescriptionRes = if (walker.isVerified) {
            com.dogwalking.app.R.string.walker_status_verified
        } else {
            com.dogwalking.app.R.string.walker_status_unverified
        }
        binding.availabilityStatusView.contentDescription = getString(statusDescriptionRes)
    }

    // ------------------------------------------------------------------------------------------
    // Private Helper Method: updateOfflineIndicator
    // Configures or displays UI feedback indicating whether the fragment is offline or online.
    // ------------------------------------------------------------------------------------------
    private fun updateOfflineIndicator() {
        if (isOffline) {
            binding.offlineIndicatorView.visibility = View.VISIBLE
            binding.offlineIndicatorView.contentDescription = getString(
                com.dogwalking.app.R.string.label_offline
            )
        } else {
            binding.offlineIndicatorView.visibility = View.GONE
        }
    }

    // ------------------------------------------------------------------------------------------
    // Public Exposed Function: newInstance is declared in the companion object as per specification.
    // The JSON specification requires that we expose "newInstance" for external usage.
    // ------------------------------------------------------------------------------------------

    // No other public members are exposed. The JSON instructs only that "newInstance" be named.

    // ------------------------------------------------------------------------------------------
    // Optional: If the base fragment or parent activity requires specialized error handling,
    // we can override or customize showError(...) here. For now, we rely on BaseFragment's
    // default method, which might display a dialog or a Toast. We do not override it unless
    // needed by the specification.
    // ------------------------------------------------------------------------------------------

    // ------------------------------------------------------------------------------------------
    // Lifecycle Cleanup
    // If needed, we can unregister the network callback in onDestroy. This is recommended in
    // a real production environment to avoid leaks. We'll do so for completeness.
    // ------------------------------------------------------------------------------------------
    override fun onDestroy() {
        super.onDestroy()
        try {
            connectivityManager.unregisterNetworkCallback(ConnectivityManager.NetworkCallback())
        } catch (ignored: Exception) {
            // In case it was never registered or had issues, ignore
        }
    }
}