package com.dogwalking.app.ui.dog

// -------------------------------------------------------------
// External Imports with Version Comments
// -------------------------------------------------------------
import android.net.Uri // android-latest for handling image URIs
import android.os.Bundle // android-latest
import android.view.LayoutInflater // android-latest
import android.view.View // android-latest
import android.view.ViewGroup // android-latest
import android.widget.Toast // android-latest
import androidx.fragment.app.viewModels // androidx.fragment.app:1.6.1
import com.google.android.material.snackbar.Snackbar // com.google.android.material:1.9.0
import dagger.hilt.android.AndroidEntryPoint // dagger.hilt.android:2.48

// -------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------
import com.dogwalking.app.databinding.FragmentAddDogBinding
import com.dogwalking.app.domain.models.Dog
import com.dogwalking.app.ui.common.BaseFragment
import com.dogwalking.app.ui.dog.viewmodel.DogViewModel

/**
 * [AddDogFragment] is responsible for adding or editing an existing dog profile in the
 * Dog Walking application. It includes comprehensive form validation, offline support,
 * and accessibility features. This fragment inherits from [BaseFragment], leveraging
 * shared functionality such as showing or hiding a loading indicator.
 *
 * The fragment satisfies the following requirements:
 * 1. Pet Profile Management:
 *    - Allows the creation or update of dog profiles by owners.
 *    - Implements thorough form validation and data handling.
 * 2. Data Management:
 *    - Integrates with [DogViewModel] to support offline-first architecture.
 *    - Observes [loading] and [error] states to reflect UI behavior.
 * 3. Mobile UI Requirements:
 *    - Applies Material Design components for an accessible, user-friendly layout.
 *    - Offers real-time validations, date picking, accessibility announcements, and
 *      robust error handling for better UX.
 */
@AndroidEntryPoint
class AddDogFragment : BaseFragment<FragmentAddDogBinding>() {

    // ------------------------------------------------------------------------
    // Fragment Properties
    // ------------------------------------------------------------------------

    /**
     * The associated [DogViewModel] managing data operations (saveDog, loadDog, etc.)
     * and reflecting offline states, error messages, and loading signals.
     */
    private val viewModel: DogViewModel by viewModels()

    /**
     * The optional dogId parameter representing the ID of the dog to edit. If null,
     * this indicates the user is adding a new dog profile.
     */
    private var dogId: String? = null

    /**
     * An optional [Uri] reference representing the selected image from the gallery or camera,
     * used for uploading a profile photo for the dog.
     */
    private var selectedImageUri: Uri? = null

    /**
     * Tracks whether the system is operating in offline mode (no network connection).
     * Set by observing [DogViewModel.isOffline]. If true, certain online operations might
     * be deferred or performed locally until connectivity is restored.
     */
    private var isOfflineMode: Boolean = false

    /**
     * This is the fragment's primary constructor. It performs the following steps:
     * 1. Calls the base fragment constructor for initialization.
     * 2. Sets up the fragment's saved state handling (Hilt injection occurs automatically).
     * 3. Checks or initializes offline status reference from the [DogViewModel].
     */
    constructor() : super() {
        // Intentionally empty; essential fragment setup is done in lifecycle overrides.
    }

    // ------------------------------------------------------------------------
    // Companion Object
    // ------------------------------------------------------------------------

    /**
     * Creates a new instance of [AddDogFragment], optionally receiving an existing dogId
     * if the user is editing an existing profile. The dogId is added to the fragment's
     * arguments bundle for restoration or usage during the fragment lifecycle.
     *
     * @param dogId The unique dog's ID for editing, or null for a new profile.
     * @return A newly created instance of [AddDogFragment].
     */
    companion object {
        @JvmStatic
        fun newInstance(dogId: String?): AddDogFragment {
            val fragment = AddDogFragment()
            fragment.arguments = Bundle().apply {
                putString("ARG_DOG_ID", dogId)
            }
            return fragment
        }
    }

    // ------------------------------------------------------------------------
    // BaseFragment Overrides
    // ------------------------------------------------------------------------

    /**
     * Inflates the specific ViewBinding [FragmentAddDogBinding] for this fragment.
     * This method is called within [BaseFragment.onCreateView].
     *
     * @param inflater The [LayoutInflater] to inflate the view.
     * @param container The optional container for this fragment's UI.
     * @return An instance of [FragmentAddDogBinding] representing the UI.
     */
    override fun inflateViewBinding(
        inflater: LayoutInflater,
        container: ViewGroup?
    ): FragmentAddDogBinding {
        return FragmentAddDogBinding.inflate(inflater, container, false)
    }

    /**
     * Called after the view has been created. Extracts fragment arguments, assigns
     * internal properties, and initializes UI elements such as form fields and
     * accessibility features.
     */
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Step 1: Retrieve dogId from arguments if present
        dogId = arguments?.getString("ARG_DOG_ID")

        // Step 2: Handle any additional setup or offline checks
        isOfflineMode = false

        // The rest of the UI initialization is deferred to initializeViews and setupObservers
    }

    /**
     * Sets up the UI elements with Material Design components, accessibility support,
     * and form validation triggers. Called by [BaseFragment.onViewCreated].
     */
    override fun initializeViews() {
        super.initializeViews()

        // Step 1: Configure toolbar or top-level UI for accessibility
        binding.toolbarAddDog.apply {
            title = if (dogId.isNullOrBlank()) "Add New Dog" else "Edit Dog Profile"
            // Accessibility enhancements for screen readers:
            contentDescription = "Dog Profile Toolbar"
            setNavigationOnClickListener { requireActivity().onBackPressedDispatcher.onBackPressed() }
        }

        // Step 2: Initialize form fields with accessibility-friendly hints
        binding.editTextDogName.apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) validateName()
            }
        }

        binding.editTextBreed.apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) validateBreed()
            }
        }

        // Step 3: Set up date picker for dog's birth date
        binding.editTextBirthDate.apply {
            setOnClickListener { showDatePickerDialog() }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }

        // Step 4: Configure image selection for dog's profile photo
        binding.buttonSelectImage.setOnClickListener {
            // This might open a gallery intent or a camera capture. For demonstration,
            // we simulate image picking:
            pickImageFromGallery()
        }

        // Step 5: Setup offline indicators if needed (e.g., text or icon for offline mode)
        // We will update the UI in observers, reflecting the isOfflineMode changes.

        // Step 6: Configure Save button with comprehensive validation and data submission
        binding.buttonSaveDog.setOnClickListener {
            if (validateForm()) {
                saveDogProfile()
            }
        }
    }

    /**
     * Observes [DogViewModel] state flows for loading, error, selected dog data,
     * offline status, and any relevant image upload progress. Called by [BaseFragment.onViewCreated].
     */
    override fun setupObservers() {
        super.setupObservers()

        // Observing loading state to show or hide progress indicators
        viewLifecycleOwner.lifecycle.addObserver(this)
        viewModel.loading.collectOnLifecycle(viewLifecycleOwner) { loadingState ->
            if (loadingState) showLoading("Saving dog profile...") else hideLoading()
        }

        // Observing error state for offline handling or user alerts
        viewModel.error.collectOnLifecycle(viewLifecycleOwner) { errorMessage ->
            if (!errorMessage.isNullOrBlank()) {
                showError(errorMessage)
            }
        }

        // Observing offline state to reflect offline mode in the UI
        viewModel.isOffline.collectOnLifecycle(viewLifecycleOwner) { offlineStatus ->
            isOfflineMode = offlineStatus
            // Optionally reflect the offline status in UI or show a Snackbar
            if (offlineStatus) {
                Snackbar.make(
                    binding.root,
                    "Offline mode activated. Data will be saved locally.",
                    Snackbar.LENGTH_SHORT
                ).show()
            }
        }

        // Observing selected dog data if editing an existing profile
        if (!dogId.isNullOrBlank()) {
            viewModel.loadDog(dogId!!)
            viewModel.selectedDog.collectOnLifecycle(viewLifecycleOwner) { dog ->
                if (dog != null) populateDogFields(dog)
            }
        }
    }

    // ------------------------------------------------------------------------
    // Public / Exposed Functions
    // ------------------------------------------------------------------------

    /**
     * Handles an image selection from the user. This includes performing any necessary
     * compression for memory efficiency, verifying file formats, and preparing data either
     * for immediate upload or offline caching.
     *
     * @param imageUri The URI referencing the newly selected image.
     */
    fun handleImageSelection(imageUri: Uri) {
        selectedImageUri = imageUri
        // Step 1: Validate image size and format (placeholder)
        // Step 2: Compress image if needed (placeholder)
        // Step 3: Update UI with selected image
        binding.imageViewDogPhoto.setImageURI(selectedImageUri)
        // Step 4: If online, optionally call a hypothetical uploadImage function
        // If offline, store or queue it for later upload.
    }

    // ------------------------------------------------------------------------
    // Private Helper Methods
    // ------------------------------------------------------------------------

    /**
     * Presents a date picker dialog for selecting the dog's birth date with proper
     * accessibility announcements and validation. The resulting value is placed
     * into the birth date text field.
     */
    private fun showDatePickerDialog() {
        // This demonstration uses a placeholder date approach
        // In a real scenario, invoke DatePickerDialog with local/Material design
        binding.editTextBirthDate.setText("2020-01-01")
    }

    /**
     * Simulates picking an image from the gallery. In a real world scenario, this might
     * start an activity for result using ACTION_GET_CONTENT or a similar approach.
     */
    private fun pickImageFromGallery() {
        // Placeholder: assume we get a mock URI
        val mockUri: Uri = Uri.parse("content://com.dogwalking.app.sample/dogphoto.jpg")
        handleImageSelection(mockUri)
    }

    /**
     * Populates the UI fields with an existing dog's data, allowing the user to edit
     * and update the profile. This is called when [dogId] is not null.
     *
     * @param dog The [Dog] data to show in the form fields.
     */
    private fun populateDogFields(dog: Dog) {
        binding.apply {
            editTextDogName.setText(dog.name)
            editTextBreed.setText(dog.breed)
            editTextBirthDate.setText(dog.birthDate)
            editTextWeight.setText(dog.weight.toString())
            // If the dog has a profile image URL, we might load it into imageViewDogPhoto with a library
            // For demonstration, ignoring actual image loading:
        }
    }

    /**
     * Runs a thorough validation check on the user's input for dog's name, breed, birth date,
     * and weight. Displays inline errors or accessibility announcements if fields are invalid.
     *
     * @return True if all fields are valid, false otherwise.
     */
    private fun validateForm(): Boolean {
        val isNameValid = validateName()
        val isBreedValid = validateBreed()
        val isBirthDateValid = validateBirthDate()
        val isWeightValid = validateWeight()
        return isNameValid && isBreedValid && isBirthDateValid && isWeightValid
    }

    /**
     * Validates the dog's name text field. Sets an error if empty, returning false. If valid,
     * clears any prior error and returns true.
     *
     * @return True if name is valid, false otherwise.
     */
    private fun validateName(): Boolean {
        val text = binding.editTextDogName.text?.toString()?.trim()
        return if (text.isNullOrEmpty()) {
            binding.editTextDogName.error = "Please enter a name."
            false
        } else {
            binding.editTextDogName.error = null
            true
        }
    }

    /**
     * Validates the dog's breed text field. Checks if empty, returning false if invalid.
     *
     * @return True if breed is valid, false otherwise.
     */
    private fun validateBreed(): Boolean {
        val text = binding.editTextBreed.text?.toString()?.trim()
        return if (text.isNullOrEmpty()) {
            binding.editTextBreed.error = "Please enter a breed."
            false
        } else {
            binding.editTextBreed.error = null
            true
        }
    }

    /**
     * Validates the dog's birth date format. This demonstration checks for a non-empty field.
     * A real implementation might parse and ensure correct YYYY-MM-DD data.
     *
     * @return True if the birth date is in an acceptable format, false otherwise.
     */
    private fun validateBirthDate(): Boolean {
        val text = binding.editTextBirthDate.text?.toString()?.trim()
        return if (text.isNullOrEmpty()) {
            binding.editTextBirthDate.error = "Please select a birth date."
            false
        } else {
            binding.editTextBirthDate.error = null
            true
        }
    }

    /**
     * Validates the dog's weight field, ensuring a valid positive floating-point number.
     *
     * @return True if the weight is valid, false otherwise.
     */
    private fun validateWeight(): Boolean {
        val text = binding.editTextWeight.text?.toString()?.trim()
        return try {
            val weight = text?.toFloat() ?: 0f
            if (weight > 0f) {
                binding.editTextWeight.error = null
                true
            } else {
                binding.editTextWeight.error = "Weight must be a positive value."
                false
            }
        } catch (ex: NumberFormatException) {
            binding.editTextWeight.error = "Please enter a valid floating number."
            false
        }
    }

    /**
     * Invoked after successful validation to construct a [Dog] object (either new or updated),
     * and call [viewModel.saveDog]. Observes any result from the ViewModel to reflect success
     * or display errors.
     */
    private fun saveDogProfile() {
        // 1. Gather data from fields
        val name = binding.editTextDogName.text?.toString()?.trim().orEmpty()
        val breed = binding.editTextBreed.text?.toString()?.trim().orEmpty()
        val birthDate = binding.editTextBirthDate.text?.toString()?.trim().orEmpty()
        val weightStr = binding.editTextWeight.text?.toString()?.trim().orEmpty()

        // 2. Convert weight to float safely
        val weight = weightStr.toFloatOrNull() ?: 0f

        // 3. Create or update the dog model
        val currentTime = System.currentTimeMillis()
        val newDog = Dog(
            id = dogId ?: generateDogId(), // generate a new ID if dogId is null
            ownerId = getOwnerIdOrPlaceholder(),
            name = name,
            breed = breed,
            birthDate = birthDate,
            medicalInfo = emptyMap(),
            active = true,
            profileImageUrl = null, // We can store the local file path or wait for actual upload
            weight = weight,
            specialInstructions = emptyList(),
            lastUpdated = currentTime
        )

        // 4. Perform the save operation on the ViewModel
        // showLoading is triggered automatically by the observer of viewModel.loading
        viewLifecycleOwner.lifecycle.addObserver(this)
        viewLifecycleOwner.lifecycleScope.launchWhenStarted {
            val success = viewModel.saveDog(newDog)
            if (success) {
                Toast.makeText(
                    requireContext(),
                    "Dog profile saved successfully.",
                    Toast.LENGTH_SHORT
                ).show()
                // Return or navigate back
                requireActivity().onBackPressedDispatcher.onBackPressed()
            } else {
                // Error will be handled by the observer of viewModel.error
            }
        }
    }

    /**
     * Utility method to generate a new dog ID if this is a new dog. Typically, IDs
     * might be generated by a backend service or a local UUID function.
     *
     * @return A new string ID guaranteed unique for local usage.
     */
    private fun generateDogId(): String {
        return java.util.UUID.randomUUID().toString()
    }

    /**
     * Retrieves the current owner's ID. For demonstration, returns a placeholder string.
     * In a real application, this might query a user repository or session manager.
     *
     * @return The owner's unique ID as a non-empty string.
     */
    private fun getOwnerIdOrPlaceholder(): String {
        // Replace with real logic to retrieve the actual owner's ID
        return "owner-1234"
    }

    /**
     * Displays an error to the user using a Toast, which can be upgraded to a
     * Snackbar or dedicated UI for more advanced usage. Also ensures accessibility
     * announcements are queued by the system.
     *
     * @param message The error message to show. Must not be null or blank.
     */
    private fun showError(message: String) {
        Toast.makeText(requireContext(), message, Toast.LENGTH_LONG).show()
    }
}