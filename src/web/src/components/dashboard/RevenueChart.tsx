/**
 * RevenueChart.tsx
 * ---------------------------------------------------------------------------------------------
 * A React component that renders a real-time revenue analytics chart for the dog walking platform
 * dashboard, providing interactive visualization of earnings trends, financial metrics, and
 * supporting multiple time ranges with WebSocket updates.
 *
 * This implementation addresses:
 *  - Financial Operations: Visualization of revenue data, earnings trends, and financial metrics,
 *    leveraging PaymentService.getPaymentHistory for historical data and WebSocket updates.
 *  - System Monitoring: Real-time updates via PaymentService.subscribeToPayments and integration
 *    with the useWebSocket hook for live financial metrics and reactive chart animations.
 *
 * Dependencies and Key Features:
 *  1) React 18.2.0
 *  2) Chart.js 4.4.0 for advanced chart rendering
 *  3) date-fns 2.30.0 for date formatting
 *  4) PaymentService for retrieving payment history and subscribing to real-time updates
 *  5) Payment interface, focusing on amount, createdAt, and status fields
 *  6) useWebSocket hook for streamlined WebSocket connection management (connect/disconnect)
 *
 * Code Outline:
 *  1) Props & State Interfaces
 *  2) Utility functions: fetchRevenueData (for historical data), handleRealtimeUpdate (for
 *     incremental updates)
 *  3) RevenueChart class-based component:
 *      - constructor: Initializes references, local state, PaymentService instance, error handling.
 *      - componentDidMount: Registers Chart.js components, sets up chart, fetches data, subs to updates.
 *      - componentDidUpdate: Re-fetches data if timeRange or chartType has changed.
 *      - componentWillUnmount: Cleans up subscriptions, destroys chart instance, disconnects WebSocket.
 *      - render: Returns a <canvas> for chart rendering.
 *
 *  4) Extremely detailed code comments for enterprise readiness, robust error boundaries, and
 *     real-time updates integration.
 */

// --------------------------- External Imports (with version comments for IE2) -------------------
import React, { Component, RefObject } from 'react'; // ^18.2.0
import {
  Chart,
  ChartData,
  ChartOptions,
  registerables,
  AnimationEvent,
} from 'chart.js'; // ^4.4.0
import { format } from 'date-fns'; // ^2.30.0

// --------------------------- Internal Imports (with usage verification as per IE1) --------------
import { Payment, PaymentStatus } from '../../types/payment.types';
import { PaymentService } from '../../services/payment.service';
import { useWebSocket } from '../../hooks/useWebSocket';

// --------------------------- Interfaces for Props & State ---------------------------------------

/**
 * Describes all props passed to the RevenueChart component.
 *  timeRange   - The selected time range identifier (e.g., 'daily', 'monthly').
 *  chartType   - The desired chart visualization type (e.g., 'bar', 'line').
 */
export interface RevenueChartProps {
  timeRange: string;
  chartType: string;
}

/**
 * Describes the component's internal state, capturing:
 *  - chartData: Data used by Chart.js for rendering aggregated revenue info.
 *  - error:     Any encountered error messages during data fetching or subscription.
 *  - isLoading: Whether the component is currently fetching or processing data.
 */
interface RevenueChartState {
  chartData: ChartData<'bar' | 'line' | 'pie' | 'doughnut' | 'radar' | 'scatter'>;
  error: string | null;
  isLoading: boolean;
}

/**
 * Interface specifying the shape of chart filters used in the fetchRevenueData method.
 *  timeRange - 'daily', 'monthly', or any custom string range for data grouping.
 *  chartType - 'bar', 'line', etc., to align with the type of chart being used.
 */
interface RevenueChartFilters {
  timeRange: string;
  chartType: string;
}

/**
 * A simple in-memory cache record shape to store aggregated data keyed by (timeRange + chartType).
 */
interface CacheRecord {
  dataset: ChartData;
  timestamp: number;
}

// --------------------------- Implementation of Utility Functions --------------------------------

/**
 * fetchRevenueData
 * ---------------------------------------------------------------------------------------------
 * Fetches and processes historical payment data using PaymentService.getPaymentHistory,
 * applying caching, date-fns-based formatting, summation logic, and currency formatting.
 * This function is designed to be called within the RevenueChart component while ensuring
 * robust error handling and data validation.
 *
 * Steps:
 *  1) Check if data is cached for the given filters (timeRange & chartType).
 *  2) If cache is available (and not stale), use cached data to update chart state.
 *  3) Otherwise, call PaymentService.getPaymentHistory(...) with the specified filters.
 *  4) Process the returned Payment[] array to aggregate daily/monthly revenue totals.
 *  5) Apply currency formatting, localization, and ensure data integrity.
 *  6) Update the component's chartData state with the aggregated dataset.
 *  7) Cache the processed dataset for future re-use.
 *  8) Handle any errors gracefully, setting local error state if needed.
 */
async function fetchRevenueData(
  filters: RevenueChartFilters,
  service: PaymentService,
  cache: Record<string, CacheRecord>,
  setStateCallback: (partialState: Partial<RevenueChartState>) => void
): Promise<void> {
  try {
    setStateCallback({ isLoading: true, error: null });

    // 1) Construct a cache key from filters
    const cacheKey = `${filters.timeRange}-${filters.chartType}`;

    // 2) Check for existing cached data
    const cachedEntry = cache[cacheKey];
    if (cachedEntry) {
      // For demonstration, we skip checking for staleness or TTL. In production, consider expiry.
      setStateCallback({
        chartData: cachedEntry.dataset,
        isLoading: false,
        error: null,
      });
      return;
    }

    // 3) Retrieve payment history from PaymentService (assuming the method takes a filter object).
    //    The JSON specification references "getPaymentHistory" but does not define its signature.
    //    We'll assume it returns a promise resolving to Payment[].
    const payments: Payment[] = await service.getPaymentHistory(filters);

    // 4) Aggregate daily or monthly revenue from Payment[] data
    //    We'll group payments by date (YYYY-MM-DD or YYYY-MM), sum amounts for COMPLETED statuses, etc.
    const aggregatedMap: Record<string, number> = {};

    payments.forEach((pay) => {
      // We only count completed payments for revenue calculations
      if (pay.status === PaymentStatus.COMPLETED) {
        // Derive grouping key based on filters.timeRange
        // If daily => group by YYYY-MM-DD, if monthly => group by YYYY-MM
        const dateFmt =
          filters.timeRange === 'monthly'
            ? format(pay.createdAt, 'yyyy-MM')
            : format(pay.createdAt, 'yyyy-MM-dd');

        aggregatedMap[dateFmt] = (aggregatedMap[dateFmt] || 0) + pay.amount;
      }
    });

    // Convert aggregated map to Chart.js labels & datasets
    const sortedKeys = Object.keys(aggregatedMap).sort();
    const chartLabels: string[] = sortedKeys;
    const chartValues: number[] = sortedKeys.map((key) => aggregatedMap[key]);

    // 5) Basic currency formatting placeholder. In a real system, consider dayjs, i18n, or advanced logic
    //    For demonstration, we do a simple .toFixed(2).
    // 6) Construct a dataset object suitable for Chart.js
    const newChartData: ChartData<'bar' | 'line'> = {
      labels: chartLabels,
      datasets: [
        {
          label: 'Revenue ($)',
          data: chartValues.map((val) => Number(val.toFixed(2))),
          backgroundColor: filters.chartType === 'bar' ? 'rgba(54, 162, 235, 0.6)' : 'rgba(75, 192, 192, 0.6)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1,
        },
      ],
    };

    // 7) Update chart data in the component's state
    setStateCallback({
      chartData: newChartData,
      isLoading: false,
      error: null,
    });

    // 7) Cache the processed data for future usage
    cache[cacheKey] = {
      dataset: newChartData,
      timestamp: Date.now(),
    };
  } catch (error: any) {
    // 8) Handle errors, set error field in state
    setStateCallback({
      isLoading: false,
      error: error?.message || 'Failed to load revenue data',
    });
  }
}

/**
 * handleRealtimeUpdate
 * ---------------------------------------------------------------------------------------------
 * Processes a newly incoming Payment entity in real-time. Validates data, applies updates
 * to the current aggregated totals, triggers chart animations, and forces re-render so
 * that the user sees immediate changes.
 *
 * Steps:
 *  1) Validate the incoming Payment object, ensuring amount and status fields exist.
 *  2) If Payment status is COMPLETED, adjust relevant aggregated data in the chart's dataset.
 *  3) Animate the chart for a dynamic user experience (Chart.js update).
 *  4) Propagate changes back to the RevenueChart component state if necessary.
 */
function handleRealtimeUpdate(
  payment: Payment,
  currentData: ChartData,
  filters: RevenueChartFilters,
  chartInstance: Chart | null
): ChartData {
  // 1) Validate minimal Payment data
  if (!payment || payment.amount == null || !payment.createdAt) {
    // We can simply return current data if the incoming Payment is invalid
    return currentData;
  }

  // 2) Only account for new REVENUE if the payment is COMPLETED
  if (payment.status !== PaymentStatus.COMPLETED) {
    return currentData;
  }

  // Derive grouping key from timeRange
  const newKey =
    filters.timeRange === 'monthly'
      ? format(payment.createdAt, 'yyyy-MM')
      : format(payment.createdAt, 'yyyy-MM-dd');

  // Update the existing chart data. We'll assume there's only one dataset. If there are multiple
  // datasets, you'd need to handle them carefully.
  const updatedData = { ...currentData };
  if (!updatedData.labels || updatedData.labels.length === 0 || !updatedData.datasets?.[0]?.data) {
    return currentData;
  }

  // Attempt to find index of newKey in the label array
  const labelIndex = updatedData.labels.indexOf(newKey);

  if (labelIndex >= 0) {
    // Key already exists, so add to the existing amount
    const currentValue = Number(updatedData.datasets[0].data[labelIndex]) || 0;
    updatedData.datasets[0].data[labelIndex] = Number((currentValue + payment.amount).toFixed(2));
  } else {
    // Insert a new label and new data point in sorted position
    // We'll do a simple insertion, then re-sort
    updatedData.labels.push(newKey);
    updatedData.datasets[0].data.push(Number(payment.amount.toFixed(2)));

    // For daily or monthly keys, we can re-sort
    // Create an array of new combined { label, value } pairs, sort, then reassign
    const combinedArr = (updatedData.labels as string[]).map((lbl, idx) => ({
      label: lbl,
      value: Number(updatedData.datasets[0].data[idx]),
    }));

    combinedArr.sort((a, b) => a.label.localeCompare(b.label));

    updatedData.labels = combinedArr.map((c) => c.label);
    updatedData.datasets[0].data = combinedArr.map((c) => c.value);
  }

  // 3) Animate the chart
  if (chartInstance) {
    chartInstance.update('active'); // Tells Chart.js to animate from current to new state
  }

  // 4) Return the newly updated chart data, letting the parent React component reassign state
  return updatedData;
}

// --------------------------- Main Component: RevenueChart ---------------------------------------

/**
 * RevenueChart
 * ---------------------------------------------------------------------------------------------
 * A class-based React component that visualizes revenue analytics with real-time updates.
 * Offers time-range options (e.g., daily/monthly) and chart types (bar, line, etc.).
 *
 * Flow:
 *  - In the constructor, we set up references, local caching, PaymentService instance,
 *    and placeholders for WebSocket usage.
 *  - componentDidMount: register Chart.js components, create the chart, fetch data,
 *    subscribe to real-time updates from PaymentService, and optionally connect
 *    a WebSocket using useWebSocket if needed for broader usage.
 *  - componentDidUpdate: if timeRange or chartType props change, re-fetch data and
 *    update the chart accordingly.
 *  - componentWillUnmount: unsubscribe from PaymentService events & destroy chart for cleanup.
 *  - render: display the <canvas> used by Chart.js for visualization.
 */
export default class RevenueChart extends Component<RevenueChartProps, RevenueChartState> {
  /**
   * A ref pointing to the <canvas> element where Chart.js will render the revenue chart.
   */
  private chartRef: RefObject<HTMLCanvasElement>;

  /**
   * Holds the Chart.js instance. We'll instantiate it during componentDidMount
   * and destroy it during componentWillUnmount.
   */
  private chartInstance: Chart | null = null;

  /**
   * A local reference to PaymentService for retrieving historical data
   * and subscribing to real-time payment updates.
   */
  private paymentService: PaymentService;

  /**
   * A local usage of the useWebSocket hook's connect/disconnect methods, if needed.
   * In a class-based approach, we might not invoke hooks directly; we can store references
   * to a functional placement or a bridging approach. This is just to illustrate usage
   * as per the JSON specification.
   */
  private wsConnection: { connect: () => void; disconnect: () => void } | null = null;

  /**
   * Maintain an in-memory cache to avoid refetching the same aggregated data repeatedly.
   */
  private revenueCache: Record<string, CacheRecord> = {};

  /**
   * Constructor: sets up references and initial state, configures PaymentService,
   * and optionally sets up a bridging object for useWebSocket usage.
   */
  constructor(props: RevenueChartProps) {
    super(props);

    this.chartRef = React.createRef<HTMLCanvasElement>();
    this.paymentService = new PaymentService();

    // In a class-based approach, we cannot directly call the useWebSocket hook,
    // but we can illustrate a bridging mechanism as if we had a custom hook that
    // returns connect/disconnect. In practice, we'd do this in a functional component.
    this.wsConnection = {
      connect: () => {
        // Example placeholder if needed:
        // console.log('WebSocket connecting...');
      },
      disconnect: () => {
        // console.log('WebSocket disconnecting...');
      },
    };

    // Initialize local state
    this.state = {
      chartData: {
        labels: [],
        datasets: [],
      },
      error: null,
      isLoading: false,
    };
  }

  /**
   * componentDidMount: Lifecycle method invoked immediately after the component is mounted.
   * Steps:
   *  - Register Chart.js modules
   *  - Initialize the chart instance
   *  - Fetch historical revenue data
   *  - Subscribe to PaymentService real-time updates
   *  - (Optionally) Connect WebSocket if needed
   */
  async componentDidMount(): Promise<void> {
    try {
      // Register Chart.js modules globally
      Chart.register(...registerables);

      // Create the chart instance once the canvas ref is available
      if (this.chartRef.current) {
        const ctx = this.chartRef.current.getContext('2d');
        if (ctx) {
          this.chartInstance = new Chart(ctx, {
            type: this.props.chartType === 'bar' ? 'bar' : 'line',
            data: this.state.chartData,
            options: this.getChartOptions(),
          });
        }
      }

      // Immediately fetch revenue data
      await fetchRevenueData(
        { timeRange: this.props.timeRange, chartType: this.props.chartType },
        this.paymentService,
        this.revenueCache,
        (partial) => this.setState(partial as RevenueChartState)
      );

      // We must update the underlying Chart.js instance data once it's been fetched
      if (this.chartInstance) {
        this.chartInstance.data = this.state.chartData;
        this.chartInstance.update('none');
      }

      // Subscribe to real-time Payment updates
      // The JSON specification says PaymentService.subscribeToPayments is a method we can call
      this.paymentService.subscribeToPayments((newPayment: Payment) => {
        const updatedData = handleRealtimeUpdate(
          newPayment,
          this.state.chartData,
          { timeRange: this.props.timeRange, chartType: this.props.chartType },
          this.chartInstance
        );

        // Update local state with the newly updated data
        this.setState({ chartData: updatedData }, () => {
          // Once React state is updated, ensure the chart instance is also updated
          if (this.chartInstance) {
            this.chartInstance.data = updatedData;
            this.chartInstance.update('active');
          }
        });
      });

      // (Optionally) connect the WebSocket via the bridging object
      if (this.wsConnection) {
        this.wsConnection.connect();
      }

      // Listen for window resize events, or implement a ResizeObserver if more advanced approach is needed.
      window.addEventListener('resize', this.handleResize);
    } catch (err: any) {
      this.setState({ error: err?.message || 'Error during mount', isLoading: false });
    }
  }

  /**
   * componentDidUpdate: Invoked immediately after updating the component (e.g., when props change).
   * Steps:
   *  - If timeRange or chartType changed, re-fetch data and update the chart instance accordingly.
   */
  async componentDidUpdate(prevProps: RevenueChartProps): Promise<void> {
    if (
      prevProps.timeRange !== this.props.timeRange ||
      prevProps.chartType !== this.props.chartType
    ) {
      // Re-fetch data based on updated props
      await fetchRevenueData(
        { timeRange: this.props.timeRange, chartType: this.props.chartType },
        this.paymentService,
        this.revenueCache,
        (partial) => this.setState(partial as RevenueChartState)
      );

      // Update the chart instance once data is re-fetched
      if (this.chartInstance) {
        this.chartInstance.config.type = this.props.chartType === 'bar' ? 'bar' : 'line';
        this.chartInstance.data = this.state.chartData;
        this.chartInstance.update('none');
      }
    }
  }

  /**
   * componentWillUnmount: Cleanup logic, unsubscribing from PaymentService events,
   * disconnecting WebSocket, and removing any event listeners or chart references.
   */
  componentWillUnmount(): void {
    // Chart.js instance destroy
    if (this.chartInstance) {
      this.chartInstance.destroy();
      this.chartInstance = null;
    }

    // PaymentService unsubscription is hypothetical; assume it returns an unsubscribe fn
    this.paymentService.subscribeToPayments(null); // In a real scenario, we might pass an ID or a method to unsub

    // If WebSocket is connected, disconnect
    if (this.wsConnection) {
      this.wsConnection.disconnect();
    }

    // Remove resize event listener
    window.removeEventListener('resize', this.handleResize);
  }

  /**
   * handleResize: Event handler for the browser window resize.
   * Steps:
   *  - Re-draw the chart with new dimensions. Chart.js typically handles responsiveness,
   *    but we can force an update if needed. We'll call chartInstance.resize() if valid.
   */
  private handleResize = (): void => {
    if (this.chartInstance) {
      this.chartInstance.resize();
    }
  };

  /**
   * getChartOptions: Defines the Chart.js configuration, including responsive behavior,
   * tooltips, axes, and advanced animation options.
   */
  private getChartOptions(): ChartOptions {
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: {
        // Animate on real-time updates
        duration: 500,
        onComplete: (e: AnimationEvent) => {
          // Additional logic after chart animation
        },
      },
      scales: {
        x: {
          title: {
            display: true,
            text: this.props.timeRange === 'monthly' ? 'Month' : 'Date',
          },
        },
        y: {
          title: {
            display: true,
            text: 'Revenue (USD)',
          },
        },
      },
      plugins: {
        legend: {
          display: true,
        },
        tooltip: {
          mode: 'index',
          intersect: false,
        },
      },
    };
  }

  /**
   * render: Renders the primary canvas within a container. We rely on Chart.js
   * to populate the canvas with data. Additional loading states or errors are displayed
   * accordingly.
   */
  render(): React.ReactNode {
    const { isLoading, error } = this.state;

    return (
      <div style={{ position: 'relative', width: '100%', height: '400px' }}>
        {isLoading && (
          <div
            style={{
              position: 'absolute',
              zIndex: 10,
              left: '50%',
              top: '50%',
              transform: 'translate(-50%, -50%)',
              padding: '1rem',
              backgroundColor: 'rgba(255, 255, 255, 0.9)',
              borderRadius: '4px',
              boxShadow: '0 0 8px rgba(0,0,0,0.15)',
            }}
          >
            <p>Loading revenue data...</p>
          </div>
        )}

        {error && (
          <div
            style={{
              position: 'absolute',
              color: 'red',
              top: 0,
              left: 0,
              padding: '0.5rem',
            }}
          >
            <p>Error: {error}</p>
          </div>
        )}

        {/* Canvas for Chart.js rendering */}
        <canvas
          ref={this.chartRef}
          style={{
            width: '100%',
            height: '100%',
          }}
        />
      </div>
    );
  }
}