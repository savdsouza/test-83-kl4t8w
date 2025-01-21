package com.dogwalking.app.viewmodel

// ---------------------------------------------------------------------------------
// External Imports with Version Comments
// ---------------------------------------------------------------------------------
import org.junit.jupiter.api.BeforeEach // org.junit.jupiter.api v5.9.0
import org.junit.jupiter.api.AfterEach // org.junit.jupiter.api v5.9.0
import org.junit.jupiter.api.Test // org.junit.jupiter.api v5.9.0
import org.junit.jupiter.api.Assertions.assertEquals // org.junit.jupiter.api v5.9.0
import org.junit.jupiter.api.Assertions.assertTrue // org.junit.jupiter.api v5.9.0
import org.junit.jupiter.api.Assertions.assertFalse // org.junit.jupiter.api v5.9.0
import org.junit.jupiter.api.Assertions.assertNull // org.junit.jupiter.api v5.9.0

import io.mockk.mockk // io.mockk v1.13.5
import io.mockk.clearAllMocks // io.mockk v1.13.5
import io.mockk.coEvery // io.mockk v1.13.5
import io.mockk.coVerify // io.mockk v1.13.5

import app.cash.turbine.test // app.cash.turbine v1.0.0

import org.jetbrains.kotlinx.coroutines.test.TestCoroutineDispatcher // org.jetbrains.kotlinx.coroutines.test v1.7.3
import org.jetbrains.kotlinx.coroutines.test.setMain // org.jetbrains.kotlinx.coroutines.test v1.7.3
import org.jetbrains.kotlinx.coroutines.test.resetMain // org.jetbrains.kotlinx.coroutines.test v1.7.3
import org.jetbrains.kotlinx.coroutines.test.runTest // org.jetbrains.kotlinx.coroutines.test v1.7.3
import org.jetbrains.kotlinx.coroutines.test.advanceUntilIdle // org.jetbrains.kotlinx.coroutines.test v1.7.3

// ---------------------------------------------------------------------------------
// Internal Imports
// ---------------------------------------------------------------------------------
import androidx.lifecycle.SavedStateHandle // androidx.lifecycle v2.6.2
import kotlinx.coroutines.Dispatchers // kotlinx.coroutines v1.7.3
import kotlinx.coroutines.flow.flowOf // kotlinx.coroutines.flow v1.7.3
import kotlinx.coroutines.flow.flow // kotlinx.coroutines.flow v1.7.3

import com.dogwalking.app.ui.dog.viewmodel.DogViewModel
import com.dogwalking.app.domain.usecases.DogUseCase
import com.dogwalking.app.domain.models.Dog

/**
 * [DogViewModelTest] provides a comprehensive unit test suite for [DogViewModel],
 * verifying pet profile management functionality, state handling, and error scenarios.
 * It tests:
 * - Owner dogs loading (success/error)
 * - Saving a dog (success)
 * - Deactivating a dog (success)
 * - Proper loading/error state flow transitions
 */
class DogViewModelTest {

    /**
     * A [TestCoroutineDispatcher] instance used to control and manipulate
     * coroutine scheduling in unit tests. This ensures deterministic behavior
     * of asynchronous code paths in [DogViewModel].
     */
    private lateinit var testDispatcher: TestCoroutineDispatcher

    /**
     * A mock of [DogUseCase] used to simulate data retrieval, saving, and deactivation
     * logic for unit testing. Powered by the MockK framework.
     */
    private lateinit var mockDogUseCase: DogUseCase

    /**
     * The [DogViewModel] instance under test, which uses [mockDogUseCase] for domain calls.
     */
    private lateinit var viewModel: DogViewModel

    /**
     * A sample [Dog] domain model used for testing retrieval, saving, and deactivation flows.
     */
    private lateinit var testDog: Dog

    /**
     * Sets up the unit test environment before each test. This includes:
     * 1. Initializing [TestCoroutineDispatcher].
     * 2. Setting the main dispatcher to [testDispatcher].
     * 3. Creating a mock instance of [DogUseCase].
     * 4. Constructing a sample [Dog] for test usage.
     * 5. Initializing the [DogViewModel] with a [SavedStateHandle] and the mock use case.
     */
    @BeforeEach
    fun setup() {
        testDispatcher = TestCoroutineDispatcher()
        Dispatchers.setMain(testDispatcher)

        // Create a relaxed mock for DogUseCase to avoid specifying default behaviors
        mockDogUseCase = mockk(relaxed = true)

        // Build a test Dog instance with valid default data
        testDog = Dog(
            id = "test-dog-id",
            ownerId = "owner-123",
            name = "Buddy",
            breed = "Beagle",
            birthDate = "2018-06-12",
            medicalInfo = mapOf("allergies" to "pollen"),
            active = true,
            profileImageUrl = null,
            weight = 10.0f,
            specialInstructions = listOf("No special instructions"),
            lastUpdated = System.currentTimeMillis()
        )

        // Initialize the ViewModel under test
        viewModel = DogViewModel(
            savedStateHandle = SavedStateHandle(),
            dogUseCase = mockDogUseCase
        )
    }

    /**
     * Cleans up the unit test environment after each test. This includes:
     * 1. Clearing all MockK mocks.
     * 2. Resetting the main dispatcher to its default.
     * 3. Cleaning up any lingering coroutines.
     */
    @AfterEach
    fun cleanup() {
        clearAllMocks()
        Dispatchers.resetMain()
        testDispatcher.cleanupTestCoroutines()
    }

    /**
     * Verifies successful loading of an owner's dogs. Specifically checks:
     * 1. Mocking a successful Flow emission from [DogUseCase.getOwnerDogs].
     * 2. Transitional loading state from false -> true -> false.
     * 3. [dogs] Flow updates from empty list to a list containing [testDog].
     * 4. [error] Flow remains null upon success.
     */
    @Test
    fun testLoadOwnerDogs_Success() = runTest {
        // Step 1: Mock a successful response with a single dog in the list
        coEvery {
            mockDogUseCase.getOwnerDogs(any(), any(), any(), any())
        } returns flowOf(Result.success(listOf(testDog)))

        // Collect and verify loading state transition
        viewModel.loading.test {
            // Initially false
            assertFalse(awaitItem())

            // Trigger load operation
            viewModel.loadOwnerDogs("owner-123")

            // Loading should become true
            assertTrue(awaitItem())

            // Eventually back to false
            assertFalse(awaitItem())
            cancel()
        }

        // Collect and verify dogs state flow
        viewModel.dogs.test {
            // The first emission is empty
            val initialList = awaitItem()
            assertTrue(initialList.isEmpty())

            // After loadOwnerDogs, we get a new emission with testDog
            val updatedList = awaitItem()
            assertEquals(1, updatedList.size)
            assertEquals(testDog.id, updatedList[0].id)
            cancel()
        }

        // Collect and verify error state
        viewModel.error.test {
            // Should remain null (no errors)
            val err1 = awaitItem()
            assertNull(err1)
            cancel()
        }

        // Verify the mock was called correctly
        coVerify(exactly = 1) {
            mockDogUseCase.getOwnerDogs("owner-123", 0, 50, null)
        }
    }

    /**
     * Verifies error handling when loading an owner's dogs fails. Specifically checks:
     * 1. Mocking a failure result from [DogUseCase.getOwnerDogs].
     * 2. [loading] transitions from false -> true -> false.
     * 3. [dogs] remains an empty list if an error occurs.
     * 4. [error] is updated with the provided error message.
     */
    @Test
    fun testLoadOwnerDogs_Error() = runTest {
        // Step 1: Mock an error response flow
        coEvery {
            mockDogUseCase.getOwnerDogs(any(), any(), any(), any())
        } returns flowOf(Result.failure(Exception("Load dogs error")))

        // Collect loading states
        viewModel.loading.test {
            // Initially false
            assertFalse(awaitItem())

            // Trigger load
            viewModel.loadOwnerDogs("owner-123")

            // Loading becomes true
            assertTrue(awaitItem())

            // Then false again
            assertFalse(awaitItem())
            cancel()
        }

        // Collect dogs list
        viewModel.dogs.test {
            // Initial
            assertTrue(awaitItem().isEmpty())

            // After error, remains empty
            assertTrue(awaitItem().isEmpty())
            cancel()
        }

        // Collect error flow
        viewModel.error.test {
            // Initially null
            assertNull(awaitItem())

            // Updated with error message
            val errMsg = awaitItem()
            assertEquals("Load dogs error", errMsg)
            cancel()
        }

        // Verify method was called once with correct params
        coVerify(exactly = 1) {
            mockDogUseCase.getOwnerDogs("owner-123", 0, 50, null)
        }
    }

    /**
     * Verifies successful saving of a dog's profile. Specifically checks:
     * 1. Mocking a successful [DogUseCase.saveDog] call.
     * 2. [loading] transitions during the save operation.
     * 3. [dogs] Flow is refreshed by calling loadOwnerDogs internally.
     * 4. [error] remains null if the save is successful.
     */
    @Test
    fun testSaveDog_Success() = runTest {
        // Arrange: Mock a successful saveDog result
        coEvery { mockDogUseCase.saveDog(testDog) } returns Result.success(true)

        // Also mock the reload of owner's dogs after saving
        coEvery {
            mockDogUseCase.getOwnerDogs("owner-123", 0, 50, null)
        } returns flowOf(Result.success(listOf(testDog)))

        // Collect loading states
        viewModel.loading.test {
            // Starts false
            assertFalse(awaitItem())

            // Act: Call saveDog on the ViewModel
            val saveResult = viewModel.saveDog(testDog)
            assertTrue(saveResult, "Expected saveDog to return true for success")

            // We should see the loading go true -> false
            assertTrue(awaitItem())
            assertFalse(awaitItem())
            cancel()
        }

        // Verify dogs is updated after the internal refresh
        viewModel.dogs.test {
            // Initially empty
            assertTrue(awaitItem().isEmpty())

            // After a successful save, the ViewModel calls loadOwnerDogs which should update dogs
            val updatedDogs = awaitItem()
            assertEquals(1, updatedDogs.size)
            assertEquals(testDog.id, updatedDogs[0].id)
            cancel()
        }

        // Verify no errors
        viewModel.error.test {
            // Should remain null
            assertNull(awaitItem())
            cancel()
        }

        // Ensure the appropriate use case methods were invoked
        coVerify(exactly = 1) { mockDogUseCase.saveDog(testDog) }
        coVerify(exactly = 1) { mockDogUseCase.getOwnerDogs("owner-123", 0, 50, null) }
    }

    /**
     * Verifies successful deactivation of a dog's profile. Specifically checks:
     * 1. Mocking a successful [DogUseCase.deactivateDog] call.
     * 2. [loading] transitions correctly.
     * 3. [dogs] is updated if the ViewModel triggers a reload (demonstration).
     *    In actual code, the current sample does not refresh automatically,
     *    but we manually test the scenario to confirm expected behavior.
     * 4. [error] remains null if deactivation succeeds.
     */
    @Test
    fun testDeactivateDog_Success() = runTest {
        // Step 1: Mock a successful deactivation
        coEvery {
            mockDogUseCase.deactivateDog("test-dog-id", "User initiated deactivation")
        } returns Result.success(true)

        // Also mock the subsequent read of dog's list. Suppose the dog is removed or updated as inactive.
        coEvery {
            mockDogUseCase.getOwnerDogs("owner-123", 0, 50, null)
        } returns flowOf(Result.success(emptyList()))

        // Observe loading
        viewModel.loading.test {
            // Initially false
            assertFalse(awaitItem())

            // Act: Deactivate
            val result = viewModel.deactivateDog("test-dog-id")
            assertTrue(result, "Expected deactivateDog to return true")

            // Should go true -> false
            assertTrue(awaitItem())
            assertFalse(awaitItem())
            cancel()
        }

        // For demonstration, call loadOwnerDogs after deactivation to confirm removal
        viewModel.loadOwnerDogs("owner-123")

        viewModel.dogs.test {
            // Emission #1: Possibly empty if we haven't loaded anything yet
            assertTrue(awaitItem().isEmpty())

            // Emission #2: The updated list with dog removed
            val updatedList = awaitItem()
            assertTrue(updatedList.isEmpty())
            cancel()
        }

        // Error flow remains null
        viewModel.error.test {
            assertNull(awaitItem())
            cancel()
        }

        // Verify correct calls
        coVerify(exactly = 1) {
            mockDogUseCase.deactivateDog("test-dog-id", "User initiated deactivation")
        }
    }
}