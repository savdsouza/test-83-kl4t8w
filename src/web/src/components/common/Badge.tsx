import * as React from 'react'; // React v^18.0.0 core library for component development
import classNames from 'classnames'; // classnames v^2.3.2 for conditional class composition
import '../../styles/variables.css'; // Importing design system tokens (colors, typography, spacing, transitions)

/**
 * Describes the shape of the props accepted by the Badge component.
 * This interface enables a highly customizable and accessible badge
 * for displaying status, labels, counts, or other compact visual information.
 */
export interface BadgeProps {
  /**
   * Controls the visual style of the badge, mapped to specific color schemes.
   * If the provided variant is unsupported, a default styling is applied.
   */
  variant?: string;

  /**
   * Main content to be displayed inside the badge (e.g., number, label, or icon).
   * If children are provided, they take precedence over this content prop.
   */
  content?: React.ReactNode;

  /**
   * When set to true, renders a small circular dot, typically used for indicators
   * such as unread notifications or status presence.
   */
  dot?: boolean;

  /**
   * Additional CSS class names to be merged for extended or overriding styles.
   */
  className?: string;

  /**
   * Optional ReactNode that, if present, will be displayed instead of content prop.
   * This allows for more flexible rendering, such as embedding custom icons or elements.
   */
  children?: React.ReactNode;

  /**
   * Specifies the predefined size styling of the badge (e.g., 'small', 'medium', 'large').
   * If an unrecognized size is provided, default sizing is applied.
   */
  size?: string;

  /**
   * Click event handler. If provided, the badge becomes interactive and
   * will be focusable/accessibly treated as a button or clickable element.
   */
  onClick?: React.MouseEventHandler<HTMLSpanElement>;

  /**
   * Provides an accessible label for screen readers, conveying the badge’s purpose or content
   * when the actual text content may be insufficient or omitted.
   */
  'aria-label'?: string;

  /**
   * Maximum length for textual content. If the content exceeds this length,
   * it will be truncated and a title tooltip will be added for the full text.
   */
  maxLength?: number;
}

/**
 * Returns the appropriate CSS class name for the given badge variant
 * (e.g. "primary", "secondary", "error", "success"). If the provided
 * variant is not recognized, a default class is returned as a fallback.
 *
 * Steps:
 * 1) Validate input variant against allowed or known types.
 * 2) Map variant to the corresponding CSS class name.
 * 3) Return a default class if the specified variant is not found.
 * 4) Apply variant-specific modifiers if needed.
 *
 * @param variant - The variant string indicating the badge style.
 * @returns A string representing the CSS class for the chosen variant.
 */
function getBadgeVariantClass(variant: string | undefined): string {
  // Map of variant identifiers to class names for styling
  const VARIANT_MAP: Record<string, string> = {
    primary: 'badge--primary',
    secondary: 'badge--secondary',
    error: 'badge--error',
    success: 'badge--success',
    default: 'badge--default',
  };

  // Return the mapped class or default fallback if unrecognized
  if (variant && VARIANT_MAP[variant]) {
    return VARIANT_MAP[variant];
  }
  return VARIANT_MAP.default;
}

/**
 * Formats the provided content for the badge by handling different data types,
 * number formatting, text truncation, and optional tooltip for truncated content.
 *
 * Steps:
 * 1) Check the type of the content (number, string, or ReactNode).
 * 2) If numeric, optionally format it (e.g., locale-based formatting).
 * 3) If string, and longer than maxLength, truncate and add a title tooltip.
 * 4) Return rendered or original content for ReactNode types.
 *
 * @param content   - The badge's main content (number, string, or ReactNode).
 * @param maxLength - The character limit for truncation. If undefined, no truncation is applied.
 * @returns A ReactNode with properly formatted/truncated content.
 */
function formatContent(content: React.ReactNode, maxLength?: number): React.ReactNode {
  // Early return if no content
  if (content === null || content === undefined) return null;

  // If numeric, format using built-in number formatting for demonstration
  if (typeof content === 'number') {
    const formattedNumber = new Intl.NumberFormat().format(content);
    return formattedNumber;
  }

  // If string, handle truncation
  if (typeof content === 'string') {
    const textValue = content;
    if (maxLength && textValue.length > maxLength) {
      const truncated = textValue.slice(0, maxLength) + '…';
      return (
        <span title={textValue}>
          {truncated}
        </span>
      );
    }
    return textValue;
  }

  // For any other ReactNode, return as is
  return content;
}

/**
 * A highly customizable Badge component that displays status, count,
 * or label information in a compact visual format. Supports multiple
 * variants, sizes, and interactive states while maintaining accessibility
 * and performance.
 *
 * Steps involved in rendering:
 * 1) Use `classNames` to compose base, variant, size, and additional classes.
 * 2) Determine and apply the correct styling classes for the given variant and size.
 * 3) Format the content according to type, length, and optional tooltip logic.
 * 4) Add accessibility attributes like `aria-label`, keyboard focus, and `role="button"` if clickable.
 * 5) Apply transitions from the design system for hover/focus interactions.
 * 6) Invoke `onClick` if provided when badge is clicked (or user keys “Enter”/“Space”).
 * 7) Return a span element representing the badge.
 */
export const Badge: React.FC<BadgeProps> = ({
  variant,
  content,
  dot = false,
  className,
  children,
  size,
  onClick,
  'aria-label': ariaLabel,
  maxLength,
}) => {
  // Derive the appropriate variant class using our utility
  const variantClass = getBadgeVariantClass(variant);

  // We can optionally handle size classes with a simple map or fallback
  const SIZE_MAP: Record<string, string> = {
    small: 'badge--small',
    medium: 'badge--medium',
    large: 'badge--large',
  };
  const derivedSizeClass = size && SIZE_MAP[size] ? SIZE_MAP[size] : 'badge--medium';

  // Prepare the final content to be displayed (children override content)
  const displayContent = children ?? content;
  const formattedContent = formatContent(displayContent, maxLength);

  // Compose the final className string for the badge element
  const badgeClassName = classNames(
    'badge',             // base badge class
    variantClass,        // variant-based styling (color, background, etc.)
    derivedSizeClass,    // size-based styling
    { 'badge--dot': dot }, // special dot style if dot prop is true
    className            // any additional class(es) passed in
  );

  // Accessibility and interactivity considerations
  // If onClick is provided, we treat this element as a button-like component
  const isInteractive = typeof onClick === 'function';
  const handleKeyDown = (event: React.KeyboardEvent<HTMLSpanElement>): void => {
    if (!isInteractive) return;
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      onClick?.(event as unknown as React.MouseEvent<HTMLSpanElement>);
    }
  };

  return (
    <span
      className={badgeClassName}
      // Provide button-like semantics if clickable
      role={isInteractive ? 'button' : undefined}
      tabIndex={isInteractive ? 0 : undefined}
      onClick={onClick}
      onKeyDown={handleKeyDown}
      aria-label={ariaLabel}
      // Apply basic inline transition to complement design system variables
      style={{ transition: 'var(--transition-fast)' }}
    >
      {/* If dot is true, typically we do not display textual content; else show formattedContent */}
      {!dot && formattedContent}
    </span>
  );
};