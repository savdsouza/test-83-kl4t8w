################################################################################
# PROGUARD / R8 CONFIGURATION FILE FOR THE ANDROID DOG WALKING APPLICATION
#------------------------------------------------------------------------------
# This configuration file implements a comprehensive code shrinking, optimization,
# and obfuscation strategy outlined by the technical requirements. It leverages
# the isMinifyEnabled = true and proguardFiles(...) directives defined in
# src/android/app/build.gradle.kts (release build). The following sections ensure:
#   1) Security Layer protection (multi-factor auth, encryption-sensitive code)
#   2) System Uptime optimization (stable, optimized code for 99.9% availability)
#   3) Real-time Features preservation (WebSocket-based tracking and messaging)
################################################################################

################################################################################
# GLOBAL RULES
#------------------------------------------------------------------------------
# 1) Keep essential attributes, including annotations, exception details,
#    and debug info for improved traceability.
# 2) Preserve CREATOR fields for classes implementing android.os.Parcelable.
# 3) Retain crucial enum methods for enumerations used throughout the app.
################################################################################
-keepattributes *Annotation*, Signature, Exception, EnclosingMethod, InnerClasses, SourceFile, LineNumberTable
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class * extends java.lang.Enum {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

################################################################################
# SECURITY RULES (SecurityRules)
#------------------------------------------------------------------------------
# Protect security-sensitive components required for multi-factor authentication,
# encryption, and biometric features, contributing to the Security Layer coverage.
################################################################################

# Encryption module
-keep class com.dogwalking.app.security.encryption.** { *; }

# Authentication module
-keep class com.dogwalking.app.security.auth.** { *; }

# Biometric module
-keep class com.dogwalking.app.security.biometric.** { *; }

################################################################################
# DOMAIN RULES (DomainRules)
#------------------------------------------------------------------------------
# Preserve critical domain logic, such as models and business rules. This ensures
# stable operation and robust performance, contributing to both System Uptime and
# feature correctness.
################################################################################

# Domain models
-keep class com.dogwalking.app.domain.models.** { *; }

# Domain use cases
-keep class com.dogwalking.app.domain.usecases.** { *; }

# Domain repositories
-keep class com.dogwalking.app.domain.repositories.** { *; }

################################################################################
# DATA RULES (DataRules)
#------------------------------------------------------------------------------
# Preserve data layer components (API interfaces, database entities, and
# WebSocket real-time features) for accurate data operations and real-time
# tracking/messaging compliance.
################################################################################

# API interfaces
-keep interface com.dogwalking.app.data.api.** { *; }

# Database classes
-keep class com.dogwalking.app.data.database.** { *; }

# WebSocket real-time components
-keep class com.dogwalking.app.data.websocket.** { *; }

################################################################################
# LIBRARY RULES (LibraryRules)
#------------------------------------------------------------------------------
# Keep necessary classes/methods for third-party libraries:
#  - Retrofit (version 2.9.0)
#  - Gson (version 2.9.0)
#  - Kotlin Coroutines (version 1.7.3)
#  - Hilt (version 2.48)
#  - WebSocket (version 4.11.0)
# Preserves functionality for networking, JSON serialization, async ops,
# dependency injection, and real-time communication.
################################################################################

# Retrofit 2.9.0
-keep class retrofit2.** { *; }

# Gson 2.9.0
-keep class com.google.gson.** { *; }

# Kotlin Coroutines 1.7.3
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}

# Hilt 2.48
-keep class dagger.hilt.** { *; }

# WebSocket / OkHttp 4.11.0
-keep class okhttp3.WebSocket* { *; }

################################################################################
# OPTIMIZATION RULES (OptimizationRules)
#------------------------------------------------------------------------------
# Code optimization directives for stable performance and reduced size:
# 1) Restrict certain optimizations that can cause instability.
# 2) Prevent aggressive shrinking of critical classes.
# 3) Output mapping for debugging.
# 4) Keep certain debugging attributes.
################################################################################

# Fine-tune optimization passes (avoid certain arithmetic/cast merges)
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# Disable shrinking if you wish to preserve critical application code
-dontshrink

# Output obfuscation mapping for debugging and QA
-printmapping mapping.txt

# Keep essential source/line info for crash reporting
-keepattributes SourceFile,LineNumberTable