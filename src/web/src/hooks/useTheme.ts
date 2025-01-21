/**
 * useTheme.ts
 *
 * Custom React hook that provides access to theme context and functionality,
 * including runtime type checking, error handling, and memoization.
 * Enables components to retrieve the current theme, check dark mode status,
 * and toggle between themes with strict type safety.
 */

// react@^18.0.0
import { useContext, useMemo } from 'react';

// Internal theme context import
import { ThemeContext } from '../contexts/ThemeContext';

/**
 * TypographyConfig:
 * Defines required typography properties for fonts, sizes,
 * weights, line heights, and letter spacing.
 */
interface TypographyConfig {
  fontFamily: {
    primary: string;
    secondary: string;
    monospace: string;
  };
  fontSize: {
    xs: string;
    sm: string;
    md: string;
    lg: string;
    xl: string;
    xxl: string;
  };
  fontWeight: {
    regular: number;
    medium: number;
    semibold: number;
    bold: number;
  };
  lineHeight: {
    tight: number;
    normal: number;
    relaxed: number;
  };
  letterSpacing: {
    tight: string;
    normal: string;
    wide: string;
  };
}

/**
 * ColorPalette:
 * Defines color sets for primary, secondary, erroneous states,
 * backgrounds, text, and gradient usage.
 */
interface ColorPalette {
  primary: {
    main: string;
    light: string;
    dark: string;
    alpha?: {
      '10': string;
      '50': string;
      '90': string;
    };
  };
  secondary: {
    main: string;
    light: string;
    dark: string;
  };
  error: {
    main: string;
    light: string;
    dark: string;
  };
  background: {
    primary: string;
    secondary: string;
    tertiary: string;
  };
  text: {
    primary: string;
    secondary: string;
    disabled: string;
  };
  gradients: {
    primary: string;
    secondary: string;
  };
}

/**
 * SpacingConfig:
 * Defines spacing units, grid-based increments, and compound spacing
 * for standardized internal component layouts.
 */
interface SpacingConfig {
  base: string;
  grid: {
    '1x': string;
    '2x': string;
    '3x': string;
    '4x': string;
    '5x': string;
    '6x': string;
    '8x': string;
  };
  compound: {
    cardPadding: string;
    buttonPadding: string;
    inputPadding: string;
  };
}

/**
 * ElevationConfig:
 * Defines shadow or other elevation tokens for UI layering (e.g. cards, modals).
 */
interface ElevationConfig {
  card: string;
  modal: string;
  navigation: string;
  fab: string;
  tooltip: string;
}

/**
 * BreakpointConfig:
 * Defines breakpoint values, orientation queries, and utilities
 * used in responsive design handling.
 */
interface BreakpointConfig {
  values: {
    mobile: string;
    mobileLarge: string;
    tablet: string;
    desktop: string;
    desktopLarge: string;
  };
  orientation: {
    portrait: string;
    landscape: string;
  };
  utils: {
    up: string;
    down: string;
    between: string;
  };
}

/**
 * ThemeConfig:
 * Consolidates all theme definitions (typography, colors, spacing,
 * elevation, breakpoints) into one interface for the hook's return value.
 */
export interface ThemeConfig {
  typography: TypographyConfig;
  colors: ColorPalette;
  spacing: SpacingConfig;
  elevation: ElevationConfig;
  breakpoints: BreakpointConfig;
}

/**
 * UseThemeReturn:
 * Defines the structure of the object returned from the useTheme hook,
 * providing essential theme data and methods.
 */
export interface UseThemeReturn {
  /**
   * The active theme configuration containing typography, colors, spacing,
   * elevation, and breakpoints.
   */
  theme: ThemeConfig;

  /**
   * Boolean indicating whether dark mode is enabled.
   */
  isDarkMode: boolean;

  /**
   * Function to toggle between dark and light themes.
   */
  toggleTheme: () => void;
}

/**
 * useTheme:
 * Main custom hook to retrieve theme context data (theme configuration, dark mode status),
 * perform runtime checks, memoize the returned values, and provide a toggleTheme method.
 *
 * Steps:
 * 1. Access ThemeContext using useContext hook.
 * 2. Validate context exists and throw a descriptive error if missing.
 * 3. Perform runtime type checking of context values (theme, isDarkMode, toggleTheme).
 * 4. Memoize the return object to prevent unnecessary rerenders.
 * 5. Return the memoized theme context object with type safety.
 */
export function useTheme(): UseThemeReturn {
  // Retrieve the entire context from ThemeContext
  const context = useContext(ThemeContext);

  // Immediately throw an error if context is absent (i.e., no ThemeProvider).
  if (!context) {
    throw new Error(
      'useTheme must be used within a ThemeProvider. Theme context is undefined.'
    );
  }

  // Destructure only the required properties from the context
  const { theme, isDarkMode, toggleTheme } = context;

  // Perform minimal runtime type checks to ensure valid structure
  if (typeof theme !== 'object') {
    throw new Error('Invalid theme object detected in ThemeContext.');
  }
  if (typeof isDarkMode !== 'boolean') {
    throw new Error('Invalid isDarkMode flag detected in ThemeContext.');
  }
  if (typeof toggleTheme !== 'function') {
    throw new Error('Invalid toggleTheme function detected in ThemeContext.');
  }

  // Memoize the return value to avoid unnecessary re-renders
  const memoizedValue = useMemo<UseThemeReturn>(() => {
    return {
      // Type assertion to ThemeConfig for rigor
      theme: theme as unknown as ThemeConfig,
      isDarkMode,
      toggleTheme,
    };
  }, [theme, isDarkMode, toggleTheme]);

  return memoizedValue;
}