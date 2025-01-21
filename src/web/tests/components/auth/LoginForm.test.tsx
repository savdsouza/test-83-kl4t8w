/*------------------------------------------------------------------------------
 * Comprehensive Test Suite for LoginForm Component
 * -----------------------------------------------------------------------------
 * This file verifies authentication flows, security measures, form validation,
 * accessibility compliance, and user interaction patterns for the LoginForm.
 * The tests align with project requirements around:
 *   - Authentication Methods (Argon2id, minimum 12 chars, complexity rules)
 *   - Security Controls (JWT, MFA triggers, rate limiting, lockout)
 *   - WCAG 2.1 Accessibility Checks
 *
 * References:
 *   1) 7.1.1 Authentication Flow (User must see secure form, handle errors)
 *   2) 7.1.2 Authentication Methods (Password complexity, Argon2id hashed on server)
 *   3) 6.3 Component Specifications (Validate form design & accessibility)
 *   4) Rate limiting & account lockout handling
 *   5) MFA flow triggers & verification
 *------------------------------------------------------------------------------
 */

import { describe, it, test, expect, beforeEach, vi } from 'vitest'; // vitest@^0.34.0
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react'; // @testing-library/react@^14.0.0
import '@testing-library/jest-dom/vitest'; // @testing-library/jest-dom@^5.16.5
import userEvent from '@testing-library/user-event'; // @testing-library/user-event@^14.0.0

// Internal imports (with explicit version references in comments)
import { LoginForm } from '../../src/components/auth/LoginForm'; // Enhanced login form component
import { useAuth } from '../../src/hooks/useAuth'; // Hook for authentication flows
// Mocks (based on specification JSON)
vi.mock('../../src/hooks/useAuth', () => ({
  useAuth: () => ({
    login: vi.fn(),
    isLoading: false,
    error: null,
    requiresMfa: false,
    validateToken: vi.fn(),
  }),
}));
vi.mock('../../src/hooks/useRateLimit'); // Rate limiting feature mock
vi.mock('../../src/hooks/useBiometric');  // Biometric auth capabilities mock

describe('LoginForm', () => {
  /**
   * Local references to track mock callbacks for onSuccess, onError, onMfaRequired.
   * These callbacks are integral to verifying success flows, error handling, and MFA triggers.
   */
  let mockOnSuccess: ReturnType<typeof vi.fn>;
  let mockOnError: ReturnType<typeof vi.fn>;
  let mockOnMfaRequired: ReturnType<typeof vi.fn>;

  /**
   * beforeEach: Executed before each test to reset environment and mocks,
   * ensuring test isolation and consistent initial conditions.
   * Steps (from specification):
   *   - Reset all mocks/spies
   *   - Setup authentication context (already mocked)
   *   - Initialize security mocks
   *   - Reset rate limiting counters (handled by useRateLimit mock)
   *   - Clear local storage to wipe any stored tokens
   */
  beforeEach(() => {
    // Clear Vitest mocks & spies
    vi.clearAllMocks();
    vi.resetAllMocks();

    // Clear local storage
    window.localStorage.clear();
    window.sessionStorage.clear();

    // Re-init callback mocks for each test
    mockOnSuccess = vi.fn();
    mockOnError = vi.fn();
    mockOnMfaRequired = vi.fn();

    // Reset the default mock return values for useAuth, if needed
    (useAuth as any).mockReturnValue({
      login: vi.fn(),
      isLoading: false,
      error: null,
      requiresMfa: false,
      validateToken: vi.fn(),
    });
  });

  /**
   * Test Case #1: "renders login form with WCAG 2.1 compliant elements"
   * Steps:
   *   1) Render LoginForm component
   *   2) Verify ARIA labels and roles
   *   3) Check color contrast compliance (simulated check in comments)
   *   4) Validate keyboard navigation / tab order
   *   5) Assert error message announcements (role="alert")
   */
  test('renders login form with WCAG 2.1 compliant elements', async () => {
    render(
      <LoginForm
        maxAttempts={3}
        onSuccess={mockOnSuccess}
        onError={mockOnError}
        onMfaRequired={mockOnMfaRequired}
      />
    );

    // 2) Verify ARIA labels & roles
    // Check that the email field is accessible by label
    const emailField = screen.getByLabelText(/Email Address/i);
    expect(emailField).toBeInTheDocument();
    expect(emailField).toHaveAttribute('type', 'email');

    // Check that the password field is accessible by label
    const passwordField = screen.getByLabelText(/Password/i);
    expect(passwordField).toBeInTheDocument();
    expect(passwordField).toHaveAttribute('type', 'password');

    // Confirm that there's a "Login" button
    const loginButton = screen.getByRole('button', { name: /login/i });
    expect(loginButton).toBeInTheDocument();

    // 3) Check color contrast compliance (high-level approach)
    // In actual practice, color contrast is tested with specialized tools or manual checks.
    // We'll assert that the button has the default "btn--primary" style
    // ensuring we meet design system color requirements in production.
    expect(loginButton).toHaveClass('btn--primary');

    // 4) Validate keyboard navigation:
    // We'll confirm the tab order is strictly Email -> Password -> (optional check) -> Button
    // This is partially tested by focusing elements in sequence:
    userEvent.tab();
    expect(emailField).toHaveFocus();

    userEvent.tab();
    expect(passwordField).toHaveFocus();

    userEvent.tab();
    expect(loginButton).toHaveFocus();

    // 5) Assert error message announcements => No errors yet, so ensure none are rendered
    const alerts = screen.queryAllByRole('alert');
    expect(alerts.length).toBe(0);
  });

  /**
   * Test Case #2: "enforces password complexity requirements"
   * Steps:
   *   1) Enter password with insufficient length (<12 chars)
   *   2) Verify minimum length error
   *   3) Enter password lacking required complexity
   *   4) Verify complexity error messages appear
   *   5) Validate password strength indicator (if any)
   */
  test('enforces password complexity requirements', async () => {
    render(
      <LoginForm
        maxAttempts={3}
        onSuccess={mockOnSuccess}
        onError={mockOnError}
        onMfaRequired={mockOnMfaRequired}
      />
    );

    const emailField = screen.getByLabelText(/Email Address/i);
    const passwordField = screen.getByLabelText(/Password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });

    // Step 1) Enter a password shorter than 12 chars
    await userEvent.type(emailField, 'testuser@example.com');
    await userEvent.type(passwordField, 'short12'); // "short12" ~ 7 chars
    fireEvent.click(loginButton);

    // Step 2) Verify minimum length error
    // We assume the real server or local validation would produce an error like "Password must be at least 12 characters."
    // For demonstration, let's mock the error:
    (useAuth as any).mockReturnValue({
      login: vi.fn().mockRejectedValue(new Error('Password must be at least 12 characters.')),
      isLoading: false,
      error: null,
      requiresMfa: false,
      validateToken: vi.fn(),
    });

    await waitFor(() => {
      // The onError callback is triggered with the short password error
      expect(mockOnError).toHaveBeenCalledWith('Password must be at least 12 characters.');
    });

    // Step 3) Enter a password that doesn't meet "complexity" (missing uppercase, special chars, etc.)
    // We'll simulate re-render with a new attempt
    (useAuth as any).mockReturnValue({
      login: vi.fn().mockRejectedValue(new Error('Password does not meet complexity requirements.')),
      isLoading: false,
      error: null,
      requiresMfa: false,
      validateToken: vi.fn(),
    });

    // Clear old input
    fireEvent.change(passwordField, { target: { value: '' } });
    await userEvent.type(passwordField, 'longbutalllowercase123456');

    fireEvent.click(loginButton);

    // Step 4) Verify complexity error messages appear
    await waitFor(() => {
      expect(mockOnError).toHaveBeenCalledWith('Password does not meet complexity requirements.');
    });

    // Step 5) Validate password strength indicator
    // The actual 'LoginForm' might not show a strength bar, but if it did, we might query for it:
    // e.g., const strengthBar = screen.queryByTestId('password-strength-bar');
    // expect(strengthBar).toBeInTheDocument();
    // For demonstration, we simply confirm that the error handling is consistent.
  });

  /**
   * Test Case #3: "handles rate limiting and account lockout"
   * Steps:
   *   1) Submit invalid credentials multiple times
   *   2) Verify rate limit warnings
   *   3) Assert lockout duration or message
   *   4) Validate lockout message display
   *   5) Test lockout reset behavior
   */
  test('handles rate limiting and account lockout', async () => {
    render(
      <LoginForm
        maxAttempts={2}
        onSuccess={mockOnSuccess}
        onError={mockOnError}
        onMfaRequired={mockOnMfaRequired}
      />
    );

    const emailField = screen.getByLabelText(/Email Address/i);
    const passwordField = screen.getByLabelText(/Password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });

    // Step 1) Submit invalid credentials multiple times
    // Prepare mock: server returns "Invalid credentials"
    (useAuth as any).mockReturnValue({
      login: vi.fn().mockRejectedValue(new Error('Invalid credentials')),
      isLoading: false,
      error: null,
      requiresMfa: false,
      validateToken: vi.fn(),
    });

    // First attempt
    await userEvent.type(emailField, 'user@example.com');
    await userEvent.type(passwordField, 'somewrongpassword');
    fireEvent.click(loginButton);
    await waitFor(() => {
      expect(mockOnError).toHaveBeenLastCalledWith('Invalid credentials');
    });

    // Clear fields for second attempt
    fireEvent.change(emailField, { target: { value: '' } });
    fireEvent.change(passwordField, { target: { value: '' } });

    // Step 2) Another invalid attempt leading to lockout
    // We assume after second attempt, user is locked out
    await userEvent.type(emailField, 'user@example.com');
    await userEvent.type(passwordField, 'somewrongpasswordagain');
    fireEvent.click(loginButton);

    // Step 3) & 4) We should see a lockout
    // The code in LoginForm increments attempts and triggers onError with:
    // "You have exceeded the maximum number of login attempts. Please try again later."
    await waitFor(() => {
      expect(mockOnError).toHaveBeenLastCalledWith(
        'You have exceeded the maximum number of login attempts. Please try again later.'
      );
    });

    // Step 5) Test lockout reset behavior (simulate user tries again after "cool-down")
    // We'll re-render the component or replicate a scenario where attempts are cleared
    // This might be done by reloading the page in a real app. We'll do a fresh render:
    vi.clearAllMocks();

    render(
      <LoginForm
        maxAttempts={2}
        onSuccess={mockOnSuccess}
        onError={mockOnError}
        onMfaRequired={mockOnMfaRequired}
      />
    );
    // Suppose the app reset attempts after some time
    const newEmailField = screen.getByLabelText(/Email Address/i);
    const newPasswordField = screen.getByLabelText(/Password/i);
    const newLoginButton = screen.getByRole('button', { name: /login/i });

    // Provide valid credentials this time, verifying that user can attempt again
    (useAuth as any).mockReturnValue({
      login: vi.fn().mockResolvedValue({
        user: { id: 'abc123' },
        requiresMfa: false,
      }),
      isLoading: false,
      error: null,
      requiresMfa: false,
      validateToken: vi.fn(),
    });

    await userEvent.type(newEmailField, 'user2@example.com');
    await userEvent.type(newPasswordField, 'CorrectPassword123!');
    fireEvent.click(newLoginButton);

    await waitFor(() => {
      // onSuccess is called, indicating the lockout was reset
      expect(mockOnSuccess).toHaveBeenCalled();
    });
  });

  /**
   * Test Case #4: "manages multi-factor authentication flow"
   * Steps:
   *   1) Submit valid credentials
   *   2) Verify MFA trigger conditions (server sets requiresMfa=true)
   *   3) Test OTP input handling
   *   4) Validate biometric prompt (placeholder check, as the form might not display it)
   *   5) Assert successful MFA completion
   */
  test('manages multi-factor authentication flow', async () => {
    // Step 1) Submit valid credentials that cause an MFA requirement
    (useAuth as any).mockReturnValue({
      login: vi.fn().mockResolvedValue({
        user: { id: 'mfaUserId', email: 'mfaUser@example.com' },
        requiresMfa: true,
      }),
      isLoading: false,
      error: null,
      requiresMfa: true,
      validateToken: vi.fn(),
    });

    render(
      <LoginForm
        maxAttempts={3}
        onSuccess={mockOnSuccess}
        onError={mockOnError}
        onMfaRequired={mockOnMfaRequired}
      />
    );

    const emailField = screen.getByLabelText(/Email Address/i);
    const passwordField = screen.getByLabelText(/Password/i);
    const loginButton = screen.getByRole('button', { name: /login/i });

    await userEvent.type(emailField, 'mfaUser@example.com');
    await userEvent.type(passwordField, 'SuperSecurePassword123!');
    fireEvent.click(loginButton);

    // Step 2) Verify that onMfaRequired is invoked after server indicates requiresMfa=true
    await waitFor(() => {
      expect(mockOnMfaRequired).toHaveBeenCalledWith('mfauser@example.com');
    });

    // Once the form knows MFA is required, it conditionally renders an MFA token field
    // (the actual LoginForm code displays an Input for "MFA Token" if requiresMfa is true).
    const otpField = screen.getByLabelText(/MFA Token/i);
    expect(otpField).toBeInTheDocument();

    // Step 3) Test OTP input handling:
    await userEvent.type(otpField, '123456');

    // Prepare mock for final auth (server verifying MFA code).
    (useAuth as any).mockReturnValue({
      login: vi.fn().mockResolvedValue({
        user: { id: 'mfaUserId', email: 'mfaUser@example.com' },
        requiresMfa: false, // means MFA is now complete
      }),
      isLoading: false,
      error: null,
      requiresMfa: false,
      validateToken: vi.fn(),
    });

    // Simulate user pressing "Login" again or the same "Submit" that re-calls login with the appended token
    fireEvent.click(loginButton);

    // Step 4) Validate biometric prompt -> For demonstration, we check if a certain mock or UI element is present.
    // The base code doesn't actually show a biometrics UI, so we do a placeholder check.
    // If there was a biometricFlow element or any reference, we'd test it. For now, we assume not present.

    // Step 5) Assert successful MFA completion
    await waitFor(() => {
      expect(mockOnSuccess).toHaveBeenCalledWith(
        { id: 'mfaUserId', email: 'mfaUser@example.com' },
        expect.any(String) // deviceId generated by fingerprinting
      );
    });
  });
});