/******************************************************************************
 * Module-level Gradle build configuration file for the Android Dog Walking
 * Application. This configuration enforces robust security, real-time features,
 * comprehensive testing support, and ensures enterprise readiness.
 ******************************************************************************/

/******************************************************************************
 * PLUGINS
 * ----------------------------------------------------------------------------
 * Below are the required plugins for our Android application module,
 * including Kotlin, Hilt for dependency injection, and Safe Args for
 * navigation. For each plugin, we note the library version as required.
 ******************************************************************************/
plugins {
    // Android application plugin for building the app, version 8.1.0
    id("com.android.application") version "8.1.0"

    // Kotlin Android plugin for Kotlin language support, version 1.9.0
    id("org.jetbrains.kotlin.android") version "1.9.0"

    // Hilt dependency injection for scalable architecture, version 2.48
    id("com.google.dagger.hilt.android") version "2.48"

    // Navigation Safe Args for type-safe navigation, version 2.7.1
    id("androidx.navigation.safeargs.kotlin") version "2.7.1"

    // Kapt plugin for annotation processing in Kotlin, version 1.9.0
    kotlin("kapt") version "1.9.0"
}

/******************************************************************************
 * ANDROID CONFIGURATION
 * ----------------------------------------------------------------------------
 * Defines Android SDK versions, namespace, and default configurations such as
 * application ID, minSdk, targetSdk, and versioning. Also specifies vector
 * drawables support and testing instrumentation.
 ******************************************************************************/
android {
    // The namespace used for R.class generation and AndroidManifest references
    namespace = "com.dogwalking.app"

    // Specifies the latest SDK level used for compiling the app
    compileSdk = 34

    defaultConfig {
        // Unique application ID
        applicationId = "com.dogwalking.app"

        // Minimum Android version supported (API 26 => Android 8.0)
        minSdk = 26

        // Target Android version (API 34 => Android 14)
        targetSdk = 34

        // Versioning configurations for the application
        versionCode = 1
        versionName = "1.0.0"

        // Specifies the instrumentation runner used for tests
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Enables vector drawables support library
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    /**************************************************************************
     * BUILD FEATURES
     * ------------------------------------------------------------------------
     * Configures modern Android development features, including:
     * 1) ViewBinding for efficient binding to XML views
     * 2) BuildConfig generation for holding config fields
     * 3) DataBinding for MVVM architecture
     * 4) Compose for modern UI components
     * 5) MLKit for future on-device ML features
     *************************************************************************/
    buildFeatures {
        viewBinding = true       // Step 1
        buildConfig = true       // Step 2
        dataBinding = true       // Step 3
        compose = true           // Step 4
        mlModelBinding = true    // Step 5
    }

    /**************************************************************************
     * COMPOSE OPTIONS
     * ------------------------------------------------------------------------
     * Defines the Kotlin compiler extension version for Jetpack Compose.
     * This version may need alignment with the Compose libraries used.
     *************************************************************************/
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.3"
    }

    /**************************************************************************
     * SIGNING CONFIGURATIONS (PLACEHOLDERS)
     * ------------------------------------------------------------------------
     * Defines signing configs for debug and release builds. In a production
     * environment, these should reference secure keystore files or secure
     * credential storage.
     *************************************************************************/
    signingConfigs {
        create("release") {
            // TODO: Configure release signing parameters, e.g.:
            // storeFile = file("release.keystore")
            // storePassword = "RELEASE_STORE_PASSWORD"
            // keyAlias = "RELEASE_KEY_ALIAS"
            // keyPassword = "RELEASE_KEY_PASSWORD"
        }
        getByName("debug") {
            // Default debug Keystore configuration
        }
    }

    /**************************************************************************
     * BUILD TYPES
     * ------------------------------------------------------------------------
     * Defines 'debug' & 'release' build configurations with enhanced security
     * and debugging options.
     * 1) Release build with R8 optimization
     * 2) ProGuard with custom rules
     * 3) Debug build includes debugging symbols
     * 4) Strict mode for debug builds
     * 5) Separate signing configs
     * 6) Crash reporting enabled for release builds
     *************************************************************************/
    buildTypes {
        debug {
            // Suffix details for debug build
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"

            // Debugging symbols and strict mode for QA and development
            isMinifyEnabled = false
            buildConfigField("Boolean", "ENABLE_STRICT_MODE", "true")

            // Use debug signing config
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // R8 optimization is enabled by default when minifyEnabled = true
            isMinifyEnabled = true

            // Enable ProGuard with custom rules
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Associate release signing config
            signingConfig = signingConfigs.getByName("release")

            // Additional field for enabling crash reporting
            buildConfigField("Boolean", "ENABLE_CRASH_REPORTING", "true")
        }
    }

    /**************************************************************************
     * COMPATIBILITY SETTINGS
     * ------------------------------------------------------------------------
     * Ensures that the Java version is set to 17, aligning with the project’s
     * requirement for advanced language features and standard library support.
     *************************************************************************/
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

/******************************************************************************
 * KOTLIN CONFIGURATION
 * ----------------------------------------------------------------------------
 * Sets up the Kotlin JVM toolchain to use Java 17 for advanced language features.
 ******************************************************************************/
kotlin {
    jvmToolchain(17)
}

/******************************************************************************
 * DEPENDENCIES
 * ----------------------------------------------------------------------------
 * Specifies all libraries and frameworks required at runtime (implementation),
 * annotation processing (kapt), unit testing (testImplementation),
 * and instrumentation testing (androidTestImplementation).
 * Each dependency is annotated with its version for clarity.
 ******************************************************************************/
dependencies {
    // ------------------- IMPLEMENTATION DEPENDENCIES -----------------------
    // AndroidX Core KTX 1.12.0
    implementation("androidx.core:core-ktx:1.12.0")

    // AndroidX AppCompat 1.6.1
    implementation("androidx.appcompat:appcompat:1.6.1")

    // Google Material Design 1.9.0
    implementation("com.google.android.material:material:1.9.0")

    // AndroidX ConstraintLayout 2.1.4
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")

    // AndroidX Lifecycle ViewModel KTX 2.6.2
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2")

    // AndroidX Lifecycle LiveData KTX 2.6.2
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.6.2")

    // AndroidX Navigation Fragment KTX 2.7.1
    implementation("androidx.navigation:navigation-fragment-ktx:2.7.1")

    // AndroidX Navigation UI KTX 2.7.1
    implementation("androidx.navigation:navigation-ui-ktx:2.7.1")

    // Dagger Hilt (Android) 2.48
    implementation("com.google.dagger:hilt-android:2.48")

    // Retrofit 2.9.0
    implementation("com.squareup.retrofit2:retrofit:2.9.0")

    // Retrofit Gson Converter 2.9.0
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")

    // OkHttp Logging Interceptor 4.11.0
    implementation("com.squareup.okhttp3:logging-interceptor:4.11.0")

    // Kotlinx Coroutines (Android) 1.7.3
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Google Play Services Maps 18.1.0
    implementation("com.google.android.gms:play-services-maps:18.1.0")

    // Google Play Services Location 21.0.1
    implementation("com.google.android.gms:play-services-location:21.0.1")

    // Glide Image Loading 4.16.0
    implementation("com.github.bumptech.glide:glide:4.16.0")

    // Moshi Kotlin 1.15.0
    implementation("com.squareup.moshi:moshi-kotlin:1.15.0")

    // AndroidX Security Crypto 1.1.0-alpha06
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // AndroidX Biometric 1.2.0-alpha05
    implementation("androidx.biometric:biometric:1.2.0-alpha05")

    // ----------------------- KAPT DEPENDENCIES -----------------------------
    // Dagger Hilt Compiler 2.48
    kapt("com.google.dagger:hilt-android-compiler:2.48")

    // ---------------------- TEST IMPLEMENTATION ----------------------------
    // JUnit 4.13.2
    testImplementation("junit:junit:4.13.2")

    // Mockito Core 5.5.0
    testImplementation("org.mockito:mockito-core:5.5.0")

    // Kotlinx Coroutines Test 1.7.3
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")

    // AndroidX Architecture Core Testing 2.2.0
    testImplementation("androidx.arch.core:core-testing:2.2.0")

    // MockK 1.13.7
    testImplementation("io.mockk:mockk:1.13.7")

    // ------------------ ANDROID TEST IMPLEMENTATION ------------------------
    // AndroidX Test Ext JUnit 1.1.5
    androidTestImplementation("androidx.test.ext:junit:1.1.5")

    // Espresso Core 3.5.1
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")

    // AndroidX Test Runner 1.5.2
    androidTestImplementation("androidx.test:runner:1.5.2")

    // AndroidX Test Rules 1.5.0
    androidTestImplementation("androidx.test:rules:1.5.0")
}