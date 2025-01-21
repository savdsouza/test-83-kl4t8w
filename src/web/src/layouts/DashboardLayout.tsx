import React, {
  FC,
  ReactNode,
  useEffect,
  useState,
  useCallback,
  KeyboardEvent
} from 'react';
// NOTE: react@^18.0.0

import styled from 'styled-components';
// NOTE: styled-components@^6.0.0

import { useMediaQuery } from '@mui/material';
// NOTE: @mui/material@^5.0.0

import { useAuth } from '@auth/core';
// NOTE: @auth/core@^0.5.0

// Internal Imports (matching the JSON specification for named imports)
import { Header } from '../components/layout/Header';
import { Navigation } from '../components/layout/Navigation';
import { Footer } from '../components/layout/Footer';

/* -------------------------------------------------------------------------------------------------
 * DashboardLayoutProps
 * -------------------------------------------------------------------------------------------------
 * Describes the props used by the DashboardLayout component, including:
 *  - children: ReactNode representing inner page content.
 *  - className: An optional string for custom styling overrides via class references.
 *  - disableSidebar: A boolean to disable or hide the sidebar entirely.
 */
export interface DashboardLayoutProps {
  /** The child nodes or React elements to be rendered inside the layout. */
  children: ReactNode;

  /** Optional CSS class name for targeted styling of the layout container. */
  className: string;

  /** If true, the sidebar will be disabled/hidden, forcing a single-column layout. */
  disableSidebar: boolean;
}

/* -------------------------------------------------------------------------------------------------
 * Interface: UseDashboardLayoutReturn
 * -------------------------------------------------------------------------------------------------
 * Describes the shape of the state and methods returned by useDashboardLayout,
 * including sidebar collapsed state, toggling logic, theme handling, etc.
 */
interface UseDashboardLayoutReturn {
  /** Indicates if the sidebar is currently collapsed to minimal width. */
  isSidebarCollapsed: boolean;

  /** Function to toggle the sidebar collapsed state. */
  handleSidebarToggle: () => void;

  /** Flag tracking if the dark theme is active. */
  isDarkTheme: boolean;

  /** Function to toggle between light and dark themes. */
  handleThemeToggle: () => void;
}

/* -------------------------------------------------------------------------------------------------
 * useDashboardLayout (Custom Hook)
 * -------------------------------------------------------------------------------------------------
 * Manages the primary layout logic, covering:
 *  1) Sidebar collapsed state with localStorage persistence.
 *  2) Media query detection for responsive breakpoints.
 *  3) Theme toggling and persistent storage of user preference.
 *  4) Keyboard accessibility for toggling layout features.
 *  5) Returning all relevant state and methods for layout control.
 *
 * @param initialCollapsed - Initial boolean controlling sidebar collapse state.
 * @returns An object with layout states and handler methods.
 */
export function useDashboardLayout(initialCollapsed: boolean): UseDashboardLayoutReturn {
  // (1) Retrieve any stored sidebar collapse preference from localStorage, else use initial.
  const storedSidebar = localStorage.getItem('dashboard.sidebarCollapsed');
  const parsedSidebar = storedSidebar ? JSON.parse(storedSidebar) : initialCollapsed;
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState<boolean>(parsedSidebar);

  // (2) Media query: can be used if we want to auto-expand or collapse the sidebar on large screens.
  const isAboveMd = useMediaQuery('(min-width: 1024px)');

  // (3) Theme management: track a simple dark mode toggle with localStorage or default.
  const storedTheme = localStorage.getItem('dashboard.theme');
  const defaultIsDark = storedTheme === 'dark';
  const [isDarkTheme, setIsDarkTheme] = useState<boolean>(defaultIsDark);

  // (4) On mount or changes, persist states in localStorage for consistency across page reloads.
  useEffect(() => {
    localStorage.setItem('dashboard.sidebarCollapsed', JSON.stringify(isSidebarCollapsed));
  }, [isSidebarCollapsed]);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', isDarkTheme ? 'dark' : 'light');
    localStorage.setItem('dashboard.theme', isDarkTheme ? 'dark' : 'light');
  }, [isDarkTheme]);

  // (5) Toggle handlers for sidebar and theme states.
  const handleSidebarToggle = useCallback(() => {
    setIsSidebarCollapsed((prev) => !prev);
  }, []);

  const handleThemeToggle = useCallback(() => {
    setIsDarkTheme((prev) => !prev);
  }, []);

  // (6) Keyboard accessibility: e.g., alt + S to toggle sidebar for demonstration.
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent<HTMLDocument>) => {
      // Example: alt + shift + 'S' => toggle sidebar
      if (event.altKey && event.shiftKey && event.key.toLowerCase() === 's') {
        event.preventDefault();
        setIsSidebarCollapsed((prev) => !prev);
      }
      // Additional key combos for other layout features can be added here.
    };

    // Attach at document level
    const handleKeyDownWrapper = (e: any) => handleKeyDown(e);
    document.addEventListener('keydown', handleKeyDownWrapper);

    // Cleanup on unmount
    return () => {
      document.removeEventListener('keydown', handleKeyDownWrapper);
    };
  }, []);

  // (7) Optional logic: auto-expand sidebar if above certain breakpoints
  useEffect(() => {
    if (isAboveMd && isSidebarCollapsed) {
      // Potentially expand automatically on large screens
      // Keep or remove this logic based on design preference.
    }
  }, [isAboveMd, isSidebarCollapsed]);

  // Return the shape containing all relevant layout states and methods.
  return {
    isSidebarCollapsed,
    handleSidebarToggle,
    isDarkTheme,
    handleThemeToggle
  };
}

/* -------------------------------------------------------------------------------------------------
 * StyledLayout
 * -------------------------------------------------------------------------------------------------
 * A styled container for the entire dashboard layout, employing CSS grid
 * to position a collapsible sidebar, a main content region, and optionally
 * a footer. Automatically adjusts grid columns based on the isSidebarCollapsed prop.
 */
interface StyledLayoutProps {
  $collapsed: boolean;
}

const StyledLayout = styled.div<StyledLayoutProps>`
  /* Enable grid for a three-row layout: top (header), main content, bottom (footer) */
  display: grid;
  grid-template-columns: ${(props) => (props.$collapsed ? '80px 1fr' : '280px 1fr')};
  grid-template-rows: 64px 1fr auto;

  /* Ensure the layout extends at least the full viewport height */
  min-height: 100vh;

  /* Smooth transitions, especially for the sidebar column resizing */
  transition: all 0.3s ease-in-out;
`;

/* -------------------------------------------------------------------------------------------------
 * MainContent
 * -------------------------------------------------------------------------------------------------
 * A styled container for the primary inner content area of the dashboard,
 * wrapping the core page content. Allows vertical scrolling and transitions
 * background color for theme changes.
 */
const MainContent = styled.main`
  padding: var(--spacing-lg);
  overflow-y: auto;
  background-color: var(--color-background);
  transition: background-color 0.3s ease;
  contain: layout paint;
`;

/* -------------------------------------------------------------------------------------------------
 * DashboardLayout
 * -------------------------------------------------------------------------------------------------
 * The main functional component that composes:
 *  - Header: top bar for branding, toggles, user profile, etc.
 *  - Navigation: sidebar or main menu system (collapsible).
 *  - MainContent: the core area for page rendering.
 *  - Footer: bottom area for supplementary links, copyright.
 *
 * Props:
 *  - children, className, disableSidebar from DashboardLayoutProps
 * Implementation Steps:
 *  1) Acquire layout state from useDashboardLayout (sidebar, theme toggles, etc.).
 *  2) Acquire user info from useAuth if needed for passing to header or nav.
 *  3) Conditionally render or hide the sidebar if disableSidebar = true.
 *  4) Render the layout as a grid: [Navigation | MainContent] with a top header.
 *  5) Include the Footer in the last grid row.
 */
export const DashboardLayout: FC<DashboardLayoutProps> = ({
  children,
  className,
  disableSidebar
}) => {
  // (1) Acquire custom layout states: side nav collapse, theme toggler, etc.
  const {
    isSidebarCollapsed,
    handleSidebarToggle,
    isDarkTheme,
    handleThemeToggle
  } = useDashboardLayout(false);

  // (2) Acquire user authentication context if required
  const { currentUser } = useAuth();

  // (3) Decide if we disable the sidebar entirely
  const effectiveSidebarCollapsed = disableSidebar ? true : isSidebarCollapsed;

  return (
    <StyledLayout
      className={className}
      $collapsed={effectiveSidebarCollapsed}
      /* If the user wants no sidebar at all, we collapse forcibly. */
    >
      {/* Header: Full width across top row, ignoring the grid columns */}
      <Header
        isSidebarCollapsed={effectiveSidebarCollapsed}
        onSidebarToggle={handleSidebarToggle}
        /* If we want to pass user info: */
        userProfile={currentUser ?? undefined}
      />

      {/* Navigation (Sidebar): Occupies the first grid column if not disabled */}
      {disableSidebar ? null : (
        <Navigation
          className="dashboard-sidebar"
          role="navigation"
          routes={[]}
        />
      )}

      {/* Main content area: second grid column, row 2 */}
      <MainContent>
        {children}
      </MainContent>

      {/* Footer: Spans the bottom row (grid-row: 3), across both columns */}
      <Footer className="dashboard-footer" />
    </StyledLayout>
  );
};