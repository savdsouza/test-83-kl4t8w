/**
 * Configuration file for Google Maps integration.
 * This file provides comprehensive settings for real-time location tracking,
 * custom map styling, and performance optimizations specific to dog walking visualization.
 * 
 * References:
 * - Technical Specifications/4.2.2 Supporting Libraries
 * - Technical Specifications/2.1 High-Level Architecture/Core Features
 */

// Importing the Loader from @googlemaps/js-api-loader (v1.16.2) for potential use in map initialization
import { Loader } from '@googlemaps/js-api-loader'; // v1.16.2

/**
 * DEFAULT_CENTER
 * ------------------------------------------------------
 * Default geographical center for the Google Map.
 * In this case, we are centering the map on New York City
 * with lat/long coordinates (40.7128, -74.006).
 */
const DEFAULT_CENTER = {
  lat: 40.7128,
  lng: -74.006,
};

/**
 * DEFAULT_ZOOM
 * ------------------------------------------------------
 * Default zoom level optimized for a neighborhood view.
 * The value of 13 offers a balanced perspective
 * suited to dog walking routes within urban areas.
 */
const DEFAULT_ZOOM = 13;

/**
 * MAP_STYLES
 * ------------------------------------------------------
 * An array of style rules applied to the map to customize
 * the visual presentation. This configuration reduces saturation
 * for a subtle look and highlights parks and roads with specific settings.
 */
const MAP_STYLES = [
  {
    featureType: 'all',
    stylers: [
      { saturation: -20 },
    ],
  },
  {
    featureType: 'poi.park',
    stylers: [
      { visibility: 'on' },
      { saturation: 10 },
    ],
  },
  {
    featureType: 'road',
    stylers: [
      { weight: 1.5 },
    ],
  },
];

/**
 * MAP_OPTIONS
 * ------------------------------------------------------
 * A comprehensive set of Google Maps initialization options
 * that emphasize real-time tracking performance and a user-friendly UI.
 * Includes constraints like min and max zoom, disabled clickable POI icons,
 * and controls for user gestures. Incorporates sub-configurations:
 *   - markerClustering
 *   - trackingOptions
 * for advanced features like cluster grouping of markers and real-time tracking.
 */
const MAP_OPTIONS = {
  zoomControl: true,
  mapTypeControl: false,
  streetViewControl: false,
  fullscreenControl: true,
  gestureHandling: 'cooperative',
  maxZoom: 19,
  minZoom: 10,
  clickableIcons: false,
  tilt: 0,
  optimized: true,
  /**
   * Applying the MAP_STYLES array to the map.
   */
  styles: MAP_STYLES,
  /**
   * markerClustering
   * --------------------------------------
   * Configures how markers are clustered on the map.
   * Useful for grouping multiple dog walkers or walk points in dense areas.
   */
  markerClustering: {
    enabled: true,
    maxZoom: 14,
    gridSize: 50,
  },
  /**
   * trackingOptions
   * --------------------------------------
   * Fine-grained parameters for real-time location updates.
   * Specifies how frequently positions are refreshed and how errors are handled.
   */
  trackingOptions: {
    updateInterval: 3000,    // Interval in ms for location updates
    smoothAnimation: true,   // Interpolate marker position changes
    retryOnError: true,      // Attempt to recover if a location fetch fails
    maxRetries: 3,           // Maximum retry attempts for errors
  },
};

/**
 * mapConfig
 * ------------------------------------------------------
 * Exports the primary configuration object with
 * the essential parameters for initializing and customizing
 * Google Maps for dog walking services. This object includes
 * the following properties:
 *   1) apiKey          -> string
 *   2) defaultCenter   -> object
 *   3) defaultZoom     -> number
 *   4) styles          -> array
 *   5) options         -> object
 *   6) markerIcons     -> object
 *   7) clusterOptions  -> object
 *   8) trackingConfig  -> object
 */
export const mapConfig = {
  /**
   * apiKey
   * ------------------------------------------------------
   * Google Maps API key required for map rendering.
   * Replace this placeholder with a valid key for production.
   */
  apiKey: 'YOUR_GOOGLE_MAPS_API_KEY_HERE',

  /**
   * defaultCenter
   * ------------------------------------------------------
   * JSON object representing the initial lat/lng for the map center.
   */
  defaultCenter: DEFAULT_CENTER,

  /**
   * defaultZoom
   * ------------------------------------------------------
   * The initial zoom level for the map upon load.
   */
  defaultZoom: DEFAULT_ZOOM,

  /**
   * styles
   * ------------------------------------------------------
   * Array containing visual styling rules for the map,
   * derived from MAP_STYLES.
   */
  styles: MAP_STYLES,

  /**
   * options
   * ------------------------------------------------------
   * Comprehensive map options that combine multiple settings
   * including gesture handling, controls visibility, and
   * real-time tracking needs. This merges directly into
   * the Google Maps MapOptions interface when creating the map.
   */
  options: MAP_OPTIONS,

  /**
   * markerIcons
   * ------------------------------------------------------
   * A collection of custom marker icons for various entities
   * such as dog walkers, dog owners, or points of interest.
   * These placeholder URLs should be replaced with actual icon paths.
   */
  markerIcons: {
    owner: 'https://example.com/icons/owner-icon.png',
    walker: 'https://example.com/icons/walker-icon.png',
    dog: 'https://example.com/icons/dog-icon.png',
    location: 'https://example.com/icons/current-location.png',
  },

  /**
   * clusterOptions
   * ------------------------------------------------------
   * Specific settings for marker clustering, extracted
   * from the MAP_OPTIONS.markerClustering property.
   */
  clusterOptions: {
    enabled: MAP_OPTIONS.markerClustering.enabled,
    maxZoom: MAP_OPTIONS.markerClustering.maxZoom,
    gridSize: MAP_OPTIONS.markerClustering.gridSize,
  },

  /**
   * trackingConfig
   * ------------------------------------------------------
   * Enhanced real-time tracking configuration extracted
   * from MAP_OPTIONS.trackingOptions.
   */
  trackingConfig: {
    updateInterval: MAP_OPTIONS.trackingOptions.updateInterval,
    smoothAnimation: MAP_OPTIONS.trackingOptions.smoothAnimation,
    retryOnError: MAP_OPTIONS.trackingOptions.retryOnError,
    maxRetries: MAP_OPTIONS.trackingOptions.maxRetries,
  },
};