/**
 * Central index file for exporting all SVG icons used throughout the web application.
 * Implements the design system's icon specifications and provides a consistent interface
 * for icon usage across components. Includes accessibility support, theme awareness, 
 * and RTL considerations. Ensures icons scale appropriately across breakpoints according
 * to the mobile responsiveness requirement.
 */

// --------------------------------------
// External Imports
// --------------------------------------
// React ^18.0.0 is used for creating functional components and handling JSX in TypeScript.
import React from 'react'; // version ^18.0.0

// --------------------------------------
// IconProps Interface
// --------------------------------------
/**
 * Shared interface defining common properties for all icon components.
 * - size: The size of the icon in pixels (e.g., 24).
 * - color: The fill or stroke color of the icon (e.g., "#000000").
 * - variant: Determines the style of the icon, either 'filled' or 'outlined'.
 * - className: Additional CSS class names to allow custom styling.
 * - ariaLabel: Accessible label for screen readers.
 */
export interface IconProps {
  size: number;
  color: string;
  variant: 'filled' | 'outlined';
  className?: string;
  ariaLabel?: string;
}

// --------------------------------------
// Utility Functions: Path Data
// --------------------------------------
/**
 * For each icon, we define two sets of path data: filled and outlined.
 * These are placeholders crafted to illustrate typical shapes for each icon.
 * Adjust the path data as needed to match the design system's actual SVGs.
 */

// User/Profile Icon (@)
const userIconPaths = {
  filled:
    'M12 2C9.32 2 7 4.32 7 7C7 9.68 9.32 12 12 12C14.68 12 17 9.68 17 7C17 4.32 14.68 2 12 2ZM4 20C4 16.13 8.03 13 12 13C15.97 13 20 16.13 20 20H4Z',
  outlined:
    'M12 4C9.794 4 8 5.794 8 8C8 10.206 9.794 12 12 12C14.206 12 16 10.206 16 8C16 5.794 14.206 4 12 4ZM12 14C8.13 14 2 16.065 2 20H4C4 17.34 8.17 16 12 16C15.83 16 20 17.34 20 20H22C22 16.065 15.87 14 12 14Z'
};

// Menu/Dashboard Icon (#)
const menuIconPaths = {
  filled:
    'M3 6H21V8H3V6ZM3 11H21V13H3V11ZM3 16H21V18H3V16Z',
  outlined:
    'M3 7H21V5H3V7ZM3 13H21V11H3V13ZM3 19H21V17H3V19Z'
};

// Payment Icon ($)
const paymentIconPaths = {
  filled:
    'M2 6C2 4.9 2.9 4 4 4H20C21.1 4 22 4.9 22 6V18C22 19.1 21.1 20 20 20H4C2.9 20 2 19.1 2 18V6ZM20 8V6H4V8H20ZM4 10V18H20V10H4ZM6 13H9V15H6V13Z',
  outlined:
    'M4 6H20V18H4V6ZM2 6V18C2 19.1 2.9 20 4 20H20C21.1 20 22 19.1 22 18V6C22 4.9 21.1 4 20 4H4C2.9 4 2 4.9 2 6ZM6 13H9V15H6V13Z'
};

// Help/Info Icon (?)
const helpIconPaths = {
  filled:
    'M12 2C6.49 2 2 6.49 2 12C2 17.52 6.49 22 12 22C17.51 22 22 17.52 22 12C22 6.49 17.51 2 12 2ZM12 19C11.45 19 11 18.55 11 18C11 17.45 11.45 17 12 17C12.55 17 13 17.45 13 18C13 18.55 12.55 19 12 19ZM14.07 11.25L13.17 12.17C12.46 12.88 12 13.5 12 15H10V14.5C10 13.57 10.46 12.68 11.17 12.07L12.07 11.17C12.4 10.84 12.6 10.43 12.6 10C12.6 9.15 11.85 8.4 11 8.4C10.15 8.4 9.4 9.15 9.4 10H7.4C7.4 8.34 8.74 7 10.3 7C11.86 7 13.2 8.34 13.2 10C13.2 10.43 13 10.84 12.67 11.17L14.07 11.25Z',
  outlined:
    'M12 2C6.49 2 2 6.49 2 12C2 17.52 6.49 22 12 22C17.51 22 22 17.52 22 12C22 6.49 17.51 2 12 2ZM12 19C11.45 19 11 18.55 11 18C11 17.45 11.45 17 12 17C12.55 17 13 17.45 13 18C13 18.55 12.55 19 12 19ZM11 14.5V15H13C13 13.5 13.46 12.88 14.17 12.17L15.07 11.27C15.4 10.94 15.6 10.53 15.6 10C15.6 8.34 14.26 7 12.7 7C11.14 7 9.8 8.34 9.8 10H11.8C11.8 9.15 12.55 8.4 13.4 8.4C14.25 8.4 15 9.15 15 10C15 10.43 14.8 10.84 14.47 11.17L13.57 12.07C12.86 12.68 12.4 13.57 12.4 14.5H11Z'
};

// Alert/Warning Icon (!)
const alertIconPaths = {
  filled:
    'M1 21H23L12 2L1 21ZM13 18H11V16H13V18ZM13 14H11V10H13V14Z',
  outlined:
    'M12 2L1 21H23L12 2ZM12 4.77L20.48 19H3.52L12 4.77ZM11 16H13V18H11V16ZM11 10H13V14H11V10Z'
};

// Add/Create Icon (+)
const addIconPaths = {
  filled:
    'M19 11H13V5H11V11H5V13H11V19H13V13H19V11Z',
  outlined:
    'M11 11V5H13V11H19V13H13V19H11V13H5V11H11Z'
};

// Close/Delete Icon (x)
const closeIconPaths = {
  filled:
    'M6 6L18 18M6 18L18 6',
  outlined:
    'M4.71 4.71L19.29 19.29M4.71 19.29L19.29 4.71'
};

// Upload Icon (^)
const uploadIconPaths = {
  filled:
    'M5 20H19V17H5V20ZM12 4L6 10H9V14H15V10H18L12 4Z',
  outlined:
    'M5 20H19V17H5V20ZM12 4L6 10H9V14H15V10H18L12 4ZM9 12V10.83L12 7.83L15 10.83V12H9Z'
};

// Settings Icon (=)
const settingsIconPaths = {
  filled:
    'M19.14 12.94C19.2 12.64 19.2 12.34 19.14 12.04L21 10.61L19.4 8.04L17.53 8.48C17.16 8.19 16.77 7.93 16.35 7.71L15.94 5.55L13.06 5.55L12.65 7.71C12.23 7.93 11.84 8.19 11.47 8.48L9.61 8.04L8 10.61L9.86 12.04C9.8 12.34 9.8 12.64 9.86 12.94L8 14.37L9.61 16.94L11.47 16.5C11.84 16.79 12.23 17.05 12.65 17.27L13.06 19.43H15.94L16.35 17.27C16.77 17.05 17.16 16.79 17.53 16.5L19.4 16.94L21 14.37L19.14 12.94ZM14 12C14 13.1 13.1 14 12 14C10.89 14 10 13.1 10 12C10 10.9 10.89 10 12 10C13.1 10 14 10.9 14 12Z',
  outlined:
    'M19.14 12.94C19.2 12.64 19.2 12.34 19.14 12.04L21 10.61L19.4 8.04L17.53 8.48C17.16 8.19 16.77 7.93 16.35 7.71L15.94 5.55H13.06L12.65 7.71C12.23 7.93 11.84 8.19 11.47 8.48L9.61 8.04L8 10.61L9.86 12.04C9.8 12.34 9.8 12.64 9.86 12.94L8 14.37L9.61 16.94L11.47 16.5C11.84 16.79 12.23 17.05 12.65 17.27L13.06 19.43H15.94L16.35 17.27C16.77 17.05 17.16 16.79 17.53 16.5L19.4 16.94L21 14.37L19.14 12.94ZM12 14C10.89 14 10 13.1 10 12C10 10.9 10.89 10 12 10C13.1 10 14 10.9 14 12C14 13.1 13.1 14 12 14Z'
};

// Favorite Icon (*)
const favoriteIconPaths = {
  filled:
    'M12 21.35L10.55 20.03C5.4 15.36 2 12.28 2 8.5C2 5.42 4.42 3 7.5 3C9.24 3 10.91 3.81 12 5.08C13.09 3.81 14.76 3 16.5 3C19.58 3 22 5.42 22 8.5C22 12.28 18.6 15.36 13.45 20.04L12 21.35Z',
  outlined:
    'M16.5 3C14.76 3 13.09 3.81 12 5.08C10.91 3.81 9.24 3 7.5 3C4.42 3 2 5.42 2 8.5C2 12.28 5.4 15.36 10.55 20.03L12 21.35L13.45 20.03C18.6 15.36 22 12.28 22 8.5C22 5.42 19.58 3 16.5 3ZM12.1 18.55L12 18.65L11.9 18.55C7.14 14.24 4 11.39 4 8.5C4 6.5 5.5 5 7.5 5C9 5 10.36 5.83 11 7.09H13C13.64 5.83 15 5 16.5 5C18.5 5 20 6.5 20 8.5C20 11.39 16.86 14.24 12.1 18.55Z'
};

// --------------------------------------
// Icon Component Generators
// --------------------------------------
/**
 * Each icon is defined as a standalone React functional component that implements
 * the IconProps interface. The icon's path data is determined by the 'variant' prop.
 * The 'size' prop controls the width and height in pixels, and the 'color' prop is used
 * as the primary fill or stroke for the SVG path. The 'ariaLabel' prop provides
 * better accessibility support, and 'className' allows for additional styling.
 *
 * NOTE: Adjust viewBox, paths, or any other SVG attributes as per the final design.
 */

// -------------------------------------------------
// Shared utility to render an SVG icon
// -------------------------------------------------
function renderIcon(
  { size, color, variant, className, ariaLabel }: IconProps,
  paths: { filled: string; outlined: string }
): JSX.Element {
  const pathData = variant === 'filled' ? paths.filled : paths.outlined;

  return (
    <svg
      width={`${size}px`}
      height={`${size}px`}
      viewBox="0 0 24 24"
      fill="none"
      // Using stroke for a consistent approach, but you can switch to fill if desired:
      stroke={color}
      strokeWidth={variant === 'outlined' ? 2 : 0}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className || ''}
      aria-label={ariaLabel || ''}
      role={ariaLabel ? 'img' : 'presentation'}
    >
      <path d={pathData} fill={variant === 'filled' ? color : 'none'} />
    </svg>
  );
}

// --------------------------------------
// Individual Icon Components
// --------------------------------------
export const UserIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, userIconPaths);
};

export const MenuIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, menuIconPaths);
};

export const PaymentIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, paymentIconPaths);
};

export const HelpIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, helpIconPaths);
};

export const AlertIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, alertIconPaths);
};

export const AddIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, addIconPaths);
};

export const CloseIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, closeIconPaths);
};

export const UploadIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, uploadIconPaths);
};

export const SettingsIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, settingsIconPaths);
};

export const FavoriteIcon: React.FC<IconProps> = (props) => {
  return renderIcon(props, favoriteIconPaths);
};

// --------------------------------------
// Combined Exports
// --------------------------------------
/**
 * Named exports for the interface and all icon components.
 * This allows consumers to import only the icons they need or the entire set.
 */