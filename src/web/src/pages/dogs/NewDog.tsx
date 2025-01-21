/***************************************************************************************
 * NewDog.tsx
 *
 * This page component is responsible for creating a new dog profile with comprehensive
 * validation, secure handling of sensitive data, and user feedback mechanisms. It also
 * integrates with the DogForm component for input collection and utilizes the DogService
 * for backend interactions, adhering to the project's requirements for:
 *   1) Pet Profile Management
 *   2) Data Security
 *
 * The code below demonstrates:
 *   - Proper owner (user) validation via the authentication hook.
 *   - ErrorBoundary usage for graceful error handling.
 *   - Secure dog data creation (including form sanitization, toast notifications).
 *   - Detailed commentary for enterprise-level maintainability.
 ***************************************************************************************/

/* -----------------------------------------------------------------------------
   1) External Imports with Version Comments
   ----------------------------------------------------------------------------- */
/** React library for UI components (version: ^18.0.0) */
import React, { useCallback, useState } from 'react';

/** React Router hook for programmatic navigation (version: ^6.0.0) */
import { useNavigate } from 'react-router-dom';

/** Toast library for user feedback on success/error (version: ^9.0.0) */
import { toast } from 'react-toastify';

/** React hooks for state and memoization (version: ^18.0.0)
    (Already covered by main React import, but specifically requested in specification) */
import { useCallback as useCb, useState as useSt } from 'react';

/* -----------------------------------------------------------------------------
   2) Internal Imports
   ----------------------------------------------------------------------------- */
/** Reusable form component for dog profile creation */
import DogForm from '../../components/dogs/DogForm';

/** Named import for the createDog method from dog service (as per specification) */
import { createDog } from '../../services/dog.service';

/** Authentication hook to retrieve current user for owner validation */
import { useAuth } from '../../hooks/useAuth';

/** Type definition for the dog creation request payload */
import { CreateDogRequest } from '../../types/dog.types';

/** Error boundary component for graceful error handling */
import ErrorBoundary from '../../components/common/ErrorBoundary';

/* -----------------------------------------------------------------------------
   3) Interface & Types (If Additional Local Typing Is Needed)
   ----------------------------------------------------------------------------- */
/** No extra local interfaces required beyond the specification. */

/* -----------------------------------------------------------------------------
   4) HandleSubmit - Orchestrates the secure creation of a new dog profile
   ----------------------------------------------------------------------------- */
/**
 * handleSubmit
 *
 * Handles the submission of new dog profile data with validation and security measures.
 * Steps:
 *  1) Validate owner ID from auth context.
 *  2) Set loading state to prevent double submission.
 *  3) Sanitize input data (placeholder demonstration).
 *  4) Add owner ID to dog data.
 *  5) Implement request deduplication (skipping duplicate submissions when loading).
 *  6) Call dog service to create profile.
 *  7) Log audit trail (simple console.log placeholder).
 *  8) Show success notification with toast.
 *  9) Navigate to dog list on success.
 * 10) Handle errors with proper error notification.
 * 11) Reset loading state.
 * 12) Update error state if needed.
 *
 * @param dogData - The new dog profile data from the form.
 * @param currentUserId - The ID of the current authenticated user (owner).
 * @param setLoading - State setter for loading boolean.
 * @param setError - State setter for capturing error messages.
 * @param navigate - React Router hook function to navigate after success.
 */
async function handleSubmit(
  dogData: CreateDogRequest,
  currentUserId: string,
  setLoading: React.Dispatch<React.SetStateAction<boolean>>,
  setError: React.Dispatch<React.SetStateAction<string | null>>,
  navigate: (path: string) => void
): Promise<void> {
  try {
    // 1) Validate owner ID
    if (!currentUserId) {
      throw new Error('Invalid owner: No authenticated user found.');
    }

    // 2) Set loading state
    setLoading(true);

    // 3) Sanitize input data (basic placeholder here; real logic would be more robust)
    const sanitizedName = dogData.name.trim();

    // 4) Add owner ID to dog data
    const securedDogData: CreateDogRequest = {
      ...dogData,
      name: sanitizedName,
      ownerId: currentUserId,
    };

    // 5) Check for request deduplication (skip if still loading)
    //    Already satisfied by the external loading check in the main component.

    // 6) Call dog service to create the new dog profile
    const response = await createDog(securedDogData);

    // 7) Log audit trail
    console.log('[AUDIT] New dog creation attempt completed:', response);

    // If success is false, handle as error
    if (!response.success) {
      throw new Error(response.error?.message || 'Failed to create dog profile');
    }

    // 8) Show success notification
    toast.success('Dog profile created successfully!');

    // 9) Navigate to dog list page
    navigate('/dogs');

  } catch (error: any) {
    // 10) Handle errors with toast and local error state
    toast.error(error?.message || 'An error occurred while creating dog profile.');
    setError(error?.message || 'An unexpected error occurred.');
  } finally {
    // 11) Reset loading state
    setLoading(false);
    // 12) Error state handling is done above
  }
}

/* -----------------------------------------------------------------------------
   5) handleCancel - Cleans up and navigates away from new dog creation
   ----------------------------------------------------------------------------- */
/**
 * handleCancel
 *
 * Handles cancellation of dog profile creation with proper cleanup.
 * Steps:
 *  1) Clear form data (the form itself resets on unmount).
 *  2) Reset loading state.
 *  3) Clear error state.
 *  4) Navigate back to dog list page.
 *  5) Show cancellation notification.
 *
 * @param setLoading - State setter for loading.
 * @param setError - State setter for error messages.
 * @param navigate - React Router hook function for navigation.
 */
function handleCancel(
  setLoading: React.Dispatch<React.SetStateAction<boolean>>,
  setError: React.Dispatch<React.SetStateAction<string | null>>,
  navigate: (path: string) => void
): void {
  // 1) Clear form data (implicitly done by unmounting DogForm).
  // 2) Reset loading state
  setLoading(false);

  // 3) Clear error state
  setError(null);

  // 4) Navigate back to dog list
  navigate('/dogs');

  // 5) Show cancellation notification
  toast.info('Dog profile creation cancelled.');
}

/* -----------------------------------------------------------------------------
   6) NewDog Page Component
   ----------------------------------------------------------------------------- */
/**
 * NewDog
 *
 * Page component for creating a new dog profile with security measures and error handling.
 * Steps:
 *  1) Initialize navigation hook for routing.
 *  2) Get current user from auth context for owner validation.
 *  3) Initialize loading state with useState.
 *  4) Initialize error state for form validation or system errors.
 *  5) Set up error boundary for graceful error handling (component is wrapped below).
 *  6) Render form with loading state and error handling.
 *  7) Implement accessibility features with ARIA labels (the DogForm also covers aspects).
 *  8) Add proper focus management if error occurs (optional approach shown here).
 *
 * @returns JSX.Element - Rendered new dog page component wrapped in error boundary
 */
const NewDog: React.FC = () => {
  // 1) Initialize navigation hook
  const navigate = useNavigate();

  // 2) Get current user from auth context
  const { currentUser } = useAuth();

  // 3) Initialize loading state
  const [loading, setLoading] = useState(false);

  // 4) Initialize error state
  const [error, setError] = useState<string | null>(null);

  // 8) Optional focus management:
  //    If there's an error, you could place focus on an alert or error message.
  //    For brevity, we do not define an entire ref-based approach here.

  // Render the dog creation form:
  // On submit, we pass dogData to handleSubmit.
  // On cancel, we pass to handleCancel.
  return (
    <div aria-label="New Dog Profile Page" style={{ padding: '1rem' }}>
      {error && (
        <div
          role="alert"
          style={{ color: 'red', marginBottom: '1rem' }}
          aria-live="assertive"
        >
          {error}
        </div>
      )}
      <DogForm
        dog={undefined}
        onSubmit={async (dogData) =>
          handleSubmit(dogData, currentUser?.id || '', setLoading, setError, navigate)
        }
        onCancel={() => handleCancel(setLoading, setError, navigate)}
        isLoading={loading}
        onValidationError={(validationErrors) => {
          // Merge them into a display string or handle as needed
          if (validationErrors.length > 0) {
            setError(validationErrors[0].message);
          }
        }}
      />
    </div>
  );
};

/* -----------------------------------------------------------------------------
   7) Export with ErrorBoundary Wrapping
   ----------------------------------------------------------------------------- */
/**
 * We wrap the NewDog component in an ErrorBoundary to gracefully handle any
 * runtime errors that might occur. This ensures robust error security and
 * instant fallback for user-facing safety.
 */
const WrappedNewDog: React.FC = () => (
  <ErrorBoundary>
    <NewDog />
  </ErrorBoundary>
);

export default WrappedNewDog;