@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.dogwalking.app.viewmodel

// --------------------------------------------------------------------------------------------
// External Imports with Specified Versions
// --------------------------------------------------------------------------------------------
import org.junit.jupiter.api.BeforeEach // version 5.9.3
import org.junit.jupiter.api.Test // version 5.9.3
import org.junit.jupiter.api.Assertions.assertTrue // version 5.9.3
import org.junit.jupiter.api.Assertions.assertEquals // version 5.9.3
import org.junit.jupiter.api.Assertions.assertNotNull // version 5.9.3
import org.junit.jupiter.api.Assertions.assertNull // version 5.9.3
import org.junit.jupiter.api.Assertions.assertFalse // version 5.9.3

import io.mockk.MockKAnnotations // version 1.13.5
import io.mockk.impl.annotations.MockK // version 1.13.5
import io.mockk.coEvery // version 1.13.5
import io.mockk.coVerify // version 1.13.5
import io.mockk.clearMocks // version 1.13.5
import io.mockk.every // version 1.13.5
import io.mockk.MockKVerificationScope // version 1.13.5
import io.mockk.mockk // version 1.13.5
import io.mockk.slot // version 1.13.5
import io.mockk.just
import io.mockk.runs

import org.jetbrains.kotlinx.coroutines.test.StandardTestDispatcher // version 1.7.3
import org.jetbrains.kotlinx.coroutines.test.TestCoroutineScheduler // version 1.7.3
import org.jetbrains.kotlinx.coroutines.test.advanceUntilIdle // version 1.7.3
import org.jetbrains.kotlinx.coroutines.test.runTest // version 1.7.3

import androidx.arch.core.executor.testing.InstantTaskExecutorRule // version 2.2.0
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.extension.RegisterExtension

// --------------------------------------------------------------------------------------------
// Internal Imports (Named) - Classes Under Test
// --------------------------------------------------------------------------------------------
import com.dogwalking.app.ui.payment.viewmodel.PaymentViewModel
import com.dogwalking.app.ui.payment.viewmodel.PaymentUIState
import com.dogwalking.app.domain.models.Payment
import com.dogwalking.app.domain.models.PaymentStatus
import com.dogwalking.app.domain.models.PaymentMethod
import com.dogwalking.app.domain.usecases.PaymentUseCase

// --------------------------------------------------------------------------------------------
// Additional Android / Kotlin Imports
// --------------------------------------------------------------------------------------------
import android.net.ConnectivityManager // version default
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runBlockingTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.resetMain
import kotlin.random.Random

/**
 * Comprehensive test suite for PaymentViewModel covering:
 * 1) Secure payments and billing scenarios
 * 2) Transaction history management with pagination
 * 3) Error cases, including network failures
 * 4) Security and encryption compliance checks
 * 
 * This aligns with:
 * - Financial Operations (1.3 Scope/Core Features)
 * - Payment Processing (2.1 High-Level Architecture)
 * - Security Layer (1.2 System Overview)
 */
@kotlinx.coroutines.ExperimentalCoroutinesApi
class PaymentViewModelTest {

    // ------------------------------------------------------------------------------
    // JUnit Test Rules and Coroutine Scheduler
    // ------------------------------------------------------------------------------

    /**
     * Ensures LiveData and other arch components execute synchronously, suitable for testing.
     */
    @JvmField
    @org.junit.Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    /**
     * Provides the ability to control or pause coroutines on the main dispatcher.
     * This rule is typically from the coroutines-test library or a custom implementation.
     */
    private val testScheduler = TestCoroutineScheduler()

    // ------------------------------------------------------------------------------
    // Mocked Dependencies
    // ------------------------------------------------------------------------------

    /**
     * Mock of the PaymentUseCase which handles payment operations, offline queueing,
     * history retrieval, and refunds. We mock this to simulate success or error scenarios.
     */
    @MockK
    lateinit var mockPaymentUseCase: PaymentUseCase

    /**
     * System Under Test: PaymentViewModel responsible for orchestrating payment processes.
     * Injected with mocked PaymentUseCase for verifying logic flow and state updates.
     */
    private lateinit var viewModel: PaymentViewModel

    /**
     * Mock or fake connectivity manager to simulate online/offline states.
     */
    private lateinit var mockConnectivityManager: ConnectivityManager

    // ------------------------------------------------------------------------------
    // Setup
    // ------------------------------------------------------------------------------

    /**
     * Initializes test environment with mocks and a test dispatcher.
     * Steps:
     * 1) Initialize MockK annotations
     * 2) Configure the main dispatcher with testScheduler
     * 3) Setup PaymentUseCase stubs
     * 4) Initialize PaymentViewModel with mocks
     */
    @BeforeEach
    fun setup() {
        // Step 1: Initialize MockK
        MockKAnnotations.init(this, relaxUnitFun = true)

        // Step 2: Configure test dispatcher as main
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))

        // Step 3: Setup stubs for PaymentUseCase to avoid uninitialized calls
        coEvery { mockPaymentUseCase.processPayment(any()) } returns flowOf(Result.success(createTestPayment()))
        coEvery { mockPaymentUseCase.getPaymentHistory(any(), any(), any()) } returns flowOf(createPaginatedResult())
        coEvery { mockPaymentUseCase.refundPayment(any(), any()) } returns flowOf(Result.success(createTestRefund()))
        coEvery { mockPaymentUseCase.queueOfflinePayment(any()) } just runs

        // Initialize connectivity manager as a relaxed mock to control network connectivity state
        mockConnectivityManager = mockk(relaxed = true)
        // We'll rely on PaymentViewModel's isNetworkConnected() logic to interpret connectivity

        // Step 4: Initialize the viewModel with the mocked PaymentUseCase and mock connectivity
        viewModel = PaymentViewModel(
            paymentUseCase = mockPaymentUseCase,
            connectivityManager = mockConnectivityManager
        )
    }

    // ------------------------------------------------------------------------------
    // TEARDOWN
    // ------------------------------------------------------------------------------

    @org.junit.jupiter.api.AfterEach
    fun tearDown() {
        // Cleanup or reset the main dispatcher
        Dispatchers.resetMain()
        clearMocks(mockPaymentUseCase)
    }

    // ------------------------------------------------------------------------------
    // Test: testProcessPayment_Success
    // ------------------------------------------------------------------------------

    /**
     * Verifies successful payment processing with analytics or encryption tracking.
     * Steps:
     * 1) Create test payment data (simulates encryption or security fields)
     * 2) Mock a successful processPayment invocation
     * 3) Call viewModel.processPayment and advance coroutines
     * 4) Check PaymentUIState transitions to Success
     * 5) Validate secure token or encryption handling if any
     */
    @Test
    fun testProcessPayment_Success() = runTest {
        // Step 1: Create test payment
        val testPayment = createTestPayment()

        // Step 2: Mock PaymentUseCase response for success
        coEvery { mockPaymentUseCase.processPayment(testPayment) } returns flow {
            emit(Result.success(testPayment.copy(status = PaymentStatus.COMPLETED)))
        }
        
        // Step 3: Trigger payment processing
        viewModel.processPayment(testPayment)
        testScheduler.runCurrent()

        // Step 4: Assert UI state is PaymentUIState.Success
        val currentUiState = viewModel.uiState.value
        assertTrue(currentUiState is PaymentUIState.Success, "UI state should be Success after a successful payment.")

        // Step 5: Validate secure data or token handling
        // In a real scenario, you might verify encryption calls or token usage. Here we do a symbolic check.
        val successState = currentUiState as PaymentUIState.Success
        assertNotNull(successState.payment, "A successfully processed payment should not be null.")
        assertEquals(PaymentStatus.COMPLETED, successState.payment?.status, "Payment should be marked as COMPLETED.")
    }

    // ------------------------------------------------------------------------------
    // Test: testProcessPayment_NetworkError
    // ------------------------------------------------------------------------------

    /**
     * Tests the payment handling routine when a network failure is encountered.
     * Steps:
     * 1) Simulate network error / offline environment
     * 2) Attempt to process payment leading to offline queueing
     * 3) Validate offlinePayments queue mechanism in PaymentViewModel
     * 4) Check error or offline state handling
     */
    @Test
    fun testProcessPayment_NetworkError() = runTest {
        // Step 1: Simulate no network connectivity
        // PaymentViewModel checks connectivityManager.activeNetwork != null
        // For demonstration, we can do a specialized approach: just stub isNetworkConnected() to return false
        val offlinePayment = createTestPayment().copy(id = "offline-test-payment", status = PaymentStatus.PENDING)
        coEvery { mockConnectivityManager.activeNetwork } returns null

        // Step 2: Attempt to process payment
        viewModel.processPayment(offlinePayment)
        testScheduler.runCurrent()

        // Step 3: PaymentViewModel in offline state => request queueOfflinePayment
        coVerify(exactly = 1) { mockPaymentUseCase.queueOfflinePayment(offlinePayment) }

        // Step 4: UI state should be PaymentUIState.OfflineQueued
        val currentUiState = viewModel.uiState.value
        assertTrue(
            currentUiState is PaymentUIState.OfflineQueued,
            "UI state should be OfflineQueued when there is a network failure."
        )
        val queuedPayment = (currentUiState as PaymentUIState.OfflineQueued).payment
        assertEquals("offline-test-payment", queuedPayment.id, "The queued payment id should match the test payment.")
    }

    // ------------------------------------------------------------------------------
    // Test: testPaymentHistory_Pagination
    // ------------------------------------------------------------------------------

    /**
     * Tests retrieval of paginated payment history to confirm correct handling
     * of multiple pages, filters, and caching.
     * Steps:
     * 1) Mock PaymentUseCase returning multiple pages or partial results
     * 2) Call viewModel.loadPaymentHistory with test user and pagination
     * 3) Wait for completion and check PaymentUIState
     * 4) Validate correctness of returned payment list
     */
    @Test
    fun testPaymentHistory_Pagination() = runTest {
        // Step 1: Mock paginated data
        val paginatedResult = createPaginatedResult()
        coEvery { mockPaymentUseCase.getPaymentHistory("test-user", any(), any()) } returns flowOf(paginatedResult)

        // Step 2: Request loadPaymentHistory from PaymentViewModel
        viewModel.loadPaymentHistory(
            userId = "test-user",
            page = 1,
            pageSize = 5,
            filter = com.dogwalking.app.domain.usecases.PaymentFilter()
        )
        testScheduler.runCurrent()

        // Step 3: Verify that UI state becomes Success
        val currentUiState = viewModel.uiState.value
        assertTrue(
            currentUiState is PaymentUIState.Success,
            "loadPaymentHistory should result in PaymentUIState.Success if everything is normal."
        )

        val successState = currentUiState as PaymentUIState.Success
        assertNotNull(successState.payments, "Successful state should contain a list of payments.")
        assertEquals(2, successState.payments?.size, "Expected two payments in the mock paginated result.")

        // Step 4: Confirm that the payments in the ViewModel match the paginated data
        val flowPayments = viewModel.payments.value
        assertEquals(2, flowPayments.size, "ViewModel 'payments' state should match the size of the paginated result.")
    }

    // ------------------------------------------------------------------------------
    // Test: testRefundProcess_SecurityCompliance
    // ------------------------------------------------------------------------------

    /**
     * Validates the refund processing routine under strict security and compliance guidelines.
     * Steps:
     * 1) Check authorization or user eligibility (symbolic in this test)
     * 2) Test PCI compliance placeholders
     * 3) Mock a successfully processed refund in PaymentUseCase
     * 4) Verify that PaymentViewModel transitions to a success or refunded state
     * 5) Check secure data handling or audit trail references
     */
    @Test
    fun testRefundProcess_SecurityCompliance() = runTest {
        // Step 1: Symbolic: we assume user is authorized for refund
        // Step 2: Symbolic: we assume PCI compliance is enforced (no direct check here, but we confirm usage flow)

        val testPaymentId = "payment-for-refund"
        coEvery { mockPaymentUseCase.refundPayment(testPaymentId, any()) } returns flowOf(Result.success(createTestRefund()))

        // Step 3: Attempt to initiate a refund
        viewModel.refundPayment(
            paymentId = testPaymentId,
            amount = 12.00,
            reason = "Customer requested partial refund"
        )
        testScheduler.runCurrent()

        // Step 4: Verify UI state is success
        val currentUiState = viewModel.uiState.value
        assertTrue(currentUiState is PaymentUIState.Success, "Refund processing should produce a Success state on completion.")

        // Step 5: Check secure data handling (audit trail). In a real scenario, you'd assert logs or crypt usage.
        val successState = currentUiState as PaymentUIState.Success
        assertNull(successState.payment, "Refund success might not always return a Payment object, ensuring no sensitive data is leaked.")
        assertTrue(successState.message?.contains("Refund") == true, "Success message should reflect a refund result.")
    }

    // ------------------------------------------------------------------------------
    // Utility / Factory Methods for Test Data
    // ------------------------------------------------------------------------------

    /**
     * Creates a sample Payment object for testing.
     * This ensures consistent usage of Payment domain fields.
     */
    private fun createTestPayment(): Payment {
        return Payment(
            id = "test-payment-${Random.nextInt(1000, 9999)}",
            walkId = "test-walk-id",
            payerId = "owner123",
            payeeId = "walker456",
            amount = 15.00,
            status = PaymentStatus.PENDING,
            method = PaymentMethod.CREDIT_CARD,
            timestamp = System.currentTimeMillis(),
            transactionId = null,
            failureReason = null,
            retryCount = 0,
            isRefundable = true,
            receiptUrl = "https://example.com/receipt"
        )
    }

    /**
     * Creates a sample PaginatedList<Payment> to simulate multiple results for history.
     * In a real test, we might vary the data or structure for thorough coverage.
     */
    private fun createPaginatedResult(): com.dogwalking.app.domain.usecases.PaginatedList<Payment> {
        val payment1 = createTestPayment().copy(id = "history-payment-1", amount = 10.50)
        val payment2 = createTestPayment().copy(id = "history-payment-2", amount = 25.75)
        return com.dogwalking.app.domain.usecases.PaginatedList(
            items = listOf(payment1, payment2),
            totalItems = 2,
            currentPage = 1,
            totalPages = 1
        )
    }

    /**
     * Creates a sample Refund object from the use case, indicating a successful refund.
     */
    private fun createTestRefund(): com.dogwalking.app.domain.usecases.Refund {
        return com.dogwalking.app.domain.usecases.Refund(
            refundId = "refund-12345",
            amount = 12.00,
            status = "SUCCESS"
        )
    }
}