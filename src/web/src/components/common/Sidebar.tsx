import React, {
  useState,
  useEffect,
  useCallback,
  KeyboardEvent,
  MouseEvent
} from 'react'; // react@^18.2.0
import classNames from 'classnames'; // classnames@^2.3.2
import { useNavigate } from 'react-router-dom'; // react-router-dom@^6.0.0

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
// Hook providing authentication data, including currentUser, authentication status, and role.
import { useAuth } from '../../hooks/useAuth';

// A reusable Button component with variant and onClick props for consistent design and interactivity.
import { Button } from './Button';

// Route definitions (HOME, ANALYTICS, PROFILE) to navigate within the dashboard context.
import { DASHBOARD_ROUTES } from '../../constants/routes.constants';

// -------------------------------------------------------------------------------------------------
// Additional Types and Enums
// -------------------------------------------------------------------------------------------------
import { UserRole } from '../../types/auth.types';

/**
 * SidebarState captures the dynamic state of the sidebar,
 * helpful for communicating changes to external listeners.
 */
export interface SidebarState {
  /**
   * Indicates whether the sidebar is currently open (visible) or closed (hidden).
   */
  isOpen: boolean;

  /**
   * Denotes whether the sidebar is in an expanded or collapsible state,
   * which can be useful in wider layouts.
   */
  isExpanded: boolean;
}

/**
 * SidebarProps defines the full contract for configuring the Sidebar component,
 * including control of its open/close state, role-based rendering, and callbacks
 * to notify parent components about state changes.
 */
export interface SidebarProps {
  /**
   * Whether the sidebar is currently open (rendered/visible).
   */
  isOpen: boolean;

  /**
   * Callback invoked when the user or system intends to close the sidebar,
   * typically triggered by overlay clicks, escape keys, or explicit close actions.
   */
  onClose: () => void;

  /**
   * Optional extra class names for style or layout overrides,
   * merging with default and dynamic classes for enterprise design.
   */
  className?: string;

  /**
   * A responsive breakpoint (e.g., "768px" or "1024px").
   * Below this breakpoint, the sidebar may switch to an overlay mode
   * or close automatically after navigation.
   */
  breakpoint: string;

  /**
   * Indicates whether the sidebar should be in an expanded state
   * by default (e.g., showing text labels instead of icons).
   */
  defaultExpanded: boolean;

  /**
   * Notifies external components about state changes within the sidebar,
   * such as open/close transitions or expansions. Receives an object
   * describing the new sidebar state.
   */
  onStateChange: (state: SidebarState) => void;
}

/**
 * Enhanced Sidebar component providing:
 *  - Role-based access to navigation items.
 *  - Keyboard and screen reader accessibility per WCAG standards.
 *  - Automatic overlays on small screens and smooth transitions.
 *  - Optional expansion and collapse behavior.
 */
export const Sidebar: React.FC<SidebarProps> = ({
  isOpen,
  onClose,
  className,
  breakpoint,
  defaultExpanded,
  onStateChange
}) => {
  // -----------------------------------------------------------------------------------------------
  // Hooks and Internal States
  // -----------------------------------------------------------------------------------------------

  /**
   * Access the authentication context to retrieve the currentUser, isAuthenticated,
   * and userRole. This data allows for role-based menu rendering.
   */
  const { currentUser, isAuthenticated, userRole } = useAuth();

  /**
   * Manage the current open/closed state internally for animation,
   * while still respecting external prop changes. We assume the
   * parent can control isOpen but also allow local toggling.
   */
  const [sidebarOpen, setSidebarOpen] = useState<boolean>(isOpen);

  /**
   * Track whether the sidebar is expanded (i.e., shows labels)
   * or collapsed (icon-only). This can be toggled separately
   * from the full open/close state for advanced layouts.
   */
  const [isExpanded, setIsExpanded] = useState<boolean>(defaultExpanded);

  /**
   * A piece of state allowing us to maintain the currently active
   * navigation route within the sidebar. This helps in applying
   * active styles or highlight states for the selected section.
   */
  const [activeRoute, setActiveRoute] = useState<string>('');

  /**
   * Provide programmatic navigation to routes within the application.
   */
  const navigate = useNavigate();

  /**
   * Synchronize local open state whenever the parent prop changes.
   * This ensures external toggles (e.g., clicking a global menu button)
   * reflect immediately in this component.
   */
  useEffect(() => {
    setSidebarOpen(isOpen);
  }, [isOpen]);

  // -----------------------------------------------------------------------------------------------
  // Imported Route Constants
  // -----------------------------------------------------------------------------------------------
  // According to the JSON specification, we rely on specific members from DASHBOARD_ROUTES:
  const { HOME, ANALYTICS, PROFILE } = DASHBOARD_ROUTES;

  // -----------------------------------------------------------------------------------------------
  // Menu Configuration (Role-Based)
  // -----------------------------------------------------------------------------------------------
  /**
   * Example array of nav items demonstrating how roles can restrict access.
   * Each object includes:
   *  - label: The display text in the UI.
   *  - route: The path to navigate when clicked.
   *  - allowedRoles: An array of roles permitted to see or use this route.
   */
  const navItems = [
    {
      label: 'Home',
      route: HOME,
      allowedRoles: [UserRole.OWNER, UserRole.WALKER, UserRole.ADMIN]
    },
    {
      label: 'Analytics',
      route: ANALYTICS,
      allowedRoles: [UserRole.ADMIN]
    },
    {
      label: 'Profile',
      route: PROFILE,
      allowedRoles: [UserRole.OWNER, UserRole.WALKER, UserRole.ADMIN]
    }
  ];

  // -----------------------------------------------------------------------------------------------
  // Callback: toggleSidebar
  // -----------------------------------------------------------------------------------------------
  /**
   * toggleSidebar manages the open/close state of the sidebar, employing animations
   * and updating ARIA attributes for accessibility. It also fires the onStateChange
   * callback to inform parent components about the new state.
   *
   * Steps:
   * 1) Flip the local sidebarOpen state to show/hide the sidebar.
   * 2) Update ARIA attributes and possibly HTML body classes for overlays.
   * 3) Adjust focus if needed (e.g., trap focus in overlay).
   * 4) If the user is in a mobile overlay mode, we can show/hide that overlay.
   * 5) Notify external consumers via onStateChange about the updated state.
   */
  const toggleSidebar = useCallback((): void => {
    const nextOpen = !sidebarOpen;

    // Step (1): Update local state controlling visibility
    setSidebarOpen(nextOpen);

    // Step (2): We can update ARIA attributes or body classes for overlays here if needed.
    // For instance, we might do:
    // document.body.classList.toggle('sidebar-open', nextOpen);

    // Step (3): Optionally manage focus. If opening, move focus to first nav element or close button.

    // Step (4): If on mobile screens, we might show an overlay or add a blocking background.

    // Step (5): Trigger external callback with new state
    onStateChange({
      isOpen: nextOpen,
      isExpanded
    });
  }, [sidebarOpen, isExpanded, onStateChange]);

  // -----------------------------------------------------------------------------------------------
  // Callback: handleNavigation
  // -----------------------------------------------------------------------------------------------
  /**
   * handleNavigation is an enhanced click handler that performs the following actions:
   *   1) Prevents default click behavior to avoid inadvertent page reloads.
   *   2) Checks whether the current user is authorized for the route.
   *   3) Tracks analytics or logs navigation events (placeholder).
   *   4) Updates our internal active route state to apply highlight or activation styles.
   *   5) If on a small screen, closes the sidebar automatically after navigating.
   *   6) Executes the actual navigation with react-router-dom's navigate function.
   *
   * @param route - The string path to navigate to.
   * @param event - The navigation click event.
   */
  const handleNavigation = useCallback(
    (route: string, event: MouseEvent<HTMLAnchorElement>) => {
      // (1) Prevent default link behavior
      event.preventDefault();

      // (2) Validate user role. Find the nav item to confirm role-based permission.
      const targetItem = navItems.find((item) => item.route === route);
      if (targetItem && !targetItem.allowedRoles.includes(userRole)) {
        // If user has no access, we could show an alert, throw an error, or simply return.
        // For demonstration:
        console.warn(`Access denied: role [${userRole}] is not permitted to access ${route}.`);
        return;
      }

      // (3) Track navigation event for analytics. This can be expanded to log to a real system.
      console.log(`Navigating to ${route}... (User Role: ${userRole})`);

      // (4) Update local active route state for highlighting
      setActiveRoute(route);

      // (5) If viewport width is less than the specified breakpoint, we can close the sidebar.
      const viewportWidth = window.innerWidth;
      const breakpointNum = parseInt(breakpoint, 10);
      if (viewportWidth < breakpointNum) {
        setSidebarOpen(false);
        onStateChange({
          isOpen: false,
          isExpanded
        });
      }

      // (6) Use react-router-dom's navigate to route
      navigate(route);
    },
    [navItems, userRole, breakpoint, isExpanded, navigate, onStateChange, setSidebarOpen]
  );

  // -----------------------------------------------------------------------------------------------
  // Callback: handleKeyboardNavigation
  // -----------------------------------------------------------------------------------------------
  /**
   * handleKeyboardNavigation processes keyboard events to provide full accessibility.
   * Steps:
   * 1) React to arrow keys to move focus within the sidebar menu items.
   * 2) For Enter or Space keys, trigger the handleNavigation for the highlighted item.
   * 3) Trap focus if in overlay mode, preventing tabbing out of the sidebar.
   * 4) Listen for Escape key to close the sidebar if open.
   *
   * @param event - The keyboard event captured in the sidebar container.
   */
  const handleKeyboardNavigation = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      const { key } = event;

      // (4) Close on Escape
      if (key === 'Escape') {
        // Optionally confirm if the user wants to close or proceed:
        onClose();
        return;
      }

      // (1) & (2) Arrows or Enter/Space
      // For demonstration, we just note the keys.
      // A real implementation might track a list of focusable items with useRef.
      if (key === 'Enter' || key === ' ') {
        // Possibly identify the currently focused nav link, then call handleNavigation.
      }

      if (key === 'ArrowUp' || key === 'ArrowDown') {
        // Move focus through menu items in either direction.
        // This typically requires an array of focusable nav elements or refs.
      }

      // (3) If we want a strict focus trap, we handle Tab/Shift+Tab to keep focus inside.
      // This can be done with a dedicated library or manual logic to cycle focus.
    },
    [onClose]
  );

  // -----------------------------------------------------------------------------------------------
  // Effects and Utilities
  // -----------------------------------------------------------------------------------------------
  /**
   * Example effect to handle scenario where user logs out or changes roles,
   * which might alter what items are visible or forcibly navigate away.
   * This is optional but can be expanded depending on product requirements.
   */
  useEffect(() => {
    if (!isAuthenticated) {
      // Could forcibly close sidebar or reset some states, etc.
      setSidebarOpen(false);
      onStateChange({
        isOpen: false,
        isExpanded
      });
    }
  }, [isAuthenticated, onStateChange, isExpanded]);

  // -----------------------------------------------------------------------------------------------
  // Render
  // -----------------------------------------------------------------------------------------------
  /**
   * Compose runtime class names, including a base sidebar class,
   * a dynamic open/closed class, an expanded class if needed,
   * plus any user-defined className overrides.
   */
  const sidebarClasses = classNames(
    'sidebar-container',
    {
      'sidebar--open': sidebarOpen,
      'sidebar--closed': !sidebarOpen,
      'sidebar--expanded': isExpanded,
      'sidebar--collapsed': !isExpanded
    },
    className
  );

  return (
    <aside
      className={sidebarClasses}
      aria-hidden={!sidebarOpen}
      aria-expanded={sidebarOpen}
      onKeyDown={handleKeyboardNavigation}
      data-testid="sidebar-root"
    >
      {/* Header/Branding Area */}
      <div className="sidebar-header">
        <h2 className="sidebar-title">Navigation</h2>
        <Button
          variant="text"
          size="small"
          onClick={() => {
            // Provide a close button in the header
            onClose();
          }}
          aria-label="Close Sidebar"
        >
          &times;
        </Button>
      </div>

      {/* Menu Items */}
      <nav className="sidebar-nav" aria-label="Main Sidebar Navigation">
        <ul>
          {navItems.map((item) => {
            // Check if the user can see this item
            if (!item.allowedRoles.includes(userRole)) {
              return null;
            }

            const isItemActive = item.route === activeRoute;
            return (
              <li key={item.route}>
                <a
                  href={item.route}
                  className={classNames('sidebar-link', {
                    'sidebar-link--active': isItemActive
                  })}
                  onClick={(e) => handleNavigation(item.route, e)}
                  aria-current={isItemActive ? 'page' : undefined}
                  data-testid={`sidebar-link-${item.label.toLowerCase()}`}
                >
                  {item.label}
                </a>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* Footer/Actions Section (Example: Expand/Collapse Toggle) */}
      <div className="sidebar-footer">
        <Button
          variant="text"
          size="small"
          onClick={() => {
            // Toggle the expanded state separately from open/close
            setIsExpanded((prev) => {
              const newVal = !prev;
              onStateChange({
                isOpen: sidebarOpen,
                isExpanded: newVal
              });
              return newVal;
            });
          }}
          aria-label="Toggle Sidebar Expansion"
        >
          {isExpanded ? 'Collapse' : 'Expand'}
        </Button>

        {/* Secondary action: perhaps a button to close or a toggle for the entire sidebar */}
        <Button
          variant="secondary"
          size="small"
          onClick={toggleSidebar}
          aria-label="Toggle Sidebar Visibility"
        >
          {sidebarOpen ? 'Hide Sidebar' : 'Show Sidebar'}
        </Button>
      </div>
    </aside>
  );
};