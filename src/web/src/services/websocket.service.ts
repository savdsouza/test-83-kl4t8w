/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * ------------------------------------------------------------------------
 * WebSocket Service Implementation for Real-Time Communication
 * ------------------------------------------------------------------------
 * This file provides a comprehensive, production-grade implementation of a
 * secure WebSocket service class. The service:
 *  - Establishes and manages a ReconnectingWebSocket connection.
 *  - Encrypts and decrypts messages to ensure data confidentiality.
 *  - Sends real-time location updates (e.g., during a dog walk) while respecting
 *    maximum message size constraints.
 *  - Handles automatic reconnection, status tracking, and subscription-based
 *    event notifications.
 *  - Periodically sends ping messages to keep the connection alive and detect
 *    dropped connections quickly.
 *  - Implements extensive error handling, logging, and lifecycle management.
 *
 * Globals:
 *  - WS_RECONNECT_INTERVAL = 5000      (Interval in ms between connection retries)
 *  - WS_MAX_RETRIES        = 5         (Maximum number of reconnection attempts)
 *  - WS_MESSAGE_MAX_SIZE    = 1048576  (Max allowed message size in bytes, e.g., 1MB)
 *  - WS_PING_INTERVAL       = 30000    (Interval in ms to send ping messages)
 *
 * Dependencies:
 *  - ReconnectingWebSocket v4.4.0
 *  - crypto-js v4.1.1
 *  - @injectable decorator for potential IoC integration (e.g., inversify)
 *
 * ------------------------------------------------------------------------
 */

import { injectable } from 'inversify'; // Example IoC Decorator (version depends on project setup)
import ReconnectingWebSocket from 'reconnecting-websocket'; // v4.4.0
import * as CryptoJS from 'crypto-js'; // v4.1.1

import { LocationUpdate } from '../types/walk.types'; // Internal import for location updates

/**
 * Global constants governing WebSocket behavior.
 */
const WS_RECONNECT_INTERVAL: number = 5000;
const WS_MAX_RETRIES: number = 5;
const WS_MESSAGE_MAX_SIZE: number = 1048576;
const WS_PING_INTERVAL: number = 30000;

/**
 * Represents possible WebSocket connection states for internal tracking.
 */
export enum ConnectionState {
  /**
   * The service is disconnected with no active WebSocket connection.
   */
  DISCONNECTED = 'DISCONNECTED',

  /**
   * The service is in the process of establishing a new WebSocket connection.
   */
  CONNECTING = 'CONNECTING',

  /**
   * The service currently has an open and active WebSocket connection.
   */
  CONNECTED = 'CONNECTED',

  /**
   * The service encountered an error that may or may not be recoverable.
   */
  ERROR = 'ERROR',
}

/**
 * A simple interface for logging within the WebSocket service. This can
 * be replaced or extended by any enterprise logging library as needed.
 */
interface ILogger {
  /**
   * Logs informational messages.
   * @param message - The message to log.
   * @param optionalParams - Optional parameters or objects for expanded logging.
   */
  info(message: string, ...optionalParams: any[]): void;

  /**
   * Logs warnings or non-critical issues.
   * @param message - The warning message to log.
   * @param optionalParams - Optional parameters or objects for expanded logging.
   */
  warn(message: string, ...optionalParams: any[]): void;

  /**
   * Logs error-level messages.
   * @param message - An error message describing the issue.
   * @param optionalParams - Optional parameters or objects providing additional context.
   */
  error(message: string, ...optionalParams: any[]): void;
}

/**
 * @injectable()
 * Service class managing secure WebSocket connections for real-time
 * communication during dog walks. Implements encryption, automatic
 * reconnection, message validation, event subscription, and periodic
 * ping transmissions.
 */
@injectable()
export class WebSocketService {
  /**
   * The underlying ReconnectingWebSocket instance for maintaining
   * persistent connections with auto-reconnect.
   */
  private socket: ReconnectingWebSocket | null;

  /**
   * The current retry attempt count for reconnecting WebSockets.
   * Used to track the number of connection failures.
   */
  private retryCount: number;

  /**
   * A mapping of event type strings to arrays of callback functions,
   * enabling multiple subscribers for each event type.
   */
  private subscribers: Map<string, Function[]>;

  /**
   * The current connection lifecycle state, e.g., DISCONNECTED,
   * CONNECTING, CONNECTED, or ERROR.
   */
  private connectionState: ConnectionState;

  /**
   * Reference to the ping interval timer for periodic "ping" messages,
   * allowing us to keep the connection alive and detect drops.
   */
  private pingInterval: NodeJS.Timeout | null;

  /**
   * A secret key used to encrypt and decrypt all messages sent and received
   * over the WebSocket channel. Currently stored in memory for demonstration.
   * In production, a secure key exchange and management system is recommended.
   */
  private encryptionKey: string | null;

  /**
   * An injected or passed-in logger instance used for logging crucial
   * service steps, errors, and diagnostics.
   */
  private logger: ILogger;

  /**
   * Constructor initializes default values, sets up the logging dependency,
   * and prepares initial connection states. No network I/O is performed here.
   * @param logger - An abstraction for logging useful messages (info, warn, error).
   */
  public constructor(logger: ILogger) {
    // Initialize the ReconnectingWebSocket instance as null until connect is called.
    this.socket = null;

    // Zero-based retry counter for controlling maximum reconnection attempts.
    this.retryCount = 0;

    // Mapping of event types (e.g., "location-update") to subscribed callbacks.
    this.subscribers = new Map<string, Function[]>();

    // The connection is initially disconnected until connect() is invoked.
    this.connectionState = ConnectionState.DISCONNECTED;

    // No active ping interval until the socket is connected.
    this.pingInterval = null;

    // Encryption key is null until one is generated in the connect phase.
    this.encryptionKey = null;

    // External or system-provided logger for instrumentation and debugging.
    this.logger = logger;
  }

  /**
   * Establishes a secure WebSocket connection with optional authentication
   * and encryption. Automatically attempts reconnection up to a maximum
   * number of retries. When connected, starts a ping interval and listens
   * for inbound messages.
   *
   * Steps:
   *  1. Validate input parameters (walkId, token).
   *  2. Generate a new encryption key to secure the session's messages.
   *  3. Construct full WebSocket URL with query parameters, including the auth token.
   *  4. Initialize the ReconnectingWebSocket with custom configuration (retries, intervals).
   *  5. Bind event handlers (open, message, close, error).
   *  6. Start a periodic ping to maintain connectivity (WS_PING_INTERVAL).
   *  7. Update the connection state accordingly.
   *
   * @param walkId - Unique identifier for the active dog walk session.
   * @param token  - A valid authentication token for server-side authorization.
   * @returns A promise that resolves when the connection is successfully established.
   */
  public async connect(walkId: string, token: string): Promise<void> {
    try {
      // (1) Validate input parameters.
      if (!walkId || !token) {
        throw new Error('Invalid parameters provided. Both walkId and token are required.');
      }

      // Immediately transition to CONNECTING state.
      this.connectionState = ConnectionState.CONNECTING;

      // (2) Generate encryption key for this session (simple random hex string).
      // For demonstration, we generate a random sequence. In production, a proper key exchange is advised.
      this.encryptionKey = CryptoJS.lib.WordArray.random(16).toString();

      // (3) Construct full WebSocket URL.
      // Example endpoint - replace with real production endpoint as needed.
      const baseUrl = 'wss://api.example.com/realtime';
      const wsUrl = `${baseUrl}?walkId=${encodeURIComponent(walkId)}&auth=${encodeURIComponent(token)}`;

      // (4) Initialize the ReconnectingWebSocket.
      // NOTE: ReconnectingWebSocket constructor can accept options such as:
      //       maxRetries, reconnectionDelay, etc.
      this.socket = new ReconnectingWebSocket(wsUrl, [], {
        maxRetries: WS_MAX_RETRIES,
        reconnectInterval: WS_RECONNECT_INTERVAL,
      });

      // Reset retry count when a fresh connection attempt begins.
      this.retryCount = 0;

      // (5) Bind event handlers.
      this.socket.addEventListener('open', () => {
        this.logger.info('WebSocket connection established.');
        this.connectionState = ConnectionState.CONNECTED;
      });

      this.socket.addEventListener('message', (event: MessageEvent) => {
        this.handleMessage(event);
      });

      this.socket.addEventListener('close', () => {
        this.logger.warn('WebSocket connection closed.');
        this.connectionState = ConnectionState.DISCONNECTED;
      });

      this.socket.addEventListener('error', (err: any) => {
        this.logger.error('WebSocket encountered an error:', err);
        this.connectionState = ConnectionState.ERROR;
      });

      // (6) Start a periodic ping to keep the connection alive.
      this.startPingInterval();

      // Wait a short time to confirm the WebSocket is open (or rely on event).
      // In many real scenarios, you'd handle 'open' via events, not by a forced delay.
      // Below is a simplistic approach for demonstration or until 'open' event triggers.
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 100));

      // Verify current state after initial attempt. Throw if not connected.
      if (this.connectionState !== ConnectionState.CONNECTED) {
        this.logger.warn('WebSocket connection not yet open; monitor open event or use event-driven logic.');
      }
    } catch (error) {
      this.logger.error('Failed to establish WebSocket connection:', error);
      this.connectionState = ConnectionState.ERROR;
      throw error;
    }
  }

  /**
   * Safely closes the active WebSocket connection, clears the ping interval,
   * and resets local state. Any subsequent WebSocket usage requires another
   * connect() call.
   *
   * Steps:
   *  1. Clear the periodic ping interval if one is active.
   *  2. Close the ReconnectingWebSocket connection if it exists.
   *  3. Reset retry count, encryption key, and subscriber callbacks.
   *  4. Transition to DISCONNECTED state.
   *  5. Log the disconnection for auditing.
   */
  public disconnect(): void {
    // (1) Clear ping interval.
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }

    // (2) Close the socket if it exists.
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }

    // (3) Reset relevant fields.
    this.retryCount = 0;
    this.encryptionKey = null;
    this.subscribers.clear();

    // (4) Set connection state to DISCONNECTED.
    this.connectionState = ConnectionState.DISCONNECTED;

    // (5) Record the event in logs.
    this.logger.info('WebSocket connection has been disconnected and resources are released.');
  }

  /**
   * Sends an encrypted location update through the WebSocket connection.
   * Ensures that the message does not exceed WS_MESSAGE_MAX_SIZE bytes.
   *
   * Steps:
   *  1. Validate that a socket connection is established.
   *  2. Validate the LocationUpdate data structure (non-null, has walkId, etc.).
   *  3. Encrypt the message using the session encryption key.
   *  4. Check the length of the encrypted message against WS_MESSAGE_MAX_SIZE.
   *  5. Send the message across the WebSocket.
   *  6. Log the transmission for auditing.
   *
   * @param locationData - The location update information containing walkId and coordinates.
   */
  public sendLocation(locationData: LocationUpdate): void {
    // (1) Check if the socket is actually connected.
    if (!this.socket || this.connectionState !== ConnectionState.CONNECTED) {
      this.logger.error('Attempted to send location while socket is not connected.');
      return;
    }

    // (2) Basic data validation.
    if (!locationData || !locationData.walkId || !locationData.coordinates) {
      this.logger.error('Invalid location update payload. Required fields are missing.');
      return;
    }

    // (3) Encrypt the location data.
    const encryptedPayload = this.encryptMessage(locationData);

    // (4) Check message size.
    if (encryptedPayload.length > WS_MESSAGE_MAX_SIZE) {
      this.logger.error(`Encrypted message size (${encryptedPayload.length} bytes) exceeds limit.`);
      return;
    }

    // (5) Send the encrypted data.
    this.socket.send(encryptedPayload);

    // (6) Log successful transmission.
    this.logger.info('Location update sent via WebSocket.', locationData);
  }

  /**
   * Subscribes a callback function to a specified event type. Whenever an
   * incoming WebSocket message includes a matching "eventType", all
   * registered callbacks are invoked in FIFO order.
   *
   * Steps:
   *  1. Validate the eventType argument to avoid empty strings.
   *  2. Add the callback to the internal subscribers map.
   *  3. Return an unsubscribe function that removes the callback when called.
   *  4. Log subscription for debugging and auditing.
   *
   * @param eventType - The string that identifies a particular kind of message or topic.
   * @param callback  - The function to invoke whenever an event matching eventType arrives.
   * @returns A function to unsubscribe from this eventType.
   */
  public subscribe(eventType: string, callback: Function): Function {
    // (1) Validate the event type.
    if (!eventType) {
      this.logger.warn('Attempted to subscribe with an empty or invalid eventType.');
      return () => {};
    }

    // Retrieve or create a callbacks array for the given event type.
    const existingCallbacks = this.subscribers.get(eventType) || [];
    existingCallbacks.push(callback);
    this.subscribers.set(eventType, existingCallbacks);

    // (3) Return an unsubscribe function.
    const unsubscribe = (): void => {
      const callbacks = this.subscribers.get(eventType);
      if (!callbacks) return;

      const index = callbacks.indexOf(callback);
      if (index !== -1) {
        callbacks.splice(index, 1);
        this.subscribers.set(eventType, callbacks);
      }
      this.logger.info(`Unsubscribed a callback from eventType: ${eventType}`);
    };

    // (4) Log successful subscription.
    this.logger.info(`Subscribed to eventType: ${eventType}`);
    return unsubscribe;
  }

  /**
   * Internal function for processing incoming messages from the WebSocket.
   * Responsible for decrypting the message, parsing the JSON, and
   * dispatching to the appropriate subscriber callbacks based on
   * the event type.
   *
   * Steps:
   *  1. Validate the raw message size to ensure it doesn't exceed WS_MESSAGE_MAX_SIZE.
   *  2. Decrypt the payload using the session's encryption key.
   *  3. Parse the decrypted JSON data.
   *  4. Validate that it contains an eventType or relevant structure.
   *  5. If recognized, dispatch to all subscribers under that eventType.
   *  6. Log or handle any errors during decryption or parsing gracefully.
   *
   * @param event - The raw message event from the WebSocket 'message' listener.
   */
  private handleMessage(event: MessageEvent): void {
    try {
      // (1) Check if size is within allowed limits.
      const rawData = (event && event.data) ? event.data.toString() : '';
      if (rawData.length > WS_MESSAGE_MAX_SIZE) {
        this.logger.warn(`Inbound message size (${rawData.length} bytes) exceeds limit, ignoring.`);
        return;
      }

      // (2) Decrypt payload.
      const decryptedData = this.decryptMessage(rawData);

      // (3) Parse JSON data.
      const parsed = JSON.parse(decryptedData);

      // (4) Check for recognized structure or eventType.
      if (!parsed || !parsed.eventType) {
        // For example, ping/pong messages may not have eventType
        // or handle them specifically as below:
        if (parsed && parsed.type === 'ping') {
          // Typically, we could respond with a "pong"
          // but that depends on app protocol design.
          return;
        }
        if (parsed && parsed.type === 'pong') {
          // Possibly handle a "pong" message or ignore
          return;
        }
        // If no recognized structure, we simply log and return.
        this.logger.info('Received a message without eventType, ignoring.');
        return;
      }

      // (5) Dispatch to subscribers for the parsed.eventType.
      const callbacks = this.subscribers.get(parsed.eventType) || [];
      callbacks.forEach((cb) => {
        try {
          cb(parsed);
        } catch (callbackErr) {
          this.logger.error(`Error in callback for eventType: ${parsed.eventType}`, callbackErr);
        }
      });

      // (6) Log successful receipt.
      this.logger.info(`Message handled for eventType: ${parsed.eventType}`);
    } catch (err) {
      // If anything goes wrong in decryption or parsing, log the error.
      this.logger.error('Error handling incoming WebSocket message:', err);
    }
  }

  /**
   * Initializes a timer that periodically sends a small "ping" message
   * to the server. Helps maintain an active WebSocket and detect
   * disconnections promptly. The interval is governed by WS_PING_INTERVAL.
   */
  private startPingInterval(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
    }

    this.pingInterval = setInterval(() => {
      if (this.socket && this.connectionState === ConnectionState.CONNECTED) {
        const pingData = { type: 'ping', timestamp: Date.now() };
        const encryptedPing = this.encryptMessage(pingData);
        this.socket.send(encryptedPing);
      }
    }, WS_PING_INTERVAL);
  }

  /**
   * Encrypts a given payload (object or primitive) into a string using
   * the session encryption key. The resulting string can be transmitted
   * over the WebSocket for secure transport.
   *
   * @param data - Any data structure or value to be encrypted.
   * @returns A base64-encoded, AES-encrypted string.
   */
  private encryptMessage(data: any): string {
    if (!this.encryptionKey) {
      // If encryptionKey is not set, fallback to plain text for demonstration or throw.
      // For production, we strongly recommend throwing an error.
      return JSON.stringify(data);
    }

    const message = JSON.stringify(data);
    const encrypted = CryptoJS.AES.encrypt(
      message,
      this.encryptionKey,
    ).toString();

    return encrypted;
  }

  /**
   * Decrypts an inbound encrypted WebSocket message using the
   * session encryption key. If no key is present, the raw payload
   * is interpreted as plain text JSON.
   *
   * @param encrypted - The encrypted string from the server.
   * @returns The decrypted plaintext string in JSON format.
   */
  private decryptMessage(encrypted: string): string {
    if (!this.encryptionKey) {
      // If encryptionKey is not set, interpret as a plain text fallback.
      return encrypted;
    }

    let decrypted: string;
    try {
      const bytes = CryptoJS.AES.decrypt(encrypted, this.encryptionKey);
      decrypted = bytes.toString(CryptoJS.enc.Utf8);
    } catch (error) {
      this.logger.warn('Failed to decrypt message; possibly plain text or invalid ciphertext.');
      // If decryption fails, fallback to raw string (non-encrypted).
      decrypted = encrypted;
    }

    return decrypted;
  }
}