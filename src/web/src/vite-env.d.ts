/// <reference types="vite/client" /> // vite@^4.4.0

/**
 * --------------------------------------------------------------------------
 * Dog Walking Web Application Admin Dashboard - Vite Environment Definitions
 * --------------------------------------------------------------------------
 * This TypeScript declaration file defines and augments the environment variables
 * and interfaces needed for the Dog Walking web application admin dashboard.
 * It ensures type safety for environment-specific configurations such as
 * backend API endpoints, Google Maps integration, and WebSocket connections.
 * 
 * Usage:
 *  - These interfaces provide a strongly-typed reference for environment variables.
 *  - During the build process, Vite will inject the actual values from the
 *    project's `.env` files or system environment.
 *  - By extending `ImportMetaEnv` and `ImportMeta`, any reference to
 *    import.meta.env will be type-checked according to these definitions.
 */

/**
 * Declares global types for environment variables that will be injected at build time.
 * All properties within this interface are marked as read-only, ensuring they are
 * immutable once compiled. These variables facilitate various critical functions
 * in the admin dashboard, including but not limited to:
 *  - API interaction (VITE_API_URL)
 *  - Map rendering and geolocation services (VITE_GOOGLE_MAPS_KEY)
 *  - Real-time communications via WebSocket (VITE_WEBSOCKET_URL)
 */
declare global {
  /**
   * Interface defining the shape of environment variables used throughout the
   * admin dashboard for the Dog Walking application. Each property must be set
   * in the corresponding environment files or provided as system-level variables
   * during build time. They are crucial for connecting the dashboard to
   * microservices and third-party APIs.
   */
  interface ImportMetaEnv {
    /**
     * The base URL for the Dog Walking application's backend API.
     * This value is utilized by the admin dashboard to communicate with
     * server-side endpoints for user management, booking details, and
     * security functionalities.
     */
    readonly VITE_API_URL: string;

    /**
     * The API key for Google Maps integration used within the admin dashboard.
     * It is required to display map data, location-based analytics, and
     * other map-driven features. This key must be kept secure.
     */
    readonly VITE_GOOGLE_MAPS_KEY: string;

    /**
     * The WebSocket endpoint URL providing real-time communication capabilities,
     * including live tracking updates, push notifications, and responsive
     * dashboard data refreshes.
     */
    readonly VITE_WEBSOCKET_URL: string;
  }

  /**
   * Augments the existing ImportMeta interface to include the typed environment
   * variables specified above. This merged interface ensures that any usage of
   * import.meta.env in the codebase is validated against the declared properties,
   * providing robust type safety and preventing configuration-related errors.
   */
  interface ImportMeta {
    readonly env: ImportMetaEnv;
  }
}

/**
 * An empty export statement is added to ensure this file is treated as a module
 * by TypeScript, preserving the declared global interfaces above.
 */
export {};