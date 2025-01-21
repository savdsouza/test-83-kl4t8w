/**
 * Core theme configuration for the Dog Walking Mobile Application.
 * Defines every aspect of the design system with extreme detail,
 * including colors, typography, spacing, elevation, and breakpoints.
 * Maintains type safety via ThemeType and integrates with styled-components.
 */

// styled-components@^5.3.0
import { DefaultTheme } from 'styled-components';

/**
 * Interface defining alpha values for color variations.
 */
interface ColorAlpha {
  '10': string;
  '50': string;
  '90': string;
}

/**
 * Interface defining primary, light, and dark shades for a color.
 */
interface ColorShades {
  main: string;
  light: string;
  dark: string;
  alpha?: ColorAlpha;
}

/**
 * Interface for gradient definitions.
 */
interface GradientsType {
  primary: string;
  secondary: string;
}

/**
 * Interface grouping main application color sets.
 */
interface ColorType {
  primary: ColorShades;
  secondary: ColorShades;
  error: ColorShades;
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
  gradients: GradientsType;
}

/**
 * Interface defining all typography-related items:
 * font families, sizes, weights, line heights, and letter spacing.
 */
interface TypographyType {
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
 * Interface defining multiple spacing categories:
 * base unit, grid spacings, and compound spacing sets for UI components.
 */
interface SpacingType {
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
 * Interface offering elevation definitions corresponding to
 * shadows and surface layering in UI elements.
 */
interface ElevationType {
  card: string;
  modal: string;
  navigation: string;
  fab: string;
  tooltip: string;
}

/**
 * Interface for defining base breakpoint values,
 * orientation queries, and utility patterns used
 * across the responsive layout implementation.
 */
interface BreakpointValues {
  mobile: string;
  mobileLarge: string;
  tablet: string;
  desktop: string;
  desktopLarge: string;
}

interface BreakpointOrientation {
  portrait: string;
  landscape: string;
}

interface BreakpointUtils {
  up: string;
  down: string;
  between: string;
}

interface BreakpointType {
  values: BreakpointValues;
  orientation: BreakpointOrientation;
  utils: BreakpointUtils;
}

/**
 * Consolidated theme type definition merging styled-components'
 * DefaultTheme with all design system interfaces.
 */
export type ThemeType = DefaultTheme & {
  colors: ColorType;
  typography: TypographyType;
  spacing: SpacingType;
  elevation: ElevationType;
  breakpoints: BreakpointType;
};

/**
 * The default theme object providing comprehensive
 * style definitions and adhering to the design system specification.
 */
export const theme: ThemeType = {
  colors: {
    primary: {
      main: '#2196F3',
      light: '#64B5F6',
      dark: '#1976D2',
      alpha: {
        '10': 'rgba(33, 150, 243, 0.1)',
        '50': 'rgba(33, 150, 243, 0.5)',
        '90': 'rgba(33, 150, 243, 0.9)',
      },
    },
    secondary: {
      main: '#4CAF50',
      light: '#81C784',
      dark: '#388E3C',
    },
    error: {
      main: '#F44336',
      light: '#E57373',
      dark: '#D32F2F',
    },
    background: {
      primary: '#FFFFFF',
      secondary: '#F5F5F5',
      tertiary: '#EEEEEE',
    },
    text: {
      primary: '#212121',
      secondary: '#757575',
      disabled: '#9E9E9E',
    },
    gradients: {
      primary: 'linear-gradient(45deg, #2196F3 30%, #21CBF3 90%)',
      secondary: 'linear-gradient(45deg, #4CAF50 30%, #45D054 90%)',
    },
  },
  typography: {
    fontFamily: {
      primary: 'SF Pro, Roboto, system-ui, sans-serif',
      secondary: 'SF Pro Display, Roboto, system-ui, sans-serif',
      monospace: 'SF Mono, Consolas, monospace',
    },
    fontSize: {
      xs: '12px',
      sm: '14px',
      md: '16px',
      lg: '20px',
      xl: '24px',
      xxl: '32px',
    },
    fontWeight: {
      regular: 400,
      medium: 500,
      semibold: 600,
      bold: 700,
    },
    lineHeight: {
      tight: 1.25,
      normal: 1.5,
      relaxed: 1.75,
    },
    letterSpacing: {
      tight: '-0.025em',
      normal: '0',
      wide: '0.025em',
    },
  },
  spacing: {
    base: '8px',
    grid: {
      '1x': '4px',
      '2x': '8px',
      '3x': '12px',
      '4x': '16px',
      '5x': '20px',
      '6x': '24px',
      '8x': '32px',
    },
    compound: {
      cardPadding: '16px 24px',
      buttonPadding: '8px 16px',
      inputPadding: '12px 16px',
    },
  },
  elevation: {
    card: '0 2px 4px rgba(0,0,0,0.1)',
    modal: '0 8px 16px rgba(0,0,0,0.1)',
    navigation: '0 4px 8px rgba(0,0,0,0.1)',
    fab: '0 6px 12px rgba(0,0,0,0.1)',
    tooltip: '0 2px 8px rgba(0,0,0,0.15)',
  },
  breakpoints: {
    values: {
      mobile: '375px',
      mobileLarge: '428px',
      tablet: '768px',
      desktop: '1024px',
      desktopLarge: '1440px',
    },
    orientation: {
      portrait: '(orientation: portrait)',
      landscape: '(orientation: landscape)',
    },
    utils: {
      up: '(min-width: {breakpoint})',
      down: '(max-width: {breakpoint})',
      between: '(min-width: {start}) and (max-width: {end})',
    },
  },
};

/**
 * Dark theme configuration applying color scheme overrides
 * for backgrounds and text to accommodate a darker UI style.
 */
export const darkTheme: ThemeType = {
  ...theme,
  colors: {
    ...theme.colors,
    background: {
      primary: '#121212',
      secondary: '#1E1E1E',
      tertiary: '#2C2C2C',
    },
    text: {
      primary: '#FFFFFF',
      secondary: '#BDBDBD',
      disabled: '#9E9E9E',
    },
  },
};