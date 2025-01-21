import React, { useState, useRef, useEffect, KeyboardEvent, MouseEvent, ReactNode, ReactElement } from 'react'; // react@^18.0.0
import classNames from 'classnames'; // classnames@^2.3.2

// Internal import for theme transition CSS class (global styles)
import '../../styles/theme.css';

/**
 * Interface defining the props for the Tabs component.
 * Includes both controlled and uncontrolled usage.
 * Matches specification properties with optional orientation
 * and ARIA support for accessibility.
 */
export interface TabsProps {
  /**
   * ReactNode array that represents each tab panel content.
   * Each child can optionally include a 'title' prop for labeling the tab.
   */
  children: ReactNode[];

  /**
   * Index of the currently selected tab (controlled usage).
   * If provided, the component's internal state will be disabled.
   */
  selectedIndex?: number;

  /**
   * Default index of the selected tab (uncontrolled usage).
   * If 'selectedIndex' is not provided, this value is used for initialization.
   */
  defaultSelectedIndex?: number;

  /**
   * Callback fired when a tab is selected.
   * Receives the new index and tabId as parameters.
   */
  onChange?: (newIndex: number, tabId: string) => void;

  /**
   * Optional className for applying custom styles.
   */
  className?: string;

  /**
   * Orientation of the tabs: 'horizontal' (default) or 'vertical'.
   */
  orientation?: 'horizontal' | 'vertical';

  /**
   * ARIA label for the tablist container.
   * Provides descriptive text for screen readers.
   */
  ['aria-label']?: string;

  /**
   * Role attribute for the tablist container.
   * Typically "tablist" for an accessible tabs implementation.
   */
  role?: string;

  /**
   * TabIndex for the container, allowing control over keyboard focus.
   */
  tabIndex?: number;
}

/**
 * The Tabs component implements a responsive, accessible tab navigation system.
 * It supports both controlled and uncontrolled states, keyboard navigation,
 * ARIA compliance, and theme-specific styling with smooth transitions.
 */
const Tabs: React.FC<TabsProps> = ({
  children,
  selectedIndex,
  defaultSelectedIndex,
  onChange,
  className,
  orientation = 'horizontal',
  ['aria-label']: ariaLabel,
  role = 'tablist',
  tabIndex,
}) => {
  /**
   * Determines if this Tabs component is operating in controlled mode.
   * If 'selectedIndex' is defined, we use that value;
   * otherwise, we fall back to internal state.
   */
  const isControlled = typeof selectedIndex === 'number';

  /**
   * Internal state for managing the selected tab index in uncontrolled mode.
   * Defaults to the provided 'defaultSelectedIndex' or 0 if unspecified.
   */
  const [internalSelectedIndex, setInternalSelectedIndex] = useState<number>(
    defaultSelectedIndex || 0
  );

  /**
   * Reference to the main container for querying tab elements (focus management).
   */
  const tabsRef = useRef<HTMLDivElement | null>(null);

  /**
   * Retrieves the current list of focusable tab elements within the tabs container.
   * Filters only visible, non-disabled tabs sorted in DOM order.
   */
  function getFocusableElements(): HTMLElement[] {
    if (!tabsRef.current) {
      return [];
    }
    // Query all elements with role="tab" inside the container
    const tabElements = tabsRef.current.querySelectorAll<HTMLElement>('button[role="tab"]');
    const focusable: HTMLElement[] = [];
    tabElements.forEach((el) => {
      // Basic filtering for a potential hidden or disabled state if needed
      if (!el.hasAttribute('disabled')) {
        focusable.push(el);
      }
    });
    return focusable;
  }

  /**
   * Helper to move focus to a specific tab by index.
   */
  function focusTabByIndex(index: number): void {
    const focusableTabs = getFocusableElements();
    if (focusableTabs[index]) {
      focusableTabs[index].focus();
    }
  }

  /**
   * Computes the actual selected index, using either the controlled prop
   * or the internal selected index for uncontrolled usage.
   */
  const activeIndex = isControlled ? (selectedIndex as number) : internalSelectedIndex;

  /**
   * Handles the selection of a new tab when clicked.
   * Updates internal state, triggers the onChange callback,
   * and manages accessibility concerns (focus, ARIA attributes).
   */
  function handleTabClick(
    index: number,
    tabId: string,
    event?: MouseEvent<HTMLButtonElement>
  ): void {
    // Prevent default behavior if an event is provided
    if (event) {
      event.preventDefault();
    }

    // Update the uncontrolled state if in uncontrolled mode
    if (!isControlled) {
      setInternalSelectedIndex(index);
    }

    // Fire the onChange callback if defined
    if (onChange) {
      onChange(index, tabId);
    }

    // Set focus to the newly selected tab
    focusTabByIndex(index);
  }

  /**
   * Implements keyboard navigation behavior for tabs, including:
   * - Left/Right arrows for horizontal
   * - Up/Down arrows for vertical
   * - Home/End for first/last tab
   * Prevents default scrolling and handles focus trap.
   */
  function handleKeyDown(event: KeyboardEvent<HTMLButtonElement>): void {
    const key = event.key;
    let newIndex = activeIndex;
    const totalTabs = React.Children.count(children);

    // Identify the direction based on orientation
    const arrowBackward = orientation === 'horizontal' ? 'ArrowLeft' : 'ArrowUp';
    const arrowForward = orientation === 'horizontal' ? 'ArrowRight' : 'ArrowDown';

    switch (key) {
      case arrowBackward:
        event.preventDefault();
        newIndex = activeIndex > 0 ? activeIndex - 1 : totalTabs - 1;
        break;
      case arrowForward:
        event.preventDefault();
        newIndex = activeIndex < totalTabs - 1 ? activeIndex + 1 : 0;
        break;
      case 'Home':
        event.preventDefault();
        newIndex = 0;
        break;
      case 'End':
        event.preventDefault();
        newIndex = totalTabs - 1;
        break;
      default:
        return; // If it's not a recognized key, we skip handling
    }

    // Update state for uncontrolled usage
    if (!isControlled) {
      setInternalSelectedIndex(newIndex);
    }

    // Fire callback if in controlled or uncontrolled mode
    const tabId = `tab-${newIndex}`;
    if (onChange) {
      onChange(newIndex, tabId);
    }

    // Manage focus for the newly selected tab
    focusTabByIndex(newIndex);
  }

  /**
   * On mount or when orientation changes, we ensure focus remains consistent.
   * Also, when the active index changes, we could optionally refocus as needed.
   */
  useEffect(() => {
    // Optionally focus the active tab on mount if accessible by default
    // This can be adapted based on UX preferences.
  }, [orientation]);

  return (
    <div
      ref={tabsRef}
      className={classNames(
        'tabs', // Base container styles
        'tabsResponsive', // Responsive layout adjustments
        className, // Optional custom class
        'theme-transition' // Smooth theme transitions
      )}
      role={role}
      aria-label={ariaLabel}
      aria-orientation={orientation}
      tabIndex={tabIndex}
    >
      {/* Tab List Container */}
      <div
        className={classNames(
          'tabList',
          orientation === 'vertical' ? 'tabListVertical' : 'tabListHorizontal'
        )}
      >
        {React.Children.map(children, (child, index) => {
          // Each child can optionally have a 'title' prop for labeling
          const element = child as ReactElement<any>;
          const tabLabel = element.props.title || `Tab ${index + 1}`;
          const tabId = `tab-${index}`;
          const isActive = activeIndex === index;

          return (
            <button
              key={tabId}
              id={tabId}
              role="tab"
              type="button"
              aria-selected={isActive}
              aria-controls={`tabpanel-${index}`}
              className={classNames(
                'tab',
                isActive ? 'tabActive' : 'tabInactive',
                'theme-transition'
              )}
              tabIndex={isActive ? 0 : -1}
              onClick={(e) => handleTabClick(index, tabId, e)}
              onKeyDown={handleKeyDown}
            >
              {tabLabel}
            </button>
          );
        })}
      </div>

      {/* Tab Panels */}
      {React.Children.map(children, (child, index) => {
        const element = child as ReactElement<any>;
        const isActive = activeIndex === index;
        return (
          <div
            key={`panel-${index}`}
            id={`tabpanel-${index}`}
            role="tabpanel"
            aria-labelledby={`tab-${index}`}
            hidden={!isActive}
            className={classNames('tabPanel', 'theme-transition')}
          >
            {element}
          </div>
        );
      })}
    </div>
  );
};

export default Tabs;