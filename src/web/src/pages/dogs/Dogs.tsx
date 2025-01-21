import React, {
  FC,
  useEffect,
  useState,
  useCallback,
  useMemo,
} from 'react'; // react@^18.0.0
import { useNavigate } from 'react-router-dom'; // react-router-dom@^6.0.0
import analytics from '@segment/analytics-next'; // @segment/analytics-next@^1.0.0

// Internal imports based on JSON specification
import { DogList } from '../../components/dogs/DogList';
import { Button } from '../../components/common/Button';
import { useAuth } from '../../hooks/useAuth';
import { ErrorBoundary } from '../../components/common/ErrorBoundary';

/**
 * handleAddDog
 * ----------------------------------------------------------------------------
 * Handles navigation to the "Add Dog" page and tracks user interaction via analytics.
 * Steps:
 *  1) Tracks an "Add Dog" button click event with user context.
 *  2) Navigates to the "/dogs/add" route for creating a new dog profile.
 *
 * @param navigate - A hook-based function returned by react-router-dom for routing
 * @param currentUser - The currently authenticated user (or null if not logged in)
 */
function handleAddDog(
  navigate: ReturnType<typeof useNavigate>,
  currentUser: { id: string } | null
): void {
  analytics.track('Add Dog Button Clicked', {
    userId: currentUser?.id ?? 'anonymous',
  });
  navigate('/dogs/add');
}

/**
 * Dogs
 * ----------------------------------------------------------------------------
 * Main page component for displaying and managing a user's dog profiles.
 * Includes:
 *  - Responsive layout
 *  - Error boundary for robust error handling
 *  - Analytics tracking for page views and interactions
 *  - Integration with authentication context to retrieve current user info
 *  - Conditional rendering for loading states and error states
 *  - A button to add a new dog, triggering handleAddDog
 *
 * Implementation Steps:
 *  1) Initialize navigation hook from react-router-dom.
 *  2) Destructure necessary fields (currentUser, isLoading, error) from useAuth for user context.
 *  3) Initialize Segment analytics tracking for page views.
 *  4) Wrap top-level return in ErrorBoundary for graceful error handling.
 *  5) Render a loading skeleton/UI if the user context is still loading data.
 *  6) Provide a responsive page header with an "Add Dog" button.
 *  7) Display an error section if there's any authentication or user-related error.
 *  8) Render the DogList component with the user's ID for listing, editing, deleting dogs.
 *  9) Integrate a minimal approach to responsive design, relying on flexible
 *     CSS layouts or breakpoints (class-based or inline styles).
 *
 * @returns A React Functional Component (FC) that shows the dogs list page.
 */
export const Dogs: FC = () => {
  /**
   * Step 1: Initialize navigation hook for routing.
   */
  const navigate = useNavigate();

  /**
   * Step 2: Retrieve current user data, loading, and error states from auth context.
   * The "currentUser" property includes an "id" that we can pass to DogList.
   */
  const { currentUser, isLoading, error } = useAuth();

  /**
   * Step 3: Use an effect to track a page view event via Segment analytics.
   * This occurs once on component mount (and again if "currentUser" changes).
   */
  useEffect(() => {
    analytics.page('Dogs Page', {
      userId: currentUser?.id ?? 'anonymous',
    });
  }, [currentUser?.id]);

  /**
   * Enhanced callback to handle "Add Dog" button clicks:
   * Combines the local handleAddDog helper with the navigate hook.
   */
  const onAddDogClick = useCallback(() => {
    handleAddDog(navigate, currentUser);
  }, [navigate, currentUser]);

  /**
   * Step 4: Return the component JSX wrapped in an ErrorBoundary for robust error handling.
   * We ensure that any rendering error in the children is gracefully caught.
   */
  return (
    <ErrorBoundary>
      {/* Minimal inline style approach for a responsive container */}
      <div
        className="dogs-page-container"
        style={{
          width: '100%',
          maxWidth: '1200px',
          margin: '0 auto',
          padding: '1rem',
        }}
      >
        {/**
         * Step 5: Show a loading state if the user's authentication info is still
         * being fetched or processed.
         */}
        {isLoading ? (
          <div
            style={{
              fontSize: '1rem',
              color: '#555',
              textAlign: 'center',
              padding: '2rem 0',
            }}
          >
            Loading user data...
          </div>
        ) : (
          <>
            {/**
             * Step 6: Page header for "Your Dogs" with an "Add Dog" button.
             * This header is flex-based for responsive alignment across breakpoints.
             */}
            <header
              style={{
                display: 'flex',
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'space-between',
                marginBottom: '1.5rem',
              }}
            >
              <h1
                style={{
                  margin: 0,
                  fontSize: '1.5rem',
                  lineHeight: 1.2,
                  color: '#212121',
                }}
              >
                Your Dogs
              </h1>
              <Button
                variant="primary"
                size="medium"
                onClick={onAddDogClick}
                aria-label="Add a new dog profile"
              >
                Add Dog
              </Button>
            </header>

            {/**
             * Step 7: Render an error message if there's an authentication or user error.
             * This covers advanced error states from the auth hook or server side.
             */}
            {error && (
              <div
                role="alert"
                style={{
                  backgroundColor: '#f44336',
                  color: '#fff',
                  padding: '0.75rem 1rem',
                  marginBottom: '1rem',
                  borderRadius: '4px',
                }}
              >
                <strong>Error:</strong> {error.message}
              </div>
            )}

            {/**
             * If no user is logged in, instruct them to log in. If we do have a user,
             * render the DogList with that user's ID.
             */}
            {currentUser ? (
              <>
                {/**
                 * Step 8: The DogList component from the internal import. We pass the
                 * currentUser's ID for retrieving their dog profiles, along with
                 * extensive configuration from the JSON specification (e.g., pageSize, filterOptions).
                 */}
                <DogList
                  ownerId={currentUser.id}
                  className="dogs-list-grid"
                  pageSize={10}
                  sortOptions={[]}
                  filterOptions={[]}
                  enableBatchOperations={true}
                  cacheTimeout={300000}
                />
              </>
            ) : (
              <div
                style={{
                  fontSize: '1rem',
                  color: '#555',
                  marginTop: '1rem',
                  textAlign: 'center',
                }}
              >
                Please sign in to view or manage your dog profiles.
              </div>
            )}
          </>
        )}
      </div>
    </ErrorBoundary>
  );
};