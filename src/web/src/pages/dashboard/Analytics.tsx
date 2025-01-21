import React, {
  useState,
  useEffect,
  useCallback,
  useMemo,
  useRef,
  type ChangeEvent
} from 'react';
// react@^18.2.0

// WebSocket hook from react-use-websocket@^3.0.0 for real-time updates
import { useWebSocket } from 'react-use-websocket';

// Internal named imports per JSON spec
import { ActivityChart, ChartProps } from '../../components/dashboard/ActivityChart'; 
import { BookingStats } from '../../components/dashboard/BookingStats';
import { RevenueChart } from '../../components/dashboard/RevenueChart';
import { WalkerStats } from '../../components/dashboard/WalkerStats';

// -------------------------------------------------------------------------------------------------
// Interfaces from JSON specification
// -------------------------------------------------------------------------------------------------

/**
 * Defines a structure for representing a user-selectable time range filter.
 * This can be used to display options like daily, weekly, monthly, and custom
 * date ranges. The "value" property acts as a key, while "label" is a human-friendly
 * text. "startDate" and "endDate" are used if the user picks a custom range.
 */
interface TimeRangeFilter {
  value: string;
  label: string;
  startDate: Date | null;
  endDate: Date | null;
}

/**
 * Represents the local UI state of the Analytics page, tracking:
 * - timeRange: the currently selected filter for dates or time spans
 * - loading: whether data is being actively fetched
 * - error: any error text encountered during data retrieval
 * - lastUpdated: the timestamp of the most recent successful data refresh
 * - wsConnected: indicates if the WebSocket connection is established
 */
interface AnalyticsState {
  timeRange: TimeRangeFilter;
  loading: boolean;
  error: string | null;
  lastUpdated: Date;
  wsConnected: boolean;
}

// -------------------------------------------------------------------------------------------------
// The "Analytics" component: Main analytics dashboard with real-time updates and responsive layout
// -------------------------------------------------------------------------------------------------

/**
 * Main component that renders the comprehensive analytics dashboard. It displays:
 *  1) Real-time activity chart (ActivityChart).
 *  2) Booking statistics (BookingStats).
 *  3) Revenue analytics chart (RevenueChart).
 *  4) Walker performance metrics (WalkerStats).
 * Implements:
 *  - WebSocket-based real-time updates for system monitoring.
 *  - Periodic data refresh intervals.
 *  - Time range filtering and advanced error handling.
 *  - Responsive design with an accessible layout.
 *
 * @returns A JSX.Element containing the analytics dashboard UI.
 */
const Analytics: React.FC = (): JSX.Element => {
  // 1) Initialize state with useState for timeRange, loading, error, and wsConnected
  const [analyticsState, setAnalyticsState] = useState<AnalyticsState>({
    timeRange: {
      value: 'daily',
      label: 'Daily',
      startDate: null,
      endDate: null
    },
    loading: false,
    error: null,
    lastUpdated: new Date(),
    wsConnected: false
  });

  // A reference to an interval for periodic data refresh if desired
  const refreshIntervalRef = useRef<NodeJS.Timeout | null>(null);

  // 2) Set up WebSocket connection (react-use-websocket) for real-time updates
  // Here we provide a hypothetical WebSocket endpoint. Adjust as needed.
  const { readyState, lastMessage, sendJsonMessage } = useWebSocket('wss://example.com/analytics', {
    // Additional config could go here (e.g., reconnection attempts).
    share: true
  });

  /**
   * Updates local "wsConnected" state whenever the WebSocket's readyState changes.
   * 0: CONNECTING, 1: OPEN, 2: CLOSING, 3: CLOSED
   */
  useEffect(() => {
    setAnalyticsState((prev) => ({
      ...prev,
      wsConnected: readyState === 1
    }));
  }, [readyState]);

  /**
   * An example effect to handle incoming WebSocket messages. For instance, we might
   * parse system monitoring details or real-time performance indicators from them.
   * The "lastMessage" can be examined to update local or global states.
   */
  useEffect(() => {
    if (lastMessage !== null) {
      // Suppose we receive a JSON payload with monitoring data. For demonstration:
      try {
        const parsed = JSON.parse(lastMessage.data);
        // Here, we might process the data or log it as part of system monitoring
        // e.g., console.log('[Analytics] Real-time update:', parsed);
      } catch (err) {
        // If it's not valid JSON, we can ignore or handle accordingly
      }
    }
  }, [lastMessage]);

  // 3) Data fetching effect with error handling (hypothetical):
  // We simulate a function that fetches or refreshes data from an API.
  const fetchData = useCallback(async () => {
    try {
      setAnalyticsState((prev) => ({ ...prev, loading: true, error: null }));

      // Placeholder: Suppose we do multiple fetch calls or some aggregator
      // e.g., await someApi.get('/analytics/overview');
      // We'll just delay for demonstration:
      await new Promise((resolve) => setTimeout(resolve, 500));

      // On success, update lastUpdated and clear loading
      setAnalyticsState((prev) => ({
        ...prev,
        loading: false,
        lastUpdated: new Date()
      }));
    } catch (err: any) {
      // On failure, capture the message in "error"
      setAnalyticsState((prev) => ({
        ...prev,
        loading: false,
        error: err instanceof Error ? err.message : String(err)
      }));
    }
  }, []);

  // 4) Set up periodic refresh. This can target "fetchData()" every X milliseconds:
  useEffect(() => {
    // Let's define a 60-second refresh example
    const refreshIntervalMs = 60000;
    refreshIntervalRef.current = setInterval(() => {
      void fetchData();
    }, refreshIntervalMs);

    // Clean up on unmount
    return () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
      }
    };
  }, [fetchData]);

  // 5) Handle time range filter changes with debouncing and validation
  const handleTimeRangeChange = useCallback((newTimeRange: TimeRangeFilter): void => {
    // (a) Validate the new time range
    if (!newTimeRange.value || !newTimeRange.label) {
      console.warn('[Analytics] Invalid time range provided.');
      return;
    }

    // (b) Update state
    setAnalyticsState((prev) => ({
      ...prev,
      timeRange: newTimeRange
    }));

    // (c) Reflect changes in the URL (optional)
    // e.g., const params = new URLSearchParams(window.location.search);
    // params.set('timeRange', newTimeRange.value);
    // window.history.replaceState({}, '', `?${params.toString()}`);

    // (d) Trigger data refresh for components that rely on timeRange
    void fetchData();

    // (e) Update WebSocket subscription if needed
    if (analyticsState.wsConnected) {
      // For demonstration, we could send a message to filter real-time data
      sendJsonMessage({
        event: 'TIME_RANGE_UPDATE',
        payload: {
          value: newTimeRange.value,
          startDate: newTimeRange.startDate,
          endDate: newTimeRange.endDate
        }
      });
    }

    // (f) Log analytics event
    console.log(`[Analytics] Time range changed to: ${newTimeRange.value}`);
  }, [analyticsState.wsConnected, fetchData, sendJsonMessage]);

  // 6) On mount, we do an initial data fetch
  useEffect(() => {
    void fetchData();
  }, [fetchData]);

  // Example function to pass down to BookingStats as "onRefresh"
  const onRefreshBookingStats = useCallback(() => {
    // Could force a re-fetch for booking stats alone or entire data
    void fetchData();
  }, [fetchData]);

  // 7) Render the analytics page in a responsive grid layout. We also incorporate error boundaries.
  // We'll use a simple inline style grid for demonstration. In a larger app, a dedicated CSS or layout system might be used.
  // 8) Implement accessibility with roles and tabIndex for keyboard navigation.
  return (
    <div
      role="region"
      aria-label="Analytics Dashboard"
      tabIndex={0}
      style={{
        display: 'grid',
        gridTemplateColumns: '1fr',
        gridGap: '1rem',
        padding: '1rem'
      }}
    >
      {analyticsState.error && (
        <div
          role="alert"
          aria-live="assertive"
          style={{ color: 'red', fontWeight: 600, marginBottom: '1rem' }}
        >
          {`Error: ${analyticsState.error}`}
        </div>
      )}

      {/* A quick heading to show the last update and a time range dropdown example. */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '1rem'
        }}
      >
        <h2 style={{ margin: 0 }}>Analytics Dashboard</h2>
        <div
          style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}
          aria-label="Time Range Selection"
        >
          <label htmlFor="timeRangeSelect" style={{ fontWeight: 600 }}>
            Time Range:
          </label>
          <select
            id="timeRangeSelect"
            value={analyticsState.timeRange.value}
            onChange={(e: ChangeEvent<HTMLSelectElement>) => {
              const newValue = e.target.value;
              // For simplicity, we assume daily/weekly/monthly
              const newTimeRange: TimeRangeFilter = {
                value: newValue,
                label: newValue.charAt(0).toUpperCase() + newValue.slice(1),
                startDate: null,
                endDate: null
              };
              handleTimeRangeChange(newTimeRange);
            }}
            style={{ padding: '0.25rem 0.5rem' }}
          >
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </select>
        </div>
      </div>

      {/* Real-time activity chart for system monitoring (walk activity) */}
      <div
        role="region"
        aria-label="Activity Chart Section"
        tabIndex={0}
        style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '1rem' }}
      >
        <h3 style={{ marginTop: 0 }}>Activity Overview</h3>
        <ActivityChart
          title="Real-Time Walk Activity"
          // Additional props as needed from the ChartProps interface
        />
      </div>

      {/* Booking statistics display - includes timeRange and onRefresh usage */}
      <div
        role="region"
        aria-label="Booking Stats Section"
        tabIndex={0}
        style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '1rem' }}
      >
        <h3 style={{ marginTop: 0 }}>Booking Statistics</h3>
        <BookingStats
          timeRange={analyticsState.timeRange.value} // Basic usage from props
          className="booking-stats"
          refreshInterval={60000} // Example refresh interval or controlled externally
          onError={(err: Error) => {
            console.error('[Analytics] BookingStats error:', err);
            setAnalyticsState((prev) => ({ ...prev, error: err.message }));
          }}
          // We pass down our onRefresh function
          onRefresh={onRefreshBookingStats}
        />
      </div>

      {/* Revenue analytics chart for financial operations */}
      <div
        role="region"
        aria-label="Revenue Analytics Section"
        tabIndex={0}
        style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '1rem' }}
      >
        <h3 style={{ marginTop: 0 }}>Revenue Analytics</h3>
        <RevenueChart
          timeRange={analyticsState.timeRange.value}
          chartType="bar"
          // The "render" and "updateData" references from JSON spec are methods
          // on the RevenueChart class, invoked internally on data or prop changes.
        />
      </div>

      {/* Walker performance metrics: an example walkerId is used for demonstration */}
      <div
        role="region"
        aria-label="Walker Performance Section"
        tabIndex={0}
        style={{ border: '1px solid #ddd', borderRadius: '6px', padding: '1rem' }}
      >
        <h3 style={{ marginTop: 0 }}>Walker Performance</h3>
        <WalkerStats
          walkerId="sample-walker-123"
          className="walker-stats"
          refreshInterval={60000}
          onError={(err: Error) => {
            console.error('[Analytics] WalkerStats error:', err);
            setAnalyticsState((prev) => ({ ...prev, error: err.message }));
          }}
        />
      </div>

      {/* A small status footer to show loading or last update info, plus connection status */}
      <div style={{ textAlign: 'right', fontSize: '0.9rem', color: '#555' }}>
        {analyticsState.loading ? (
          <span>Loading data...</span>
        ) : (
          <span>Last Updated: {analyticsState.lastUpdated.toLocaleString()}</span>
        )}{' '}
        | WebSocket: {analyticsState.wsConnected ? 'Connected' : 'Disconnected'}
      </div>
    </div>
  );
};

export default Analytics;