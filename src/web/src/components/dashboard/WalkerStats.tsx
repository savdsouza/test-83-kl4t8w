import React, {
  useEffect,
  useState,
  useMemo,
  useCallback,
} from 'react'; // ^18.0.0
import { Card } from '../common/Card'; // Internal component with elevation & className props
import { Walk, WalkStatus } from '../../types/walk.types'; // Provides Walk interface & WalkStatus enum
import { WalkService } from '../../services/walk.service'; // Service for fetching walk data (getWalks & getActiveWalks)

/**
 * WalkerStatsProps
 * ----------------------------------------------------------------------------
 * Describes the input properties required by the WalkerStats component.
 * - walkerId:      The unique identifier for the current walker whose stats
 *                  are displayed.
 * - className:     An optional CSS class name for additional styling.
 * - refreshInterval: Frequency in milliseconds for automatically refreshing
 *                    the statistics data via the WalkService.
 * - onError:       A callback function to handle any errors that occur during
 *                  data fetching or computations.
 */
export interface WalkerStatsProps {
  /** ID for which walker to retrieve stats */
  walkerId: string;

  /** Optional CSS class name for custom styling */
  className?: string;

  /** Milliseconds between automatic data refetch operations */
  refreshInterval?: number;

  /** Callback function for handling fetch or calculation errors */
  onError: (error: Error) => void;
}

/**
 * StatsData
 * ----------------------------------------------------------------------------
 * Represents the comprehensive data structure holding all relevant
 * performance metrics for a given walker, including historical stats,
 * earnings, ratings, and progress indicators.
 */
export interface StatsData {
  /** Total number of walks recorded in the system for this walker */
  totalWalks: number;

  /** Number of walks that reached a completed status */
  completedWalks: number;

  /** Accumulated earnings from all completed walks, in the app's default currency */
  totalEarnings: number;

  /** Average rating from owners, based on completed walks */
  averageRating: number;

  /** Count of currently active (in-progress/accepted) walks */
  activeWalks: number;

  /**
   * Weekly trend data showing the count of walks and sum of earnings
   * over a recent 7-day window, enabling quick visual insight
   * into short-term performance.
   */
  weeklyTrend: {
    walks: number;
    earnings: number;
  };

  /**
   * A numeric value representing how much of a monthly goal
   * a walker has achieved, typically displayed as a percentage.
   */
  monthlyGoalProgress: number;

  /**
   * A metric that reflects how many returning customers
   * the walker retains, often expressed as a percentage
   * or ratio indicating long-term satisfaction.
   */
  customerRetentionRate: number;

  /** Timestamp marking the last time these stats were computed or refreshed */
  lastUpdated: Date;
}

/**
 * calculateStats
 * ----------------------------------------------------------------------------
 * Generates a comprehensive statistics object from the provided array
 * of Walk entries. This function filters out invalid data, then:
 * 1) Counts total & completed walks.
 * 2) Computes sum of completed walk earnings.
 * 3) Calculates average rating across completed walks.
 * 4) Counts active walks (ACCEPTED or IN_PROGRESS).
 * 5) Determines a 7-day weekly trend for walk count & earnings.
 * 6) Computes a mock monthly goal progress percentage.
 * 7) Estimates a mock customer retention rate.
 * 8) Sets the lastUpdated timestamp to now.
 *
 * @param walks       An array of Walk objects fetched for the current walker.
 * @returns {StatsData} The aggregated stats, suitable for use in UI display.
 */
export function calculateStats(walks: Walk[]): StatsData {
  // Filter out invalid or incomplete walk objects:
  const validWalks = walks.filter(
    (w) =>
      w &&
      w.id &&
      typeof w.price === 'number' &&
      typeof w.rating === 'number' &&
      w.startTime &&
      w.endTime &&
      w.status
  );

  // Count total
  const totalWalks = validWalks.length;

  // Identify completed walks
  const completedWalksArray = validWalks.filter(
    (w) => w.status === WalkStatus.COMPLETED
  );
  const completedWalks = completedWalksArray.length;

  // Sum up the earnings of completed walks
  const totalEarnings = completedWalksArray.reduce(
    (sum, walk) => sum + walk.price,
    0
  );

  // Calculate average rating for completed walks
  const averageRating =
    completedWalks > 0
      ? completedWalksArray.reduce((acc, w) => acc + w.rating, 0) /
        completedWalks
      : 0;

  // Count active walks (ACCEPTED or IN_PROGRESS)
  const activeWalks = validWalks.filter(
    (w) =>
      w.status === WalkStatus.ACCEPTED || w.status === WalkStatus.IN_PROGRESS
  ).length;

  // Weekly trend (past 7 days)
  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const weeklySubset = completedWalksArray.filter(
    (w) => w.endTime && w.endTime >= sevenDaysAgo
  );
  const weeklyWalks = weeklySubset.length;
  const weeklyEarnings = weeklySubset.reduce((acc, w) => acc + w.price, 0);

  // Monthly goal progress (mocked as a simple ratio)
  // For demonstration, assume monthly goal is 20 completed walks by default:
  const monthlyGoalProgress = Math.min(
    100,
    (completedWalksArray.filter((w) => {
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return w.endTime && w.endTime >= thirtyDaysAgo;
    }).length /
      20) *
      100
  );

  // Customer retention (mocked)
  // In enterprise usage, we'd track repeat owners. Here we just set a placeholder:
  const customerRetentionRate = 75;

  // Complete stats object
  return {
    totalWalks,
    completedWalks,
    totalEarnings,
    averageRating,
    activeWalks,
    weeklyTrend: {
      walks: weeklyWalks,
      earnings: weeklyEarnings,
    },
    monthlyGoalProgress,
    customerRetentionRate,
    lastUpdated: new Date(),
  };
}

/**
 * WalkerStats
 * ----------------------------------------------------------------------------
 * React component that renders a real-time dashboard for dog walker performance,
 * including aggregated metrics from all walks, earnings, retention, and
 * ongoing sessions. Automatically refreshes data at specified intervals and
 * gracefully handles errors by invoking the onError callback.
 *
 * Steps:
 * 1) Initialize local state for stats, loading, and internal error handling.
 * 2) Instantiate or reference a WalkService to fetch data from the backend.
 * 3) Implement a data fetching routine that calls getWalks and getActiveWalks,
 *    merges or updates stats accordingly, and stores them in React state.
 * 4) Set up a refresh mechanism using refreshInterval to invoke the fetch routine
 *    at a defined cadence, supporting real-time analytics refresh.
 * 5) Leverage the memoized stats to avoid unnecessary re-renders.
 * 6) Render a Card-based layout containing key performance indicators.
 * 7) Provide a loading indicator or fallback UI while data is retrieved.
 * 8) Use onError callback to surface failures to the parent.
 * 9) Offer extensive commentary and structure for enterprise readiness.
 */
export const WalkerStats: React.FC<WalkerStatsProps> = ({
  walkerId,
  className,
  refreshInterval = 30000,
  onError,
}) => {
  /**
   * Local component state for storing the computed StatsData object.
   * Starts as null to represent an uninitialized load.
   */
  const [stats, setStats] = useState<StatsData | null>(null);

  /**
   * Boolean state to indicate if the component is in a loading phase,
   * used to conditionally render spinner or skeleton placeholders.
   */
  const [loading, setLoading] = useState<boolean>(true);

  /**
   * Internal error state for capturing errors during data fetch
   * cycles. The onError prop is invoked whenever a new error arises.
   */
  const [internalError, setInternalError] = useState<Error | null>(null);

  /**
   * Create an instance of WalkService. In a more complex setup,
   * we might inject a pre-configured service. For demonstration,
   * we instantiate locally. This can connect to real-time
   * websockets internally if needed.
   */
  const walkService = useMemo(() => {
    // A more advanced scenario could share a single instance
    // of walkService across the application
    return new WalkService(
      // Potentially pass in an ApiService or WebSocket service instance if required
      // For demonstration, we assume the constructor can handle defaults
      // or they are globally accessible
      // (apiService, wsService)
      // Here we pass undefined placeholders if needed
      undefined as any,
      undefined as any
    );
  }, []);

  /**
   * fetchData
   * ----------------------------------------------------------------------------
   * Asynchronously retrieves all walks for the specified walker,
   * retrieves active walks, merges data for real-time metrics, and
   * calculates updated StatsData. Handles any errors gracefully by
   * invoking both setInternalError and onError for upper-layer
   * awareness and logging.
   */
  const fetchData = useCallback(async () => {
    try {
      setLoading(true);

      // Retrieve ALL walks from the backend
      const allWalks: Walk[] = await walkService.getWalks(walkerId);

      // Retrieve ACTIVE walks for additional real-time count
      const active: Walk[] = await walkService.getActiveWalks(walkerId);

      // Combine or use the data as needed.
      // For demonstration, we will rely mostly on the allWalks array
      // to compute stats. However, we can override the activeWalks
      // computed in calculateStats with the actual length from
      // the real-time getActiveWalks call.
      const baseStats = calculateStats(allWalks);
      const updatedStats: StatsData = {
        ...baseStats,
        activeWalks: active.length,
        lastUpdated: new Date(),
      };

      // Update local component state with computed stats
      setStats(updatedStats);
      setLoading(false);
      setInternalError(null);
    } catch (err: any) {
      // In case of failure, store error internally and pass it upstream
      const errorInstance =
        err instanceof Error ? err : new Error(String(err));
      setInternalError(errorInstance);
      onError(errorInstance);
      setLoading(false);
    }
  }, [onError, walkerId, walkService]);

  /**
   * useEffect: Data Fetch Initialization
   * ----------------------------------------------------------------------------
   * Immediately fetch stats upon first render, ensuring the component
   * has the latest data. Also sets up an interval to refresh the data
   * according to the refreshInterval prop for real-time updates.
   */
  useEffect(() => {
    let intervalId: NodeJS.Timeout | null = null;

    // Trigger an initial fetch
    fetchData();

    // Set up periodic refresh if refreshInterval > 0
    if (refreshInterval > 0) {
      intervalId = setInterval(() => {
        fetchData();
      }, refreshInterval);
    }

    // Cleanup function to cancel intervals on unmount
    return () => {
      if (intervalId) {
        clearInterval(intervalId);
      }
    };
  }, [fetchData, refreshInterval]);

  /**
   * Conditionally render a loading state or fallback UI if needed.
   * For enterprise readiness, we might show skeleton screens or
   * a placeholder Card with spinners. If an error occurred, we
   * could also handle it in a specialized UI section.
   */
  if (loading && !stats) {
    return (
      <Card className={className} elevation={2} role="region" tabIndex={0}>
        <div
          style={{
            padding: '1rem',
            textAlign: 'center',
            fontSize: '1rem',
            fontWeight: 500,
          }}
        >
          Loading walker statistics…
        </div>
      </Card>
    );
  }

  /**
   * If there's an internalError and we already finished loading,
   * we can show a partial fallback if desired. onError is invoked
   * from fetchData, so the parent container also knows about it.
   */
  if (!loading && internalError) {
    return (
      <Card className={className} elevation={1} role="region" tabIndex={0}>
        <div style={{ padding: '1rem', textAlign: 'center', color: '#F44336' }}>
          Unable to load walker statistics. Please try again later.
        </div>
      </Card>
    );
  }

  /**
   * Render the core stats data once loaded. We use a Card container
   * to group these metrics consistently. In a production UI, these
   * might be further broken into specialized subcomponents or charts
   * for advanced data visualization (e.g., weekly trends in bar
   * or line graphs).
   */
  return (
    <Card
      className={className}
      elevation={2}
      role="region"
      tabIndex={0}
      style={{ padding: '1rem', display: 'flex', flexDirection: 'column' }}
    >
      {stats && (
        <>
          <h2 style={{ marginBottom: '1rem' }}>Walker Performance Dashboard</h2>

          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Total Walks:</strong> {stats.totalWalks}
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Completed Walks:</strong> {stats.completedWalks}
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Total Earnings:</strong> ${stats.totalEarnings.toFixed(2)}
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Average Rating:</strong>{' '}
            {stats.averageRating.toFixed(2)} / 5
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Active Walks:</strong> {stats.activeWalks}
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Weekly Trend (Walks):</strong> {stats.weeklyTrend.walks}
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Weekly Trend (Earnings):</strong> $
            {stats.weeklyTrend.earnings.toFixed(2)}
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Monthly Goal Progress:</strong>{' '}
            {Math.round(stats.monthlyGoalProgress)}%
          </div>
          <div style={{ marginBottom: '0.5rem' }}>
            <strong>Customer Retention Rate:</strong>{' '}
            {stats.customerRetentionRate}%
          </div>
          <div style={{ marginTop: '1rem', fontStyle: 'italic' }}>
            <small>
              Last Updated: {stats.lastUpdated.toLocaleString()}
            </small>
          </div>
        </>
      )}
    </Card>
  );
};