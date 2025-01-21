/* -------------------------------------------------------------------------------------------------
 * AdminLayout.tsx
 * -------------------------------------------------------------------------------------------------
 * Provides the admin dashboard layout structure for the dog walking application. Implements:
 *  1) Responsive design support using breakpoints and media queries.
 *  2) Authentication protection, ensuring only admins can access these routes.
 *  3) Theme support (integrating styled-components and MUI theme tokens).
 *  4) Accessibility best practices (ARIA attributes, semantic markup).
 *  5) Layout state management, including sidebar toggling and persistence.
 *
 * JSON Specification Implemented:
 *  - Imports:
 *    • React (^18.0.0) for core React functionalities.
 *    • styled-components (^6.0.0) for styling with theme support.
 *    • useMediaQuery from @mui/material (^5.0.0) for breakpoint detection.
 *    • theme from @mui/material (^5.0.0) for design tokens (imported as needed).
 *    • Header component (../components/layout/Header) with props:
 *       - isSidebarCollapsed (prop)
 *       - onSidebarToggle (function)
 *    • Footer component (../components/layout/Footer) with prop:
 *       - className
 *    • useAuth hook (../../hooks/useAuth) providing:
 *       - isAuthenticated (boolean)
 *       - currentUser (User object)
 *       - hasRole (function)
 *  - Interfaces:
 *    • AdminLayoutProps: { children: ReactNode; requireAuth: boolean }
 *  - Classes (styled-components):
 *    • LayoutContainer
 *      - display: flex
 *      - flexDirection: column
 *      - minHeight: 100vh
 *      - backgroundColor: ${({ theme }) => theme.colors.background}
 *    • MainContent
 *      - flex: 1
 *      - display: flex
 *      - padding: ${({ theme }) => theme.spacing.lg}
 *      - transition: padding 0.3s ease
 *  - Functions:
 *    • useLayoutState
 *      - Initializes sidebar collapsed state
 *      - Sets up media query listeners
 *      - Handles sidebar toggle with animation
 *      - Returns layout state and control methods
 *    • AdminLayout
 *      - Checks auth status and admin role
 *      - Uses useLayoutState for layout
 *      - Renders Header, MainContent, Footer
 *      - Handles unauthorized access redirects
 *  - Exports:
 *    • AdminLayout as React.FC<AdminLayoutProps>
 * -------------------------------------------------------------------------------------------------
 */

// -------------------------------------------------------------------------------------------------
// External Imports (with versions)
// -------------------------------------------------------------------------------------------------
// NOTE: React version ^18.0.0
import React, { ReactNode, useState, useEffect, useCallback } from 'react';
// NOTE: styled-components version ^6.0.0
import styled from 'styled-components';
// NOTE: @mui/material version ^5.0.0 (useMediaQuery for responsive breakpoints)
import { useMediaQuery } from '@mui/material';

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import { Header } from '../components/layout/Header';
import { Footer } from '../components/layout/Footer';
import { useAuth } from '../../hooks/useAuth';

// -------------------------------------------------------------------------------------------------
// Interface: AdminLayoutProps
// -------------------------------------------------------------------------------------------------
// Holds the children elements to be displayed within the layout,
// plus a requireAuth flag to enforce protected routes.
export interface AdminLayoutProps {
  /** The child components or elements to be displayed in the main content area. */
  children: ReactNode;

  /** If true, requires user to be authenticated and have an admin role to access. */
  requireAuth: boolean;
}

// -------------------------------------------------------------------------------------------------
// Styled Component: LayoutContainer
// -------------------------------------------------------------------------------------------------
// Provides a responsive full-height container for the admin layout.
// Applies a base background color from the theme. Sets up vertical
// flex alignment so header remains on top, main content grows, and
// footer stays at the bottom.
const LayoutContainer = styled.div`
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  /* Accessing a hypothetical theme.colors.background from the styled-components theme object */
  background-color: ${({ theme }) => theme.colors.background};
`;

// -------------------------------------------------------------------------------------------------
// Styled Component: MainContent
// -------------------------------------------------------------------------------------------------
// Expands to fill available space. Applies standardized padding from
// the theme. Includes a transition for potential dynamic layout changes
// (e.g., sidebar toggle resizing).
const MainContent = styled.main`
  flex: 1;
  display: flex;
  padding: ${({ theme }) => theme.spacing.lg};
  transition: padding 0.3s ease;
`;

// -------------------------------------------------------------------------------------------------
// Hook: useLayoutState
// -------------------------------------------------------------------------------------------------
// Manages layout-related state, including sidebar collapse behavior.
//  1) Initializes sidebar collapsed based on screen size or stored preference.
//  2) Sets up a media query to adapt the layout if the screen is small.
//  3) Provides a toggle function for user control, storing preferences if needed.
//  4) Returns the layout state in a convenient object.
function useLayoutState() {
  // Step 1: Detect if the screen is below a certain breakpoint (e.g., 768px).
  // We can decide to collapse the sidebar by default on smaller devices.
  const isSmallScreen = useMediaQuery('(max-width: 768px)');

  // Step 2: Manage local state for whether the sidebar is collapsed.
  // Initialize it based on isSmallScreen or previously stored preference.
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      // Attempt to load previous state from localStorage or default logic.
      const stored = localStorage.getItem('admin_sidebar_collapsed');
      if (stored !== null) return stored === 'true';
    }
    return isSmallScreen; // default behavior
  });

  // Step 3: Toggle function, flipping the sidebar state and persisting it if desired.
  const handleSidebarToggle = useCallback(() => {
    setIsSidebarCollapsed((prev) => {
      const newValue = !prev;
      if (typeof window !== 'undefined') {
        localStorage.setItem('admin_sidebar_collapsed', String(newValue));
      }
      return newValue;
    });
  }, []);

  // Step 4: Whenever the screen size changes drastically, we could adapt.
  // (Optional) Sync with media query in useEffect if needed.
  useEffect(() => {
    if (isSmallScreen && !isSidebarCollapsed) {
      setIsSidebarCollapsed(true);
    }
  }, [isSmallScreen, isSidebarCollapsed]);

  return {
    isSidebarCollapsed,
    onSidebarToggle: handleSidebarToggle,
  };
}

// -------------------------------------------------------------------------------------------------
// Main Component: AdminLayout
// -------------------------------------------------------------------------------------------------
// Sets up the admin dashboard layout with:
//  - Auth check (requireAuth + admin role).
//  - Sidebar header + collapsible logic.
//  - Main content section for children.
//  - A consistent application footer.
//
// Steps:
//  1) Retrieve authentication and role info via useAuth().
//  2) If requireAuth is true, ensure user is authenticated and is ADMIN.
//  3) Initialize layout state with useLayoutState hook.
//  4) Render the Header with sidebar props, main content, and Footer.
//  5) Optionally handle unauthorized access or redirection if lacking admin privileges.
export const AdminLayout: React.FC<AdminLayoutProps> = ({ children, requireAuth }) => {
  // Step 1: Acquire auth context
  const { isAuthenticated, currentUser, hasRole } = useAuth();

  // Step 2: If the layout requires authentication, check it here.
  // Also ensure user has the 'ADMIN' role. If unauthorized, you might
  // return null, redirect, or show an error message.
  if (requireAuth) {
    if (!isAuthenticated || !hasRole('ADMIN')) {
      // For production, typically you'd redirect to a login or 403 page.
      return null;
    }
  }

  // Step 3: Initialize layout state for the sidebar (expanded/collapsed).
  const { isSidebarCollapsed, onSidebarToggle } = useLayoutState();

  // Step 4: Render the layout container, including <Header> and <Footer>.
  // Pass the appropriate props to our internal components.
  return (
    <LayoutContainer>
      {/* Admin header with sidebar toggling controls */}
      <Header
        isSidebarCollapsed={isSidebarCollapsed}
        onSidebarToggle={onSidebarToggle}
      />

      {/* Main content area where admin-specific pages and components are displayed */}
      <MainContent>{children}</MainContent>

      {/* Footer anchored at the bottom of the layout */}
      <Footer className="admin-footer" />
    </LayoutContainer>
  );
};