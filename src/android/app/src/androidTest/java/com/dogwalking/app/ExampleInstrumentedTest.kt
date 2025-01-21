package com.dogwalking.app

// -----------------------------------------------------------------------------------------
// EXTREMELY DETAILED AND PRODUCTION-READY CODE IMPLEMENTATION
// -----------------------------------------------------------------------------------------
// Explanation of imports with library versions for clarity and transparency in enterprise
// environments.
// -----------------------------------------------------------------------------------------

// AndroidJUnit4 (version 1.1.5) - Provides Android-specific JUnit4 test runner capabilities
import androidx.test.ext.junit.runners.AndroidJUnit4 // v1.1.5

// InstrumentationRegistry (version 1.1.5) - Delivers the Instrumentation instance used for
// retrieving the target context, thereby allowing direct access to application resources.
import androidx.test.platform.app.InstrumentationRegistry // v1.1.5

// Assert (version 4.13.2) - Contains the assertion methods that enable the validation of
// test outcomes during instrumentation tests.
import org.junit.Assert.assertEquals // v4.13.2

// JUnit Annotations - Provide structural definitions for identifying and running tests.
import org.junit.runner.RunWith
import org.junit.Test

// -----------------------------------------------------------------------------------------
// This class (ExampleInstrumentedTest) serves as the foundation for our Android
// instrumentation test suite. Its primary purpose is to validate the correct initialization
// of the application context, ensuring that core configurations (including the package
// name) align with designed expectations.
//
// This verification aims to contribute directly to the system uptime target of 99.9% by
// catching potential misconfigurations or initialization errors early in the development
// and deployment lifecycle. A properly initialized context reduces the risk of runtime
// crashes, thereby enhancing reliability and overall platform stability.
// -----------------------------------------------------------------------------------------

@RunWith(AndroidJUnit4::class)
class ExampleInstrumentedTest {

    // -------------------------------------------------------------------------------------
    // NAME: useAppContext
    // PURPOSE: Validates that the application context is properly initialized and contains
    // the exact package name "com.dogwalking.app". This guarantees that the app loads the
    // correct resources, classes, and metadata required for correct functionality.
    //
    // DECORATORS:
    //   - @Test indicates that this function is a test within the JUnit framework.
    //
    // EXECUTION STEPS:
    //   1. Use InstrumentationRegistry to get the instrumentation context object.
    //   2. Retrieve the target context from the instrumentation context to ensure it is
    //      pointing to the test target (the actual app under test).
    //   3. Extract the package name string from the target context.
    //   4. Use an assertion to confirm that the package name matches our expected
    //      "com.dogwalking.app".
    //   5. If the assertion passes, the test is successful, verifying that the correct
    //      package name (and therefore correct config) is loaded.
    //   6. If the assertion fails, the test will throw an AssertionError, indicating that
    //      the package name or environment is misconfigured.
    //
    // RETURN VALUE:
    //   - Unit (no explicit return). The test either passes (no thrown exception) or fails
    //     (an AssertionError is thrown and reported).
    // -------------------------------------------------------------------------------------
    @Test
    fun useAppContext() {
        // STEP 1: Acquire the instrumentation instance that gives access to the broader
        // test environment, including the context of the application under test.
        val instrumentation = InstrumentationRegistry.getInstrumentation()

        // STEP 2: From the instrumentation object, retrieve the target context, which
        // should be the fully initialized application context of our "dogwalking" app.
        val targetContext = instrumentation.targetContext

        // STEP 3: Extract the package name string from the retrieved context. This is
        // critical for ensuring that the app is running under the correct namespace.
        val actualPackageName = targetContext.packageName

        // STEP 4: Validate that the actual package name matches the expected
        // "com.dogwalking.app". If this fails, it indicates a fundamental mismatch in
        // configuration or environment.
        val expectedPackageName = "com.dogwalking.app"
        assertEquals("Package name mismatch - The application context is not properly initialized!",
            expectedPackageName, actualPackageName
        )
    }
}