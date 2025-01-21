/* eslint-disable @typescript-eslint/no-unused-vars */

// -------------------------------------------------------------------------------------
// External Imports with Versions
// -------------------------------------------------------------------------------------
// react@^18.0.0 - Core React functionality for building user interfaces
import React from 'react';
// styled-components@^6.0.0 - Component-level styling with support for themes and responsive design
import styled from 'styled-components';
// react-i18next@^12.0.0 - Internationalization (i18n) and localization framework for React
import { useTranslation } from 'react-i18next';

// -------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------
// theme.css - Internal theme and responsive CSS variables/classes
import '../../styles/theme.css';

// -------------------------------------------------------------------------------------
// Locally Defined Breakpoints
// -------------------------------------------------------------------------------------
// These breakpoints correspond to mobile (<375px) and tablet (≤768px)
// references from the technical specifications.
const breakpoints = {
  mobile: '375px',
  tablet: '768px',
  // Additional breakpoints can be defined here if needed
};

// -------------------------------------------------------------------------------------
// FooterContainer - Styled component for the footer container
// Description: Sets up a responsive, flexible layout with theme-driven padding,
// transitions, border, and background. Adjusts layout for smaller breakpoints.
// -------------------------------------------------------------------------------------
const FooterContainer = styled.footer`
  /* Base styling for a consistent layout and spacing */
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-md);
  border-top: 1px solid var(--color-border, #e0e0e0);
  background-color: var(--color-background);
  transition: var(--transition-normal);
  z-index: var(--z-index-footer);

  /* Responsive layout for mobile screens up to 375px */
  @media (max-width: ${breakpoints.mobile}) {
    flex-direction: column;
    gap: var(--spacing-sm);
  }

  /* Responsive layout for tablet screens up to 768px */
  @media (max-width: ${breakpoints.tablet}) {
    padding: var(--spacing-sm);
  }
`;

// -------------------------------------------------------------------------------------
// FooterLinks - Styled component for navigation links in the footer
// Description: Maintains a row-based layout with spacing that wraps on mobile.
// Provides accessible focus and hover states, referencing theme-based color tokens.
// -------------------------------------------------------------------------------------
const FooterLinks = styled.nav`
  display: flex;
  gap: var(--spacing-md);
  align-items: center;

  @media (max-width: ${breakpoints.mobile}) {
    flex-wrap: wrap;
    justify-content: center;
  }

  /* Link styling with transitions, color changes on hover/focus */
  a {
    color: var(--color-text-primary);
    text-decoration: none;
    transition: var(--transition-normal);
  }

  a:hover {
    color: var(--color-primary);
  }

  a:focus {
    outline: 2px solid var(--color-focus, #2196F3);
    outline-offset: 2px;
  }
`;

// -------------------------------------------------------------------------------------
// FooterCopyright - Styled component for copyright text
// Description: Applies secondary text color, smaller font size, center alignment,
// and reorders layout on mobile if needed.
// -------------------------------------------------------------------------------------
const FooterCopyright = styled.div`
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
  text-align: center;

  @media (max-width: ${breakpoints.mobile}) {
    order: 2;
  }
`;

// -------------------------------------------------------------------------------------
// Interface: FooterProps
// Description: Defines props accepted by the Footer component, allowing an optional
// className for advanced styling or overrides.
// -------------------------------------------------------------------------------------
interface FooterProps {
  className?: string;
}

// -------------------------------------------------------------------------------------
// getCurrentYear - Helper function
// Description: Returns the current year as a number, used to display dynamic copyright.
// -------------------------------------------------------------------------------------
function getCurrentYear(): number {
  return new Date().getFullYear();
}

// -------------------------------------------------------------------------------------
// Footer - Main footer component
// Description:
// 1) Initializes the translation hook for i18n support.
// 2) Obtains currentYear via getCurrentYear.
// 3) Renders a themable, responsive footer with accessible navigation links.
// 4) Provides proper aria attributes for screen readers.
// 5) Exports an enterprise-ready, production-grade React.FC.
// -------------------------------------------------------------------------------------
export const Footer: React.FC<FooterProps> = (props) => {
  // Step 1: Initialize translation hook for i18n support
  const { t } = useTranslation();

  // Step 2: Get the current year
  const currentYear = getCurrentYear();

  // Step 3: Render the footer container
  return (
    <FooterContainer
      role="contentinfo"
      className={props.className}
      aria-label={t('footer.ariaLabel', 'Application Footer')}
    >
      {/* Step 4: Render FooterLinks with accessible navigation role */}
      <FooterLinks role="navigation" aria-label={t('footer.navigation', 'Footer Navigation')}>
        <a href="#about">{t('footer.linkAbout', 'About')}</a>
        <a href="#contact">{t('footer.linkContact', 'Contact')}</a>
        <a href="#privacy">{t('footer.linkPrivacy', 'Privacy Policy')}</a>
      </FooterLinks>

      {/* Step 5: Render dynamic copyright */}
      <FooterCopyright>
        © {currentYear} {t('footer.copyright', 'Dog Walking')}
      </FooterCopyright>
    </FooterContainer>
  );
};