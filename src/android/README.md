<!--
  Dog Walking Android Application
  Documentation Type: Markdown
  Audience: Developers
  Version: 1.0.0
  Last Updated: 2024-01-20

  This README provides a comprehensive guide to the Dog Walking Android App,
  including its setup, architecture, development environment requirements,
  testing strategies, security measures, and contributing guidelines.
  It addresses the following core specifications:

  1) Mobile Application Platform Support (Android 8.0+, Kotlin).
  2) Development Environment Setup (Android Studio Electric Eel or newer,
     Gradle, Kotlin).
  3) System Architecture (MVVM with Clean Architecture, real-time location,
     repository pattern, domain-driven design).

  References:
  - Root-level build configuration: src/android/build.gradle.kts
  - Module build configuration: src/android/app/build.gradle.kts
-->

# Overview
The Dog Walking Android Application is a native Android solution designed to provide:  
• Comprehensive dog walking services for urban dog owners.  
• Real-time location tracking for walks.  
• Secure payment processing for booking and billing.  
• Push notifications for timely updates.  
• Offline support to ensure minimal disruptions when network connectivity is limited.

This application targets Android devices running API level 26 (Android 8.0) or higher. It leverages modern Android architecture components, written in Kotlin (version 1.9.0), and adheres to Clean Architecture principles in conjunction with MVVM. These design choices facilitate better modularity, testability, and maintainability.

---

# Prerequisites
Before contributing or building the project, ensure the following prerequisites are met:

1. ■ Android Studio Electric Eel or newer  
   – Recommended to leverage the latest IDE features and improvements.  
   – Includes Jetpack Compose support, advanced profilers, and up-to-date emulators.

2. ■ Java Development Kit (JDK) 17  
   – Aligns with Kotlin 1.9.0 and advanced language features.  
   – Confirm JAVA_HOME is properly set.

3. ■ Android SDK for API 34 (Android 14)  
   – Required to compile and test the application with the latest Android APIs.

4. ■ Gradle 8.4  
   – Manages project build lifecycle.  
   – The Kotlin DSL-based build scripts are configured in src/android/build.gradle.kts (root) and src/android/app/build.gradle.kts (app module).

5. ■ Kotlin 1.9.0  
   – Ensures compatibility with the Kotlin language version used across the project.  
   – Properly installed alongside the Android Gradle plugin.

6. ■ Google Maps API Key  
   – Required for location tracking features.  
   – Configure in local.properties or an alternative secure location.

7. ■ Firebase Configuration (Optional)  
   – Needed for push notifications (FCM) if you wish to enable advanced messaging features.  
   – Add the google-services.json file in the appropriate module directory.

---

# Architecture
This application follows an MVVM (Model-View-ViewModel) pattern with Clean Architecture layers:

1. **Presentation Layer (View + ViewModel)**  
   – Implements Jetpack ViewModel classes for state management. LiveData or Flow used for reactive data updates.  
   – UI logic is separated from the domain logic, maintaining a clean separation of concerns.  
   – Uses XML-based layouts or Jetpack Compose for modern UI components.

2. **Domain Layer**  
   – Holds use cases and entity models.  
   – Defines core business rules and interacts with repository interfaces for data retrieval or updates.  
   – Encourages domain-driven design focusing on dog-walking tasks, booking, and location-based logic.

3. **Data Layer**  
   – Responsible for accessing local data sources (Room or direct content providers) and remote data sources (REST or other APIs).  
   – Uses the repository pattern to abstract data retrieval logic from the domain layer.  
   – Retrofit is configured for networking, with interceptors for logging and request signing when applicable.

4. **Dependency Injection with Hilt**  
   – Provided by the Hilt (com.google.dagger) plugin at version 2.48.  
   – Helps manage the object graph, scope ViewModels, and ensures each layer is consistently testable.

5. **Real-Time Location Tracking**  
   – Employs Google Play Services (Location 21.0.1 and Maps 18.1.0) for GPS location updates.  
   – Allows live walk status updates and route tracking.  
   – Exposes reactive data streams for the domain layer to process and present in UI.

By organizing the code into these layers, the project achieves modularity, enabling independent development and fostering robust testing. Check “src/android/app/build.gradle.kts” for more details on implementing these architecture components and their respective library versions.

---

# Setup
Follow these steps to configure your environment and launch the application:

1. **Clone the Repository**  
   – Use Git to clone the project to your local machine. Example:  
     git clone https://github.com/YourOrg/dog-walking-android.git

2. **Open in Android Studio Electric Eel or Newer**  
   – From the “Welcome” screen, choose “Open an existing project” and select the cloned directory.  
   – Let Gradle sync the modules automatically.

3. **Configure Google Maps API Key**  
   – Acquire an API key from the Google Cloud Console.  
   – Add the key to your local.properties file (recommended) or directly in the manifest if testing only. Example in local.properties:  
     MAPS_API_KEY=YOUR_KEY_HERE

4. **(Optional) Configure Firebase for Push Notifications**  
   – Add google-services.json in the module’s root directory.  
   – Enable the Firebase plugin if push messaging is desired.

5. **Build Variant Selection**  
   – The project includes debug and release build types.  
   – For local development, select the “debug” variant in Android Studio.  
   – For production or official testing, configure the “release” build type, providing the necessary signing credentials.

6. **Gradle Sync**  
   – If not triggered automatically, select “Sync Project with Gradle Files” in Android Studio.  
   – Wait for dependencies to download.  
   – Verify that the sync completes without errors by referencing the logs in the “Build” tool window.

7. **Verify Platform Tools**  
   – Confirm you have an emulator running a device image ≥ API level 26 or a physical device with Android 8.0+.  
   – Gradle (version 8.4) and Kotlin (version 1.9.0) must be correctly installed and recognized by Android Studio.

---

# Testing
Comprehensive testing is essential to maintain quality and stability. The following test categories are recommended:

1. **Unit Testing**  
   – Primarily uses JUnit (4.13.2) and Mockito (mockito-core 5.5.0) or MockK (1.13.7).  
   – Validate ViewModels, use cases, and repository logic.  
   – Place tests in the src/test/java directory.

2. **UI Testing**  
   – Employ Espresso (3.5.1) for direct interaction with UI components.  
   – Place tests in the src/androidTest/java directory.  
   – Automate flows such as booking a dog walk, verifying location tracking screens, and offline fallback behaviors.

3. **Integration Testing**  
   – Combine multiple components (e.g., data layer + domain layer) to ensure synergy between modules.  
   – Leverage the built-in Android test framework or additional libraries for advanced validations.

4. **Performance Testing**  
   – Benchmark app startup time, memory usage, and network efficiency.  
   – Identify bottlenecks in real-time GPS tracking and concurrency with coroutines/Flows.

5. **Accessibility Testing**  
   – Ensure screen reader compatibility, color contrast compliance, and easy navigation.  
   – Use the Accessibility Scanner tool to detect potential issues.

---

# Dependencies
This project uses a wide range of libraries to support core functionalities, as defined in “src/android/app/build.gradle.kts.” Major dependencies include:

• AndroidX Core, AppCompat, and Material design for essential UI components.  
• ConstraintLayout for responsive and flexible layouts.  
• Lifecycle & LiveData KTX for observable, lifecycle-aware components.  
• Navigation Component for in-app navigation flows and Safe Args usage.  
• Dagger Hilt for scalable dependency injection.  
• Retrofit + OkHttp for networking and logging.  
• Kotlinx Coroutines for asynchronous tasks and concurrency.  
• Google Play Services (Maps, Location) for GPS and real-time mapping.  
• Glide for efficient image loading and caching.  
• Moshi or Gson for JSON parsing.  

Review the “dependencies” block in the app module’s build script for exact versions and scopes (implementation, kapt, testImplementation, androidTestImplementation).

---

# Security
Security is a core requirement within the Dog Walking Android App. Adhere to the following guidelines to protect user data and credentials:

1. **API Key Management**  
   – Store sensitive keys (e.g., MAPS_API_KEY) in local.properties.  
   – Avoid committing them to version control.

2. **Certificate Pinning**  
   – For critical endpoints, implement SSL pinning to mitigate man-in-the-middle attacks.  
   – Tools like OkHttp certificate pinner can be integrated in the networking layer.

3. **Encryption Guidelines**  
   – Use AES-256 for local data at rest when possible.  
   – Use HTTPS/TLS 1.3 for all remote communications.  
   – Leverage the AndroidX Security Crypto library (1.1.0-alpha06) for additional cryptographic convenience.

4. **ProGuard / R8 Configuration**  
   – ProGuard is enabled in the “release” build (see buildTypes in app/build.gradle.kts).  
   – Maintain or add rules in proguard-rules.pro to keep model classes used in reflection.  
   – Remove unneeded classes and obfuscate code to protect app logic.

5. **Runtime Permissions**  
   – Prompt users responsibly for location permissions.  
   – Follow the recommended flow for background location usage if required.

---

# Contributing
We welcome contributions to enhance functionality, fix bugs, or improve documentation. Please adhere to the following:

1. **Code Style**  
   – Follow Kotlin style guidelines.  
   – Use KtLint or a similar linting tool for consistency.

2. **Pull Request (PR) Process**  
   – Fork the repository, create a feature branch, and commit changes with descriptive messages.  
   – Ensure unit tests pass locally.  
   – Open a PR against the main branch, describing the changes thoroughly.  
   – Code review is required by at least one project maintainer.

3. **Review Guidelines**  
   – Validate design patterns, coding standards, and test coverage.  
   – Check backward compatibility with Android devices on API 26+.

4. **Release Process**  
   – PR merges trigger a pipeline that may deploy to the staging environment.  
   – Confirm integration tests before final production release.  
   – Tag commits properly (e.g., v1.1.0) to track versions.

By collaborating within these guidelines, we ensure that the Dog Walking Android App remains secure, reliable, and user-friendly for all stakeholders.

---