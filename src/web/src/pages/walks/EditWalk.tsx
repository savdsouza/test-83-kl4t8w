import React /* react@^18.0.0 */, {
  useState,
  useEffect,
  useCallback,
  FC
} from 'react';
import { useParams, useNavigate } from 'react-router-dom'; // react-router-dom@^6.0.0
import { useWebSocket } from 'react-use-websocket'; // react-use-websocket@^4.0.0

// ----------------------------------------------------------------------------
// Internal Imports (Per JSON Spec)
// ----------------------------------------------------------------------------
import { WalkForm } from '../../components/walks/WalkForm';
import { Walk } from '../../types/walk.types';
import { WalkService } from '../../services/walk.service';

// ----------------------------------------------------------------------------
// Interface: EditWalk
// ----------------------------------------------------------------------------
// This page component is responsible for editing an existing walk session,
// ensuring real-time schedule management, location tracking, photo sharing
// configurations, and emergency contact details are handled comprehensively.
// ----------------------------------------------------------------------------

/**
 * handleRealTimeUpdate
 * ---------------------------------------------------------------------------
 * A specialized function that processes incoming WebSocket messages for
 * real-time updates related to walk sessions. This includes:
 *  1) Parsing and validating the incoming data.
 *  2) Handling location tracking or status changes sent by the server.
 *  3) Processing any emergency alerts or relevant updates.
 *  4) Updating UI state accordingly.
 *
 * @param message - The raw WebSocket event message data (string or JSON).
 * @param setWalkData - Callback to update our walk data state if needed.
 * @param setError - Callback to set an error message upon processing issues.
 */
function handleRealTimeUpdate(
  message: MessageEvent<any>,
  setWalkData: React.Dispatch<React.SetStateAction<Walk | null>>,
  setError: React.Dispatch<React.SetStateAction<string | null>>
): void {
  try {
    // Step 1: Safely parse the incoming data from the event. Some servers
    //         may send plain strings or already-stringified JSON.
    const rawData = message?.data;
    if (!rawData) {
      // If message is empty or null, just return.
      return;
    }

    // Attempt to parse message JSON:
    let parsed;
    try {
      parsed = JSON.parse(rawData);
    } catch {
      // If parsing fails, we can treat it as a non-JSON message or log it as an error.
      console.error('Failed to parse incoming real-time message. Raw payload:', rawData);
      return;
    }

    // Step 2: Validate that we have the expected structure or authenticity fields.
    //         This might involve checking digital signatures, tokens, etc.
    //         For demonstration, we assume the message is trusted.
    if (!parsed || typeof parsed !== 'object') {
      console.warn('Unexpected message format received in handleRealTimeUpdate:', parsed);
      return;
    }

    // Step 3: React to known event types or fields. For example:
    //         location updates, status changes, or emergencies.
    if (parsed.type === 'LOCATION_UPDATE' && parsed.newCoordinates) {
      // We could update local walk data to reflect new location details if needed.
      // This might also tie into some map or route display. For demonstration:
      setWalkData((prevWalk) => {
        if (!prevWalk) return prevWalk;
        // Potential expansions: attach updated location data if your Walk interface stores it.
        return {
          ...prevWalk,
          // You could store location updates in a property like `route` or `photos`.
        };
      });
    } else if (parsed.type === 'STATUS_CHANGE' && parsed.newStatus) {
      // The server might broadcast that the walk status changed from ACCEPTED to IN_PROGRESS, etc.
      setWalkData((prevWalk) => {
        if (!prevWalk) return prevWalk;
        return {
          ...prevWalk,
          status: parsed.newStatus
        };
      });
    } else if (parsed.type === 'EMERGENCY') {
      // Potentially handle an emergency alert. The server might broadcast severity or instructions.
      setError(`Emergency alert received: ${JSON.stringify(parsed.details)}`);
    } else {
      // If an unknown type is received, we log or ignore.
      console.info('Unrecognized event type received:', parsed.type);
    }
  } catch (err) {
    // Step 4: If anything goes wrong in processing, log or set error state.
    console.error('Error processing real-time WebSocket message:', err);
    setError('Failed to process a real-time update');
  }
}

/**
 * fetchWalkData
 * ---------------------------------------------------------------------------
 * Enhanced function to fetch an existing walk's details, ensuring real-time
 * validations and any relevant initial setup. This covers:
 *  1) Setting UI to a loading state.
 *  2) Retrieving walk data from the backend via walkService.getWalkById.
 *  3) Running schedule checks with walkService (or real-time conflict detection).
 *  4) Optionally initializing real-time tracking or subscriptions.
 *  5) Handling any validation or retrieval errors gracefully.
 *  6) Finalizing the loading state.
 *
 * @param walkId - The unique string identifier of the walk.
 * @param setWalkData - React state setter function for the walk data.
 * @param setLoading - React state setter for the loading indicator.
 * @param setError - React state setter for an error message.
 * @param walkService - An instance of WalkService for data retrieval and checks.
 */
async function fetchWalkData(
  walkId: string,
  setWalkData: React.Dispatch<React.SetStateAction<Walk | null>>,
  setLoading: React.Dispatch<React.SetStateAction<boolean>>,
  setError: React.Dispatch<React.SetStateAction<string | null>>,
  walkService: WalkService
): Promise<void> {
  try {
    setLoading(true);

    // 1) Get the walk details from the service. We expect a Walk object in return.
    const walkRecord = await walkService.getWalkById(walkId);

    // 2) Validate schedule conflicts or do real-time checks if needed:
    //    This method might throw an error if conflicts are found.
    //    For demonstration, we'll call the underlying logic if it exists.
    await walkService.validateScheduleConflicts({
      ...walkRecord,
      // If the service expects a partial or create request structure,
      // adapt fields as necessary. For now, we pass the relevant data.
    });

    // 3) Potentially initialize real-time tracking or subscribe to status updates
    //    (this is optional depending on business requirements).
    walkService.subscribeToWalkStatus(walkId, (newStatus: string) => {
      // If the status changes, we can update local state accordingly.
      console.info('Status subscription callback triggered with:', newStatus);
      setWalkData((prev) => {
        if (!prev) return prev;
        return { ...prev, status: newStatus as Walk['status'] };
      });
    });

    // 4) If the fetched record indicates any custom photo sharing or emergency
    //    contact preferences, we could handle that here. For demonstration, the
    //    retrieved data is set directly into component state.
    setWalkData(walkRecord);

    setLoading(false);
  } catch (err: any) {
    console.error('Error fetching or validating walk data:', err);
    setError(err?.message || 'Failed to load the walk details');
    setLoading(false);
  }
}

/**
 * handleSubmit
 * ---------------------------------------------------------------------------
 * Enhanced handler for form submission, providing comprehensive validation
 * and ensuring all relevant walk updates (location tracking, photo sharing,
 * emergency contact info) are processed. Steps:
 *  1) Set loading state true.
 *  2) Validate location tracking settings (if any).
 *  3) Verify photo sharing permissions or logic.
 *  4) Ensure emergency contact is provided for safety.
 *  5) Check for schedule conflicts again if the time changed.
 *  6) Call walkService.updateWalk with the new data.
 *  7) Optionally update real-time tracking configurations.
 *  8) Navigate or indicate success, and handle errors.
 *  9) Restore loading to false.
 *
 * @param updatedWalk - The updated walk object coming from the form submission.
 * @param setLoading - React state setter for loading UI feedback.
 * @param setError - React state setter for an error message upon failure.
 * @param navigate - React Router hook for navigation after success.
 * @param walkService - Instance of WalkService used to run updates.
 */
async function handleSubmit(
  updatedWalk: Walk,
  setLoading: React.Dispatch<React.SetStateAction<boolean>>,
  setError: React.Dispatch<React.SetStateAction<string | null>>,
  navigate: ReturnType<typeof useNavigate>,
  walkService: WalkService
): Promise<void> {
  try {
    setLoading(true);

    // 1) Validate location tracking settings if we rely on a certain field or preference.
    if (updatedWalk.locationTracking && typeof updatedWalk.locationTracking !== 'boolean') {
      throw new Error('Invalid location tracking setting detected.');
    }

    // 2) Verify photo sharing logic if needed. For demonstration, we simply check boolean type.
    if (updatedWalk.photoSharing && typeof updatedWalk.photoSharing !== 'boolean') {
      throw new Error('Photo sharing flag must be a boolean.');
    }

    // 3) Ensure emergency contact is present when certain statuses or conditions demand it.
    if (!updatedWalk.emergencyContact || updatedWalk.emergencyContact.trim().length < 7) {
      throw new Error('A valid emergency contact is required to update this walk.');
    }

    // 4) Check schedule conflicts again in case the time or duration changed.
    await walkService.validateScheduleConflicts({
      ...updatedWalk
      // If partial, adapt as necessary. Just re-check the chosen times/dates.
    });

    // 5) Perform the actual update call on the service. This returns an updated record.
    const finalWalk = await walkService.updateWalk(updatedWalk);

    // 6) Optionally update real-time tracking if location tracking has changed or new data is needed.
    //    For demonstration, we might re-subscribe or do a no-op if it's the same. This is context-specific.

    // 7) On success, navigate away or show success feedback. We'll just navigate for now.
    navigate(`/walks/${finalWalk.id}`);

    setLoading(false);
  } catch (err: any) {
    console.error('Error updating the walk:', err);
    setError(err?.message || 'Failed to update the walk session');
    setLoading(false);
  }
}

/**
 * EditWalk
 * ---------------------------------------------------------------------------
 * The main React Functional Component responsible for orchestrating the editing
 * of an existing dog walk session. In addition to rendering the WalkForm with
 * real-time context, it does:
 *  - Extract the walkId from URL params.
 *  - Maintain local walk state and loading indicators.
 *  - Setup a real-time WebSocket connection for updates from the server.
 *  - Provide callback handlers for location updates, photo preference changes,
 *    and emergency contact management.
 *  - Invoke fetchWalkData on mount to load existing data.
 *  - Pass handleSubmit logic to the form to complete updates.
 */
export const EditWalk: FC = () => {
  // --------------------------------------------------------------------------
  // 1) Extract 'walkId' from the route URL using react-router-dom's useParams.
  // --------------------------------------------------------------------------
  const { walkId } = useParams<{ walkId: string }>();
  const navigate = useNavigate();

  // --------------------------------------------------------------------------
  // 2) Local component states: walkData, loading indicator, error message.
  // --------------------------------------------------------------------------
  const [walkData, setWalkData] = useState<Walk | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // --------------------------------------------------------------------------
  // 3) Instantiate the WalkService to handle all walk-related logic.
  //    Typically, you might use dependency injection or a context.
  //    For demonstration, we create a new instance here.
  // --------------------------------------------------------------------------
  const walkService = new WalkService({} as any, {} as any);

  // --------------------------------------------------------------------------
  // 4) Setup a real-time WebSocket connection to handle updates for this walk.
  //    The URL or configuration can be environment-specific. For demonstration,
  //    we use a placeholder "wss://realtime.example.com/walk-updates".
  //    We attach an onMessage callback that delegates to handleRealTimeUpdate.
  // --------------------------------------------------------------------------
  const { lastMessage } = useWebSocket('wss://realtime.example.com/walk-updates', {
    share: true,
    shouldReconnect: () => true
  });

  // Whenever 'lastMessage' changes, we attempt to process it.
  useEffect(() => {
    if (lastMessage) {
      handleRealTimeUpdate(lastMessage, setWalkData, setError);
    }
  }, [lastMessage]);

  // --------------------------------------------------------------------------
  // 5) On component mount, retrieve the walk data using fetchWalkData.
  //    This also handles real-time schedule validation and sets up
  //    any relevant subscriptions via the WalkService.
  // --------------------------------------------------------------------------
  useEffect(() => {
    if (walkId) {
      fetchWalkData(walkId, setWalkData, setLoading, setError, walkService);
    }
  }, [walkId]);

  // --------------------------------------------------------------------------
  // 6) Provide an onCancel callback to revert or navigate away.
  //    In many cases, you'd simply go back to the walk details page.
  // --------------------------------------------------------------------------
  const handleCancel = useCallback(() => {
    navigate(-1);
  }, [navigate]);

  // --------------------------------------------------------------------------
  // 7) Provide a dedicated function for the child form's onSubmit prop.
  //    This references our handleSubmit above, passing the required
  //    references for setLoading, setError, and navigate.
  // --------------------------------------------------------------------------
  const onSubmitForm = useCallback(
    async (updatedWalk: Walk) => {
      await handleSubmit(updatedWalk, setLoading, setError, navigate, walkService);
    },
    [navigate, walkService]
  );

  // --------------------------------------------------------------------------
  // 8) Stubs or handlers for location tracking, photo sharing, and emergency
  //    contact updates. These are forwarded to the child WalkForm as needed
  //    (according to the JSON specification indicating usage).
  // --------------------------------------------------------------------------
  const handleLocationUpdate = useCallback((coords: any) => {
    // If we need to immediately update the server with new location preferences:
    console.info('Location update event from WalkForm:', coords);
    // In a real scenario, you might call walkService.updateLocation(...) here.
  }, []);

  const handlePhotoSettingsChange = useCallback((enabled: boolean) => {
    console.info('Photo sharing toggled to:', enabled);
    setWalkData((prev) => {
      if (!prev) return prev;
      return { ...prev, photoSharing: enabled };
    });
  }, []);

  const handleEmergencyContactUpdate = useCallback((contact: string) => {
    console.info('Emergency contact updated to:', contact);
    setWalkData((prev) => {
      if (!prev) return prev;
      return { ...prev, emergencyContact: contact };
    });
  }, []);

  // --------------------------------------------------------------------------
  // 9) Render the main UI: show any error or loading indicator, and then
  //    display the WalkForm for editing. The child form has onSubmit, onCancel,
  //    and additional callbacks for location, photo, and emergency contact.
  // --------------------------------------------------------------------------
  return (
    <div style={{ padding: 24 }}>
      <h1>Edit Walk</h1>

      {/* Display an error message if one is present */}
      {error && (
        <div style={{ color: 'red', marginBottom: 16 }}>
          <strong>Error:</strong> {error}
        </div>
      )}

      {/* A simple loading indicator */}
      {loading && <div style={{ marginBottom: 16 }}>Loading data, please wait...</div>}

      {/* Render form only if we have walk data */}
      {walkData && (
        <WalkForm
          /** The initial data used by the child form */
          initialData={walkData}
          /** Called when the user submits the form, containing updated walk data */
          onSubmit={onSubmitForm}
          /** Called when the user clicks cancel, returning to the previous screen */
          onCancel={handleCancel}
          /** Flag indicating if we're in a loading state (disables form fields) */
          isLoading={loading}
          /** Whether location tracking is enabled for this walk */
          locationTracking={walkData.locationTracking ?? false}
          /** Whether photo sharing is enabled for this walk */
          photoSharing={walkData.photoSharing ?? false}
          /** The walk's emergency contact details */
          emergencyContact={walkData.emergencyContact ?? ''}
          /** Additional walk preferences if relevant */
          walkPreferences={walkData.walkPreferences || {}}
          /** Called when location toggles or updates occur within the form */
          onLocationUpdate={handleLocationUpdate}
          /** Called when photo sharing toggles occur within the form */
          onPhotoSettingsChange={handlePhotoSettingsChange}
          /** Called when emergency contact changes are made within the form */
          onEmergencyContactUpdate={handleEmergencyContactUpdate}
        />
      )}

      {/* If no walkId, show a basic guard message */}
      {!walkId && <div>No walk specified for editing.</div>}
    </div>
  );
};