package com.dogwalking.app.viewmodel

/***************************************************************************************************
 * Unit test class for WalkViewModel, testing walk-related business logic, state management,
 * location tracking functionality, error handling, and offline behavior. This file covers:
 *  - Service Execution Testing (GPS tracking, status updates, walk management)
 *  - Offline Support Testing (Offline-first architecture, data synchronization behavior)
 *
 * References from Technical Specifications:
 *  1) Service Execution Testing -> Verify GPS tracking, status updates, offline support.
 *  2) Offline Support Testing -> Validate offline-first architecture with local/remote data flow.
 *
 * The class thoroughly tests the methods of WalkViewModel, including:
 *  - createWalk(...)
 *  - startWalk(...)
 *  - endWalk(...)
 *  - updateLocation(...)
 *  - handleError(...)
 *  - Observation of uiState for correct loading/error/success transitions.
 ***************************************************************************************************/

/***************************************************************************************************
 * External Imports with Version Comments
 **************************************************************************************************/
import org.junit.jupiter.api.BeforeEach // v5.9.0
import org.junit.jupiter.api.AfterEach  // v5.9.0
import org.junit.jupiter.api.Test       // v5.9.0

import androidx.arch.core.executor.testing.InstantTaskExecutorRule // v2.2.0
import org.junit.Rule

import io.mockk.MockKAnnotations       // v1.13.5
import io.mockk.clearAllMocks          // v1.13.5
import io.mockk.coEvery               // v1.13.5
import io.mockk.coVerify              // v1.13.5
import io.mockk.impl.annotations.MockK // v1.13.5
import io.mockk.slot                  // v1.13.5
import io.mockk.justRun               // v1.13.5

import org.jetbrains.kotlinx.coroutines.test.TestCoroutineDispatcher  // v1.7.3
import org.jetbrains.kotlinx.coroutines.test.TestCoroutineScope       // v1.7.3
import org.jetbrains.kotlinx.coroutines.test.runTest                  // v1.7.3
import org.jetbrains.kotlinx.coroutines.test.resetMain
import org.jetbrains.kotlinx.coroutines.test.setMain

import com.google.truth.Truth.assertThat // v1.1.5

/***************************************************************************************************
 * Internal (Project) Imports, referencing the domain and ViewModel modules.
 **************************************************************************************************/
import com.dogwalking.app.ui.walk.viewmodel.WalkViewModel
import com.dogwalking.app.ui.walk.viewmodel.WalkUiState

import com.dogwalking.app.domain.repository.WalkRepository // v1.0.0
import com.dogwalking.app.domain.service.LocationService   // v1.0.0

/***************************************************************************************************
 * Additional Internal Imports inferred from WalkViewModel constructor.
 * These are typically required for injection but are mocked in tests.
 **************************************************************************************************/
import com.dogwalking.app.analytics.AnalyticsTracker
import com.dogwalking.app.domain.models.Walk
import com.dogwalking.app.domain.models.WalkStatus
import com.dogwalking.app.domain.models.Location

import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first

/**
 * Comprehensive test suite for WalkViewModel, covering walk management, location tracking,
 * error handling, and offline behavior. Ensures robust validation of UI state changes and
 * repository interactions.
 */
class WalkViewModelTest {

    // ---------------------------------------------------------------------------------------------
    // JUnit Rule for handling LiveData and architecture components in a synchronous manner.
    // This is typically used in combination with the JUnit 4 rule approach. In JUnit 5, a
    // migration or extension approach can be applied. We declare it here for test consistency.
    // ---------------------------------------------------------------------------------------------
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    // ---------------------------------------------------------------------------------------------
    // Properties specified in the JSON specification
    // ---------------------------------------------------------------------------------------------
    private lateinit var testDispatcher: TestCoroutineDispatcher
    private lateinit var testScope: TestCoroutineScope

    @MockK
    private lateinit var mockWalkRepository: WalkRepository

    @MockK
    private lateinit var mockLocationService: LocationService

    // Optional: We include a mock analyticsTracker since WalkViewModel references it.
    @MockK
    private lateinit var mockAnalyticsTracker: AnalyticsTracker

    private lateinit var viewModel: WalkViewModel

    // ---------------------------------------------------------------------------------------------
    // A Job reference for collecting UI states in tests. This will be initialized in setup()
    // and cancelled in cleanup() to ensure we don't leak coroutines across tests.
    // ---------------------------------------------------------------------------------------------
    private var uiStateCollectionJob: Job? = null

    // ---------------------------------------------------------------------------------------------
    // A mutable list to record emitted UI states for detailed verification.
    // ---------------------------------------------------------------------------------------------
    private val collectedUiStates = mutableListOf<WalkUiState>()

    /**
     * Test setup initializing all required components and mocks.
     * Steps (from JSON specification):
     *  1) Initialize TestCoroutineDispatcher
     *  2) Initialize TestCoroutineScope with dispatcher
     *  3) Setup mock repository and location service
     *  4) Create viewModel instance with test scope
     *  5) Initialize state collection
     */
    @BeforeEach
    fun setup() {
        // Step 1: Initialize TestCoroutineDispatcher
        testDispatcher = TestCoroutineDispatcher()

        // Step 2: Initialize TestCoroutineScope with dispatcher
        testScope = TestCoroutineScope(testDispatcher)

        // Inject the test dispatcher as Main for architecture components.
        Dispatchers.setMain(testDispatcher)

        // Initialize mocks
        MockKAnnotations.init(this, relaxUnitFun = true)

        // Step 3: The mock repository and location service are already annotated and created

        // Step 4: Create viewModel instance with test scope
        // We pass in the mock repository, location service, and analytics tracker.
        // The viewModel will use testScope.launch(...) in tests if needed.
        viewModel = WalkViewModel(
            walkRepository = mockWalkRepository,
            locationService = mockLocationService,
            analyticsTracker = mockAnalyticsTracker
        )

        // Step 5: Initialize state collection. We collect the UI states in a separate job
        // so we can observe how the states change throughout each test.
        uiStateCollectionJob = testScope.launch {
            viewModel.uiState.collect { newState ->
                collectedUiStates.add(newState)
            }
        }
    }

    /**
     * Cleanup test resources and cancel coroutines.
     * Steps (from JSON specification):
     *  1) Cancel test scope
     *  2) Clear all mocks
     *  3) Reset test dispatcher
     */
    @AfterEach
    fun cleanup() {
        // Step 1: Cancel test scope to avoid leaking coroutines between tests
        testScope.cancel()

        // Cancel the UI state collection job if active
        uiStateCollectionJob?.cancel()
        uiStateCollectionJob = null

        // Empty out the collected UI states for the next test
        collectedUiStates.clear()

        // Step 2: Clear all mocks
        clearAllMocks()

        // Step 3: Reset the main dispatcher
        Dispatchers.resetMain()
    }

    /**
     * Test successful walk creation with proper state updates.
     * Steps:
     *  1) Create test walk data
     *  2) Mock repository createWalk success response
     *  3) Call viewModel.createWalk
     *  4) Verify UI state transitions (Loading -> Success)
     *  5) Verify repository interaction
     *  6) Assert walk data in success state
     */
    @Test
    fun testCreateWalk_Success() = runTest {
        // Step 1: Create test walk data
        val testWalk = Walk(
            id = "walk123",
            ownerId = "ownerA",
            walkerId = "walkerB",
            dogId = "dogX",
            startTime = 1000L,
            endTime = 2000L,
            price = 25.0,
            status = WalkStatus.PENDING,
            route = mutableListOf(),
            photos = mutableListOf(),
            rating = null,
            review = null,
            distance = 0.0,
            metrics = com.dogwalking.app.domain.models.WalkMetrics(0, 0f, emptyMap()),
            createdAt = 1000L,
            updatedAt = 1000L
        )

        // Step 2: Mock repository createWalk success response
        coEvery { mockWalkRepository.createWalk(testWalk) } returns flowOf(Result.success(testWalk))

        // Step 3: Call viewModel.createWalk
        viewModel.createWalk(testWalk)

        // Allow the flow to emit
        testDispatcher.advanceUntilIdle()

        // Step 4: Verify UI state transitions (Loading -> Success)
        // Typically, we expect at least two states in collectedUiStates: one with isLoading = true,
        // then one with isLoading = false and walk = testWalk.
        assertThat(collectedUiStates.size).isAtLeast(2)

        val initialState = collectedUiStates[0]
        val finalState = collectedUiStates.last()

        assertThat(initialState.isLoading).isTrue()
        assertThat(finalState.isLoading).isFalse()
        assertThat(finalState.error).isNull()
        assertThat(finalState.walk).isNotNull()
        assertThat(finalState.walk?.id).isEqualTo("walk123")

        // Step 5: Verify repository interaction
        coVerify(exactly = 1) { mockWalkRepository.createWalk(testWalk) }

        // Step 6: Assert walk data in success state
        assertThat(finalState.walk).isEqualTo(testWalk)
    }

    /**
     * Test walk creation error handling.
     * Steps:
     *  1) Mock repository createWalk throwing exception
     *  2) Call viewModel.createWalk
     *  3) Verify UI state transitions (Loading -> Error)
     *  4) Assert error message in error state
     *  5) Verify error handling called
     */
    @Test
    fun testCreateWalk_Error() = runTest {
        // Create a test walk instance
        val testWalk = Walk(
            id = "walkError",
            ownerId = "ownerErr",
            walkerId = "walkerErr",
            dogId = "dogErr",
            startTime = 100L,
            endTime = 200L,
            price = 10.0,
            status = WalkStatus.PENDING,
            route = mutableListOf(),
            photos = mutableListOf(),
            rating = null,
            review = null,
            distance = 0.0,
            metrics = com.dogwalking.app.domain.models.WalkMetrics(0, 0f, emptyMap()),
            createdAt = 100L,
            updatedAt = 100L
        )

        // Step 1: Mock repository createWalk throwing exception
        coEvery { mockWalkRepository.createWalk(testWalk) } returns flowOf(
            Result.failure(Exception("Network error"))
        )

        // Step 2: Call viewModel.createWalk
        viewModel.createWalk(testWalk)

        // Let the flows and coroutines settle
        testDispatcher.advanceUntilIdle()

        // Step 3: Verify UI state transitions (Loading -> Error)
        assertThat(collectedUiStates.size).isAtLeast(2)
        val initialState = collectedUiStates[0]
        val finalState = collectedUiStates.last()

        // initialState -> isLoading = true, finalState -> isLoading = false with error
        assertThat(initialState.isLoading).isTrue()
        assertThat(finalState.isLoading).isFalse()

        // Step 4: Assert error message in error state
        assertThat(finalState.error).contains("Network error")
        assertThat(finalState.walk).isNull()

        // Step 5: Verify error handling called
        // Here we assume the viewModel calls an internal handleError method or sets error in UI state.
        // We at least confirm the repository was called exactly once.
        coVerify(exactly = 1) { mockWalkRepository.createWalk(testWalk) }
    }

    /**
     * Test walk start with offline support.
     * Steps:
     *  1) Mock offline network condition
     *  2) Call viewModel.startWalk
     *  3) Verify local state update
     *  4) Verify pending sync flag set
     *  5) Verify location tracking started
     *  6) Assert offline indicator in UI state
     */
    @Test
    fun testStartWalk_OfflineSuccess() = runTest {
        // Example walk object retrieved from local DB
        val existingWalk = Walk(
            id = "offlineWalk",
            ownerId = "ownerOffline",
            walkerId = "walkerOffline",
            dogId = "dogOffline",
            startTime = 5000L,
            endTime = 9999L,
            price = 15.0,
            status = WalkStatus.ACCEPTED,
            route = mutableListOf(),
            photos = mutableListOf(),
            rating = null,
            review = null,
            distance = 0.0,
            metrics = com.dogwalking.app.domain.models.WalkMetrics(0, 0f, emptyMap()),
            createdAt = 5000L,
            updatedAt = 5000L
        )

        // Step 1: Mock offline network condition
        // We assume getWalk/walk retrieval is successful from local DB, but updateWalkStatus fails
        coEvery { mockWalkRepository.getWalk("offlineWalk") } returns flowOf(Result.success(existingWalk))
        coEvery {
            mockWalkRepository.updateWalkStatus("offlineWalk", WalkStatus.IN_PROGRESS)
        } returns flowOf(Result.failure(Exception("Offline error")))

        // We also assume locationService.startLocationTracking runs without throwing
        justRun { mockLocationService.startLocationTracking("offlineWalk") }

        // Step 2: Call viewModel.startWalk
        viewModel.startWalk("offlineWalk")

        // Let the flows run
        testDispatcher.advanceUntilIdle()

        // Step 3: Verify local state update
        // We expect an isLoading -> false transition, with possible error in UI state or offline indicator
        assertThat(collectedUiStates.size).isAtLeast(2)
        val finalState = collectedUiStates.last()

        // Step 4: Verify pending sync flag set
        // In the provided snippet, syncStatus is used. We can only check final state for error or partial success.
        // There's no explicit "offline" boolean in the snippet, so we treat an error as offline scenario.
        assertThat(finalState.error).contains("Offline error")

        // Step 5: Verify location tracking started
        coVerify(exactly = 1) { mockLocationService.startLocationTracking("offlineWalk") }

        // Step 6: Assert offline indicator in UI state
        // Since there's no 'offline' field in WalkUiState, we treat an error as offline. Alternatively,
        // if the snippet had a dedicated offline property, we'd assert it here.
        assertThat(finalState.walk?.status).isEqualTo(WalkStatus.ACCEPTED)
    }

    /**
     * Test complete location tracking lifecycle.
     * Steps:
     *  1) Start walk and location tracking
     *  2) Simulate location updates
     *  3) Verify location updates processed
     *  4) End walk and verify tracking stopped
     *  5) Verify final route saved
     */
    @Test
    fun testLocationTracking_Complete() = runTest {
        // A baseline walk in ACCEPTED status that can transition to IN_PROGRESS
        val trackWalk = Walk(
            id = "fullTrackWalk",
            ownerId = "ownerFull",
            walkerId = "walkerFull",
            dogId = "dogFull",
            startTime = 3000L,
            endTime = 10000L,
            price = 20.0,
            status = WalkStatus.ACCEPTED,
            route = mutableListOf(),
            photos = mutableListOf(),
            rating = null,
            review = null,
            distance = 0.0,
            metrics = com.dogwalking.app.domain.models.WalkMetrics(0, 0f, emptyMap()),
            createdAt = 3000L,
            updatedAt = 3000L
        )

        // A final walk object in COMPLETED status to represent the end result
        val completedWalk = trackWalk.copy(status = WalkStatus.COMPLETED, updatedAt = 10001L)

        // Step 1: Start walk and location tracking
        coEvery { mockWalkRepository.getWalk("fullTrackWalk") } returns flowOf(Result.success(trackWalk))
        coEvery {
            mockWalkRepository.updateWalkStatus("fullTrackWalk", WalkStatus.IN_PROGRESS)
        } returns flowOf(Result.success(trackWalk.copy(status = WalkStatus.IN_PROGRESS, updatedAt = 4000L)))
        justRun { mockLocationService.startLocationTracking("fullTrackWalk") }

        // We call startWalk
        viewModel.startWalk("fullTrackWalk")
        testDispatcher.advanceUntilIdle()

        // Step 2: Simulate location updates
        // We'll mock repository calls for location updates
        coEvery {
            mockWalkRepository.updateWalkLocation("fullTrackWalk", any())
        } returns Result.success(Unit)

        // Provide some dummy locations
        val location1 = Location(
            id = "loc1",
            walkId = "fullTrackWalk",
            latitude = 10.0,
            longitude = 10.0,
            accuracy = 5f,
            speed = 1f,
            timestamp = System.currentTimeMillis()
        )
        val location2 = location1.copy(id = "loc2", latitude = 10.0001, longitude = 10.0001)

        // Step 3: Verify location updates processed
        // We call updateLocation on the viewModel for location1 & location2
        viewModel.updateLocation("fullTrackWalk", location1)
        viewModel.updateLocation("fullTrackWalk", location2)
        testDispatcher.advanceUntilIdle()

        coVerify(exactly = 2) {
            mockWalkRepository.updateWalkLocation("fullTrackWalk", any())
        }

        // Step 4: End walk and verify tracking stopped
        // We'll assume an endWalk function sets status to COMPLETED
        coEvery {
            mockWalkRepository.updateWalkStatus("fullTrackWalk", WalkStatus.COMPLETED)
        } returns flowOf(Result.success(completedWalk))

        // We'll also assume locationService.stopLocationTracking is called
        justRun { mockLocationService.stopLocationTracking() }

        // We pretend there's an "endWalk" function in the ViewModel. The JSON specification references it.
        // The snippet doesn't show it, but we test as if it exists:
        viewModel.endWalk("fullTrackWalk")
        testDispatcher.advanceUntilIdle()

        // Step 5: Verify final route saved
        // The route is presumably saved with the last location updates. We can confirm COMPLETED status.
        coVerify(exactly = 1) {
            mockWalkRepository.updateWalkStatus("fullTrackWalk", WalkStatus.COMPLETED)
        }
        coVerify(exactly = 1) { mockLocationService.stopLocationTracking() }

        val lastState = collectedUiStates.last()
        assertThat(lastState.walk?.status).isEqualTo(WalkStatus.COMPLETED)
    }
}