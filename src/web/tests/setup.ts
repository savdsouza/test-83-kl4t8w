import '@testing-library/jest-dom'; // v^5.16.5
import 'jest-environment-jsdom'; // v^29.5.0

/**
 * Configure global browser APIs and mocks for Jest tests
 * to ensure a comprehensive testing environment.
 */

// -----------------------------------------------------------------------------
// Global window.matchMedia mock
// -----------------------------------------------------------------------------
if (!window.matchMedia) {
  window.matchMedia = (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: jest.fn(),
    removeListener: jest.fn(),
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  });
}

// -----------------------------------------------------------------------------
// Global window.ResizeObserver mock
// -----------------------------------------------------------------------------
if (!window.ResizeObserver) {
  window.ResizeObserver = jest
    .fn()
    .mockImplementation(() => ({
      observe: jest.fn(),
      unobserve: jest.fn(),
      disconnect: jest.fn(),
    }));
}

// -----------------------------------------------------------------------------
// Global fetch mock
// -----------------------------------------------------------------------------
if (!global.fetch) {
  global.fetch = jest.fn().mockImplementation(() =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve({}),
      text: () => Promise.resolve(''),
      blob: () => Promise.resolve(new Blob()),
      headers: new Headers(),
    })
  ) as jest.Mock;
}

// -----------------------------------------------------------------------------
// Global localStorage mock
// -----------------------------------------------------------------------------
Object.defineProperty(window, 'localStorage', {
  value: {
    getItem: jest.fn(),
    setItem: jest.fn(),
    removeItem: jest.fn(),
    clear: jest.fn(),
    length: 0,
    key: jest.fn(),
  },
  writable: true,
});

// -----------------------------------------------------------------------------
// Global sessionStorage mock
// -----------------------------------------------------------------------------
Object.defineProperty(window, 'sessionStorage', {
  value: {
    getItem: jest.fn(),
    setItem: jest.fn(),
    removeItem: jest.fn(),
    clear: jest.fn(),
    length: 0,
    key: jest.fn(),
  },
  writable: true,
});

// -----------------------------------------------------------------------------
// Mock WebSocket for testing real-time features
// -----------------------------------------------------------------------------
(global as any).WebSocket = jest.fn().mockImplementation(() => ({
  send: jest.fn(),
  close: jest.fn(),
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
  readyState: WebSocket.CONNECTING,
  onopen: null,
  onclose: null,
  onmessage: null,
  onerror: null,
}));

// -----------------------------------------------------------------------------
// Mock Geolocation for testing location-based features
// -----------------------------------------------------------------------------
Object.defineProperty(global.navigator, 'geolocation', {
  value: {
    getCurrentPosition: jest
      .fn()
      .mockImplementation((success: (pos: { coords: { latitude: number; longitude: number; accuracy: number } }) => void) => {
        success({
          coords: {
            latitude: 40.7128,
            longitude: -74.0060,
            accuracy: 10,
          },
        });
      }),
    watchPosition: jest.fn(),
    clearWatch: jest.fn(),
  },
});

/**
 * Sets up a comprehensive Google Maps mock for testing map components,
 * including markers, routes, and geolocation features.
 */
export function setupGoogleMaps(): void {
  // Create mock google.maps namespace if not already present
  if (!(window as any).google) {
    (window as any).google = {};
  }
  if (!(window as any).google.maps) {
    (window as any).google.maps = {};
  }

  // Mock Map class
  (window as any).google.maps.Map = jest.fn().mockImplementation(() => ({
    setCenter: jest.fn(),
    setZoom: jest.fn(),
    addListener: jest.fn(),
    getCenter: jest.fn(),
    getZoom: jest.fn(),
  }));

  // Mock Marker class
  (window as any).google.maps.Marker = jest.fn().mockImplementation(() => ({
    setPosition: jest.fn(),
    setMap: jest.fn(),
    addListener: jest.fn(),
  }));

  // Mock LatLng class
  (window as any).google.maps.LatLng = jest.fn().mockImplementation((lat: number, lng: number) => ({
    lat: jest.fn(() => lat),
    lng: jest.fn(() => lng),
  }));

  // Mock InfoWindow class
  (window as any).google.maps.InfoWindow = jest.fn().mockImplementation(() => ({
    setContent: jest.fn(),
    open: jest.fn(),
    close: jest.fn(),
  }));

  // Mock DirectionsService
  (window as any).google.maps.DirectionsService = jest.fn().mockImplementation(() => ({
    route: jest.fn().mockImplementation((_: unknown, callback: (result: any, status: any) => void) => {
      callback(null, 'OK');
    }),
  }));

  // Event binding and triggering
  (window as any).google.maps.event = {
    addListener: jest.fn(),
    removeListener: jest.fn(),
    trigger: jest.fn(),
  };
}

/**
 * Sets up an IntersectionObserver mock for testing components
 * that rely on scroll detection and infinite loading functionality.
 */
export function setupIntersectionObserver(): void {
  class MockIntersectionObserver {
    private callback: IntersectionObserverCallback;
    private elements: Element[];

    constructor(callback: IntersectionObserverCallback) {
      this.callback = callback;
      this.elements = [];
    }

    observe(element: Element): void {
      if (!this.elements.includes(element)) {
        this.elements.push(element);
      }
      this.callback(
        this.elements.map((el) => ({
          isIntersecting: true,
          intersectionRatio: 1,
          target: el,
        })) as IntersectionObserverEntry[],
        this as unknown as IntersectionObserver
      );
    }

    unobserve(element: Element): void {
      this.elements = this.elements.filter((el) => el !== element);
    }

    disconnect(): void {
      this.elements = [];
    }

    takeRecords(): IntersectionObserverEntry[] {
      return this.elements.map((el) => ({
        isIntersecting: true,
        intersectionRatio: 1,
        target: el,
      })) as IntersectionObserverEntry[];
    }
  }

  Object.defineProperty(window, 'IntersectionObserver', {
    writable: true,
    configurable: true,
    value: MockIntersectionObserver,
  });
}