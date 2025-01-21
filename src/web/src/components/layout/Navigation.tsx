import React, {
  FC, // ^18.2.0
  useMemo,
  useCallback,
  useState
} from 'react';
import { Link, useLocation } from 'react-router-dom'; // react-router-dom ^6.0.0
import { useMediaQuery } from '@mui/material'; // @mui/material ^5.0.0
import { useAuth } from '../../hooks/useAuth'; // Internal: Authentication state hook
import { Button } from '../common/Button'; // Internal: Accessible button component

// Importing route constants according to specification
// Note: The specification references HOME, PROFILE, SETTINGS in DASHBOARD_ROUTES, which may
// not literally exist in the provided routes, but we adhere to the JSON spec's members used.
import {
  AUTH_ROUTES,    // Contains { LOGIN, REGISTER, ... }
  DASHBOARD_ROUTES // Contains (per spec) { HOME, PROFILE, SETTINGS } injected or mapped
} from '../../constants/routes.constants';

/**
 * NavigationProps
 * ------------------------------------------------------------------------------
 * Describes the external interface for the Navigation component, including
 * optional className for styling, aria-label for accessibility, and data-testid
 * for test automation hooks.
 */
export interface NavigationProps {
  /**
   * An optional set of class names that can be applied
   * to the container for layout or design overrides.
   */
  className?: string;

  /**
   * An ARIA label describing the overarching purpose
   * of this navigation region for assistive technologies.
   */
  'aria-label'?: string;

  /**
   * A unique identifier used by test frameworks
   * (e.g., Jest, Cypress) to locate this component.
   */
  'data-testid'?: string;
}

/**
 * Represents a single navigation item, encapsulating:
 *  - route: The path or URL to navigate to.
 *  - label: The user-visible text describing the destination.
 *  - icon: A string-based reference to an icon, if applicable.
 *  - ariaLabel: Accessibility label for screen reader usage.
 */
interface NavigationItem {
  route: string;
  label: string;
  icon?: string;
  ariaLabel: string;
}

/**
 * getNavigationItems
 * ------------------------------------------------------------------------------
 * Returns an array of NavigationItem objects tailored to the user's authentication
 * state, role, and whether the screen is in a mobile layout. This function
 * implements the steps from the JSON specification:
 *
 * Parameters:
 *  1. currentUser  - The currently authenticated user or null.
 *  2. isAuthenticated - Flag indicating if user is logged in.
 *  3. isMobile - Boolean indicating if the interface is rendered on a small viewport.
 *
 * Steps:
 *  1) Check authentication status and (optionally) loading states.
 *  2) Get user role from currentUser.
 *  3) Generate base navigation items.
 *  4) Add role-specific items for owners or walkers, if any.
 *  5) Add responsive layout attributes or omit items in mobile views, if needed.
 *  6) Include accessibility attributes in each nav item.
 *  7) Return the final array of NavigationItem objects.
 *
 * Returns:
 *  An array of fully populated NavigationItem objects with routes, labels, and ARIA support.
 */
function getNavigationItems(
  currentUser: { role?: string } | null,
  isAuthenticated: boolean,
  isMobile: boolean
): NavigationItem[] {
  // (1) In a real scenario, we might conditionally check a loading state as well, but
  //     the JSON specification focuses on user role and auth status. We'll skip an explicit
  //     isLoading check for brevity.

  // (2) Obtain user role. If none, default to a placeholder role or treat as 'guest.'
  const userRole = currentUser?.role || 'GUEST';

  // (3) Base navigation: If user is not authenticated, show login & registration links.
  //     If authenticated, proceed to certain default items or placeholders.
  let navItems: NavigationItem[] = [];

  if (!isAuthenticated) {
    navItems = [
      {
        route: AUTH_ROUTES.LOGIN,
        label: 'Login',
        icon: '[@]',
        ariaLabel: 'Login to your account'
      },
      {
        route: AUTH_ROUTES.REGISTER,
        label: 'Sign Up',
        icon: '[+]',
        ariaLabel: 'Create a new account'
      }
    ];
  } else {
    // For demonstration, we will suppose the specification's "HOME", "PROFILE", "SETTINGS"
    // exist under the imported DASHBOARD_ROUTES. The actual underlying file may differ.
    navItems = [
      {
        route: (DASHBOARD_ROUTES as any).HOME || '/', // Using fallback in case not literally defined
        label: 'Home',
        icon: '[#]',
        ariaLabel: 'Go to home/dashboard'
      },
      {
        route: (DASHBOARD_ROUTES as any).PROFILE || '/profile',
        label: 'Profile',
        icon: '[@]',
        ariaLabel: 'View your profile'
      },
      {
        route: (DASHBOARD_ROUTES as any).SETTINGS || '/settings',
        label: 'Settings',
        icon: '[=]',
        ariaLabel: 'Review and update your settings'
      }
    ];

    // (4) Add role-specific items (owner vs walker vs admin). For instance:
    if (userRole === 'OWNER') {
      navItems.push({
        route: '/dashboard/owner',
        label: 'Owner Dashboard',
        icon: '[*]',
        ariaLabel: 'Access owner-specific dashboard'
      });
    } else if (userRole === 'WALKER') {
      navItems.push({
        route: '/dashboard/walker',
        label: 'Walker Dashboard',
        icon: '[$]',
        ariaLabel: 'Access walker-specific dashboard'
      });
    } else if (userRole === 'ADMIN') {
      navItems.push({
        route: '/admin',
        label: 'Admin Panel',
        icon: '[?]',
        ariaLabel: 'Go to the admin control panel'
      });
    }
  }

  // (5) Mark or customize items if in mobile view, e.g. shorten labels or hide certain items
  if (isMobile) {
    // Example: we might reduce label text or hide one item. This is only a placeholder illustration.
    navItems = navItems.map((item) => ({
      ...item,
      label: item.label.length > 10 ? item.label.substring(0, 10) + '…' : item.label
    }));
  }

  // (6) We already included ariaLabel in each item for accessibility.

  // (7) Return the final list of items
  return navItems;
}

/**
 * handleNavigation
 * ------------------------------------------------------------------------------
 * Manages the side effects of a navigation request, including loading states,
 * potential error handling, and analytics logging. Execution steps:
 *
 * 1) Track navigation attempt (e.g., console or analytics).
 * 2) Show loading state (local or global).
 * 3) Execute the navigation callback (which might be pushing to router history).
 * 4) In a try/catch, handle any errors from the callback.
 * 5) Update loading state after success/failure.
 * 6) Log analytics or other usage data.
 *
 * Parameters:
 *  1. route: The string representing the path or name of the route to track or navigate to.
 *  2. callback: A function that performs the actual navigation logic.
 *
 * Returns:
 *  void (no direct return value; side effects only).
 */
function handleNavigation(route: string, callback: () => void): void {
  // (1) Track navigation attempt
  //     In production, you might use an analytics service to track route usage.
  console.debug(`Navigation attempt to route: ${route}`);

  // (2) Show loading state - here we can simulate a local state or a global context
  //     For demonstration, we'll just log the state.
  let localLoading = true;
  console.debug(`Navigation loading: ${localLoading}`);

  try {
    // (3) Execute the provided callback, presumably routing to the new path
    callback();

    // (4) If any errors occur during navigation, they'd be caught
  } catch (error) {
    console.error(`Navigation error: ${(error as Error).message}`);
  } finally {
    // (5) Turn off loading state
    localLoading = false;
    console.debug(`Navigation loading: ${localLoading}`);
  }

  // (6) Log navigation analytics (placeholder)
  console.info(`Navigation to ${route} completed - analytics logged.`);
}

/**
 * Navigation
 * ------------------------------------------------------------------------------
 * A React functional component implementing the main navigation interface for the
 * dog walking platform web application. It addresses:
 *  - Role-based links (owner, walker, admin, or unauthenticated).
 *  - Responsive layout, collapsing or adjusting items for mobile usage.
 *  - Accessibility attributes (e.g., descriptive aria-labels) for screen readers.
 *
 * Usage:
 *  <Navigation className="topnav" aria-label="Main Navigation" data-testid="nav-test" />
 *
 * Props:
 *  - className?: string
 *  - aria-label?: string
 *  - data-testid?: string
 *
 * Exports:
 *  1. NavigationProps (interface)
 *  2. Navigation (React.FC<NavigationProps>)
 */
export const Navigation: FC<NavigationProps> = ({
  className,
  'aria-label': ariaLabel,
  'data-testid': dataTestId
}) => {
  /**
   * Access authentication state and user data from the custom hook.
   * The hook provides:
   *   - currentUser: The user object or null if not logged in.
   *   - isAuthenticated: Boolean indicating whether a valid login session exists.
   *   - isLoading: A boolean for ongoing auth checks.
   */
  const { currentUser, isAuthenticated, isLoading } = useAuth();

  /**
   * We can inspect the current route location to highlight active links
   * or conditionally render selectively. Not strictly required, but typical
   * for navigation.
   */
  const location = useLocation();

  /**
   * Determine if we are in a mobile context. For example, using a media query
   * that triggers at a 600px breakpoint. This can drive us to reduce nav item
   * text or use icons only for small screens.
   */
  const isMobile = useMediaQuery('(max-width:600px)');

  /**
   * Generate the final set of navigation items with memoization to avoid
   * unnecessary recalculations on every render.
   */
  const navItems = useMemo(
    () => getNavigationItems(currentUser, isAuthenticated, isMobile),
    [currentUser, isAuthenticated, isMobile]
  );

  /**
   * Local method to handle the final step of routing once a user
   * clicks a navigation link or button. We wrap "handleNavigation"
   * to supply a correct callback (using <Link> or a push).
   */
  const onNavigate = useCallback(
    (targetRoute: string) => {
      handleNavigation(targetRoute, () => {
        // Here we might do a SPA route push. Since we have <Link> usage below,
        // this callback remains minimal or purely for demonstration of side effects.
      });
    },
    []
  );

  return (
    <nav
      className={className || ''}
      aria-label={ariaLabel || 'Primary Navigation'}
      data-testid={dataTestId}
    >
      {/* Example: We might conditionally display a loading state if isLoading is true */}
      {isLoading && (
        <div className="nav__loading-indicator">
          {/* Could show a spinning icon or skeleton in a real application */}
          Authenticating user...
        </div>
      )}

      {/* Navigation item listing: each item is displayed as a Link or Button */}
      <ul className="nav__items">
        {navItems.map((item) => {
          const isActive = location.pathname === item.route;
          return (
            <li key={item.route} className={`nav__item ${isActive ? 'nav__item--active' : ''}`}>
              {/* Use react-router-dom Link for direct client-side navigation */}
              <Link
                to={item.route}
                aria-label={item.ariaLabel}
                className="nav__link"
                onClick={() => onNavigate(item.route)}
              >
                {/* A placeholder for an icon from the design system: */}
                <span aria-hidden="true" className="nav__icon">
                  {item.icon}
                </span>
                {/* Possibly condensed label if on mobile, or normal label otherwise */}
                {!isMobile && <span className="nav__label">{item.label}</span>}
              </Link>
            </li>
          );
        })}
      </ul>

      {/* Potentially a logout or secondary action button if authenticated */}
      {isAuthenticated && (
        <div className="nav__actions">
          <Button
            variant="secondary"
            size="medium"
            disabled={false}
            loading={false}
            fullWidth={false}
            aria-label="Logout"
            onClick={() => onNavigate(AUTH_ROUTES.LOGOUT)}
          >
            Logout
          </Button>
        </div>
      )}
    </nav>
  );
};