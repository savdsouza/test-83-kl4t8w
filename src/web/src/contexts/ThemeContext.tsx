/**
 * ThemeContext.tsx
 * 
 * Provides a React Context and Provider for managing theming across the application.
 * Implements responsive design requirements, system preference detection, 
 * and persistent theme storage for both light and dark modes. 
 * Also supports text direction (RTL) and reduced motion preferences.
 */

// react@^18.0.0
import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useMemo,
  ReactNode
} from 'react';

// styled-components@^5.3.0
import { ThemeProvider as StyledThemeProvider } from 'styled-components';

// Internal theme configuration imports
import { theme, darkTheme } from '../config/theme.config';

/**
 * THEME_STORAGE_KEY:
 * Used to persist and retrieve user-selected theme (dark or light) 
 * from local storage.
 */
export const THEME_STORAGE_KEY = 'app_theme_preference';

/**
 * Interface representing the shape of our ThemeContext.
 */
interface ThemeContextType {
  /**
   * Current theme object (light or dark), fully typed from theme definitions.
   */
  theme: typeof theme;

  /**
   * Indicates whether the dark mode theme is active.
   */
  isDarkMode: boolean;

  /**
   * Indicates whether text layout is set for Right-To-Left languages.
   */
  isRTL: boolean;

  /**
   * Indicates the system preference for dark mode, independent of user toggle.
   */
  prefersDarkMode: boolean;

  /**
   * Indicates the system preference for reduced motion, which can be used by 
   * components to limit animations.
   */
  prefersReducedMotion: boolean;

  /**
   * Toggles between dark mode and light mode explicitly, persisting user preference.
   */
  toggleTheme: () => void;

  /**
   * Sets layout direction to RTL or LTR, facilitating right-to-left support as needed.
   */
  setRTL: (direction: boolean) => void;
}

/**
 * ThemeContext:
 * Provides a shared context object for theming with an initial undefined 
 * to ensure usage only within the ThemeProvider.
 */
export const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

/**
 * useSystemPreferences:
 * Hook to detect system-level preferences for dark mode and reduced motion.
 * Syncs with OS settings changes in real time using media queries.
 */
export function useSystemPreferences(): {
  systemPrefersDarkMode: boolean;
  systemPrefersReducedMotion: boolean;
} {
  // Media query for dark mode
  const [systemPrefersDarkMode, setSystemPrefersDarkMode] = useState<boolean>(() => {
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    return false;
  });

  // Media query for reduced motion
  const [systemPrefersReducedMotion, setSystemPrefersReducedMotion] = useState<boolean>(() => {
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    }
    return false;
  });

  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) {
      return;
    }

    // Dark mode listener
    const darkModeMediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleDarkModeChange = () => {
      setSystemPrefersDarkMode(darkModeMediaQuery.matches);
    };
    darkModeMediaQuery.addEventListener('change', handleDarkModeChange);

    // Reduced motion listener
    const reducedMotionMediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    const handleReducedMotionChange = () => {
      setSystemPrefersReducedMotion(reducedMotionMediaQuery.matches);
    };
    reducedMotionMediaQuery.addEventListener('change', handleReducedMotionChange);

    // Cleanup listeners on unmount
    return () => {
      darkModeMediaQuery.removeEventListener('change', handleDarkModeChange);
      reducedMotionMediaQuery.removeEventListener('change', handleReducedMotionChange);
    };
  }, []);

  return { systemPrefersDarkMode, systemPrefersReducedMotion };
}

/**
 * useThemeContext:
 * A convenience hook for quickly accessing the ThemeContext values in a type-safe manner.
 * Throws an error if attempted to be used outside of the ThemeProvider.
 */
export function useThemeContext(): ThemeContextType {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useThemeContext must be used within a ThemeProvider');
  }
  return context;
}

/**
 * Props for the ThemeProvider component. Allows children to be rendered 
 * within the context.
 */
interface ThemeProviderProps {
  children: ReactNode;
}

/**
 * ThemeProvider:
 * Manages theme state, system preferences, and persists user preference 
 * for dark or light theme. Injects the current styled-components theme 
 * into the application via StyledThemeProvider.
 *
 * Also handles RTL toggling and provides system-level preferences 
 * for reduced motion.
 */
function ThemeProvider({ children }: ThemeProviderProps) {
  // Detect system preferences outside of user overrides
  const { systemPrefersDarkMode, systemPrefersReducedMotion } = useSystemPreferences();

  // State to track theme override (dark or light)
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      const storedPreference = localStorage.getItem(THEME_STORAGE_KEY);
      if (storedPreference === 'dark') return true;
      if (storedPreference === 'light') return false;
    }
    // Default to system preference if no local storage setting
    return systemPrefersDarkMode;
  });

  // State to track Right-To-Left direction
  const [isRTL, setIsRTL] = useState<boolean>(false);

  /**
   * toggleTheme:
   * Toggles the current theme between dark and light modes, 
   * persisting the preference in localStorage.
   */
  const toggleTheme = useCallback(() => {
    setIsDarkMode((prev) => {
      const nextValue = !prev;
      if (typeof window !== 'undefined') {
        localStorage.setItem(THEME_STORAGE_KEY, nextValue ? 'dark' : 'light');
      }
      return nextValue;
    });
  }, []);

  /**
   * setRTL:
   * Sets our text direction based on the boolean parameter. 
   * This can be extended to store user preference if needed.
   */
  const handleSetRTL = useCallback((direction: boolean) => {
    setIsRTL(direction);
  }, []);

  /**
   * Memoize the theme context value to avoid unnecessary re-renders. 
   * Combines current theme, dark mode flag, RTL flag, and system preferences.
   */
  const contextValue = useMemo<ThemeContextType>(() => {
    return {
      theme: isDarkMode ? darkTheme : theme,
      isDarkMode,
      isRTL,
      prefersDarkMode: systemPrefersDarkMode,
      prefersReducedMotion: systemPrefersReducedMotion,
      toggleTheme,
      setRTL: handleSetRTL
    };
  }, [
    isDarkMode,
    isRTL,
    toggleTheme,
    handleSetRTL,
    systemPrefersDarkMode,
    systemPrefersReducedMotion
  ]);

  return (
    <ThemeContext.Provider value={contextValue}>
      {/* 
        The styled-components ThemeProvider receives either darkTheme or 
        default theme based on isDarkMode, ensuring all styled components 
        have access to the appropriate theme tokens.
      */}
      <StyledThemeProvider theme={contextValue.theme}>
        {children}
      </StyledThemeProvider>
    </ThemeContext.Provider>
  );
}

export default ThemeProvider;