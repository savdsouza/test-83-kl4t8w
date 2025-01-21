import React, {
  useEffect,
  useRef,
  useState,
  useCallback,
  useMemo,
  MutableRefObject,
} from 'react';
// Lodash v4.17.21 for performance optimization (debouncing, etc.)
import { debounce } from 'lodash';

// Internal Imports (Enterprise-Grade Map Service & Config)
import { MapService } from '../../services/maps.service'; // Enhanced service for managing map functionality
import { mapConfig } from '../../config/maps.config'; // Enhanced configuration for performance & clustering

/**
 * MapViewProps
 * ----------------------------------------------------------------------------
 * Interface defining all props for the MapView component, supporting
 * real-time location tracking, route display, performance toggles,
 * clustering, and robust error handling.
 */
export interface MapViewProps {
  /**
   * center
   * Optional initial center coordinates of the map.
   */
  center?: { lat: number; lng: number };

  /**
   * zoom
   * Optional initial zoom level for the map.
   */
  zoom?: number;

  /**
   * walkerLocations
   * Array of walker location objects, each containing a unique ID
   * and a position (latitude & longitude). Used to display markers
   * for each walker on the map.
   */
  walkerLocations?: Array<{
    id: string;
    position: { lat: number; lng: number };
  }>;

  /**
   * routeCoordinates
   * Array of latitude/longitude coordinates representing the walk route.
   * Used for drawing a polyline on the map to visualize an active or
   * historical route.
   */
  routeCoordinates?: Array<{ lat: number; lng: number }>;

  /**
   * onMapClick
   * Optional callback function invoked whenever the user clicks on the map.
   * Receives the google.maps.MouseEvent as an argument.
   */
  onMapClick?: (event: google.maps.MouseEvent) => void;

  /**
   * performanceMode
   * If true, the component applies additional optimizations for
   * low-end devices, possibly adjusting rendering intervals or
   * reducing feature overhead.
   */
  performanceMode?: boolean;

  /**
   * enableClustering
   * Toggles whether marker clustering should be used for walker markers,
   * potentially improving map performance and clarity with large numbers
   * of markers.
   */
  enableClustering?: boolean;

  /**
   * onError
   * Callback function for handling errors raised during map initialization,
   * updates, or other runtime issues. Receives the error object as an argument.
   */
  onError?: (error: Error) => void;
}

/**
 * MapView
 * ----------------------------------------------------------------------------
 * A reusable React functional component that integrates the enterprise-grade
 * MapService to render and manage a Google Maps instance. This component
 * supports advanced performance optimizations, accessibility features,
 * marker clustering, route drawing, and real-time walker location updates.
 * 
 * Steps:
 *  1) Manage local state for errors and loading feedback.
 *  2) Create refs for container div and MapService instance.
 *  3) Initialize the map with robust error handling and accessibility.
 *  4) Implement debounced marker updates for walker locations.
 *  5) Draw or update route polylines for a provided route.
 *  6) Handle map click events, if provided.
 *  7) Provide toggles for clustering and performance mode optimizations.
 *  8) Implement basic keyboard accessibility and performance monitoring.
 *  9) Clean up on unmount to prevent memory leaks and stale references.
 *
 * @param props MapViewProps - The component props conforming to the above interface.
 * @returns JSX.Element - The rendered map container.
 */
export default function MapView(props: MapViewProps): JSX.Element {
  //--------------------------------------------------------------------------
  // State Definitions
  //--------------------------------------------------------------------------
  /**
   * Local state for capturing errors encountered during initialization
   * or while updating walker markers.
   */
  const [error, setError] = useState<Error | null>(null);

  /**
   * Tracks whether the map is still being set up or if asynchronous
   * operations are in progress. This can be used to display loading
   * indicators or placeholders.
   */
  const [isLoading, setIsLoading] = useState<boolean>(true);

  //--------------------------------------------------------------------------
  // Refs for Map & MapService
  //--------------------------------------------------------------------------
  /**
   * containerRef points to the DOM element where the Google Maps instance
   * will be rendered. This is needed for the MapService to attach the map.
   */
  const containerRef = useRef<HTMLDivElement | null>(null);

  /**
   * mapServiceRef holds the instance of MapService, providing access
   * to methods such as initializeMap, updateWalkerLocation, drawRoute, etc.
   */
  const mapServiceRef = useRef<MapService | null>(null);

  //--------------------------------------------------------------------------
  // Performance Related: Debounce Setup
  //--------------------------------------------------------------------------
  /**
   * If performanceMode is enabled, we can debounce walker location updates
   * more aggressively. Otherwise, use a smaller interval for more immediate
   * updates.
   */
  const locationDebounceInterval = useMemo(() => {
    if (props.performanceMode) {
      // In performance mode, we slow down updates for better efficiency.
      return 3000;
    }
    // Default or faster interval for more realtime feedback.
    return 1000;
  }, [props.performanceMode]);

  /**
   * debouncedUpdateWalker is a memoized function that wraps
   * MapService.updateWalkerLocation in a debounce to avoid excessive
   * re-renders or API calls.
   */
  const debouncedUpdateWalker = useCallback(
    debounce(
      (walkerId: string, position: { lat: number; lng: number }) => {
        if (mapServiceRef.current) {
          mapServiceRef.current
            .updateWalkerLocation(walkerId, position)
            .catch((err) => handleError(err as Error));
        }
      },
      locationDebounceInterval,
      { leading: false, trailing: true }
    ),
    [locationDebounceInterval]
  );

  //--------------------------------------------------------------------------
  // Error Handling Method
  //--------------------------------------------------------------------------
  /**
   * handleError provides a unified place to manage errors. It sets
   * local state and calls the consumer's optional onError callback.
   */
  const handleError = (err: Error): void => {
    setError(err);
    if (props.onError) {
      props.onError(err);
    }
  };

  //--------------------------------------------------------------------------
  // Map Initialization
  //--------------------------------------------------------------------------
  useEffect(() => {
    /**
     * We initialize the MapService and attempt to create the Google Map
     * using the containerRef. If successful, we enable certain features
     * like marker clustering based on enableClustering, then track completion
     * to hide any loading indicator. If unsuccessful, we handle errors.
     */
    const initialize = async () => {
      try {
        // 1) Create a new MapService instance.
        const service = new MapService();

        // 2) Adjust service-level performance settings if needed.
        service.locationUpdateDebounceTime = props.performanceMode ? 4000 : 2000;

        // 3) Save reference to mapServiceRef for all subsequent calls.
        mapServiceRef.current = service;

        // 4) Define final mapOptions, merging user preferences with config defaults.
        const mapOptions: google.maps.MapOptions = {
          center: props.center || mapConfig.defaultCenter,
          zoom: props.zoom || mapConfig.defaultZoom,
          ...mapConfig.options,
        };

        // 5) If clustering is toggled off, we might override mapConfig settings.
        if (props.enableClustering === false) {
          (mapOptions as any).markerClustering = { enabled: false };
        }

        // 6) Ensure containerRef is valid before calling initialize.
        if (!containerRef.current) {
          throw new Error(
            '[MapView] No valid containerRef found for rendering Google Map.'
          );
        }

        // 7) Initialize the map using MapService.
        await service.initializeMap(containerRef.current, mapOptions);

        // 8) If the consumer wants to react to map clicks, attach a handler.
        if (props.onMapClick) {
          service.mapInstance.addListener('click', (event: google.maps.MapMouseEvent) => {
            if (props.onMapClick && event) {
              props.onMapClick(event);
            }
          });
        }

        // 9) Conclude loading state on success.
        setIsLoading(false);
      } catch (initError) {
        handleError(initError as Error);
        setIsLoading(false);
      }
    };

    initialize().catch((err) => handleError(err as Error));

    // Cleanup routine executed on component unmount:
    // Here we remove markers, polylines, or any other allocated resources.
    return () => {
      try {
        if (mapServiceRef.current) {
          // MapService may optionally have a custom cleanup method.
          // We assume it will remove markers, polylines, etc.
          if (typeof (mapServiceRef.current as any).cleanupMap === 'function') {
            (mapServiceRef.current as any).cleanupMap();
          }
          mapServiceRef.current = null;
        }
      } catch (cleanupErr) {
        // We still handle errors encountered during teardown.
        handleError(cleanupErr as Error);
      }
    };
    // We only want this run once at mount/unmount, so no dependencies.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  //--------------------------------------------------------------------------
  // Effect: Update Walker Locations
  //--------------------------------------------------------------------------
  useEffect(() => {
    /**
     * Whenever walkerLocations changes, we update or create markers
     * for each walker on the map. Each update is debounced individually
     * to avoid rapid thrashing.
     */
    if (!props.walkerLocations || !mapServiceRef.current) {
      return;
    }

    props.walkerLocations.forEach((walker) => {
      debouncedUpdateWalker(walker.id, walker.position);
    });
  }, [props.walkerLocations, debouncedUpdateWalker]);

  //--------------------------------------------------------------------------
  // Effect: Draw or Update Route
  //--------------------------------------------------------------------------
  useEffect(() => {
    /**
     * If routeCoordinates are provided, we instruct the MapService
     * to draw or update the route on the map. If no routeCoordinates, we
     * could optionally clear the route if needed.
     */
    if (!mapServiceRef.current || !props.routeCoordinates) {
      return;
    }

    try {
      mapServiceRef.current.drawRoute(props.routeCoordinates);
    } catch (routeErr) {
      handleError(routeErr as Error);
    }
  }, [props.routeCoordinates]);

  //--------------------------------------------------------------------------
  // Accessibility & Keyboard Navigation
  //--------------------------------------------------------------------------
  /**
   * We can implement optional keyboard handlers to navigate the map
   * or focus on markers. In real-world scenarios, advanced logic
   * may be added here for better accessibility.
   */
  const handleKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    // Example: Press 'Escape' to recenter the map.
    if (event.key === 'Escape' && mapServiceRef.current) {
      mapServiceRef.current.mapInstance.setCenter(mapConfig.defaultCenter);
      mapServiceRef.current.mapInstance.setZoom(mapConfig.defaultZoom);
    }
  };

  //--------------------------------------------------------------------------
  // Render
  //--------------------------------------------------------------------------
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        position: 'relative',
        outline: 'none',
      }}
      tabIndex={0}
      onKeyDown={handleKeyDown}
      ref={containerRef}
      aria-label="Map container for dog walking application"
      role="region"
    >
      {/* Optional: If desired, we could render a loading or error overlay */}
      {isLoading && (
        <div
          style={{
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            padding: '1rem',
            background: 'rgba(255, 255, 255, 0.8)',
            borderRadius: '4px',
            zIndex: 999,
          }}
        >
          Loading map...
        </div>
      )}
      {error && (
        <div
          style={{
            position: 'absolute',
            bottom: 0,
            left: 0,
            backgroundColor: '#f44336',
            color: '#fff',
            padding: '0.75rem',
            margin: '0.5rem',
            borderRadius: '4px',
            zIndex: 999,
          }}
        >
          Map Error: {error.message}
        </div>
      )}
      {/* The map itself is rendered in containerRef. */}
    </div>
  );
}