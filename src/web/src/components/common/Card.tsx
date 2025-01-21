import React, { FC } from 'react'; // ^18.0.0
import classNames from 'classnames'; // ^2.3.0

/**
 * NOTE ON INTERNAL IMPORT:
 * We import the CSS module as a namespace because it contains hyphenated class names ("theme-card", "card-transition")
 * which are not directly valid as named imports in TypeScript. This allows us to reference them via bracket notation.
 */
import * as cStyles from '../../styles/components.css'; // Internal styles for card, theme transitions, and theming

/**
 * CardProps Interface
 * ----------------------------------------------------------------------------
 * Extends the standard React.HTMLAttributes<HTMLDivElement> to ensure that any
 * valid HTML div attributes (e.g., 'id', 'style', 'onClick') can be passed along,
 * while restricting the 'elevation' property to a discrete set of values for
 * consistent visual depth (1 | 2 | 3).
 */
export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /**
   * The content to be rendered inside the card component.
   * Can include text nodes, images, or any valid React element.
   */
  children: React.ReactNode;

  /**
   * An optional additional class name to merge with this component's
   * default styling, allowing for customization and extensibility.
   */
  className?: string;

  /**
   * The elevation level of the card, dictating the visual depth
   * (shadow intensity). Acceptable values are 1, 2, or 3.
   */
  elevation?: 1 | 2 | 3;

  /**
   * The 'role' attribute for the card container, enhancing accessibility
   * by indicating the card's semantic function (e.g., "region", "complementary").
   * Defaults to "region" if not specified.
   */
  role?: string;

  /**
   * The 'tabIndex' attribute allowing users to tab-focus the card if desired.
   * Defaults to 0 for keyboard accessibility.
   */
  tabIndex?: number;
}

/**
 * Card Component (Functional)
 * ----------------------------------------------------------------------------
 * Renders a themed, reusable card container with support for elevation,
 * theme transitions (for dark/light mode or branded themes), and
 * accessibility features. It automatically applies responsive styles
 * based on screen size breakpoints (mobile, tablet, desktop).
 */
export const Card: FC<CardProps> = ({
  children,
  className,
  elevation = 2,
  role = 'region',
  tabIndex = 0,
  ...rest
}) => {
  /**
   * STEP 1: Combine default card classes with theme and transition classes
   * ------------------------------------------------------------------------
   * We use the 'classNames' utility to elegantly merge multiple class strings
   * and conditionally apply variations based on the 'elevation' prop.
   */
  const cardClassNames = classNames(
    cStyles['card'],           // Base card styles
    cStyles['theme-card'],     // Theme-related styles (color, background)
    cStyles['card-transition'],// Transition styles for smooth theme switching
    {
      /**
       * Dynamically map the provided elevation prop to matching CSS classes.
       * We could define separate classes like 'card--elev1', 'card--elev2', etc.
       * For demonstration, we assume these styles exist in components.css.
       */
      [cStyles['card-elevation1']]: elevation === 1,
      [cStyles['card-elevation2']]: elevation === 2,
      [cStyles['card-elevation3']]: elevation === 3,
    },
    className // Merge any external class names passed in via props
  );

  /**
   * STEP 2: Render the div container
   * ------------------------------------------------------------------------
   * Attach role, tabIndex, and any other <div> HTML attributes passed
   * through the component props. The children are displayed inside.
   */
  return (
    <div
      className={cardClassNames}
      role={role}
      tabIndex={tabIndex}
      {...rest}
    >
      {/**
       * STEP 3: Render children with proper spacing
       * --------------------------------------------------------------------
       * The CSS module handles default padding, margins, or other spacing
       * details. Additional spacing can be modified via the className prop
       * or by nesting other styled components within this container.
       */}
      {children}
    </div>
  );
};