import React, {
  useState,
  useEffect,
  useMemo,
  useCallback,
  type ReactElement
} from 'react';

/**
 * ----------------------------------------------------------------------------
 * External Dependencies (per JSON spec with versions in comments)
 * ----------------------------------------------------------------------------
 */
// react-use-websocket@^3.0.0
import { useWebSocket, ReadyState } from 'react-use-websocket';

/**
 * ----------------------------------------------------------------------------
 * Internal Dependencies (per JSON spec)
 * ----------------------------------------------------------------------------
 * 1) ActivityChart (default import), providing the chart for displaying walk
 *    activity trends in real time or through aggregated data.
 * 2) BookingStats ({ timeRange }) for presenting booking statistics.
 * 3) WalkerStats ({ walkerId }) for presenting walker-specific statistics.
 * 4) useAuth ({ user }) hook for authenticated user info.
 * 5) ErrorBoundary (default import) for robust error handling at component level.
 * 6) Loading (default import) for displaying a loading indicator.
 */
import ActivityChart from '../../components/dashboard/ActivityChart';
import { BookingStats } from '../../components/dashboard/BookingStats';
import { WalkerStats } from '../../components/dashboard/WalkerStats';
import { useAuth } from '../../hooks/useAuth';
import ErrorBoundary from '../common/ErrorBoundary';
import Loading from '../common/Loading';

/**
 * ----------------------------------------------------------------------------
 * Interfaces from JSON Specification
 * ----------------------------------------------------------------------------
 */

/**
 * DashboardProps
 * Defines the optional props accepted by the Dashboard component, including
 * an optional className for advanced styling or theming.
 */
export interface DashboardProps {
  /**
   * An optional CSS class name for custom styling, appended to the
   * component's root container.
   */
  className?: string;
}

/**
 * DashboardMetrics
 * Represents the shape of consolidated dashboard metrics, recognized in the
 * JSON by name "DashboardMetrics". We detail success metrics including user
 * adoption, walker retention, and booking completion rates (as required by
 * success criteria), plus optional placeholders for further expansions.
 */
export interface DashboardMetrics {
  /**
   * Tracks user adoption rates, e.g. new sign-ups or active users.
   */
  userAdoption: number;
  /**
   * Reflects the retention rate of walkers over a given period.
   */
  walkerRetention: number;
  /**
   * The booking completion rate (percentage).
   */
  bookingCompletionRate: number;
  /**
   * Additional placeholders for advanced success or system metrics.
   */
  [key: string]: number;
}

/**
 * DashboardState
 * Reflects the local state for the main dashboard page, storing time range
 * selections, loading/error states, real-time metrics data, and online status.
 */
interface DashboardState {
  /**
   * Selected time range for metrics (e.g., 'daily', 'weekly', 'monthly').
   */
  timeRange: string;
  /**
   * Indicates if the dashboard is currently fetching or processing data.
   */
  loading: boolean;
  /**
   * Captures any encountered Error object or null if no errors are present.
   */
  error: Error | null;
  /**
   * Holds the current set of dashboard metrics retrieved or computed.
   */
  metrics: DashboardMetrics;
  /**
   * Reflects live WebSocket connection status (online/offline).
   */
  isOnline: boolean;
}

/**
 * ----------------------------------------------------------------------------
 * "handleTimeRangeChange" function specification from JSON
 * ----------------------------------------------------------------------------
 * Updates the timeRange state and triggers a data refresh. Also demonstrates
 * updating URL parameters and tracking analytics events.
 */
function handleTimeRangeChange(
  newRange: string,
  setStateCallback: React.Dispatch<React.SetStateAction<DashboardState>>,
  refreshFn: () => void
): void {
  // 1) Validate new time range value
  const validRanges = ['daily', 'weekly', 'monthly'];
  if (!validRanges.includes(newRange)) {
    // If invalid, default or short-circuit; for demonstration, default to 'daily'
    // In production, we could throw an error or show a warning
    newRange = 'daily';
  }

  // 2) Update timeRange in local state
  setStateCallback((prev) => ({ ...prev, timeRange: newRange }));

  // 3) Trigger metrics refresh
  refreshFn();

  // 4) Update URL parameters (demo approach: basic manipulation via history API)
  const params = new URLSearchParams(window.location.search);
  params.set('timeRange', newRange);
  window.history.replaceState({}, '', `${window.location.pathname}?${params.toString()}`);

  // 5) Track analytics event (for demonstration, console log)
  console.log(`[Analytics] Time range changed to: ${newRange}`);
}

/**
 * ----------------------------------------------------------------------------
 * "handleWebSocketMessage" function specification from JSON
 * ----------------------------------------------------------------------------
 * Interprets incoming WebSocket messages, updates relevant metrics, and triggers UI changes.
 */
function handleWebSocketMessage(
  message: any,
  setStateCallback: React.Dispatch<React.SetStateAction<DashboardState>>
): void {
  try {
    // 1) Validate message format
    if (!message || typeof message !== 'object' || !message.type) {
      console.warn('[Dashboard] Received invalid WS message');
      return;
    }

    // 2) Parse (already done if we have a JSON object, but could do deeper checks)
    const { type, payload } = message;

    // 3) Update relevant metrics if message type matches
    if (type === 'DASHBOARD_UPDATE') {
      // Example structure: { payload: { userAdoption: number, walkerRetention: number, bookingCompletionRate: number } }
      setStateCallback((prev) => ({
        ...prev,
        metrics: {
          ...prev.metrics,
          ...payload // merges new or updated fields
        }
      }));
    }

    // 4) Optionally handle error cases or unknown message types
    if (type === 'ERROR') {
      console.error('[Dashboard] Received WS error message:', payload);
      setStateCallback((prev) => ({ ...prev, error: new Error(payload?.message || 'WS Error') }));
    }

    // 5) Trigger UI updates automatically by virtue of setState
  } catch (err) {
    console.error('[Dashboard] Failed to handle WebSocket message:', err);
    setStateCallback((prev) => ({ ...prev, error: err instanceof Error ? err : new Error(String(err)) }));
  }
}

/**
 * ----------------------------------------------------------------------------
 * Main Dashboard Component
 * ----------------------------------------------------------------------------
 * Renders a comprehensive overview of key platform metrics, success criteria,
 * and real-time data. Implements role-based views, time-range filtering,
 * and system monitoring features with WebSocket-based updates.
 *
 * Steps (from JSON specification):
 *  1) Initialize dashboard state with useState hooks
 *  2) Get authenticated user data from useAuth hook
 *  3) Set up WebSocket connection for real-time updates (useWebSocket)
 *  4) Initialize data refresh interval with useEffect
 *  5) Set up error boundary for error handling
 *  6) Handle role-based content rendering
 *  7) Implement accessibility features
 *  8) Render loading state while data loads
 *  9) Render error state if errors occur
 * 10) Render BookingStats with selected time range
 * 11) Render ActivityChart for walk activity
 * 12) Render WalkerStats for walker users
 * 13) Clean up subscriptions on unmount
 */
const Dashboard: React.FC<DashboardProps> = (props: DashboardProps): ReactElement => {
  // (1) Initialize local state
  const [dashboardState, setDashboardState] = useState<DashboardState>({
    timeRange: 'daily',
    loading: false,
    error: null,
    metrics: {
      userAdoption: 0,
      walkerRetention: 0,
      bookingCompletionRate: 0
    },
    isOnline: true
  });

  // (2) Obtain user data from useAuth
  const { user } = useAuth();

  /**
   * Step (3) Setup WebSocket connection
   * This is real-time monitoring for success metrics, bookings, walker retention, etc.
   * For demonstration, we assume an endpoint "wss://example.com/dashboard-updates"
   * that emits JSON messages with a "type" field describing the event.
   */
  const socketUrl = 'wss://example.com/dashboard-updates';
  const { sendMessage, lastMessage, readyState } = useWebSocket(socketUrl, {
    // Attempt to reconnect indefinitely
    shouldReconnect: () => true,
    // Optionally: add query params for authentication or user ID
    queryParams: { userId: user?.id || '' }
  });

  /**
   * Derived readability of WebSocket connection (Step 7: accessibility or system info).
   * We'll map the readyState to a textual label for user-friendly or debugging outputs.
   */
  const connectionStatusLabel = useMemo<string>(() => {
    switch (readyState) {
      case ReadyState.CONNECTING:
        return 'Connecting...';
      case ReadyState.OPEN:
        return 'Online';
      case ReadyState.CLOSING:
        return 'Closing...';
      case ReadyState.CLOSED:
        return 'Offline';
      default:
        return 'Unrecognized';
    }
  }, [readyState]);

  // Process incoming WebSocket messages (Step 3.2).
  useEffect(() => {
    if (lastMessage && lastMessage.data) {
      try {
        const parsed = JSON.parse(lastMessage.data);
        handleWebSocketMessage(parsed, setDashboardState);
      } catch (parseError) {
        console.error('[Dashboard] Invalid JSON message from WS:', parseError);
      }
    }
  }, [lastMessage]);

  // Update isOnline flag based on readyState changes
  useEffect(() => {
    setDashboardState((prev) => ({
      ...prev,
      isOnline: readyState === ReadyState.OPEN
    }));
  }, [readyState]);

  /**
   * Step (4) Initialize data refresh with useEffect
   * We simulate a refresh for metrics from a hypothetical endpoint on an interval or
   * each time the user changes the time range. This can be replaced with real requests.
   */
  const refreshDashboardData = useCallback((): void => {
    setDashboardState((prev) => ({ ...prev, loading: true }));
    // Simulate a fetch call to an API that returns success metrics
    setTimeout(() => {
      // For demonstration, we randomly generate some metric values
      const randomUserAdoption = Math.floor(Math.random() * 5000);
      const randomWalkerRetention = Math.random() * 100;
      const randomBookingRate = Math.random() * 100;

      setDashboardState((prev) => ({
        ...prev,
        loading: false,
        error: null,
        metrics: {
          ...prev.metrics,
          userAdoption: randomUserAdoption,
          walkerRetention: parseFloat(randomWalkerRetention.toFixed(2)),
          bookingCompletionRate: parseFloat(randomBookingRate.toFixed(2))
        }
      }));
    }, 1000);
  }, []);

  // Trigger a data refresh on component mount + every timeRange change
  useEffect(() => {
    refreshDashboardData();
    // Clean up might be needed if we had subscriptions, but the setTimeout is ephemeral
    // so no specific unmount cleanup is strictly required here
  }, [refreshDashboardData, dashboardState.timeRange]);

  /**
   * handleTimeRangeChange method, matching the JSON specification's function signature
   */
  const onTimeRangeChange = (newRange: string): void => {
    handleTimeRangeChange(newRange, setDashboardState, refreshDashboardData);
  };

  /**
   * Step (5) Wrap the entire rendering in an ErrorBoundary for robust error handling.
   */
  return (
    <ErrorBoundary>
      {/* Step 7 (Accessibility Features): We can provide some aria-labels or roles */}
      <section
        aria-label="Dashboard Section"
        className={props.className || ''}
        style={{ padding: '1rem' }}
      >
        {/* Step 8: Render loading state if needed */}
        {dashboardState.loading && (
          <div style={{ marginBottom: '1rem' }}>
            <Loading text="Loading Dashboard Metrics..." />
          </div>
        )}

        {/* Step 9: Render error state if present */}
        {dashboardState.error && (
          <div style={{ color: '#f44336', fontWeight: 500, marginBottom: '1rem' }}>
            An error occurred: {dashboardState.error.message}
          </div>
        )}

        {/* Step 3.1: Show connection status from the WebSocket for user or dev reference */}
        <div style={{ marginBottom: '0.5rem' }}>
          <strong>Connection Status:</strong> {connectionStatusLabel}
        </div>

        {/* Step 10: Render BookingStats for "OWNER" role, or also for "ADMIN" who might want
            an overview of the entire booking system. We pass the timeRange from state. */}
        {(user?.role === 'OWNER' || user?.role === 'ADMIN') && (
          <BookingStats
            timeRange={dashboardState.timeRange}
            className="booking-stats"
            refreshInterval={60000} // example 1-min refresh within the stats component
          />
        )}

        {/* Step 12: Render WalkerStats if user is "WALKER" or "ADMIN" wanting to see aggregated walker data */}
        {(user?.role === 'WALKER' || user?.role === 'ADMIN') && (
          <WalkerStats
            walkerId={user?.id || 'unknown-walker'} // assumed user ID for the walker
            className="walker-stats"
            refreshInterval={60000}
            onError={(err: Error) => {
              console.error('[Dashboard] WalkerStats error:', err);
              setDashboardState((prev) => ({ ...prev, error: err }));
            }}
          />
        )}

        {/* Step 11: Render ActivityChart for walk activity trends (always visible as a real-time feature) */}
        <div style={{ marginTop: '1rem' }}>
          <ActivityChart title="Platform-wide Walk Activity Trends" />
        </div>

        {/* Provide a simple time range switcher to demonstrate handleTimeRangeChange */}
        <div style={{ marginTop: '1rem' }}>
          <div style={{ marginBottom: '0.5rem' }}>Select Time Range:</div>
          <button
            type="button"
            onClick={() => onTimeRangeChange('daily')}
            style={{ marginRight: '0.5rem' }}
          >
            Daily
          </button>
          <button
            type="button"
            onClick={() => onTimeRangeChange('weekly')}
            style={{ marginRight: '0.5rem' }}
          >
            Weekly
          </button>
          <button type="button" onClick={() => onTimeRangeChange('monthly')}>
            Monthly
          </button>
        </div>

        {/* Demonstration of the success metrics (userAdoption, walkerRetention, bookingCompletionRate) */}
        <div style={{ marginTop: '2rem', border: '1px solid #ddd', padding: '1rem' }}>
          <h2>Key Success Metrics (Time Range: {dashboardState.timeRange})</h2>
          <ul style={{ listStyleType: 'disc', marginLeft: '20px' }}>
            <li>User Adoption: {dashboardState.metrics.userAdoption}</li>
            <li>Walker Retention: {dashboardState.metrics.walkerRetention}%</li>
            <li>Booking Completion Rate: {dashboardState.metrics.bookingCompletionRate}%</li>
          </ul>
        </div>
      </section>
    </ErrorBoundary>
  );
};

export default Dashboard;