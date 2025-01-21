package com.dogwalking.app

// ------------------------------------------------------------------------------------
// External Imports (JUnit 4.13.2)
// ------------------------------------------------------------------------------------
// We import the necessary JUnit classes to enable us to write and run unit tests
// for the Dog Walking application. Specifically, we import:
// - @Test annotation to mark test functions
// - Assert utilities for validation of tested logic
import org.junit.Test // JUnit 4.13.2
import org.junit.Assert // JUnit 4.13.2

/**
 * ExampleUnitTest
 *
 * This class demonstrates a basic JUnit-based unit test setup for the Dog Walking
 * mobile application. It reflects standard testing practices and ensures that
 * the testing framework is correctly integrated. Additionally, it addresses
 * the requirement for system testing setup by showing how code is tested at the
 * unit level within the Android environment.
 */
class ExampleUnitTest {

    /**
     * addition_isCorrect
     *
     * This test method demonstrates a simple assertion to validate that the JUnit test
     * environment is properly configured. By performing a basic arithmetic operation
     * (adding two integers) and verifying the result, the method confirms that tests can
     * run successfully and that the assertion mechanism is functional.
     *
     * Steps Involved (Detailed for clarity):
     *  1. Define the expected result of the operation (4).
     *  2. Perform the arithmetic addition of 2 + 2.
     *  3. Use the Assert class to verify that the calculated result matches the expected value.
     *  4. The test passes if the assertion is true; otherwise, it fails.
     */
    @Test
    fun addition_isCorrect() {
        // Step 1: Define the expected result
        val expectedResult = 4

        // Step 2: Perform the arithmetic addition of 2 + 2
        val actualResult = 2 + 2

        // Step 3: Assert that the actual result equals the expected result
        // This uses JUnit's assertEquals method, which throws an AssertionError
        // if the two values are not equal, causing the test to fail.
        Assert.assertEquals("The arithmetic operation did not yield the expected value.", expectedResult, actualResult)

        // Test passes if no assertion errors are thrown
    }
}