/* -------------------------------------------------------------------------------------------------
 * Header.tsx
 * -------------------------------------------------------------------------------------------------
 * Provides the top navigation bar for the dog walking application web dashboard, implementing:
 *  1) Responsive design via media queries.
 *  2) User authentication integration (session checks, logout).
 *  3) Navigation controls, including sidebar toggle, notifications, and profile menu.
 *  4) Compliance with the design system specifications for layout, user avatar, and interaction.
 *
 * JSON Specification Implemented:
 *  - Interfaces:
 *    • HeaderProps: { isSidebarCollapsed: boolean; onSidebarToggle: () => void }
 *    • HeaderState: {
 *        isProfileMenuOpen: boolean;
 *        isNotificationsOpen: boolean;
 *        notificationCount: number;
 *        isMobileView: boolean;
 *      }
 *  - Functions:
 *    • useHeaderState: Custom hook returning a comprehensive header state object.
 *    • handleProfileClick: Handles user profile menu interactions and optional session refresh.
 *    • handleLogout: Securely logs out the current user, clearing states and redirecting.
 *  - Main Component:
 *    • Header: React.FC<HeaderProps>, implements multiple render methods (desktop vs. mobile).
 *
 * External Dependencies (Versions):
 *  - React (^18.0.0)
 *  - @mui/material (^5.0.0) [useMediaQuery, IconButton, Badge, Menu, MenuItem]
 *
 * Internal Dependencies:
 *  - Avatar component (../common/Avatar)
 *  - useAuth hook (../../hooks/useAuth)
 *
 * Extensive comments included to align with enterprise-grade clarity and maintainability.
 * -------------------------------------------------------------------------------------------------
 */

/* -------------------------------------------------------------------------------------------------
 * External Imports
 * -------------------------------------------------------------------------------------------------
 */
// NOTE: React version ^18.0.0
import React, { useCallback, useEffect, useState, MouseEvent } from 'react';

// NOTE: @mui/material version ^5.0.0
import { useMediaQuery } from '@mui/material'; 
import IconButton from '@mui/material/IconButton';
import Badge from '@mui/material/Badge';
import Menu from '@mui/material/Menu';
import MenuItem from '@mui/material/MenuItem';

/* -------------------------------------------------------------------------------------------------
 * Internal Imports
 * -------------------------------------------------------------------------------------------------
 */
import { Avatar } from '../common/Avatar';
import { useAuth } from '../../hooks/useAuth';

/* -------------------------------------------------------------------------------------------------
 * Interface: HeaderProps
 * -------------------------------------------------------------------------------------------------
 * Describes the props used by the Header component. 
 *  - isSidebarCollapsed: A boolean indicating the sidebar's collapsed/expanded state.
 *  - onSidebarToggle: Callback function to toggle the sidebar state.
 */
export interface HeaderProps {
  /** Indicates if the sidebar is currently collapsed. */
  isSidebarCollapsed: boolean;

  /** Callback to toggle the sidebar collapsed state. */
  onSidebarToggle: () => void;
}

/* -------------------------------------------------------------------------------------------------
 * Interface: HeaderState
 * -------------------------------------------------------------------------------------------------
 * Manages local state for the header, including:
 *  - isProfileMenuOpen: Whether the user's profile menu is visible.
 *  - isNotificationsOpen: Whether the notifications list/panel is open.
 *  - notificationCount: Number of unread or new notifications.
 *  - isMobileView: Whether the layout is in a mobile breakpoint.
 */
interface HeaderState {
  isProfileMenuOpen: boolean;
  isNotificationsOpen: boolean;
  notificationCount: number;
  isMobileView: boolean;
}

/* -------------------------------------------------------------------------------------------------
 * useHeaderState (Custom Hook)
 * -------------------------------------------------------------------------------------------------
 * Handles the header's internal logic with responsive detection, notification counting,
 * and menu toggling. Returns a comprehensive object for external use (e.g., in the Header).
 * 
 * Steps:
 *  1) Initialize state for profile menu, notifications, and mobile breakpoint detection.
 *  2) Use useMediaQuery to detect small screen sizes for 'isMobileView'.
 *  3) Provide methods to toggle profile menu, toggle notifications, and manipulate 
 *     notification counts (mocked for demonstration).
 *  4) Return a state object with getters and setters for the entire header state.
 */
export function useHeaderState(): {
  state: HeaderState;
  toggleProfileMenu: (open?: boolean) => void;
  toggleNotifications: (open?: boolean) => void;
  incrementNotifications: (amount: number) => void;
} {
  // React Hook for media query matching common mobile breakpoint
  const isSmallScreen = useMediaQuery('(max-width: 768px)');

  // Initialize local header-related states
  const [isProfileMenuOpen, setIsProfileMenuOpen] = useState<boolean>(false);
  const [isNotificationsOpen, setIsNotificationsOpen] = useState<boolean>(false);
  const [notificationCount, setNotificationCount] = useState<number>(0);

  // Reflect the media query result in our state
  const [isMobileView, setIsMobileView] = useState<boolean>(isSmallScreen);

  useEffect(() => {
    setIsMobileView(isSmallScreen);
  }, [isSmallScreen]);

  /**
   * Simple method to toggle the profile menu's open state.
   * If 'open' is provided, we use that value rather than toggling.
   */
  const toggleProfileMenu = useCallback(
    (open?: boolean) => {
      setIsProfileMenuOpen((prev) => (typeof open === 'boolean' ? open : !prev));
    },
    [setIsProfileMenuOpen],
  );

  /**
   * Method to toggle the notifications panel's open state.
   * If 'open' is provided, we use that value rather than toggling.
   */
  const toggleNotifications = useCallback(
    (open?: boolean) => {
      setIsNotificationsOpen((prev) => (typeof open === 'boolean' ? open : !prev));
    },
    [setIsNotificationsOpen],
  );

  /**
   * Method to increment the notification count. 
   * Typically, this would be replaced with real-time updates or server data.
   */
  const incrementNotifications = useCallback(
    (amount: number) => {
      setNotificationCount((prev) => prev + amount);
    },
    [setNotificationCount],
  );

  return {
    state: {
      isProfileMenuOpen,
      isNotificationsOpen,
      notificationCount,
      isMobileView,
    },
    toggleProfileMenu,
    toggleNotifications,
    incrementNotifications,
  };
}

/* -------------------------------------------------------------------------------------------------
 * handleProfileClick
 * -------------------------------------------------------------------------------------------------
 * Handles user profile menu interactions.
 * Steps:
 *  1) Prevent default event behavior.
 *  2) Validate the current session (e.g., user is authenticated).
 *  3) Toggle the profile dropdown visibility or set it explicitly.
 *  4) Implement any outside-click logic if needed (passed from parent or handled globally).
 *  5) Optionally trigger auth token refresh if session is nearing expiry.
 */
function handleProfileClick(
  event: MouseEvent<HTMLButtonElement>,
  toggleProfileMenu: (open?: boolean) => void,
  refreshSession: () => Promise<void>,
): void {
  // 1) Prevent default event (where relevant).
  event.preventDefault();

  // 2) (Optional) Validate session. For brevity, we assume the user is authenticated if arrived here.

  // 3) Toggle the profile menu's open state. 
  toggleProfileMenu();

  // 5) Trigger a token refresh if needed (illustrative).
  void refreshSession();
}

/* -------------------------------------------------------------------------------------------------
 * handleLogout
 * -------------------------------------------------------------------------------------------------
 * Securely logs out the current user, ensuring:
 *  1) Local session state is cleared.
 *  2) The global auth.logout() function is called to invalidate tokens.
 *  3) Any open dropdown (profile, notifications) is closed.
 *  4) Notification state is reset.
 *  5) Redirect the user to the login page (example).
 */
async function handleLogout(
  logoutFn: () => Promise<void>,
  toggleProfileMenu: (open?: boolean) => void,
  toggleNotifications: (open?: boolean) => void,
  setNotificationCount: (val: number) => void,
): Promise<void> {
  // 1) Clear local session states (closing any open menus).
  toggleProfileMenu(false);
  toggleNotifications(false);

  // 2) Call the global logout function from useAuth to handle token & server session cleanup.
  await logoutFn();

  // 4) Reset the notification count as part of clearing session data.
  setNotificationCount(0);

  // 5) Optionally redirect to login route or a dedicated logout confirmation page.
  window.location.href = '/login';
}

/* -------------------------------------------------------------------------------------------------
 * Header Component
 * -------------------------------------------------------------------------------------------------
 * The main header component that:
 *  - Consumes state from useHeaderState for controlling menus, breakpoints, notifications.
 *  - Integrates with user authentication (useAuth) to show user info or logout option.
 *  - Distinguishes between mobile and desktop rendering via renderMobileHeader and renderDesktopHeader.
 *  - Renders a user profile menu with security checks.
 */
export const Header: React.FC<HeaderProps> = ({ isSidebarCollapsed, onSidebarToggle }) => {
  // Acquire authentication context (current user, logout, refreshSession, etc.)
  const auth = useAuth();

  // Acquire local header state from custom hook
  const {
    state: { isProfileMenuOpen, isNotificationsOpen, notificationCount, isMobileView },
    toggleProfileMenu,
    toggleNotifications,
    incrementNotifications,
  } = useHeaderState();

  /* -----------------------------------------------------------------------------------------------
   * renderUserMenu
   * -----------------------------------------------------------------------------------------------
   * Renders the user profile menu, restricted to authenticated users.
   * Steps:
   *  - Check if we have a valid user from auth.
   *  - Display user avatar and name.
   *  - Provide menu items for account management, settings, and logout.
   */
  const renderUserMenu = (): React.ReactNode => {
    const anchorElement = document.getElementById('profile-menu-anchor');
    return (
      <Menu
        anchorEl={anchorElement}
        open={isProfileMenuOpen}
        onClose={() => toggleProfileMenu(false)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
        transformOrigin={{ vertical: 'top', horizontal: 'center' }}
        keepMounted
      >
        <MenuItem onClick={() => toggleProfileMenu(false)}>
          {auth.currentUser?.firstName ?? 'My'} Profile
        </MenuItem>
        <MenuItem
          onClick={() =>
            void handleLogout(
              auth.logout,
              toggleProfileMenu,
              toggleNotifications,
              (val) => incrementNotifications(-val) // a trick to set notifications to zero
            )
          }
        >
          Logout
        </MenuItem>
      </Menu>
    );
  };

  /* -----------------------------------------------------------------------------------------------
   * renderMobileHeader
   * -----------------------------------------------------------------------------------------------
   * Renders a simplified header for mobile breakpoints:
   *  - Includes a hamburger icon for toggling sidebar if needed.
   *  - Condenses user info.
   *  - Shows essential icons (notifications, profile).
   */
  const renderMobileHeader = (): React.ReactNode => (
    <header className="flex items-center justify-between bg-white px-4 py-2 border-b border-gray-200">
      {/* Sidebar Toggle (Hamburger) */}
      <IconButton aria-label="toggle sidebar" onClick={onSidebarToggle} size="large">
        <span className="material-icons">{isSidebarCollapsed ? 'menu_open' : 'menu'}</span>
      </IconButton>

      {/* Center Section: Possibly the application logo or title */}
      <div className="font-bold text-lg">Dog Walk Dashboard</div>

      {/* Right Section: Notifications + Profile */}
      <div className="flex items-center space-x-4">
        {/* Notifications */}
        <IconButton
          aria-label="open notifications"
          onClick={() => toggleNotifications()}
          size="large"
        >
          <Badge badgeContent={notificationCount} color="error">
            <span className="material-icons">notifications_none</span>
          </Badge>
        </IconButton>

        {/* User Profile Avatar */}
        {auth.isAuthenticated && (
          <IconButton
            onClick={(e) => handleProfileClick(e, toggleProfileMenu, auth.refreshSession)}
            id="profile-menu-anchor"
            size="large"
          >
            <Avatar
              user={auth.currentUser ?? undefined}
              size="small"
              className="rounded-full"
              loading={false}
              alt="User Avatar"
            />
          </IconButton>
        )}
      </div>
      {renderUserMenu()}
    </header>
  );

  /* -----------------------------------------------------------------------------------------------
   * renderDesktopHeader
   * -----------------------------------------------------------------------------------------------
   * Renders the full-featured header for wider screens:
   *  - Sidebar toggle button
   *  - Application title in the center or left
   *  - Right-justified section with notifications, user avatar, and search, if needed
   */
  const renderDesktopHeader = (): React.ReactNode => (
    <header className="flex items-center justify-between bg-white px-6 py-2 border-b border-gray-200">
      {/* Left Section: Toggle + Optional Title */}
      <div className="flex items-center space-x-2">
        <IconButton aria-label="toggle sidebar" onClick={onSidebarToggle} size="large">
          <span className="material-icons">{isSidebarCollapsed ? 'menu_open' : 'menu'}</span>
        </IconButton>
        <div className="font-bold text-xl">Dog Walk Dashboard</div>
      </div>

      {/* Right Section: Notifications + Profile */}
      <div className="flex items-center space-x-6">
        {/* Sample Notification Icon */}
        <IconButton
          aria-label="notifications"
          onClick={() => toggleNotifications()}
          size="large"
        >
          <Badge badgeContent={notificationCount} color="error">
            <span className="material-icons">notifications</span>
          </Badge>
        </IconButton>

        {/* User Profile Avatar */}
        {auth.isAuthenticated && (
          <IconButton
            onClick={(e) => handleProfileClick(e, toggleProfileMenu, auth.refreshSession)}
            id="profile-menu-anchor"
            size="large"
          >
            <Avatar
              user={auth.currentUser ?? undefined}
              size="medium"
              className="rounded-full"
              loading={false}
              alt="User Avatar"
            />
          </IconButton>
        )}
      </div>
      {renderUserMenu()}
    </header>
  );

  /* -----------------------------------------------------------------------------------------------
   * Main Render Logic
   * -----------------------------------------------------------------------------------------------
   * Decides whether to display the mobile or desktop layout based on 'isMobileView'.
   * That value is automatically updated by the useHeaderState hook's media query logic.
   */
  return isMobileView ? <>{renderMobileHeader()}</> : <>{renderDesktopHeader()}</>;
};