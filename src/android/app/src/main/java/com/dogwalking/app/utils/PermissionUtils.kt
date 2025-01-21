package com.dogwalking.app.utils

import android.Manifest // Android permission constants (default Android library)
import android.app.Activity // Android activity context (default Android library)
import android.content.pm.PackageManager // Android package manager (default Android library)
import android.os.Build // Used for Android version checks (default Android library)
// Third-party library version: 1.7.0
import androidx.core.app.ActivityCompat 
// Third-party library version: 1.7.0
import androidx.core.content.ContextCompat

/**
 * Comprehensive utility object for handling Android runtime permissions with
 * enhanced compatibility, security, and user experience features. Supports
 * location tracking, media capture, and storage access requirements for the
 * dog walking application. Manages version-specific checks and rationale display.
 */
object PermissionUtils {

    /**
     * Global constants representing request codes for various permission requests.
     * Each constant is associated with a unique permission requirement for the app.
     */
    const val PERMISSION_REQUEST_LOCATION = 1001
    const val PERMISSION_REQUEST_CAMERA = 1002
    const val PERMISSION_REQUEST_STORAGE = 1003
    const val PERMISSION_REQUEST_BACKGROUND_LOCATION = 1004
    const val PERMISSION_REQUEST_NOTIFICATION = 1005

    /**
     * Checks if the application has all required location permissions granted.
     * This includes both fine and coarse location, and optionally background
     * location if requested for devices running Android 10 (API 29) or higher.
     *
     * @param activity The Android Activity used for checking permission status.
     * @param backgroundRequired A boolean indicating whether background
     *                           location permission is also needed.
     * @return True if all required permission(s) are granted; false otherwise.
     */
    fun hasLocationPermission(activity: Activity?, backgroundRequired: Boolean): Boolean {
        // 1. Validate the Activity parameter to ensure it is not null before proceeding.
        if (activity == null) {
            return false
        }

        // 2. Check ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION using request-time checks.
        val fineLocationGranted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocationGranted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        // 3. If backgroundRequired is true, check for ACCESS_BACKGROUND_LOCATION on
        // Android 10 (API 29) and above, since the permission was introduced in Q.
        return if (backgroundRequired && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val backgroundLocationGranted = ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            fineLocationGranted && coarseLocationGranted && backgroundLocationGranted
        } else {
            // If background location is not required or the device is below API 29,
            // we only need both fine and coarse location to be granted.
            fineLocationGranted && coarseLocationGranted
        }
    }

    /**
     * Verifies camera permission status along with an additional check to confirm whether
     * the device has camera hardware available. This ensures that the user experience is
     * handled gracefully on devices with or without a camera.
     *
     * @param activity The Android Activity used for checking camera permission status
     *                 and hardware availability.
     * @return True if camera permission is granted and camera hardware exists; false otherwise.
     */
    fun hasCameraPermission(activity: Activity?): Boolean {
        // 1. Validate the Activity parameter to ensure it is not null before proceeding.
        if (activity == null) {
            return false
        }

        // 2. Check if the device has camera hardware using the PackageManager system service.
        val hasCameraHardware = activity.packageManager.hasSystemFeature(
            PackageManager.FEATURE_CAMERA_ANY
        )

        // 3. Check CAMERA permission using the backwards-compatible ContextCompat method.
        val cameraPermissionGranted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        // 4. Return the combined result of both camera hardware availability and permission status.
        return hasCameraHardware && cameraPermissionGranted
    }

    /**
     * Requests the necessary location permissions from the system with an
     * enhanced user experience flow. This method determines whether background
     * location permission is also required, handles educational UI for rationale
     * if needed, and leverages the correct request code for location-based usage.
     *
     * @param activity The Android Activity context used to request permissions.
     * @param includeBackground Boolean value indicating if background location
     *                          permission is also needed for this request.
     *
     * Initiates the system permission request dialogs, which will result in a
     * callback to the Activity's onRequestPermissionsResult method.
     */
    fun requestLocationPermission(activity: Activity?, includeBackground: Boolean) {
        // 1. Validate the Activity parameter to ensure it is not null before attempting to request permissions.
        if (activity == null) {
            return
        }

        // 2. Create an array of required location permissions based on whether background is required
        // and the device's Android version.
        val permissionList = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        // If background location is included and the device runs on Android 10 or higher,
        // add ACCESS_BACKGROUND_LOCATION to the request array.
        if (includeBackground && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissionList.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        // 3. Determine the request code. We use a different code if background access is requested.
        val requestCode = if (includeBackground && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            PERMISSION_REQUEST_BACKGROUND_LOCATION
        } else {
            PERMISSION_REQUEST_LOCATION
        }

        // 4. Determine if any permission in our list requires rationale before requesting.
        // If rationale is needed, the application can display an educational UI or explanation.
        if (shouldShowPermissionRationale(activity, permissionList.toTypedArray())) {
            // Implement or show a rationale to the user here if desired.
            // This could be a dialog, a Toast, or any other user-friendly reminder
            // explaining why your app needs these permissions.
        }

        // 5. Proceed to request the permissions. The system will handle the rest of the flow
        // and eventually invoke the onRequestPermissionsResult callback.
        ActivityCompat.requestPermissions(
            activity,
            permissionList.toTypedArray(),
            requestCode
        )
    }

    /**
     * Checks whether any of the provided permissions require a rationale display before requesting.
     * If the user has previously denied one or more permissions, the system recommends showing
     * further explanation for the necessity of those permissions to improve acceptance rates.
     *
     * @param activity The current Android Activity to check permission rationales against.
     * @param permissions An array of permissions to evaluate for rationale display.
     * @return True if a rationale should be shown for at least one of the specified permissions;
     *         false otherwise.
     */
    fun shouldShowPermissionRationale(activity: Activity?, permissions: Array<String>): Boolean {
        // 1. Validate the Activity parameter to ensure it is not null.
        if (activity == null) {
            return false
        }

        // 2. Validate that the permissions array is not empty, as an empty array
        // would make checking for rationale unnecessary.
        if (permissions.isEmpty()) {
            return false
        }

        // 3. Check for each permission in the provided list whether the system
        // recommends showing a rationale to the user.
        for (permission in permissions) {
            if (ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)) {
                // 4. If any single permission requires a rationale, return true immediately.
                return true
            }
        }

        // 5. If none of the permissions require a rationale, return false.
        return false
    }
}