import React, { ErrorInfo } from 'react'; // react@^18.0.0
import styled from 'styled-components'; // styled-components@^6.0.0

// Internal Imports (Strictly Following JSON Specification)
// ----------------------------------------------------------------------------
// 1) Loading - Default import from ../components/common/Loading.tsx
// 2) Footer - Default import from ../components/layout/Footer.tsx
// 3) useAuth - Named import providing isLoading, error states from ../hooks/useAuth.ts
import Loading from '../components/common/Loading';
import { useAuth } from '../hooks/useAuth';
import Footer from '../components/layout/Footer';

// ============================================================================
// AuthLayoutContainer
// ----------------------------------------------------------------------------
// A styled container providing the overarching layout for authentication pages,
// with full-height options, theme-based background, responsive padding, and
// containment properties for optimized rendering. Adheres to design token
// usage and media queries specified in the JSON specification, aligning with
// the project's global design system for typography, spacing, and color.
// ============================================================================
const AuthLayoutContainer = styled.div`
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  background-color: var(--color-background);
  position: relative;
  z-index: 1;
  contain: layout style;

  @media (max-width: 375px) {
    padding: var(--spacing-md);
  }

  @media (max-width: 768px) {
    padding: var(--spacing-lg);
  }

  @media (min-width: 1024px) {
    padding: var(--spacing-xl);
  }
`;

// ============================================================================
// AuthContent
// ----------------------------------------------------------------------------
// A responsive content wrapper for interactive authentication elements (e.g.,
// login forms, registration forms, password reset flows). The layout centers
// the content horizontally, respects maximum width constraints, and adjusts
// padding for smaller screens while maintaining consistent alignment for
// mid-sized and larger viewports.
// ============================================================================
const AuthContent = styled.div`
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-lg);
  max-width: 480px;
  margin: 0 auto;
  width: 100%;

  @media (max-width: 375px) {
    padding: var(--spacing-sm);
  }

  @media (max-width: 768px) {
    max-width: 100%;
  }
`;

// ============================================================================
// AuthErrorBoundary
// ----------------------------------------------------------------------------
// A dedicated error boundary class to gracefully handle rendering errors within
// authentication-related UI flows. If a rendering error occurs, the fallback UI
// is displayed, preventing the entire application from crashing and providing
// a clear message to the user for troubleshooting or recovery. This aligns with
// best practices for robust, enterprise-grade React applications.
// ============================================================================
interface AuthErrorBoundaryState {
  hasError: boolean;
  errorMessage: string | null;
}

class AuthErrorBoundary extends React.Component<React.PropsWithChildren, AuthErrorBoundaryState> {
  constructor(props: React.PropsWithChildren) {
    super(props);
    this.state = {
      hasError: false,
      errorMessage: null,
    };
  }

  static getDerivedStateFromError(error: Error): Partial<AuthErrorBoundaryState> {
    return { hasError: true, errorMessage: error.message };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    // In a production system, we could log this error and stack trace to a monitoring service
    // for further investigation and alerting.
    /* eslint-disable no-console */
    console.error('AuthErrorBoundary caught an error:', error, errorInfo);
    /* eslint-enable no-console */
  }

  render(): React.ReactNode {
    if (this.state.hasError) {
      return (
        <div
          role="alert"
          aria-live="assertive"
          style={{ color: 'var(--color-error)', padding: 'var(--spacing-md)' }}
        >
          <strong>Something went wrong in the authentication layout:</strong>
          <br />
          {this.state.errorMessage}
        </div>
      );
    }
    return this.props.children;
  }
}

// ============================================================================
// AuthLayout
// ----------------------------------------------------------------------------
// Enhanced authentication layout component. It draws on the AuthErrorBoundary
// for failsafe, connects with the useAuth hook to derive loading/error states,
// applies ARIA roles for accessibility, and ensures a consistent page structure
// with a top-level container, main content block, dynamic loading, error
// handling UI, and a themed footer.
//
// Steps (From JSON Specification):
// 1) Acquire loading/error signals from useAuth
// 2) Wrap content in an error boundary for graceful handling
// 3) Declare ARIA labels and roles for accessibility
// 4) Render AuthLayoutContainer with theming
// 5) Show a fullscreen Loading indicator if isLoading is true
// 6) Render an inline error message if error is present
// 7) Render AuthContent area containing children
// 8) Conclude with a themed Footer
// ============================================================================
const AuthLayout: React.FC<React.PropsWithChildren> = React.memo(function AuthLayout({
  children,
}) {
  // 1) Acquire isLoading and error from enhanced authentication state
  const { isLoading, error } = useAuth();

  // 2) Wrap content in AuthErrorBoundary (see below)
  return (
    <AuthErrorBoundary>
      {/* 3) Apply accessibility roles and labeling */}
      <AuthLayoutContainer aria-label="Authentication Layout Region" role="region">
        {/* 5) Conditionally render the Loading component in full-screen mode */}
        {isLoading && (
          <Loading
            fullScreen
            text="Please wait, loading authentication..."
            color="var(--color-primary)"
            size="lg"
          />
        )}

        {/* 6) If there is an authentication error, display an accessible alert */}
        {error && (
          <div
            role="alert"
            aria-live="assertive"
            style={{ color: 'var(--color-error)', padding: 'var(--spacing-sm)' }}
          >
            <strong>Authentication Error:</strong> {error.message}
          </div>
        )}

        {/* 7) Render the main auth content area */}
        <AuthContent aria-label="Authentication Content" role="main">
          {children}
        </AuthContent>

        {/* 8) Footer with theme support */}
        <Footer />
      </AuthLayoutContainer>
    </AuthErrorBoundary>
  );
});

// Export (default) the memoized AuthLayout component
export default AuthLayout;