/****************************************************************************************************
 * tracking.routes.ts
 * --------------------------------------------------------------------------------------------------
 * Provides all API endpoints for real-time location tracking, including HTTP routes for posting
 * current location data and retrieving location histories, as well as a WebSocket endpoint for
 * bi-directional real-time updates. Integrates authentication, validation, rate limiting, MQTT-based
 * broadcasts, and Prometheus metrics to meet enterprise-grade standards in reliability, security,
 * and scalability as specified in the technical requirements.
 *
 * This module implements:
 *  1) setupTrackingRoutes(): Main function returning an Express router with:
 *     - POST /api/v1/tracking/location: Updates a dog's current location.
 *     - GET  /api/v1/tracking/location/history/:walkId: Fetches historical location data for a walk.
 *     - WS   /api/v1/tracking/ws: WebSocket endpoint for live location streaming (proxied).
 *
 *  2) handleWebSocketConnection(ws, req): In-depth lifecycle management for WebSocket connections,
 *     including authentication, heartbeat intervals, MQTT subscriptions, message handling, and
 *     resource cleanup.
 *
 * Enterprise Features:
 *  - Authentication via JWT (RS256), courtesy of authenticateToken middleware.
 *  - Request validation (Joi), guided by validateSchema and a schema specifically for location data.
 *  - Rate limiting to mitigate abuse and adhere to performance constraints.
 *  - Observability with prom-client counters, tracking usage statistics.
 *  - MQTT client connection to broadcast location updates or subscribe to internal location domains.
 *  - WebSocket Proxy with optional manual lifecycle management for advanced control (heartbeat,
 *    subscriptions, etc.).
 ****************************************************************************************************/

// --------------------------------------------------------------------------------------------------
// External Imports (with library version comments)
// --------------------------------------------------------------------------------------------------
import { Router, Request, Response, NextFunction } from 'express'; // express@4.18.2
import Joi from 'joi'; // joi@17.11.0
import { createProxyMiddleware } from 'http-proxy-middleware'; // http-proxy-middleware@2.0.6
import mqtt from 'mqtt'; // mqtt@5.0.5
import { WebSocketServer, WebSocket } from 'ws'; // ws@8.14.2
import rateLimit from 'express-rate-limit'; // express-rate-limit@7.1.0
import * as PromClient from 'prom-client'; // prom-client@14.2.0

// --------------------------------------------------------------------------------------------------
// Internal Imports
// --------------------------------------------------------------------------------------------------
import { authenticateToken } from '../middleware/auth.middleware';
import validateSchema from '../middleware/validation.middleware';

// --------------------------------------------------------------------------------------------------
// Global Configuration Constants (from specification)
// --------------------------------------------------------------------------------------------------
const trackingServiceUrl: string =
  process.env.TRACKING_SERVICE_URL || 'http://tracking-service:8080';
const mqttBrokerUrl: string =
  process.env.MQTT_BROKER_URL || 'mqtt://broker:1883';
const wsHeartbeatInterval: number = Number(
  process.env.WS_HEARTBEAT_INTERVAL || 30000
);

// --------------------------------------------------------------------------------------------------
// MQTT Client Initialization
// --------------------------------------------------------------------------------------------------
/**
 * Create and configure an MQTT client to facilitate location broadcasts and/or
 * subscriptions for real-time dog-walking events. Adjust connection retries,
 * will messages, or QoS here as needed for production reliability.
 */
const mqttClient = mqtt.connect(mqttBrokerUrl, {
  keepalive: 60,
  reconnectPeriod: 2000, // 2 seconds between reconnection attempts
  clean: true,
});

/**
 * Log MQTT connection status and errors for operational monitoring.
 */
mqttClient.on('connect', () => {
  // eslint-disable-next-line no-console
  console.log(`[MQTT] Connected to broker at: ${mqttBrokerUrl}`);
});
mqttClient.on('error', (err) => {
  // eslint-disable-next-line no-console
  console.error(`[MQTT] Connection error: ${err.message}`);
});

// --------------------------------------------------------------------------------------------------
// Prometheus Metrics Setup
// --------------------------------------------------------------------------------------------------
/**
 * Register default metrics (CPU, memory, event loop lag, etc.) for system observability
 * and add custom counters/gauges relevant to location tracking if desired.
 */
PromClient.collectDefaultMetrics();

/**
 * Counter to track how many location updates have been received through the POST endpoint.
 */
const locationUpdateCounter = new PromClient.Counter({
  name: 'location_updates_total',
  help: 'Total number of location update requests received',
});

/**
 * Gauge to reflect the current number of active WebSocket connections on tracking channels.
 * This increments whenever a new client connects via WebSocket and decrements on disconnection.
 */
const wsConnectionGauge = new PromClient.Gauge({
  name: 'tracking_ws_connections_current',
  help: 'Gauge of current active WebSocket connections for tracking',
});

// --------------------------------------------------------------------------------------------------
// Rate Limiting Configuration (Example Inline)
// --------------------------------------------------------------------------------------------------
/**
 * For production usage, consider using a Redis or other distributed store. This demo
 * sets 100 requests per 15-minute window as a baseline.
 */
const trackingRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Rate limit exceeded for tracking endpoints. Please try again later.',
});

// --------------------------------------------------------------------------------------------------
// Joi Schema: locationUpdateSchema
// --------------------------------------------------------------------------------------------------
/**
 * Validates the shape of the request body for POST /api/v1/tracking/location
 * including required fields (walkId, latitude, longitude, timestamp) and optional
 * numeric fields (accuracy, speed, bearing).
 */
const locationUpdateSchema = Joi.object({
  walkId: Joi.string().required().description('Unique identifier for the walk'),
  latitude: Joi.number().required().description('Current latitude of the dog'),
  longitude: Joi.number().required().description('Current longitude of the dog'),
  timestamp: Joi.string()
    .isoDate()
    .required()
    .description('ISO-8601 timestamp when this location was captured'),
  accuracy: Joi.number()
    .min(0)
    .optional()
    .description('GPS accuracy in meters'),
  speed: Joi.number()
    .min(0)
    .optional()
    .description('Speed in m/s'),
  bearing: Joi.number()
    .min(0)
    .max(359)
    .optional()
    .description('Direction of movement in degrees (0-359)'),
});

// --------------------------------------------------------------------------------------------------
// Function: handleWebSocketConnection
// --------------------------------------------------------------------------------------------------
/****************************************************************************************************
 * handleWebSocketConnection
 * --------------------------------------------------------------------------------------------------
 * Manages WebSocket connection lifecycle for real-time location streams:
 *   1) Validate connection authentication (already done by upstream middleware).
 *   2) Set up heartbeat to keep the connection alive or detect failures.
 *   3) Initialize any relevant MQTT subscriptions for location streaming or topic-based data.
 *   4) Listen for client messages to handle location-based commands or manual pings.
 *   5) Monitor connection health; forcibly close if unresponsive beyond a threshold.
 *   6) Clean up MQTT subscriptions, counters, and other resources on close.
 *
 * @param ws  - The WebSocket instance for the client connection
 * @param req - The HTTP request upgraded to WebSocket; may contain user data
 ****************************************************************************************************/
export async function handleWebSocketConnection(
  ws: WebSocket,
  req: Request
): Promise<void> {
  // --------------------------------------------------------------------------
  // 1) Optional: We trust that 'authenticateToken' already performed JWT checks.
  //    If needed, we can verify roles or additional claims here.
  // --------------------------------------------------------------------------
  // Example (commented-out) role check:
  // if (!req.user || req.user.role !== 'walker') {
  //   ws.close(4403, 'Forbidden: insufficient privileges');
  //   return;
  // }

  // --------------------------------------------------------------------------
  // 2) Set up heartbeat mechanism to keep connection alive or detect silent drops.
  // --------------------------------------------------------------------------
  let isAlive = true;
  ws.on('pong', () => {
    isAlive = true;
  });

  const heartbeat = setInterval(() => {
    if (!isAlive) {
      ws.terminate();
      clearInterval(heartbeat);
      return;
    }
    isAlive = false;
    ws.ping(); // Actively request a 'pong' from the client
  }, wsHeartbeatInterval);

  // --------------------------------------------------------------------------
  // 3) Optionally subscribe to relevant MQTT topics to push location updates.
  // --------------------------------------------------------------------------
  // For demonstration, we subscribe to a hypothetical topic "tracking/global"
  // if the user is interested in all location streams. In reality, filter by walkId or userId.
  mqttClient.subscribe('tracking/global', (err) => {
    if (err) {
      // eslint-disable-next-line no-console
      console.error('[WebSocket] MQTT subscription error:', err.message);
    }
  });

  // --------------------------------------------------------------------------
  // 4) Handle incoming WebSocket messages from the client. Could parse JSON
  //    for commands, like requesting an on-demand location snapshot, toggling
  //    status updates, or other forms of real-time interactions.
  // --------------------------------------------------------------------------
  ws.on('message', (data) => {
    // Basic logging
    // eslint-disable-next-line no-console
    console.log('[WebSocket] Received message from client:', data.toString());

    // Example: echo back or handle specific command
    ws.send(JSON.stringify({ echo: data.toString() }));
  });

  // --------------------------------------------------------------------------
  // 5) Update metrics and monitor connection health. We already track 'isAlive'.
  //    Increment gauge on connection, decrement on close.
  // --------------------------------------------------------------------------
  wsConnectionGauge.inc(); // On connect

  // --------------------------------------------------------------------------
  // 6) Clean up resources on closure, unsubscribing from MQTT and clearing intervals.
  // --------------------------------------------------------------------------
  ws.on('close', () => {
    mqttClient.unsubscribe('tracking/global');
    clearInterval(heartbeat);
    wsConnectionGauge.dec(); // On disconnect
  });
}

// --------------------------------------------------------------------------------------------------
// WebSocket Proxy Setup
// --------------------------------------------------------------------------------------------------
/**
 * In scenarios where we prefer forwarding WebSocket traffic to a dedicated
 * tracking microservice, we configure the http-proxy-middleware with WebSocket
 * support. This integrates seamlessly with Express. We also can tie in
 * handleWebSocketConnection at various lifecycle hooks if implementing fine-grained
 * logic inside the gateway instead of the microservice.
 */
const wsProxy = createProxyMiddleware({
  target: trackingServiceUrl, // The external microservice handling actual socket logic (if used)
  changeOrigin: true,
  ws: true,
  pathRewrite: { '^/api/v1/tracking/ws': '/' },

  // Optional advanced hooks for custom logic:
  onProxyReqWs: (proxyReq, req, socket, options, head) => {
    // We can insert advanced logic or call handleWebSocketConnection if we want
    // direct gateway-level involvement. For demonstration, we'll simply log a statement.
    // eslint-disable-next-line no-console
    console.log('[WebSocket Proxy] Upgrading connection for path:', req.url);
  },
});

// --------------------------------------------------------------------------------------------------
// Main Function: setupTrackingRoutes
// --------------------------------------------------------------------------------------------------
/****************************************************************************************************
 * setupTrackingRoutes
 * --------------------------------------------------------------------------------------------------
 * Configures and returns an Express router instance with the following:
 *   1) Real-time location POST endpoint (/api/v1/tracking/location)
 *   2) Location history GET endpoint (/api/v1/tracking/location/history/:walkId)
 *   3) WebSocket route (/api/v1/tracking/ws) proxied or handled for real-time streaming
 *   4) Comprehensive security controls: JWT auth, rate limiting, request validation
 *   5) MQTT and Prometheus integration for real-time updates and monitoring
 *   6) Detailed production-ready logging, error handling, and placeholders for caching
 *
 * Steps:
 *   1) Instantiate new Express router.
 *   2) Configure route-level middlewares (authentication, rate limiting, validation).
 *   3) Define POST /location endpoint for storing or broadcasting the dog's current location.
 *   4) Define GET /location/history/:walkId endpoint for retrieving location data.
 *   5) Integrate WebSocket support at /api/v1/tracking/ws with a proxy or direct usage.
 *   6) Return the router instance to be mounted in the main server or gateway.
 *
 * @returns The fully configured Express router instance for tracking routes.
 ****************************************************************************************************/
export default function setupTrackingRoutes() {
  // 1) Create a new router
  const router = Router();

  // 2) Set up the POST /api/v1/tracking/location route
  //    with the required middlewares: authenticateToken, trackingRateLimiter,
  //    and validateSchema for locationUpdateSchema.
  router.post(
    '/api/v1/tracking/location',
    authenticateToken,
    trackingRateLimiter,
    validateSchema(locationUpdateSchema, {
      abortEarly: false,
      stripUnknown: true,
    }),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        // 3) Increment metrics to reflect usage
        locationUpdateCounter.inc();

        // 4) Extract validated location data from req.body
        const {
          walkId,
          latitude,
          longitude,
          timestamp,
          accuracy,
          speed,
          bearing,
        } = req.body;

        // 5) Optionally publish to an MQTT topic for real-time processing or consumer services.
        //    For demonstration, we post the entire location payload to "tracking/updates" topic.
        const locationPayload = {
          walkId,
          latitude,
          longitude,
          timestamp,
          accuracy,
          speed,
          bearing,
        };
        mqttClient.publish(
          'tracking/updates',
          JSON.stringify(locationPayload),
          { qos: 1 }
        );

        // 6) Forward data to the dedicated tracking microservice or store in DB (placeholder).
        //    For example, we might call an internal service endpoint here:
        //    await axios.post(`${trackingServiceUrl}/location`, locationPayload);
        //    This snippet is omitted for brevity.

        // 7) Respond with success
        return res.status(200).json({
          message: 'Location updated successfully',
          data: locationPayload,
        });
      } catch (error) {
        return next(error);
      }
    }
  );

  // ---------------------------------------------------------------------------------------------
  // GET /api/v1/tracking/location/history/:walkId
  // Retrieve historical location data for a completed walk, potentially with caching.
  // ---------------------------------------------------------------------------------------------
  router.get(
    '/api/v1/tracking/location/history/:walkId',
    authenticateToken,
    trackingRateLimiter,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const { walkId } = req.params;

        // Example: Check a local or distributed cache first (placeholder).
        // In real usage, we might use Redis or a caching layer integrated with the DB.
        // if (cache.has(walkId)) { return res.json(cache.get(walkId)); }

        // Otherwise, fetch from TimescaleDB or data store. This is a stub:
        // const locationHistory = await getLocationHistoryFromDb(walkId);
        // For demonstration, we respond with a mock payload.
        const locationHistory = [
          { latitude: 40.7128, longitude: -74.006, timestamp: '2023-01-01T12:00:00Z' },
          { latitude: 40.7130, longitude: -74.0062, timestamp: '2023-01-01T12:05:00Z' },
        ];

        // Possibly store in cache:
        // cache.set(walkId, locationHistory, 60 * 5); // 5-minute TTL

        return res.status(200).json({
          walkId,
          history: locationHistory,
        });
      } catch (error) {
        return next(error);
      }
    }
  );

  // ---------------------------------------------------------------------------------------------
  // WebSocket Endpoint: /api/v1/tracking/ws
  // ---------------------------------------------------------------------------------------------
  // The specification includes a WS route with middlewares: authenticateToken, wsProxy, rateLimiter.
  // For advanced usage, we can manually handle WebSocket events or rely on the proxy to forward
  // them to a specialized microservice. The handleWebSocketConnection can be integrated if
  // local gateway-level control is required for heartbeats, MQTT, etc.
  // ---------------------------------------------------------------------------------------------
  router.use(
    '/api/v1/tracking/ws',
    authenticateToken,
    trackingRateLimiter,
    wsProxy
  );

  // 11) Return the fully configured router
  return router;
}
```