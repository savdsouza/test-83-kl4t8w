import React, {
  Suspense as ReactSuspense /* ^18.0.0 */,
  lazy,
  useMemo,
  ReactNode,
  FC
} from 'react';
import { ErrorBoundary /* ^4.0.0 */ } from 'react-error-boundary';
import {
  BrowserRouter as Router /* ^6.0.0 */,
  Routes /* ^6.0.0 */,
  Route /* ^6.0.0 */,
  Navigate /* ^6.0.0 */
} from 'react-router-dom';

// -------------------------------------------------------------------------------------
// Internal Imports (Strictly Following JSON Specification)
// -------------------------------------------------------------------------------------
// AuthProvider and useAuth hook for authentication context management
import { AuthProvider, useAuth } from './contexts/AuthContext';
// Layouts for Auth and Dashboard, as specified in the JSON
import { AuthLayout } from './layouts/AuthLayout';
import { DashboardLayout } from './layouts/DashboardLayout';

// -------------------------------------------------------------------------------------
// Lazy-Loaded Pages or Placeholder Components
// -------------------------------------------------------------------------------------
// In a real application, these would be replaced by actual page components
// or lazy imports. For demonstration and route connectivity, we define placeholders.

const PlaceholderAuthPage: FC = () => (
  <div style={{ padding: '2rem', fontSize: '1.2rem' }}>
    <strong>Public Auth Page Placeholder</strong>
  </div>
);

const PlaceholderDashboardPage: FC<{ title?: string }> = ({ title }) => (
  <div style={{ padding: '2rem', fontSize: '1.2rem' }}>
    <strong>{title || 'Protected Dashboard Placeholder'}</strong>
  </div>
);

const NotFoundPage: FC = () => (
  <div style={{ padding: '2rem', fontSize: '1.2rem', color: 'red' }}>
    <strong>404 - Page Not Found</strong>
  </div>
);

// -------------------------------------------------------------------------------------
// PrivateRoute
// -------------------------------------------------------------------------------------
// A route component protecting authenticated pages. Based on the JSON specification:
// 1) Retrieves authentication state and user role.
// 2) If not authenticated, redirects to a login route.
// 3) If authenticated, checks role authorization if roles[] are provided.
// 4) Wraps children in DashboardLayout if authorized, or displays an unauthorized message.
// 5) Handles potential loading states while verifying.
//
// Parameters:
//   - children: The React node(s) to render if the user passes security checks.
//   - roles: Array of string roles required to access this route.
// Returns:
//   - A JSX.Element, either the authorized content or a redirect/unauthorized.
interface PrivateRouteProps {
  children: ReactNode;
  roles?: string[];
}
function PrivateRoute({ children, roles = [] }: PrivateRouteProps): JSX.Element {
  // 1) Acquire auth context (authentication state + user role)
  const { isLoading, isAuthenticated, currentUser } = useAuth();

  // 2) If loading is ongoing (e.g., verifying tokens), show a loading indicator.
  if (isLoading) {
    return (
      <div style={{ padding: '2rem', fontSize: '1rem' }}>
        <em>Checking authentication...</em>
      </div>
    );
  }

  // 3) If the user is not authenticated, redirect to login (public route).
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // 4) If roles are specified, check if the user's role is included in the required list.
  //    In a real application, user roles might be more complex. This is a simplified scenario.
  if (roles.length > 0 && currentUser?.role) {
    const userHasAccess = roles.includes(currentUser.role);
    if (!userHasAccess) {
      return (
        <div style={{ padding: '2rem', color: 'red' }}>
          <strong>Access Denied:</strong> You are not authorized to view this page.
        </div>
      );
    }
  }

  // 5) If everything checks out, wrap the protected children in the DashboardLayout.
  return <DashboardLayout disableSidebar={false} className="" >{children}</DashboardLayout>;
}

// -------------------------------------------------------------------------------------
// PublicRoute
// -------------------------------------------------------------------------------------
// A route component for pages requiring an unauthenticated user. If the user is already
// authenticated, it redirects to a suitable protected page (dashboard or a default).
//
// Steps (from specification):
// 1) Retrieve auth context isLoading/isAuthenticated
// 2) If loading, show a loading indicator
// 3) If authenticated, redirect to a default route (e.g., protected home)
// 4) If not, render children with AuthLayout
// 5) Optionally apply route transition or animation
interface PublicRouteProps {
  children: ReactNode;
}
function PublicRoute({ children }: PublicRouteProps): JSX.Element {
  const { isLoading, isAuthenticated } = useAuth();

  if (isLoading) {
    return (
      <div style={{ padding: '2rem' }}>
        <em>Loading public route...</em>
      </div>
    );
  }
  if (isAuthenticated) {
    return <Navigate to="/owner" replace />;
  }
  return <AuthLayout>{children}</AuthLayout>;
}

// -------------------------------------------------------------------------------------
// App
// -------------------------------------------------------------------------------------
// The root application component that sets up:
//   - Global ErrorBoundary for top-level error handling
//   - AuthProvider for authentication context
//   - Router, including route definitions for both public and private routes
//   - Suspense to handle lazy-loaded pages if used
//   - Role-based route protection and a 404 fallback
//
// Steps (from specification):
// 1) Wrap application in top-level ErrorBoundary
// 2) Provide AuthProvider for entire app
// 3) Use BrowserRouter for routing
// 4) Suspense boundary for lazy loaded routes, if any
// 5) Define public routes and private routes with role checks
// 6) Implement 404 not found route
// 7) Optionally implement performance or error monitoring
// 8) Export App as default
function App(): JSX.Element {
  return (
    <ErrorBoundary
      fallbackRender={({ error }) => (
        <div style={{ padding: '2rem', color: 'red' }}>
          <h2>Something Went Wrong:</h2>
          <p>{error?.message}</p>
          <p>Please try refreshing the page or contacting support.</p>
        </div>
      )}
    >
      {/* AuthProvider: Exposing authentication context across entire app */}
      <AuthProvider>
        {/* Router: Using react-router-dom for client-side routing */}
        <Router>
          {/* Suspense: In case of lazy imports or routes, we show a fallback */}
          <ReactSuspense
            fallback={
              <div style={{ padding: '2rem' }}>
                <em>Loading Application...</em>
              </div>
            }
          >
            <Routes>
              {/* Public Routes (Unauthenticated Access) */}
              <Route
                path="/login"
                element={
                  <PublicRoute>
                    <PlaceholderAuthPage />
                  </PublicRoute>
                }
              />
              <Route
                path="/register"
                element={
                  <PublicRoute>
                    <PlaceholderAuthPage />
                  </PublicRoute>
                }
              />

              {/* Private Route Examples with role-based access */}
              <Route
                path="/owner"
                element={
                  <PrivateRoute roles={['OWNER']}>
                    <PlaceholderDashboardPage title="Owner Dashboard" />
                  </PrivateRoute>
                }
              />
              <Route
                path="/walker"
                element={
                  <PrivateRoute roles={['WALKER']}>
                    <PlaceholderDashboardPage title="Walker Dashboard" />
                  </PrivateRoute>
                }
              />
              <Route
                path="/admin"
                element={
                  <PrivateRoute roles={['ADMIN']}>
                    <PlaceholderDashboardPage title="Admin Panel" />
                  </PrivateRoute>
                }
              />

              {/* Example of a general private route with no role restriction */}
              <Route
                path="/protected"
                element={
                  <PrivateRoute>
                    <PlaceholderDashboardPage title="General Protected Page" />
                  </PrivateRoute>
                }
              />

              {/* 404 Not Found Route */}
              <Route path="*" element={<NotFoundPage />} />
            </Routes>
          </ReactSuspense>
        </Router>
      </AuthProvider>
    </ErrorBoundary>
  );
}

// -------------------------------------------------------------------------------------
// Named or Default Export
// -------------------------------------------------------------------------------------
// Per the JSON specification, we export App as the root component.
export { App as default };