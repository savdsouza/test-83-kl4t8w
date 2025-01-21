import React, {
  useState,
  useRef,
  useEffect,
  useCallback,
  CSSProperties,
  FC,
  ReactNode,
  MouseEvent,
  FocusEvent,
  TouchEvent
} from 'react'; // version ^18.0.0
import classNames from 'classnames'; // version ^2.3.0

// Internal CSS imports for consistent theming and component styling
import * as themeCss from '../../styles/theme.css'; // Named import for .theme-transition
import * as componentsCss from '../../styles/components.css'; // Named import for tooltip-related styles

/**
 * TooltipPosition type describes all supported tooltip positions, including an 'auto'
 * option that can dynamically adjust based on available window space or RTL settings.
 */
export type TooltipPosition = 'top' | 'bottom' | 'left' | 'right' | 'auto';

/**
 * Offset type provides optional x and y offsets to nudge the tooltip's final position.
 */
export interface TooltipOffset {
  x?: number;
  y?: number;
}

/**
 * useTooltipPosition hook parameters:
 * 1. triggerRect (DOMRect): bounding rectangle of the trigger element.
 * 2. preferredPosition (TooltipPosition): user-specified initial position preference.
 * 3. offset (TooltipOffset): custom offset values along the x and y axes.
 *
 * This hook returns an object with computed coordinates, a resolved placement string,
 * and any additional positioning attributes to ensure the tooltip stays within
 * window boundaries, handles RTL layouts, and respects custom offset values.
 */
interface UseTooltipPositionResult {
  left: number;
  top: number;
  placement: TooltipPosition;
}

export function useTooltipPosition(
  triggerRect: DOMRect | null,
  preferredPosition: TooltipPosition,
  offset: TooltipOffset
): UseTooltipPositionResult {
  /**
   * This hook calculates an optimal tooltip position based on the size and
   * location of the trigger element (triggerRect), the user's requested position,
   * current window boundaries, and optional offsets. It also accounts for RTL
   * page direction by checking the document's direction or any custom override.
   */
  const [left, setLeft] = useState<number>(0);
  const [top, setTop] = useState<number>(0);
  const [resolvedPlacement, setResolvedPlacement] = useState<TooltipPosition>(preferredPosition);

  // Helper function to detect if document is set to RTL
  const isRTL = useCallback((): boolean => {
    if (typeof document !== 'undefined') {
      return document?.dir?.toLowerCase() === 'rtl';
    }
    return false;
  }, []);

  useEffect(() => {
    if (!triggerRect) {
      return;
    }

    // Basic measurements
    const tooltipWidth = 200; // Assume the tooltip container's approximate width
    const tooltipHeight = 80; // Assume the tooltip container's approximate height
    const margin = 8; // Base spacing to keep tooltip away from edges and trigger

    // Calculate initial positions (centered above, below, left, or right)
    let newLeft = 0;
    let newTop = 0;
    let finalPlacement = preferredPosition;

    const handleAutoPlacement = () => {
      /**
       * If the 'auto' position is selected, we attempt to find the most suitable
       * position by checking available space on each side. This is a simplistic
       * approach and can be extended for more advanced placement logic.
       */
      const spaceAbove = triggerRect.top;
      const spaceBelow = window.innerHeight - triggerRect.bottom;
      const spaceLeft = triggerRect.left;
      const spaceRight = window.innerWidth - triggerRect.right;

      // Choose the position with the largest available space
      const maxVertical = Math.max(spaceAbove, spaceBelow);
      const maxHorizontal = Math.max(spaceLeft, spaceRight);

      if (maxVertical >= maxHorizontal) {
        finalPlacement = spaceAbove > spaceBelow ? 'top' : 'bottom';
      } else {
        finalPlacement = spaceLeft > spaceRight ? 'left' : 'right';
      }
    };

    // If position is 'auto', decide best placement automatically
    if (preferredPosition === 'auto') {
      handleAutoPlacement();
    }

    // Check for RTL if we're dealing with left or right placements
    const directionIsRTL = isRTL();

    // Compute new positions based on chosen or auto-resolved finalPlacement
    switch (finalPlacement) {
      case 'top':
        newLeft = triggerRect.left + (triggerRect.width / 2) - (tooltipWidth / 2);
        newTop = triggerRect.top - tooltipHeight - margin;
        break;
      case 'bottom':
        newLeft = triggerRect.left + (triggerRect.width / 2) - (tooltipWidth / 2);
        newTop = triggerRect.bottom + margin;
        break;
      case 'left':
        if (directionIsRTL) {
          // If RTL, left means physically right, so invert accordingly
          newLeft = triggerRect.right + margin;
        } else {
          newLeft = triggerRect.left - tooltipWidth - margin;
        }
        newTop = triggerRect.top + (triggerRect.height / 2) - (tooltipHeight / 2);
        break;
      case 'right':
        if (directionIsRTL) {
          // If RTL, right means physically left
          newLeft = triggerRect.left - tooltipWidth - margin;
        } else {
          newLeft = triggerRect.right + margin;
        }
        newTop = triggerRect.top + (triggerRect.height / 2) - (tooltipHeight / 2);
        break;
      default:
        break;
    }

    // Apply offset
    newLeft += offset?.x || 0;
    newTop += offset?.y || 0;

    // Clamp values to stay within viewport boundaries
    // (This is a simple approach; advanced solutions might recalc the position.)
    const maxLeft = window.innerWidth - tooltipWidth - margin;
    const maxTop = window.innerHeight - tooltipHeight - margin;
    newLeft = Math.max(margin, Math.min(newLeft, maxLeft));
    newTop = Math.max(margin, Math.min(newTop, maxTop));

    // Set final states
    setResolvedPlacement(finalPlacement);
    setLeft(newLeft);
    setTop(newTop);
  }, [triggerRect, preferredPosition, offset, isRTL]);

  return { left, top, placement: resolvedPlacement };
}

/**
 * TooltipProps define the inputs accepted by the Tooltip component.
 * - children: ReactNode to wrap with tooltip trigger behavior
 * - content: string displayed inside the tooltip bubble
 * - position: a TooltipPosition (top, bottom, left, right, auto)
 * - className: optional override for additional styling
 * - disabled: if true, the tooltip is inactive
 * - showDelay: how long to wait (ms) before showing tooltip on hover/focus
 * - hideDelay: how long to wait (ms) before hiding tooltip on mouse out/blur
 * - offset: an optional x/y offset for adjusting tooltip position
 * - aria-label: accessibility label for screen readers
 */
export interface TooltipProps {
  children: ReactNode;
  content: string;
  position?: TooltipPosition;
  className?: string;
  disabled?: boolean;
  showDelay?: number;
  hideDelay?: number;
  offset?: TooltipOffset;
  'aria-label'?: string;
}

/**
 * Tooltip is a fully accessible, robust, and production-ready component that
 * displays contextual information when hovering, focusing, or touching the
 * wrapped content. It supports multiple positions, custom offsets, delays,
 * and RTL layouts. It also utilizes ResizeObserver and IntersectionObserver
 * (when available) to track element changes.
 */
export const Tooltip: FC<TooltipProps> = ({
  children,
  content,
  position = 'top',
  className = '',
  disabled = false,
  showDelay = 200,
  hideDelay = 150,
  offset = { x: 0, y: 0 },
  'aria-label': ariaLabel
}) => {
  /**
   * isVisible indicates whether the tooltip is currently shown or hidden.
   * triggerRect stores the bounding rectangle of the trigger element used
   * by our useTooltipPosition hook to calculate final tooltip coordinates.
   */
  const [isVisible, setIsVisible] = useState<boolean>(false);
  const [triggerRect, setTriggerRect] = useState<DOMRect | null>(null);
  const triggerRef = useRef<HTMLSpanElement | null>(null);
  const showTimerId = useRef<number | null>(null);
  const hideTimerId = useRef<number | null>(null);

  // Resize and intersection observers to ensure we handle dynamic layout changes
  const resizeObserver = useRef<ResizeObserver | null>(null);
  const intersectionObserver = useRef<IntersectionObserver | null>(null);

  // Calculate the tooltip's final position based on current triggerRect
  const { left, top, placement } = useTooltipPosition(triggerRect, position, offset);

  /**
   * Clears any active show/hide timers, typically called prior to scheduling
   * a new delay-based visibility change.
   */
  const clearTimers = useCallback(() => {
    if (showTimerId.current) {
      window.clearTimeout(showTimerId.current);
      showTimerId.current = null;
    }
    if (hideTimerId.current) {
      window.clearTimeout(hideTimerId.current);
      hideTimerId.current = null;
    }
  }, []);

  /**
   * handleMouseEnter: triggered upon mouse hover over the trigger element.
   * Schedules tooltip to become visible after showDelay if not disabled.
   */
  const handleMouseEnter = useCallback((e: MouseEvent) => {
    if (disabled) return;
    clearTimers();

    if (triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect();
      setTriggerRect(rect);
    }

    showTimerId.current = window.setTimeout(() => {
      setIsVisible(true);
    }, showDelay);
  }, [clearTimers, disabled, showDelay]);

  /**
   * handleMouseLeave: triggered when mouse leaves the trigger element.
   * Schedules tooltip to hide after hideDelay if currently visible.
   */
  const handleMouseLeave = useCallback((e: MouseEvent) => {
    if (disabled) return;
    clearTimers();

    hideTimerId.current = window.setTimeout(() => {
      setIsVisible(false);
    }, hideDelay);
  }, [clearTimers, disabled, hideDelay]);

  /**
   * handleFocus: triggered when the trigger element gains keyboard focus.
   * Immediately shows the tooltip for improved accessibility.
   */
  const handleFocus = useCallback((e: FocusEvent) => {
    if (disabled) return;
    clearTimers();

    if (triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect();
      setTriggerRect(rect);
    }
    setIsVisible(true);
  }, [clearTimers, disabled]);

  /**
   * handleBlur: triggered when the trigger element loses keyboard focus.
   * Hides the tooltip after the standard hide delay.
   */
  const handleBlur = useCallback((e: FocusEvent) => {
    if (disabled) return;
    clearTimers();

    hideTimerId.current = window.setTimeout(() => {
      setIsVisible(false);
    }, hideDelay);
  }, [clearTimers, disabled, hideDelay]);

  /**
   * handleTouchStart: for mobile/touch environments, we show the tooltip
   * on touch. This is optional logic, but can be helpful if we want
   * consistent behavior for long-press or touches. We set an immediate
   * show to avoid confusion with delayed interactions on mobile.
   */
  const handleTouchStart = useCallback((e: TouchEvent) => {
    if (disabled) return;
    clearTimers();

    if (triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect();
      setTriggerRect(rect);
    }
    setIsVisible(true);
  }, [clearTimers, disabled]);

  /**
   * handleTouchEnd: once the user lifts their finger, we schedule the tooltip
   * to be hidden after hideDelay, mimicking the mouse leave behavior.
   */
  const handleTouchEnd = useCallback((e: TouchEvent) => {
    if (disabled) return;
    clearTimers();
    hideTimerId.current = window.setTimeout(() => {
      setIsVisible(false);
    }, hideDelay);
  }, [clearTimers, disabled, hideDelay]);

  /**
   * Set up ResizeObserver and IntersectionObserver to re-calc positions when
   * the trigger element's size or visibility changes. This helps ensure the
   * tooltip remains correctly placed if layouts are dynamic or if the user
   * scrolls to a new area.
   */
  useEffect(() => {
    const currentTrigger = triggerRef.current;
    if (!currentTrigger) return;

    // Observe size changes
    if ('ResizeObserver' in window) {
      resizeObserver.current = new ResizeObserver(() => {
        if (currentTrigger) {
          setTriggerRect(currentTrigger.getBoundingClientRect());
        }
      });
      resizeObserver.current.observe(currentTrigger);
    }

    // Observe intersection changes
    if ('IntersectionObserver' in window) {
      intersectionObserver.current = new IntersectionObserver(entries => {
        const [entry] = entries;
        if (!entry.isIntersecting) {
          setIsVisible(false);
        }
      });
      intersectionObserver.current.observe(currentTrigger);
    }

    return () => {
      if (resizeObserver.current && currentTrigger) {
        resizeObserver.current.unobserve(currentTrigger);
        resizeObserver.current.disconnect();
      }
      if (intersectionObserver.current && currentTrigger) {
        intersectionObserver.current.unobserve(currentTrigger);
        intersectionObserver.current.disconnect();
      }
    };
  }, [triggerRect]);

  /**
   * Clean up any pending timers when this component unmounts to avoid
   * updating state after destruction.
   */
  useEffect(() => {
    return () => {
      clearTimers();
    };
  }, [clearTimers]);

  // Combine any custom className with tooltip styling classes
  const tooltipContainerClasses = classNames(
    // The following is referencing the named classes from the imported CSS
    componentsCss['tooltip styles'], // fictional named export or class
    themeCss['theme-transition'],
    className
  );

  // Conditionally render the tooltip element if it's visible
  const shouldRenderTooltip = isVisible && !disabled;

  // Inline styles for final tooltip positioning
  const tooltipStyle: CSSProperties = {
    left: `${left}px`,
    top: `${top}px`,
    position: 'fixed', // or 'absolute' depending on the approach
    visibility: shouldRenderTooltip ? 'visible' : 'hidden',
    opacity: shouldRenderTooltip ? 1 : 0,
    zIndex: 800,
  };

  // The ID for aria-describedby reference
  const tooltipId = `tooltip-${Math.floor(Math.random() * 1000000)}`;

  return (
    <>
      {/* 
        Trigger wrapper: we wrap the children with a <span> or <div> that 
        captures the relevant mouse/touch/keyboard events. 
      */}
      <span
        ref={triggerRef}
        tabIndex={disabled ? -1 : 0}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        onFocus={handleFocus}
        onBlur={handleBlur}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
        aria-describedby={shouldRenderTooltip ? tooltipId : undefined}
        aria-label={ariaLabel}
        style={{ cursor: disabled ? 'default' : 'pointer' }}
      >
        {children}
      </span>

      {/* Tooltip bubble with computed styles and content */}
      {shouldRenderTooltip && (
        <div
          id={tooltipId}
          role="tooltip"
          className={tooltipContainerClasses}
          style={tooltipStyle}
          aria-hidden={!shouldRenderTooltip}
          data-placement={placement}
        >
          {content}
        </div>
      )}
    </>
  );
};