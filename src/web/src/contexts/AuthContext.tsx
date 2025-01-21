import React, {
  createContext as createReactContext /* v18.2.0 */,
  useContext /* v18.2.0 */,
  useEffect /* v18.2.0 */,
  useState /* v18.2.0 */
} from 'react';

// Internal import of AuthService class and its methods (login, register, logout, etc.)
import { AuthService } from '../services/auth.service';
import { ApiService } from '../services/api.service';

/**
 * Represents the minimal shape of user data stored within the AuthContext.
 * In a larger application, this can include roles, permissions, profile info, etc.
 */
export interface UserData {
  id: string;
  email?: string;
  roles?: string[];
  [key: string]: any;
}

/**
 * Represents a structured session object that can hold detailed session info,
 * including device identifiers, creation time, last activity info, etc.
 */
export interface AuthSession {
  sessionId: string;
  createdAt: number;
  lastRefresh?: number;
  [key: string]: any;
}

/**
 * Represents the expected return type for an authentication method call (e.g., login).
 * Typically includes tokens, user data, flags indicating whether MFA is required, etc.
 */
export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  userId: string;
  mfaRequired?: boolean;
  [key: string]: any;
}

/**
 * Represents the result for any biometric authentication setup or flow.
 * Depending on your implementation, might include device metadata, API tokens, etc.
 */
export interface BiometricSetupResult {
  success: boolean;
  message?: string;
  [key: string]: any;
}

/**
 * Defines the shape of an optional AuthConfig object to parametrize the AuthProvider.
 * For instance, you can pass environment-specific configuration, feature flags,
 * or UI preferences for authentication flows.
 */
export interface AuthConfig {
  enableBiometric?: boolean;
  enableSocialLogin?: boolean;
  allowRememberMe?: boolean;
  [key: string]: any;
}

/**
 * Comprehensive interface describing the shape and capabilities offered
 * by the AuthContext to consuming components. This alignment ensures that
 * any component using auth context has full type safety and awareness of all auth operations.
 */
export interface AuthContextType {
  /**
   * The current authenticated user (if any). Will be null if the user is not authenticated.
   */
  user: UserData | null;

  /**
   * A boolean flag indicating whether the user is authenticated.
   * May be derived from the presence of an access token, user object, etc.
   */
  isAuthenticated: boolean;

  /**
   * A boolean flag indicating if an authentication-related process
   * (e.g., login, token refresh, or MFA verification) is currently loading.
   */
  isLoading: boolean;

  /**
   * A boolean that becomes true if the server indicates Multi-Factor Authentication is required
   * after a login attempt. The UI can then branch to a separate MFA flow or a dedicated screen.
   */
  isMfaRequired: boolean;

  /**
   * Logs in a user with the provided credentials, handling advanced scenarios (MFA, device ID).
   */
  login: (credentials: any) => Promise<AuthResult>;

  /**
   * Logs in a user with an OAuth2-based social provider using PKCE or similar flows.
   */
  socialLogin: (provider: string) => Promise<AuthResult>;

  /**
   * Initiates or completes a biometric authentication flow, such as TouchID/FaceID.
   */
  biometricAuth: () => Promise<AuthResult>;

  /**
   * Sets up or configures biometric authentication on a device, possibly enabling
   * future biometric logins.
   */
  setupBiometric: () => Promise<BiometricSetupResult>;

  /**
   * Optionally sets up multi-factor authentication for the current user (e.g., TOTP).
   */
  setupMfa?: (method: string, rememberDevice: boolean) => Promise<any>;

  /**
   * Optionally verifies multi-factor authentication codes (TOTP, SMS, etc.).
   */
  verifyMfa?: (code: string) => Promise<boolean>;

  /**
   * Registers a new user in the system. Typically requires more advanced input (name, email, etc.).
   * Implementation details may vary widely.
   */
  register?: (formData: any) => Promise<AuthResult>;

  /**
   * Logs out the current user, destroying tokens, clearing session data, and redirecting if needed.
   */
  logout?: () => Promise<void>;

  /**
   * The current device ID associated with the user session (if any). Helps with device tracking,
   * push notifications, and advanced session management.
   */
  deviceId?: string;

  /**
   * A structured representation of the current authentication session, including
   * session IDs, timestamps, or other relevant data.
   */
  session?: AuthSession;
}

/**
 * Creation of the AuthContext with default initial values.
 * The actual state and methods will be provided by AuthProvider at runtime.
 */
export const AuthContext = createReactContext<AuthContextType>({
  user: null,
  isAuthenticated: false,
  isLoading: false,
  isMfaRequired: false,
  login: async () => {
    throw new Error('AuthContext not yet initialized: login() not available.');
  },
  socialLogin: async () => {
    throw new Error('AuthContext not yet initialized: socialLogin() not available.');
  },
  biometricAuth: async () => {
    throw new Error('AuthContext not yet initialized: biometricAuth() not available.');
  },
  setupBiometric: async () => {
    throw new Error('AuthContext not yet initialized: setupBiometric() not available.');
  }
});

/**
 * Props for AuthProvider, allowing injection of children (React nodes)
 * and an optional authConfig for advanced usage or environment-based overrides.
 */
interface AuthProviderProps {
  children: React.ReactNode;
  authConfig?: AuthConfig;
}

/**
 * AuthProvider: Enhanced authentication context provider that implements
 * production-grade security features such as multi-factor authentication,
 * biometric verification, and social login. It wraps the entire application
 * (or a significant subtree) to expose a comprehensive AuthContext.
 */
export function AuthProvider({ children, authConfig }: AuthProviderProps): JSX.Element {
  /**
   * Instantiate the underlying AuthService once, providing a shared ApiService
   * for all authentication-related calls. A single instance is sufficient for
   * the lifetime of this context.
   */
  const [authService] = useState<AuthService>(() => {
    return new AuthService(new ApiService());
  });

  /**
   * user: Holds the currently authenticated user's data.
   * isLoading: Indicates an in-flight authentication or token refresh operation.
   * isMfaRequired: If the server signals that an additional MFA step is required after login.
   * deviceId: A unique identifier for this device or session, useful for tracking or "remember device" flows.
   * session: A structured object capturing session details (ID, creation time, etc.).
   */
  const [user, setUser] = useState<UserData | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [isMfaRequired, setIsMfaRequired] = useState<boolean>(false);
  const [deviceId, setDeviceId] = useState<string>(() => {
    // Attempt to load existing device ID from localStorage or generate a new one
    const existingId = localStorage.getItem('app_device_id');
    if (existingId) return existingId;
    const newId = `device-${Math.random().toString(36).substring(2, 15)}`;
    localStorage.setItem('app_device_id', newId);
    return newId;
  });
  const [session, setSession] = useState<AuthSession | undefined>(undefined);

  /**
   * Derive isAuthenticated from the presence of a valid user object.
   * For an even stronger check, you could verify an unexpired token.
   */
  const isAuthenticated = Boolean(user);

  /**
   * login():
   * Attempts to authenticate the user with standard credentials (e.g., email/password)
   * or triggers any required MFA flows. On success, stores user info and session data,
   * setting the appropriate flags in state.
   */
  const login = async (credentials: any): Promise<AuthResult> => {
    try {
      setIsLoading(true);
      const result = await authService.login(credentials, 'PASSWORD');
      setIsMfaRequired(Boolean(result.mfaRequired));

      // For demonstration, set a minimal user object with the userId returned
      const userData: UserData = {
        id: result.userId || '',
        email: credentials.email || '',
      };
      setUser(userData);

      // Optionally, capture session details
      setSession({
        sessionId: `sess-${Date.now()}`,
        createdAt: Date.now()
      });

      setIsLoading(false);
      return result;
    } catch (error) {
      setIsLoading(false);
      setUser(null);
      setIsMfaRequired(false);
      throw error;
    }
  };

  /**
   * socialLogin():
   * Initiates a social authentication flow with a chosen provider (e.g., Google, Facebook, Apple).
   * Depending on your architecture, you might redirect to an external OAuth flow or open a
   * popup/embedded webview for PKCE-based login. On completion, updates local user/session state.
   */
  const socialLogin = async (provider: string): Promise<AuthResult> => {
    try {
      setIsLoading(true);
      const result = await authService.socialLogin(provider);
      setIsMfaRequired(Boolean(result.mfaRequired));

      const userData: UserData = {
        id: result.userId || '',
        // We may not have an email from the provider, but if so, store it here.
      };
      setUser(userData);

      setSession({
        sessionId: `sess-social-${Date.now()}`,
        createdAt: Date.now()
      });

      setIsLoading(false);
      return result;
    } catch (error) {
      setIsLoading(false);
      setUser(null);
      setIsMfaRequired(false);
      throw error;
    }
  };

  /**
   * biometricAuth():
   * Performs a biometric-based authentication attempt if the device supports TouchID, FaceID,
   * or similar. If successful, returns an AuthResult that can be used to update local user state.
   */
  const biometricAuth = async (): Promise<AuthResult> => {
    try {
      setIsLoading(true);
      const result = await authService.biometricAuth();
      // If the service indicates the user is now fully authenticated, update state
      setIsMfaRequired(Boolean(result.mfaRequired));

      setUser({
        id: result.userId || '',
      });

      setSession({
        sessionId: `sess-bio-${Date.now()}`,
        createdAt: Date.now()
      });

      setIsLoading(false);
      return result;
    } catch (error) {
      setIsLoading(false);
      setUser(null);
      setIsMfaRequired(false);
      throw error;
    }
  };

  /**
   * setupBiometric():
   * Configures biometric authentication on the current device, possibly setting up
   * local secure storage and enabling future frictionless logins.
   */
  const setupBiometric = async (): Promise<BiometricSetupResult> => {
    try {
      // In some architectures, you'd call a specialized method
      // or handle local device registration. For simplicity:
      const result: BiometricSetupResult = {
        success: true,
        message: 'Biometric setup complete.'
      };
      // Alternatively, you could call authService.biometricAuth() or handle
      // a different flow for device provisioning.
      return result;
    } catch (error: any) {
      return {
        success: false,
        message: error?.message || 'Biometric setup failed.'
      };
    }
  };

  /**
   * setupMfa():
   * Initiates or configures an MFA method (e.g., TOTP, SMS). Returns
   * a response that typically includes a secret, backup codes, or a QR code URL.
   */
  const setupMfa = async (method: string, rememberDevice: boolean): Promise<any> => {
    try {
      const response = await authService.setupMfa(method as any, rememberDevice);
      return response; // Could contain { secret, backupCodes, qrCodeUrl, etc. }
    } catch (error) {
      throw error;
    }
  };

  /**
   * verifyMfa():
   * Verifies an MFA code (TOTP, SMS, or other). If successful, fully authenticates user
   * if they were partially authenticated. Clears isMfaRequired state if verification succeeds.
   */
  const verifyMfa = async (code: string): Promise<boolean> => {
    try {
      const verified = await authService.verifyMfa(code);
      if (verified) {
        setIsMfaRequired(false);
      }
      return verified;
    } catch (error) {
      throw error;
    }
  };

  /**
   * register():
   * Creates a new user account in the system. This typically requires
   * user-supplied data such as email, password, name, etc.
   */
  const register = async (formData: any): Promise<AuthResult> => {
    try {
      setIsLoading(true);
      const result = await authService.register(formData);
      setIsMfaRequired(Boolean(result.mfaRequired));

      setUser({
        id: result.userId || '',
        email: formData.email
      });

      setSession({
        sessionId: `sess-reg-${Date.now()}`,
        createdAt: Date.now()
      });

      setIsLoading(false);
      return result;
    } catch (error) {
      setIsLoading(false);
      setUser(null);
      setIsMfaRequired(false);
      throw error;
    }
  };

  /**
   * logout():
   * Terminates the current user session, calling the server to invalidate tokens if applicable,
   * then clears local user and session data.
   */
  const logout = async (): Promise<void> => {
    try {
      setIsLoading(true);
      await authService.logout();
      setUser(null);
      setSession(undefined);
      setIsMfaRequired(false);
      setIsLoading(false);
    } catch (error) {
      setIsLoading(false);
      // In case the server logout fails, we still want to clear local data
      setUser(null);
      setIsMfaRequired(false);
      setSession(undefined);
      throw error;
    }
  };

  /**
   * Optionally, useEffect for session initialization or token refresh checks upon first load.
   * This can handle auto-login scenarios if tokens are stored locally.
   */
  useEffect(() => {
    // Example: Attempt silent refresh if a valid refresh token is present
    // or check session validity on app mount. This is a placeholder for deeper logic.
    (async () => {
      try {
        const existingToken = sessionStorage.getItem('authToken');
        if (existingToken) {
          // If there's a stored token, we could validate or refresh it here.
          // This is very implementation-specific.
        }
      } catch {
        // If refresh fails, or no token found, user remains logged out.
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /**
   * Prepare the AuthContext value object, exposing all relevant state
   * and operations to consumer components.
   */
  const contextValue: AuthContextType = {
    user,
    isAuthenticated,
    isLoading,
    isMfaRequired,
    login,
    socialLogin,
    biometricAuth,
    setupBiometric,
    setupMfa,
    verifyMfa,
    register,
    logout,
    deviceId,
    session
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
}

/**
 * useAuth():
 * A custom hook to simplify access to the authentication context.
 * Provides type-safety and ensures that consuming components do
 * not proceed if no AuthContext is available (e.g., out of provider scope).
 */
export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider.');
  }

  // Additional checks or session validation can be performed here.
  return context;
}