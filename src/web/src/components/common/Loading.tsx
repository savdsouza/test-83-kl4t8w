/* ============================================================================
   Loading.tsx
   ----------------------------------------------------------------------------
   A reusable loading component that provides visual feedback during
   asynchronous operations. Implements a customizable spinner with:
   - Animation support from animations.css
   - Accessibility features via ARIA attributes
   - Responsive design using design tokens from variables.css
   - Reduced motion handling via prefers-reduced-motion detection

   This file strictly follows the technical and JSON specifications:
   1) It defines a LoadingProps interface with size, color, text, fullScreen,
      and className properties.
   2) It provides a custom hook (useReducedMotion) to detect user motion
      preferences.
   3) It includes the Loading functional component (React 18.x) with advanced
      TypeScript types, returning a fully accessible and animatable spinner.
   4) It imports and utilizes .loading-spinner and .loading-spinner--reduced-motion
      from animations.css, along with design tokens from variables.css.
   5) It ensures robust enterprise-ready coding practices, thorough
      inline documentation, and strictly typed objects.
============================================================================ */

/* ============================================================================
   External Dependencies
   ----------------------------------------------------------------------------
   React@^18.0.0 is used here for building declarative UI components with hooks.
============================================================================ */
import React, { FC, useState, useEffect } from 'react'; // React@^18.0.0

/* ============================================================================
   Internal Stylesheet Imports
   ----------------------------------------------------------------------------
   Below, animations.css contains keyframes for the spinner and optional
   reduced-motion classes, whereas variables.css includes design tokens like
   colors, spacing, and z-index values.
============================================================================ */
import '../../styles/animations.css';
import '../../styles/variables.css';

/* ============================================================================
   LoadingProps Interface
   ----------------------------------------------------------------------------
   Defines the expected properties for the Loading component, including:
   - size: The spinner dimension derived from design system spacing tokens.
   - color: Custom spinner color, defaulting to primary brand color.
   - text: Screen reader text for accessibility, e.g., 'Loading...'.
   - fullScreen: Whether to display a full-screen overlay behind the spinner.
   - className: Optional additional CSS class names for advanced customization.
============================================================================ */
export interface LoadingProps {
  /**
   * Determines the size of the loading spinner. Supported values map to the
   * application's design system spacing tokens:
   *   'sm' -> var(--spacing-sm)
   *   'md' -> var(--spacing-md)
   *   'lg' -> var(--spacing-lg)
   */
  size?: 'sm' | 'md' | 'lg';

  /**
   * Optional custom color for the spinner's border-top. Falls back to
   * var(--color-primary) if not provided.
   */
  color?: string;

  /**
   * Optional text string announced via screen readers for accessibility,
   * e.g., 'Loading your data...'.
   */
  text?: string;

  /**
   * Indicates if the spinner should be presented with a full-screen overlay,
   * preventing user interactions underneath.
   */
  fullScreen?: boolean;

  /**
   * Optional additional CSS class names for advanced styling hooks.
   */
  className?: string;
}

/* ============================================================================
   useReducedMotion Hook
   ----------------------------------------------------------------------------
   A custom React Hook for detecting if the user has requested reduced motion
   in their OS or browser settings. Adheres to the steps from the specification:
   1. Create a media query for 'prefers-reduced-motion: reduce'.
   2. Set up listeners for any preference changes.
   3. Return the current preference state as a boolean.
   4. Clean up the event listeners on component unmount.
============================================================================ */
export function useReducedMotion(): boolean {
  // Initialize state based on the current matchMedia status
  const [isReduced, setIsReduced] = useState<boolean>(() => {
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    }
    return false;
  });

  // Effect to handle changes in the user's reduced motion preference
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) {
      return;
    }

    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    const handleChange = () => {
      setIsReduced(mediaQuery.matches);
    };

    // Listen for changes in the reduced-motion media query
    mediaQuery.addEventListener('change', handleChange);

    // Cleanup: remove event listener on unmount
    return () => {
      mediaQuery.removeEventListener('change', handleChange);
    };
  }, []);

  return isReduced;
}

/* ============================================================================
   Internal Utilities
   ----------------------------------------------------------------------------
   Helper function to map the size prop to design token-based dimension values.
============================================================================ */
function mapSizeToDimension(size: 'sm' | 'md' | 'lg' = 'md'): string {
  switch (size) {
    case 'sm':
      return 'var(--spacing-sm)'; // 8px
    case 'lg':
      return 'var(--spacing-lg)'; // 24px
    case 'md':
    default:
      return 'var(--spacing-md)'; // 16px
  }
}

/* ============================================================================
   Loading Component
   ----------------------------------------------------------------------------
   Renders a loading spinner with optional full-screen overlay, custom color,
   accessibility features, and motion settings based on user preferences.

   Steps from the JSON specification:
   1. Check for reduced motion preference via useReducedMotion.
   2. Map size prop to design system spacing variables.
   3. Apply color styles with fallback to primary color.
   4. Set up ARIA attributes for accessibility.
   5. Apply fullScreen styles if enabled.
   6. Render spinner with optional text.
   7. Apply animation classes or reduced motion styles accordingly.
============================================================================ */
const Loading: FC<LoadingProps> = ({
  size = 'md',
  color,
  text,
  fullScreen = false,
  className = ''
}) => {
  // Detect user preference for reduced motion
  const reduceMotion = useReducedMotion();

  // Determine final dimension for the spinner
  const dimension = mapSizeToDimension(size);

  // Resolve final color fallback
  const spinnerColor = color || 'var(--color-primary)';

  // Build out className for spinner with or without reduced motion
  const spinnerClass = reduceMotion
    ? 'loading-spinner loading-spinner--reduced-motion'
    : 'loading-spinner';

  // If fullScreen is enabled, prepare inline styles for the overlay
  const overlayStyle: React.CSSProperties = {
    position: 'fixed',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.7)',
    zIndex: 'var(--z-index-overlay)',
  };

  // Accessibility attributes: the container has role=status,
  // with aria-busy to indicate loading. If text is provided, we
  // attach it via aria-label or visually hidden approach.
  return (
    <div
      className={className}
      style={fullScreen ? overlayStyle : {}}
      role="status"
      aria-busy="true"
      aria-label={text || 'Loading...'}
      aria-live="polite"
    >
      {/* 
        The spinner uses a border-based technique; we rely on 
        the animations.css file for the spin keyframe and 
        spin timing. The --color-background is used for the 
        non-top edges of the ring, while border-top-color is 
        set to the spinnerColor. 
      */}
      <div
        className={spinnerClass}
        style={{
          width: dimension,
          height: dimension,
          borderTopColor: spinnerColor
        }}
      />
      {/* 
        Optionally render the text for screen readers. 
        Many screen readers will read aria-label, but we 
        can also place hidden text if needed. 
      */}
      {text && (
        <span style={{ position: 'absolute', width: '1px', height: '1px', margin: '-1px', overflow: 'hidden', clip: 'rect(0,0,0,0)' }}>
          {text}
        </span>
      )}
    </div>
  );
};

/* ============================================================================
   Export
   ----------------------------------------------------------------------------
   The Loading component is exported as a default and typed as React.FC<LoadingProps>.
============================================================================ */
export default Loading;