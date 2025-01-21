package com.dogwalking.app.ui.components

/* 
 * External Imports with version comments as per enterprise standards
 */
import android.content.Context // Android latest
import android.util.AttributeSet // Android latest
import android.widget.LinearLayout // Android latest
import android.widget.ImageView // Android latest
import android.view.accessibility.AccessibilityEvent // Android latest
import android.os.Parcelable // Android latest
import android.view.MotionEvent // Android latest
import com.dogwalking.app.R // com.dogwalking.app latest

import kotlin.math.roundToInt

/**
 * A custom RatingBar component that displays a series of star icons indicating a rating value.
 * It supports both editable and display-only modes, preserves state across configuration changes,
 * and provides accessibility for users with assistive technologies.
 *
 * The rating bar can display partial stars based on a stepSize property, enabling precision ratings
 * (e.g., 3.5 out of 5). It also supports haptic feedback if the device permits.
 *
 * @constructor Constructs a new RatingBar with optional XML attributes for customization.
 */
class RatingBar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : LinearLayout(context, attrs) {

    /**
     * Current rating value displayed by this rating bar.
     * Supported range is from 0.0f up to [maxStars].
     */
    var rating: Float = 0.0f
        private set

    /**
     * Maximum number of stars to display.
     * This value controls the size of the [starViews] collection.
     */
    var maxStars: Int = 5

    /**
     * Determines whether this rating bar can be interacted with by the user.
     * If false, the rating bar is in display-only mode and does not respond to touch events.
     */
    var isEditable: Boolean = true

    /**
     * Stores the star ImageView references for updating drawables in real time.
     */
    private val starViews: MutableList<ImageView> = mutableListOf()

    /**
     * A function reference that is triggered whenever the rating value changes.
     * This is useful for notifying external listeners about rating updates.
     */
    var onRatingChanged: (Float) -> Unit = {}

    /**
     * Step size value used to constrain ratings to a specific increment (e.g., 0.5 for half-star increments).
     */
    var stepSize: Float = 0.5f

    /**
     * If true, the user receives haptic feedback (vibration) on devices that support it whenever they change the rating.
     */
    var isHapticFeedbackEnabled: Boolean = true

    // Region: Constructors and Initialization

    init {
        // Setup the layout orientation for the star bar
        orientation = HORIZONTAL

        // Attempt to load any custom XML attributes if present
        context.theme.obtainStyledAttributes(attrs, R.styleable.RatingBar, 0, 0).apply {
            try {
                // Overrides default values if provided
                maxStars = getInt(R.styleable.RatingBar_rb_maxStars, maxStars)
                rating = getFloat(R.styleable.RatingBar_rb_rating, rating)
                isEditable = getBoolean(R.styleable.RatingBar_rb_isEditable, isEditable)
                stepSize = getFloat(R.styleable.RatingBar_rb_stepSize, stepSize)
                isHapticFeedbackEnabled = getBoolean(
                    R.styleable.RatingBar_rb_isHapticFeedbackEnabled,
                    isHapticFeedbackEnabled
                )
            } finally {
                recycle()
            }
        }

        // Initialize the star image views
        initializeStars()
        // Reflect the initial rating visually
        updateStars()
    }

    /**
     * Creates and adds star ImageView objects to the layout and configures them for
     * visual consistency, accessibility, and interactivity.
     */
    private fun initializeStars() {
        // Clear any existing views and data to rebuild from scratch
        removeAllViews()
        starViews.clear()

        // Populate layout with the appropriate number of star ImageView objects
        for (i in 0 until maxStars) {
            val star = ImageView(context).apply {
                // Provide consistent layout and sizing
                val layoutParams = LayoutParams(
                    LayoutParams.WRAP_CONTENT,
                    LayoutParams.WRAP_CONTENT
                )
                this.layoutParams = layoutParams

                // Enable talkback and other assistive features
                isFocusable = true
                contentDescription = context.getString(R.string.rating_star)

                // Indicate this view is relevant for accessibility services
                importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY

                // If isEditable, enable a clickable state and set a unique star index
                if (isEditable) {
                    isClickable = true
                }
            }

            // Add the newly created star ImageView to the parent layout
            addView(star)
            // Save reference for future updates
            starViews.add(star)
        }
    }

    /**
     * Updates each star drawable based on the current rating.
     * Supports partial star filling when the rating includes fractional components
     * and respects the stepSize property to ensure rating increments are consistent.
     */
    private fun updateStars() {
        // Safety check: if maxStars <= 0, abort
        if (maxStars <= 0) return

        // Calculate how many stars should be fully filled
        val fullStars = rating.toInt()
        // Determine fractional part for potential partial star
        val fractionalPart = rating - fullStars

        starViews.forEachIndexed { index, imageView ->
            val starResource = when {
                index < fullStars -> {
                    // Full star for all indices below the integer part
                    R.drawable.ic_star_filled
                }
                index == fullStars && fractionalPart >= stepSize / 2f && fractionalPart < 1.0f -> {
                    // Partial star if fractional part meets step threshold
                    R.drawable.ic_star_half
                }
                else -> {
                    // Outline star
                    R.drawable.ic_star_outline
                }
            }
            imageView.setImageResource(starResource)
        }

        // Dispatch rating change callback to observers
        onRatingChanged.invoke(rating)

        // Announce possible state change for accessibility
        sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_SELECTED)
    }

    /**
     * Sets the rating value of this rating bar. The value is automatically clamped to valid bounds
     * and adjusted to the nearest step increment specified by [stepSize].
     *
     * @param newRating The new rating value to set, within 0..[maxStars].
     */
    fun setRating(newRating: Float) {
        // Bound the rating between 0 and maxStars
        var adjustedRating = newRating.coerceIn(0f, maxStars.toFloat())

        // Round to step size increments if stepSize is > 0
        if (stepSize > 0f) {
            val multiplier = (adjustedRating / stepSize).roundToInt()
            adjustedRating = multiplier * stepSize
            // Ensure still within valid range after rounding
            adjustedRating = adjustedRating.coerceIn(0f, maxStars.toFloat())
        }

        // Update rating only if it has changed
        if (adjustedRating != rating) {
            rating = adjustedRating
            updateStars()
        }
    }

    /**
     * Allows external control of the [isEditable] property.
     * When set to false, no touch events will alter the rating.
     */
    fun setEditable(editable: Boolean) {
        this.isEditable = editable
    }

    /**
     * Handles touch interactions to update the rating smoothly based on the user's horizontal position
     * on the rating bar. This provides a fluid rating selection experience.
     *
     * @param event The MotionEvent containing details about the user's touch.
     * @return True if the event was handled; false otherwise.
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!isEditable) {
            // If this rating bar is display-only, do not process touch interactions
            return super.onTouchEvent(event)
        }

        when (event.action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE, MotionEvent.ACTION_UP -> {
                // Calculate rating based on x-coordinate relative to total width
                val xPosition = event.x.coerceAtLeast(0f).coerceAtMost(width.toFloat())
                val proportion = xPosition / width
                val newRating = proportion * maxStars.toFloat()

                // Apply the new rating
                setRating(newRating)

                // Provide optional haptic feedback if enabled
                if (isHapticFeedbackEnabled && event.action == MotionEvent.ACTION_UP) {
                    performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
                }

                // Once the rating is set, consume the touch event
                return true
            }
        }
        // Default pass through for other events
        return super.onTouchEvent(event)
    }

    /**
     * Saves the current state (rating, editability, and base layout state) so the rating bar
     * can be restored after configuration changes such as screen rotations.
     *
     * @return A Parcelable object containing the saved state of this view.
     */
    override fun onSaveInstanceState(): Parcelable {
        val superState = super.onSaveInstanceState()
        return SavedState(superState).also {
            it.savedRating = rating
            it.savedIsEditable = isEditable
        }
    }

    /**
     * Restores the saved state of this rating bar. This method is invoked automatically
     * after onSaveInstanceState when the configuration changes.
     *
     * @param state The state object previously saved by onSaveInstanceState.
     */
    override fun onRestoreInstanceState(state: Parcelable?) {
        if (state !is SavedState) {
            super.onRestoreInstanceState(state)
            return
        }
        super.onRestoreInstanceState(state.superState)
        // Restore rating and editability
        rating = state.savedRating
        isEditable = state.savedIsEditable
        updateStars()
    }

    /**
     * Nested class representing the rating bar's saved state for configuration changes.
     * Stores the custom fields that need to persist.
     */
    internal class SavedState : BaseSavedState {
        var savedRating: Float = 0f
        var savedIsEditable: Boolean = true

        constructor(superState: Parcelable?) : super(superState)
        private constructor(inParcel: android.os.Parcel) : super(inParcel) {
            savedRating = inParcel.readFloat()
            savedIsEditable = inParcel.readInt() == 1
        }

        override fun writeToParcel(out: android.os.Parcel, flags: Int) {
            super.writeToParcel(out, flags)
            out.writeFloat(savedRating)
            out.writeInt(if (savedIsEditable) 1 else 0)
        }

        companion object {
            @JvmField
            val CREATOR = object : Parcelable.Creator<SavedState> {
                override fun createFromParcel(source: android.os.Parcel): SavedState {
                    return SavedState(source)
                }

                override fun newArray(size: Int): Array<SavedState?> {
                    return arrayOfNulls(size)
                }
            }
        }
    }
}