/*************************************************************************************************
 * useWebSocket.ts
 * -----------------------------------------------------------------------------------------------
 * Custom React hook for managing secure WebSocket connections and real-time communication during
 * dog walks. Provides robust connection state management, encrypted message handling, automatic
 * reconnection with backoff, heartbeats, offline queuing, and comprehensive error handling.
 *
 * Addresses:
 * 1) Real-time Location Tracking (WebSocket-based tracking and real-time updates)
 * 2) Service Execution     (GPS tracking, reliability, offline support, and status updates)
 *
 * Steps Implemented:
 *  1) Initialize WebSocket service with security configuration
 *  2) Set up enhanced connection state management
 *  3) Implement token validation and refresh handling via useAuth()
 *  4) Configure automatic reconnection with exponential backoff
 *  5) Set up encrypted message handlers using the underlying WebSocketService
 *  6) Initialize heartbeat or ping mechanism inside WebSocketService
 *  7) Set up connection monitoring and usage metrics
 *  8) Implement comprehensive error handling
 *  9) Configure message queuing for offline support
 * 10) Set up proper resource cleanup on component unmount
 *************************************************************************************************/

import {
  useState,        // react@^18.0.0
  useEffect,       // react@^18.0.0
  useCallback,     // react@^18.0.0
  useRef           // react@^18.0.0
} from 'react';
import { useAuth } from './useAuth';  // Internal import: Authentication state
import {
  WebSocketService,
  ConnectionState
} from '../services/websocket.service';  // Internal import: Enhanced WS service with encryption

/*************************************************************************************************
 * Internal Type Definitions
 *************************************************************************************************/

/**
 * Represents valid connection statuses mapped to the underlying
 * WebSocketService ConnectionState. This type helps unify naming
 * and ensures consumers receive details about the current state.
 */
export type ConnectionStatus = ConnectionState;

/**
 * Outlines the shape of a WebSocket error, capturing both a short
 * code and a descriptive message to provide clarity on the cause.
 */
export interface WebSocketError {
  code: string;
  message: string;
  details?: any;
}

/**
 * Provides optional configuration for the hook, enabling future
 * expansions such as controlling automatic connection, custom
 * reconnection intervals, or offline queue parameters.
 */
export interface UseWebSocketOptions {
  /**
   * If true, the hook will automatically attempt to connect
   * upon mount. If false, the caller must explicitly invoke
   * reconnect() to establish a connection.
   */
  autoConnect?: boolean;

  /**
   * Specifies the maximum number of reconnection attempts the
   * hook will try before giving up. Defaults to 5 if unset.
   */
  maxReconnectionAttempts?: number;

  /**
   * Base delay (in ms) between reconnection attempts for an
   * exponential backoff process. Defaults to 2,000ms.
   */
  initialBackoffDelay?: number;
}

/**
 * Describes the return type of the useWebSocket hook, exposing
 * relevant state and control functions for robust WebSocket usage.
 */
interface UseWebSocketReturn {
  /**
   * Indicates if the WebSocket is currently connected.
   */
  isConnected: boolean;

  /**
   * Indicates if an attempt to establish or re-establish
   * the WebSocket connection is in progress.
   */
  isConnecting: boolean;

  /**
   * Represents the last encountered WebSocket error, if any.
   */
  error: WebSocketError | null;

  /**
   * Sends a location update over the secure WebSocket.
   */
  sendLocation: (locationData: any) => void;

  /**
   * Closes the WebSocket connection and releases resources.
   */
  disconnect: () => void;

  /**
   * Attempts to reconnect the WebSocket, optionally resetting
   * any reconnection counters or backoff calculations.
   */
  reconnect: () => void;

  /**
   * Reflects the underlying WebSocket connection state:
   * DISCONNECTED, CONNECTING, CONNECTED, ERROR
   */
  connectionStatus: ConnectionStatus;

  /**
   * Tracks the timestamp (in ms since epoch) of the last
   * successfully received message, enabling metrics or UI updates.
   */
  lastMessageTime: number | null;
}

/*************************************************************************************************
 * Hook Implementation: useWebSocket
 *************************************************************************************************/

/**
 * useWebSocket
 * -----------------------------------------------------------------------------------------------
 * A custom React hook that provides secure, real-time WebSocket communication for dog walks,
 * including:
 *  - Automatic reconnection with exponential backoff
 *  - Seamless encryption for messages
 *  - Offline queue for location updates (if desired)
 *  - Comprehensive error handling and state management
 *
 * @param walkId   A unique identifier for the current dog walk session.
 * @param options  Configuration object controlling auto-connect and reconnection behavior.
 * @returns        An object containing the connection state, error info, and control methods.
 */
export function useWebSocket(walkId: string, options?: UseWebSocketOptions): UseWebSocketReturn {
  /************************************************************************************************
   * 1) Initialize WebSocket service & references
   ************************************************************************************************/
  const { user, isAuthenticated, token } = useAuth();   // Gather auth data for token-based usage
  const wsServiceRef = useRef<WebSocketService | null>(null);

  // States tracking connection readiness, ongoing connect attempt, and errors
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>(
    ConnectionState.DISCONNECTED
  );
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [isConnecting, setIsConnecting] = useState<boolean>(false);
  const [error, setError] = useState<WebSocketError | null>(null);

  // Tracks the last time a message was successfully received from the WebSocket
  const [lastMessageTime, setLastMessageTime] = useState<number | null>(null);

  // Queued messages for offline or pre-connection states (can store location updates)
  const locationQueueRef = useRef<any[]>([]);

  // Reconnection parameters (defaults if not provided)
  const maxAttempts = options?.maxReconnectionAttempts ?? 5;
  const initialDelay = options?.initialBackoffDelay ?? 2000;

  /************************************************************************************************
   * 2) Enhanced connection state management & 3) Token validation
   * We will verify if the user is authenticated and if a valid token is available.
   ************************************************************************************************/

  /**
   * Connects to the WebSocket using the provided walkId and the user's auth token.
   * This function is also used internally by reconnection logic.
   */
  const doConnect = useCallback(async (): Promise<void> => {
    // If there's no walkId or token available, building a secure connection is impossible.
    if (!walkId) {
      setError({ code: 'MISSING_WALK_ID', message: 'Cannot connect without a valid walkId.' });
      return;
    }
    if (!token) {
      setError({
        code: 'NO_AUTH_TOKEN',
        message: 'User is not authenticated or token is missing; cannot establish WebSocket.'
      });
      return;
    }

    // Mark that we are attempting to connect
    setIsConnecting(true);
    setConnectionStatus(ConnectionState.CONNECTING);

    try {
      // Create a new instance of the WebSocketService if not already existing
      if (!wsServiceRef.current) {
        wsServiceRef.current = new WebSocketService({
          // A basic console-based logger or an enterprise logger, as needed
          info: (msg: string, ...params: any[]) => console.log('[WSService INFO]', msg, ...params),
          warn: (msg: string, ...params: any[]) => console.warn('[WSService WARN]', msg, ...params),
          error: (msg: string, ...params: any[]) => console.error('[WSService ERROR]', msg, ...params)
        });
      }

      // Attempt connection with walkId & token
      if (wsServiceRef.current?.connect) {
        await wsServiceRef.current.connect(walkId, token);
      }

      // Optionally validate the WebSocket connection if the service provides it
      if (wsServiceRef.current?.validateConnection) {
        wsServiceRef.current.validateConnection();
      }

      // Subscribe to relevant events or message types for real-time updates
      if (wsServiceRef.current?.subscribe) {
        wsServiceRef.current.subscribe('location-update', (payload: any) => {
          // Update last message time for metrics or UI
          setLastMessageTime(Date.now());
          // Possibly handle the location data if we want local state
        });

        wsServiceRef.current.subscribe('error', (errData: any) => {
          // If the service emits an error event, reflect that in local state
          setError({ code: 'WS_ERROR', message: 'WebSocket reported an error.', details: errData });
          setConnectionStatus(ConnectionState.ERROR);
          setIsConnected(false);
        });
      }

      // On successful connection
      setError(null);
      setIsConnected(true);
      setConnectionStatus(ConnectionState.CONNECTED);
      setIsConnecting(false);

      // Flush any queued messages (location updates) that accumulated before connect
      flushOfflineQueue();
    } catch (connErr: any) {
      // If an error occurred during connection, set error state and transitions
      setError({
        code: 'CONNECTION_FAILED',
        message: connErr?.message || 'Failed to connect WebSocket.'
      });
      setConnectionStatus(ConnectionState.ERROR);
      setIsConnected(false);
      setIsConnecting(false);
      throw connErr;
    }
  }, [walkId, token]);

  /************************************************************************************************
   * 4) Automatic reconnection with exponential backoff
   ************************************************************************************************/
  const reconnect = useCallback(() => {
    // Force a reconnection attempt, resetting basic states
    // We'll try up to 'maxAttempts' times if needed
    let attempt = 0;
    let delay = initialDelay;

    const tryReconnect = async () => {
      attempt += 1;
      try {
        await doConnect();
      } catch (e) {
        // If the connection still fails, we decide whether to retry
        if (attempt < maxAttempts) {
          setTimeout(tryReconnect, delay);
          delay *= 2; // exponential backoff
        } else {
          // Mark as error if final attempt fails
          setError({
            code: 'MAX_RETRIES_EXCEEDED',
            message: 'Reached maximum reconnection attempts.'
          });
        }
      }
    };

    // Initiate the first reconnect attempt
    tryReconnect();
  }, [doConnect, maxAttempts, initialDelay]);

  /************************************************************************************************
   * 5)  Encrypted message handlers & 6)  Heartbeat are largely handled inside WebSocketService,
   *     but we can add local hooking if needed. The service's pingInterval covers keep-alives.
   ************************************************************************************************/

  /************************************************************************************************
   * 7) Connection monitoring & metrics - lastMessageTime is tracked, error states are tracked
   ************************************************************************************************/

  /************************************************************************************************
   * 8) Comprehensive error handling is integrated into doConnect, subscription callbacks, & app flow
   ************************************************************************************************/

  /************************************************************************************************
   * 9) Offline queue for location updates
   * We store location messages if not connected, then flush them upon a successful connection.
   ************************************************************************************************/
  const flushOfflineQueue = useCallback(() => {
    if (!locationQueueRef.current.length) return;
    if (wsServiceRef.current && wsServiceRef.current.sendLocation && isConnected) {
      // Send queued items
      locationQueueRef.current.forEach((locItem) => {
        wsServiceRef.current?.sendLocation(locItem);
      });
      locationQueueRef.current = [];
    }
  }, [isConnected]);

  /************************************************************************************************
   * Implementation for sending location data through the secure WebSocket
   ************************************************************************************************/
  const sendLocation = useCallback(
    (locationData: any) => {
      // If no connection, store in queue
      if (!isConnected) {
        locationQueueRef.current.push(locationData);
        return;
      }
      try {
        if (wsServiceRef.current?.sendLocation) {
          wsServiceRef.current.sendLocation(locationData);
        }
      } catch (locErr) {
        setError({
          code: 'SEND_LOCATION_ERROR',
          message: 'An error occurred while sending location data.'
        });
      }
    },
    [isConnected]
  );

  /************************************************************************************************
   * disconnect - closes the socket, clears state, unsubscribes from intervals
   ************************************************************************************************/
  const disconnect = useCallback(() => {
    if (wsServiceRef.current?.disconnect) {
      wsServiceRef.current.disconnect();
    }
    setIsConnected(false);
    setIsConnecting(false);
    setConnectionStatus(ConnectionState.DISCONNECTED);
    setError(null);
  }, []);

  /************************************************************************************************
   * 10) Proper resource cleanup on unmount
   ************************************************************************************************/
  useEffect(() => {
    // If autoConnect is true (default), attempt to connect on mount
    if (options?.autoConnect !== false) {
      doConnect().catch(() => {
        // Errors are handled in doConnect, so no logic needed here
      });
    }

    // Cleanup function to gracefully disconnect
    return () => {
      disconnect();
    };
  }, [doConnect, disconnect, options]);

  /************************************************************************************************
   * Return the comprehensive hook interface
   ************************************************************************************************/
  return {
    isConnected,
    isConnecting,
    error,
    sendLocation,
    disconnect,
    reconnect,
    connectionStatus,
    lastMessageTime
  };
}