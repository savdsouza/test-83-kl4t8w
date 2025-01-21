/*
 * Root-level Gradle build configuration file using Kotlin DSL.
 * This file addresses the following core requirements:
 * 1) Mobile Application Platform Support for Android 8.0+ builds.
 * 2) Modern build tools & plugins configuration with Gradle 8.4.
 * 3) Comprehensive repositories, dependencies, and plugin resolution strategies.
 *
 * Extensive, production-ready comments are included throughout to clarify usage.
 */

/* 
 * Plugin Management Block:
 * Responsible for specifying where Gradle should look for plugins and how to
 * resolve requested plugin versions within this project. This ensures that
 * any plugin requested with a specific namespace gets mapped to the correct
 * artifact and version.
 */
pluginManagement {
    // Repositories holding plugin artifacts.
    repositories {
        gradlePluginPortal()  // Official Gradle plugin portal for community plugins.
        google()              // Google's Maven repository for Android-specific plugins & tools.
        mavenCentral()        // Central repository hosting a wide array of open-source plugins.
    }

    // Resolution strategy ensures consistent plugin versions throughout the build.
    resolutionStrategy {
        eachPlugin {
            // Enforce the Android Gradle plugin version.
            if (requested.id.namespace == "com.android") {
                useModule("com.android.tools.build:gradle:8.1.0")
            }
            // Enforce the Kotlin plugin version.
            if (requested.id.namespace == "org.jetbrains.kotlin") {
                useVersion("1.9.0")
            }
            // Enforce the Dagger Hilt plugin version.
            if (requested.id.namespace == "com.google.dagger") {
                useVersion("2.48")
            }
            // Enforce the Navigation Safe Args plugin version.
            if (requested.id.namespace == "androidx.navigation") {
                useVersion("2.7.1")
            }
        }
    }
}

/*
 * Buildscript Block:
 * Declares dependencies required to configure and build the entire project.
 * These classpath dependencies are applied to sub-projects as needed.
 */
buildscript {
    // Repositories for dependency resolution of build scripts.
    repositories {
        google()       // Core Google Maven repository for Android plugin artifacts.
        mavenCentral() // Central repository for a wide range of library artifacts.
    }

    // Essential classpath dependencies for the Android application build process.
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0") // Android Gradle plugin v8.1.0
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // Kotlin plugin v1.9.0
        classpath("com.google.dagger:hilt-android-gradle-plugin:2.48") // Hilt DI plugin v2.48
        classpath("androidx.navigation:navigation-safe-args-gradle-plugin:2.7.1") // Navigation Safe Args plugin v2.7.1
    }
}

/*
 * Allprojects Block:
 * Configures repositories that will be available to every module/sub-project
 * within this Android dog walking application. Ensures consistent resolution
 * of library dependencies across all modules.
 */
allprojects {
    repositories {
        google()       // Required for core Android libraries and Google dependencies.
        mavenCentral() // Host to numerous open-source libraries.
    }
}

/*
 * Task Registration:
 * Provides a clean task to delete the build directory, maintaining a
 * clean state for builds. This aligns with the best practice of
 * isolating artifacts between build runs.
 */
tasks.register("clean", Delete::class) {
    // Description clarifies the function & purpose of this custom task.
    description = "Deletes the build directory to ensure clean builds."

    // Points to the root project’s build directory as the target for deletion.
    delete(rootProject.buildDir)
}