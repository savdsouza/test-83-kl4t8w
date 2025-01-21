/* eslint-disable @typescript-eslint/no-unused-vars */
/*************************************************************************************************
 * Extensive test suite for the useAuth custom hook.
 * -----------------------------------------------------------------------------------------------
 * This file rigorously verifies authentication functionality including:
 *   1) Hook usage within the AuthProvider context and behavior without a provider.
 *   2) Email/Password login, registration flows, social authentication, and biometric auth.
 *   3) MFA setup/verification, token refresh logic, concurrent session management, and error states.
 *   4) Edge cases covering network failures, invalid credentials, and token validation errors.
 *
 * References:
 *   - 7. SECURITY CONSIDERATIONS/7.3.5 (Security Testing)
 *   - 7. SECURITY CONSIDERATIONS/7.1.2 (Authentication Methods - email/password, social, biometric, MFA)
 *
 * All relevant mock objects (mockAuthService, mockLocalStorage, mockBiometricAuth, mockUser, mockTokens)
 * are declared to simulate real-world usage. We target 100% coverage on statements, branches, functions, lines.
 *************************************************************************************************/

import { renderHook, act } from '@testing-library/react-hooks'; // ^8.0.1
import { waitFor } from '@testing-library/react';               // ^13.4.0
import { describe, it, expect, beforeEach, jest } from '@jest/globals'; // ^29.5.0

/*************************************************************************************************
 * Internal Imports Under Test
 *************************************************************************************************/
import { useAuth as useAuthHook } from '../../src/hooks/useAuth';
import { AuthProvider } from '../../src/contexts/AuthContext';
import type { User, AuthResponse } from '../../src/types/auth.types';

/*************************************************************************************************
 * Mocks & Global Setup
 * -----------------------------------------------------------------------------------------------
 * We define a set of mock objects and variables to simulate various authentication flows and states.
 *************************************************************************************************/

/**
 * mockUser simulates a standard user object that might be returned by the server upon successful auth.
 * We ensure the shape matches the user structure from the system’s domain model.
 */
const mockUser: User = {
  id: 'user-123',
  email: 'testuser@example.com',
  role: 'OWNER',
  firstName: 'Test',
  lastName: 'User',
  phone: '+1234567890',
  isVerified: true,
  mfaEnabled: false,
  verificationStatus: 'VERIFIED',
  lastLogin: new Date().toISOString(),
  securityFlags: {
    accountLocked: false,
    passwordResetRequired: false,
    flaggedForReview: false,
  },
};

/**
 * mockTokens represents mocked authentication tokens returned by the server,
 * including an access token, refresh token, and standard fields for session tracking.
 */
const mockTokens: AuthResponse = {
  accessToken: 'mock-access-token-xyz',
  refreshToken: 'mock-refresh-token-abc',
  user: mockUser,
  requiresMfa: false,
  tokenExpiry: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
  sessionId: 'session-123',
};

/**
 * mockAuthService-oriented methods can be used if we wanted to replace internal calls.
 * For more direct transformations, we rely on the internal AuthProvider methods. If needed,
 * we'd patch them like: jest.spyOn(context, 'login') etc. However, here we lean on direct test usage.
 */

/**
 * mockLocalStorage ensures localStorage-related operations do not persist across tests,
 * and that we can simulate token and device-fingerprint behaviors as needed.
 */
const mockLocalStorage: Record<string, string> = {};

Object.defineProperty(window, 'localStorage', {
  value: {
    getItem: (key: string) => mockLocalStorage[key] || null,
    setItem: (key: string, value: string) => {
      mockLocalStorage[key] = value;
    },
    removeItem: (key: string) => {
      delete mockLocalStorage[key];
    },
    clear: () => {
      for (const k in mockLocalStorage) {
        delete mockLocalStorage[k];
      }
    },
  },
  writable: true,
});

/**
 * mockBiometricAuth simulates a successful or failed biometric flow.
 * We can manipulate the resolved or rejected Promise in different tests.
 */
const mockBiometricAuth = jest.fn().mockResolvedValue({
  success: true,
  message: 'Biometric authentication success',
});

/*************************************************************************************************
 * Test Wrapper
 * -----------------------------------------------------------------------------------------------
 * We define a custom wrapper that ensures the <AuthProvider> is present, so our hook can function.
 * This includes any additional props or config as needed. We then pass this wrapper into renderHook.
 *************************************************************************************************/
function createAuthWrapper() {
  return ({ children }: { children: React.ReactNode }) => (
    <AuthProvider>{children}</AuthProvider>
  );
}

/*************************************************************************************************
 * useAuth Test Suite
 * -----------------------------------------------------------------------------------------------
 * The root describe block for thoroughly testing all aspects of the useAuth custom hook.
 *************************************************************************************************/
describe('useAuth', () => {
  /*************************************************************************************************
   * Global Before Each
   * -----------------------------------------------------------------------------------------------
   * Ensures each test starts with fresh mocks, localStorage, and environment setups.
   *************************************************************************************************/
  beforeEach(() => {
    // Clear all mock calls and localStorage
    jest.clearAllMocks();
    window.localStorage.clear();

    // Pre-populate localStorage or sessionStorage if needed
    // e.g., storing a mock token or device ID
    sessionStorage.removeItem('authToken');
  });

  /*************************************************************************************************
   * Provider Integration Tests
   * -----------------------------------------------------------------------------------------------
   * Verifies correct usage of the hook with and without an AuthProvider. We also confirm context
   * updates and error handling within the provider environment.
   *************************************************************************************************/
  describe('Provider Integration', () => {
    it('should throw an error if useAuth is used without AuthProvider', () => {
      // We expect an error since we are not wrapping in AuthProvider
      const { result } = renderHook(() => useAuthHook());
      expect(result.error).toBeDefined();
      expect(result.error?.message).toMatch(/useAuth must be used within an AuthProvider/i);
    });

    it('should properly initialize with default AuthProvider', () => {
      // Render within the provider
      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });
      // We check default states from the context
      expect(result.current.isAuthenticated).toBe(false);
      expect(result.current.currentUser).toBeNull();
      expect(result.current.error).toBeNull();
      expect(result.current.sessionInfo.sessionId).toBe('');
    });

    it('should handle context-based error states from login attempts', async () => {
      // We'll simulate a failing login call within the context's login method
      const errorMessage = 'Server login error';
      jest
        .spyOn(window, 'fetch')
        .mockRejectedValueOnce(new Error(errorMessage));

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Attempt a login which triggers an error
      await expect(
        result.current.login({
          email: 'testuser@example.com',
          password: 'wrongPassword',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-123',
        })
      ).rejects.toThrowError(errorMessage);

      // The local error object in the hook should now reflect the login failure
      expect(result.current.error).not.toBeNull();
      expect(result.current.error?.code).toEqual('LOGIN_ERROR');
    });
  });

  /*************************************************************************************************
   * Authentication Methods
   * -----------------------------------------------------------------------------------------------
   * Covers email/password login, social authentication, biometric flows, and MFA-based flows.
   *************************************************************************************************/
  describe('Authentication Methods', () => {
    it('should allow login with email and password', async () => {
      // Mock a successful fetch or AuthService response
      jest
        .spyOn(window, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: mockTokens,
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response);

      // Render within AuthProvider
      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Perform login
      await act(async () => {
        const authResp = await result.current.login({
          email: 'testuser@example.com',
          password: 'validPassword',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-abc',
        });
        // Validate the returned structure
        expect(authResp.accessToken).toEqual(mockTokens.accessToken);
        expect(authResp.user.email).toEqual(mockUser.email);
      });

      // Once logged in, the hook should reflect authenticated state
      expect(result.current.isAuthenticated).toBe(true);
      expect(result.current.currentUser).not.toBeNull();
      expect(result.current.currentUser?.email).toBe(mockUser.email);

      // Also ensure no local error is present
      expect(result.current.error).toBeNull();
    });

    it('should allow social authentication (e.g., Google)', async () => {
      // Mock underlying socialLogin behavior
      jest
        .spyOn(window, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: {
              ...mockTokens,
              user: { ...mockUser, email: '' }, // some social logins might not return email
            },
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Attempt a social auth
      await act(async () => {
        const response = await result.current.socialAuth('GOOGLE');
        // We check the partial user structure returned
        expect(response.user.id).toBe(mockUser.id);
      });

      expect(result.current.isAuthenticated).toBe(true);
      // Email might be missing from social response, but user is still valid
      expect(result.current.error).toBeNull();
    });

    it('should handle biometric authentication flow successfully', async () => {
      // For demonstration, let's just mock the entire flow as a success
      // The context's `biometricAuth` might return the standard tokens
      jest
        .spyOn(window, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: mockTokens,
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Attempt to set up or call biometric flow
      // The context method is more direct for useAuth: setupBiometric is tested or we can do socialAuth('BIOMETRIC'). 
      // Here we follow the hook's method "setupBiometric".
      let biometricResp;
      await act(async () => {
        biometricResp = await result.current.setupBiometric();
      });
      expect(biometricResp).toEqual({
        success: true,
        message: 'Biometric setup complete.',
      });
    });

    it('should enable MFA and verify an MFA token', async () => {
      // Mock out the calls for setupMfa and verifyMfa
      const mfaSetupResponse = {
        qrCode: 'data:image/png;base64,iVBORfakeqrcode=',
        secret: 'XYZabc123',
        backupCodes: ['backup1', 'backup2'],
        setupToken: 'setup-xyz',
      };
      jest
        .spyOn(window, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: mfaSetupResponse,
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response);

      // Next fetch for verifying the MFA
      jest
        .spyOn(window, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: { verified: true },
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Setup MFA
      let setupData;
      await act(async () => {
        setupData = await result.current.setupMfa('TOTP');
      });
      expect(setupData).toEqual(mfaSetupResponse);

      // Verify MFA
      const token = '123456';
      let verifyResp;
      await act(async () => {
        verifyResp = await result.current.verifyMfa(token);
      });
      expect(verifyResp.success).toBe(true);
      expect(verifyResp.message).toMatch(/MFA verified./i);
    });
  });

  /*************************************************************************************************
   * Session Management
   * -----------------------------------------------------------------------------------------------
   * Focuses on token refresh, session timeouts, and concurrency handling across sessions.
   *************************************************************************************************/
  describe('Session Management', () => {
    it('should refresh session tokens successfully when nearing expiration', async () => {
      // We simulate a scenario where session is close to expiry
      // Then upon calling refreshSession, we get new tokens
      jest
        .spyOn(window, 'fetch')
        .mockImplementationOnce(async (input) => {
          // Return a valid login response to simulate existing session
          return {
            ok: true,
            json: async () => ({
              success: true,
              data: mockTokens,
              error: null,
              metadata: {},
              timestamp: Date.now(),
            }),
          } as unknown as Response;
        })
        .mockImplementationOnce(async (input) => {
          // Return a "refreshed" token
          return {
            ok: true,
            json: async () => ({
              success: true,
              data: {
                ...mockTokens,
                accessToken: 'newer-access-token',
                sessionId: 'session-456',
              },
              error: null,
              metadata: {},
              timestamp: Date.now(),
            }),
          } as unknown as Response;
        });

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // First, do a normal login
      await act(async () => {
        await result.current.login({
          email: 'testuser@example.com',
          password: 'somePassword',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-xyz',
        });
      });
      expect(result.current.isAuthenticated).toBe(true);

      // Then refresh the session
      await act(async () => {
        await result.current.refreshSession();
      });

      // We don't have a direct property that stores the newly updated token in the hook,
      // but we can confirm no error occurred. If the session refresh fails, an error would be thrown.
      expect(result.current.error).toBeNull();
    });

    it('should handle session timeout by invalidating session state', async () => {
      // We'll simulate a scenario: user logs in, token is expired upon validation
      jest.spyOn(Date, 'now').mockReturnValueOnce(Date.now() - 7200000); // Force an older time
      sessionStorage.setItem('authToken', 'expiredTokenXYZ');

      // Render the hook
      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Check if the session is valid (should return false due to forced expire)
      let isValid = true;
      await act(async () => {
        isValid = await result.current.validateSession();
      });
      expect(isValid).toBe(false);
      expect(result.current.isAuthenticated).toBe(false);
    });

    it('should handle concurrent session management if multiple logins occur', async () => {
      // We simply test that a second login overwrites existing user session
      const firstLoginTokens = { ...mockTokens, sessionId: 'session-first' };
      const secondLoginTokens = { ...mockTokens, sessionId: 'session-second' };

      jest
        .spyOn(window, 'fetch')
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: firstLoginTokens,
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response)
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            success: true,
            data: secondLoginTokens,
            error: null,
            metadata: {},
            timestamp: Date.now(),
          }),
        } as unknown as Response);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Login #1
      await act(async () => {
        await result.current.login({
          email: 'testuser1@example.com',
          password: 'pass1',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-1',
        });
      });
      expect(result.current.sessionInfo.sessionId).toBe('session-first');

      // Login #2
      await act(async () => {
        await result.current.login({
          email: 'testuser2@example.com',
          password: 'pass2',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-2',
        });
      });
      // Session should reflect the second login
      expect(result.current.sessionInfo.sessionId).toBe('session-second');
      expect(result.current.isAuthenticated).toBe(true);
    });
  });

  /*************************************************************************************************
   * Error Handling
   * -----------------------------------------------------------------------------------------------
   * Validates reaction to network failures, invalid credentials, token errors, and MFA verification issues.
   *************************************************************************************************/
  describe('Error Handling', () => {
    it('should handle network failures gracefully', async () => {
      const networkError = new Error('Network Error: Connection lost');
      jest.spyOn(window, 'fetch').mockRejectedValueOnce(networkError);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      // Attempt a login which triggers a network error
      await expect(
        result.current.login({
          email: 'network-fail@example.com',
          password: 'irrelevant',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-netfail',
        })
      ).rejects.toThrowError('Network Error: Connection lost');

      // Confirm the hook captured an error with 'LOGIN_ERROR'
      expect(result.current.error).not.toBeNull();
      expect(result.current.error?.code).toBe('LOGIN_ERROR');
    });

    it('should handle invalid credentials (401-like scenario)', async () => {
      jest.spyOn(window, 'fetch').mockResolvedValueOnce({
        ok: false,
        json: async () => ({
          success: false,
          data: null,
          error: {
            code: 'AUTH_001',
            message: 'Invalid credentials',
            details: { correlationId: 'abc123' },
            timestamp: Date.now(),
          },
          metadata: {},
          timestamp: Date.now(),
        }),
      } as unknown as Response);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      await expect(
        result.current.login({
          email: 'bad@example.com',
          password: 'badpwd',
          method: 'EMAIL_PASSWORD',
          deviceId: 'device-bad',
        })
      ).rejects.toThrowError(/Invalid credentials/);

      expect(result.current.isAuthenticated).toBe(false);
      expect(result.current.error?.code).toBe('LOGIN_ERROR');
      expect(result.current.currentUser).toBeNull();
    });

    it('should handle token validation errors during session validation', async () => {
      // Suppose token decode fails or indicates an invalid signature
      sessionStorage.setItem('authToken', 'malformedTokenXYZ');
      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      let isValid = true;
      await act(async () => {
        isValid = await result.current.validateSession();
      });
      // Should fail validation
      expect(isValid).toBe(false);
      expect(result.current.isAuthenticated).toBe(false);
    });

    it('should handle MFA verification failures (e.g., wrong code)', async () => {
      jest.spyOn(window, 'fetch').mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: false,
          data: null,
          error: {
            code: 'AUTH_005',
            message: 'MFA verification failed',
            details: {},
            timestamp: Date.now(),
          },
          metadata: {},
          timestamp: Date.now(),
        }),
      } as unknown as Response);

      const { result } = renderHook(() => useAuthHook(), {
        wrapper: createAuthWrapper(),
      });

      await expect(result.current.verifyMfa('999999')).rejects.toThrowError(/MFA verification failed/);
      expect(result.current.error?.code).toBe('MFA_VERIFY_ERROR');
      expect(result.current.error?.message).toMatch(/MFA verification failed./i);
    });
  });
});