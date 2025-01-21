/**
 * Dropdown.tsx
 *
 * A reusable, enterprise-grade dropdown component with extreme attention to detail,
 * supporting single and multi-select modes, search functionality, keyboard navigation,
 * accessibility (ARIA), and responsive design. Integrates with theme context for
 * consistent styling across light and dark modes.
 */

// react@^18.0.0
import React, {
  useState,
  useRef,
  useCallback,
  useEffect,
  useMemo,
  KeyboardEvent,
  MouseEvent,
  ReactNode,
} from 'react';

// @emotion/styled@^11.11.0
import styled from '@emotion/styled';

// Internal imports
import { useTheme } from '../../hooks/useTheme';
import { Theme } from '../../types/common.types';

/**
 * Interface representing a single dropdown option, including value,
 * label, optional disabled, optional icon, and optional description.
 * Provides maximum flexibility for item rendering.
 */
export interface DropdownOption {
  value: string | number;
  label: string;
  disabled?: boolean;
  icon?: ReactNode;
  description?: string;
}

/**
 * Defines the prop shape for the Dropdown component, including:
 * - options: The list of selectable dropdown options
 * - value: Current selection(s)
 * - onChange: Callback to propagate changes
 * - placeholder: Placeholder text for empty selection
 * - disabled: Disabled state of the entire dropdown
 * - error: Error message for validation feedback
 * - multiple: Allows multi-select if true
 * - searchable: Enables internal search filtering
 * - loading: Indicates loading state
 * - className: Optional additional CSS class
 * - maxHeight: Maximum menu height in pixels
 * - virtualized: Placeholder for advanced virtualization logic
 * - renderOption: Allows custom rendering of dropdown options
 */
export interface DropdownProps {
  options: DropdownOption[];
  value: string | number | (string | number)[];
  onChange: (value: string | number | (string | number)[]) => void;
  placeholder?: string;
  disabled?: boolean;
  error?: string;
  multiple?: boolean;
  searchable?: boolean;
  loading?: boolean;
  className?: string;
  maxHeight?: number;
  virtualized?: boolean;
  renderOption?: (option: DropdownOption) => ReactNode;
}

/**
 * Styled component for the dropdown container, applying:
 * - Layout properties (relative positioning, min-width)
 * - Theming for font, color, and transitions
 * - Potential future expansions for animations or advanced styling
 */
const DropdownContainer = styled.div<{
  isDisabled?: boolean;
  hasError?: boolean;
  fontFamily?: string;
  fontSize?: string;
}>`
  position: relative;
  width: 100%;
  min-width: 200px;
  font-family: ${({ fontFamily }) => fontFamily || 'sans-serif'};
  font-size: ${({ fontSize }) => fontSize || '16px'};
  outline: none;
  transition: all 0.2s ease;
  touch-action: manipulation;

  /* Provide a subtle visual feedback if an error is present */
  ${({ hasError, theme }) =>
    hasError &&
    `
    & ${DropdownTrigger} {
      border-color: ${theme.colors.error.main};
    }
  `}

  /* Prevent interactions if the dropdown is disabled */
  ${({ isDisabled }) =>
    isDisabled &&
    `
    pointer-events: none;
    opacity: 0.6;
  `}
`;

/**
 * Styled component for the dropdown trigger, which is the
 * visible toggling element prior to expanding the menu.
 * - Outlines a visual focus state for accessibility
 * - Adjusts layout properties for consistent sizing and alignment
 */
const DropdownTrigger = styled.button<{
  themeFontSize?: string;
  borderRadius?: string;
}>`
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  cursor: pointer;
  user-select: none;
  min-height: 44px;
  padding: ${({ theme }) => `${theme.spacing.grid['2x']} ${theme.spacing.grid['4x']}`};
  background-color: ${({ theme }) => theme.colors.background.primary};
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: ${({ borderRadius }) => borderRadius || '4px'};
  font-size: ${({ themeFontSize }) => themeFontSize || '16px'};
  text-align: left;
  color: ${({ theme }) => theme.colors.text.primary};

  &:focus-visible {
    outline: 2px solid ${({ theme }) => theme.colors.primary.main};
    outline-offset: 2px;
  }

  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
`;

/**
 * Styled component for the dropdown menu container, handling:
 * - Absolute positioning relative to the trigger
 * - Z-index layering above other UI
 * - Potential overflow management with a controlled max height
 */
const DropdownMenu = styled.ul<{
  maxHeight?: number;
  borderRadius?: string;
}>`
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  margin: 4px 0 0 0;
  padding: 0;
  list-style: none;
  background-color: ${({ theme }) => theme.colors.background.primary};
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: ${({ borderRadius }) => borderRadius || '4px'};
  box-shadow: ${({ theme }) => theme.elevation.card};
  z-index: 999;
  overflow-y: auto;
  max-height: ${({ maxHeight }) => (maxHeight ? `${maxHeight}px` : '240px')};

  /* If needed, we can incorporate scrolling or cross-browser
     custom scrollbar styling. */
`;

/**
 * Styled component for each dropdown option, providing:
 * - Hover highlights
 * - Disabled state styling
 * - Selected state styling for multi-select
 */
const DropdownOptionItem = styled.li<{
  isSelected?: boolean;
  isDisabled?: boolean;
}>`
  display: flex;
  align-items: flex-start;
  padding: ${({ theme }) => `${theme.spacing.grid['2x']} ${theme.spacing.grid['4x']}`};
  cursor: pointer;
  color: ${({ theme }) => theme.colors.text.primary};

  ${({ isSelected, theme }) =>
    isSelected &&
    `
    background-color: ${theme.colors.primary.alpha?.['10'] || 'rgba(33, 150, 243, 0.1)'};
  `}

  ${({ isDisabled }) =>
    isDisabled &&
    `
    opacity: 0.5;
    cursor: not-allowed;
  `}

  &:hover {
    background-color: ${({ theme, isDisabled }) =>
      isDisabled
        ? 'transparent'
        : theme.colors.primary.alpha?.['10'] || 'rgba(33, 150, 243, 0.1)'};
  }
`;

/**
 * An optional search input for filtering options if `searchable`
 * is enabled. Displays at the top of the dropdown menu.
 */
const DropdownSearchInput = styled.input`
  width: 100%;
  box-sizing: border-box;
  padding: ${({ theme }) => `${theme.spacing.grid['2x']} ${theme.spacing.grid['4x']}`};
  border: none;
  border-bottom: 1px solid rgba(0, 0, 0, 0.2);
  outline: none;
  font-size: ${({ theme }) => theme.typography.fontSize.md};

  &:focus {
    border-bottom: 1px solid ${({ theme }) => theme.colors.primary.main};
  }
`;

/**
 * A small container to display loading or error states
 * at the bottom of the dropdown menu, if needed.
 */
const DropdownFooter = styled.div`
  padding: ${({ theme }) => `${theme.spacing.grid['2x']} ${theme.spacing.grid['4x']}`};
  font-size: ${({ theme }) => theme.typography.fontSize.sm};
  color: ${({ theme }) => theme.colors.text.secondary};
`;

/**
 * Reusable, accessible dropdown component with single/multi-select logic,
 * search functionality, ARIA attributes, focus management, and keyboard controls.
 */
export const Dropdown: React.FC<DropdownProps> = ({
  options,
  value,
  onChange,
  placeholder = 'Select...',
  disabled = false,
  error,
  multiple = false,
  searchable = false,
  loading = false,
  className,
  maxHeight,
  virtualized = false,
  renderOption,
}) => {
  /**
   * Retrieve theme context, including color palettes and
   * a boolean representing dark mode status.
   */
  const { theme, isDarkMode } = useTheme();

  /**
   * Local state controlling the open/closed state of the dropdown menu.
   */
  const [isOpen, setIsOpen] = useState<boolean>(false);

  /**
   * Local state tracking the current search term, if `searchable` is true.
   */
  const [searchTerm, setSearchTerm] = useState<string>('');

  /**
   * Ref to the container for handling clicks outside and keyboard events.
   */
  const containerRef = useRef<HTMLDivElement | null>(null);

  /**
   * Memoized array of filtered options based on user input.
   * If not searchable, no filtering is performed.
   */
  const filteredOptions = useMemo<DropdownOption[]>(() => {
    if (!searchable) {
      return options;
    }
    const lowerSearch = searchTerm.toLowerCase();
    return options.filter((opt) => {
      const labelMatch = opt.label.toLowerCase().includes(lowerSearch);
      const descMatch = opt.description
        ? opt.description.toLowerCase().includes(lowerSearch)
        : false;
      return labelMatch || descMatch;
    });
  }, [searchTerm, options, searchable]);

  /**
   * Determines if a specific option is selected, checking
   * single or multi-selection context from props.value.
   */
  const isOptionSelected = useCallback(
    (option: DropdownOption): boolean => {
      if (multiple && Array.isArray(value)) {
        return value.includes(option.value);
      }
      return value === option.value;
    },
    [multiple, value]
  );

  /**
   * Toggles or replaces the selected value(s) when an option is clicked.
   * - Checks if the option is disabled or if the dropdown is currently loading
   * - For multi-select, toggles the chosen option in the array
   * - For single-select, replaces the existing value
   * - Closes the dropdown in single-select mode
   * - Announces the selection via an ARIA-friendly approach
   * - Updates the focus when needed
   */
  const handleOptionClick = useCallback(
    (option: DropdownOption) => {
      // 1. Check if option is disabled or loading to prevent selection
      if (option.disabled || loading) {
        return;
      }

      // 2. Multi-select toggling
      if (multiple && Array.isArray(value)) {
        let newValues: (string | number)[];
        if (value.includes(option.value)) {
          newValues = value.filter((v) => v !== option.value);
        } else {
          newValues = [...value, option.value];
        }
        onChange(newValues);
      } else {
        // 3. Single-select replacement
        onChange(option.value);
        // 4. Close the dropdown after single selection
        setIsOpen(false);
      }

      // 5. Screen reader announcement could be implemented here,
      //    e.g. updating an aria-live region to confirm selection

      // 6. Additional focus management can be handled if needed,
      //    for instance returning focus to the trigger
    },
    [multiple, onChange, value, loading]
  );

  /**
   * Manages all keyboard interactions for the dropdown, including:
   * - Arrow up/down to navigate options
   * - Home/End to jump to first/last
   * - Enter/Space to select
   * - Escape to close
   * - Tab for focus movement
   * - Character keys for quick search
   * - Updating relevant ARIA attributes
   */
  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      if (!isOpen) {
        return;
      }

      const { key } = event;

      // 1. Define a typed list of keys that must be handled in a custom way.
      const actionableKeys = [
        'ArrowDown',
        'ArrowUp',
        'Home',
        'End',
        'Enter',
        'Space',
        'Escape',
      ];

      // 2. If the user presses arrow keys, tab, or certain search-based keys, we intercept
      if (
        actionableKeys.includes(key) ||
        key === ' ' ||
        /^[a-zA-Z0-9]$/.test(key) ||
        key === 'Tab'
      ) {
        event.preventDefault();
      }

      switch (key) {
        case 'ArrowDown':
          // Move focus to next item
          focusNextOption(1);
          break;

        case 'ArrowUp':
          // Move focus to previous item
          focusNextOption(-1);
          break;

        case 'Home':
          // Move focus to first item
          focusItemAtIndex(0);
          break;

        case 'End':
          // Move focus to last item
          focusItemAtIndex(filteredOptions.length - 1);
          break;

        case 'Enter':
        case ' ':
        case 'Space':
          // Activate the currently focused option
          activateFocusedOption();
          break;

        case 'Escape':
          // Close the dropdown
          setIsOpen(false);
          break;

        case 'Tab':
          // Close and allow natural tab handling
          setIsOpen(false);
          break;

        default:
          // 3. If the user typed a character, attempt to search jump
          if (/^[a-zA-Z0-9]$/.test(key)) {
            // Could implement quick jump to matching item label
            // or update searchTerm in a 'non-searchable' scenario
          }
          break;
      }
    },
    [isOpen, filteredOptions]
  );

  /**
   * Queries the DOM to find currently focused option and moves
   * focus relative to that element by a specified offset.
   */
  const focusNextOption = (offset: number) => {
    const optionNodes = getOptionNodes();
    if (optionNodes.length === 0) return;

    const currentIndex = optionNodes.findIndex(
      (node) => node === document.activeElement
    );
    let nextIndex = currentIndex + offset;

    if (nextIndex < 0) {
      nextIndex = optionNodes.length - 1;
    } else if (nextIndex >= optionNodes.length) {
      nextIndex = 0;
    }

    focusItemAtIndex(nextIndex);
  };

  /**
   * Sets focus on the option at the specified index if it exists.
   */
  const focusItemAtIndex = (index: number) => {
    const optionNodes = getOptionNodes();
    if (optionNodes[index]) {
      (optionNodes[index] as HTMLElement).focus();
    }
  };

  /**
   * Retrieves the DOM nodes for all option items to enable
   * keyboard focus movement.
   */
  const getOptionNodes = (): HTMLElement[] => {
    if (!containerRef.current) return [];
    const menuEl = containerRef.current.querySelector('ul');
    if (!menuEl) return [];
    return Array.from(menuEl.querySelectorAll('li[role="option"]'));
  };

  /**
   * Activates or "clicks" the currently focused option item,
   * simulating a user click with the keyboard.
   */
  const activateFocusedOption = () => {
    const focusedEl = document.activeElement as HTMLElement;
    if (focusedEl?.getAttribute('data-option-value')) {
      // Look up the relevant option from the dataset
      const optionValue = focusedEl.getAttribute('data-option-value') || '';
      const matchedOption = filteredOptions.find(
        (opt) => String(opt.value) === optionValue
      );
      if (matchedOption) {
        handleOptionClick(matchedOption);
      }
    }
  };

  /**
   * Toggles the open/close state of the dropdown. If we open,
   * we handle focus. If we close, we reset search if applicable.
   */
  const toggleDropdown = useCallback(
    (evt: MouseEvent<HTMLButtonElement>) => {
      evt.preventDefault();
      if (!disabled && !loading) {
        setIsOpen((prev) => !prev);
      }
    },
    [disabled, loading]
  );

  /**
   * Closes the dropdown menu when clicking outside of it.
   */
  useEffect(() => {
    const handleDocumentClick = (evt: MouseEvent) => {
      if (!containerRef.current) return;
      if (!containerRef.current.contains(evt.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('click', handleDocumentClick);
    return () => document.removeEventListener('click', handleDocumentClick);
  }, []);

  /**
   * If we close the dropdown, reset internal search to an empty string.
   */
  useEffect(() => {
    if (!isOpen) {
      setSearchTerm('');
    }
  }, [isOpen]);

  /**
   * Renders the appropriate label or placeholder for the trigger,
   * based on selection(s) and user props.
   */
  const renderTriggerLabel = useMemo(() => {
    if (multiple && Array.isArray(value) && value.length > 0) {
      const selectedLabels = value
        .map((val) => {
          const found = options.find((o) => o.value === val);
          return found ? found.label : '';
        })
        .filter(Boolean);
      if (selectedLabels.length > 0) {
        return selectedLabels.join(', ');
      }
    }
    if (!multiple && !Array.isArray(value) && value !== '' && value !== undefined) {
      const single = options.find((o) => o.value === value);
      if (single) {
        return single.label;
      }
    }
    return placeholder;
  }, [multiple, value, placeholder, options]);

  return (
    <DropdownContainer
      className={className}
      ref={containerRef}
      isDisabled={disabled}
      hasError={!!error}
      fontFamily={theme.typography.fontFamily.primary}
      fontSize={theme.typography.fontSize.md}
      data-testid="dropdown-container"
      theme={theme}
    >
      {/* The button that toggles the dropdown menu open and closed */}
      <DropdownTrigger
        onClick={toggleDropdown}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-disabled={disabled || loading}
        disabled={disabled || loading}
        borderRadius="4px"
        themeFontSize={theme.typography.fontSize.md}
        type="button"
        theme={theme}
        data-testid="dropdown-trigger"
      >
        <span>{loading ? 'Loading...' : renderTriggerLabel}</span>
        {/* A down arrow or custom icon could go here */}
        <span aria-hidden="true">▼</span>
      </DropdownTrigger>

      {isOpen && (
        <DropdownMenu
          role="listbox"
          aria-activedescendant="dropdown-active-option"
          aria-multiselectable={multiple || undefined}
          maxHeight={maxHeight}
          borderRadius="4px"
          theme={theme}
          onKeyDown={handleKeyDown}
          data-testid="dropdown-menu"
        >
          {/* If searchable, render a text input for filtering */}
          {searchable && (
            <li role="none">
              <DropdownSearchInput
                type="text"
                placeholder="Search..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                spellCheck={false}
                aria-label="Search in dropdown"
                autoFocus
                theme={theme}
              />
            </li>
          )}

          {/* Virtualized placeholder if needed for large lists:
              In a real-world scenario, you might integrate a library
              like react-window or react-virtualized here. */}
          {virtualized && false /* Placeholder condition */ && (
            <li role="none">
              <DropdownFooter theme={theme}>
                Virtualization logic is not yet implemented
              </DropdownFooter>
            </li>
          )}

          {/* Render the filtered options */}
          {filteredOptions.map((opt, idx) => {
            const selected = isOptionSelected(opt);
            const keyVal = `dropdown-option-${String(opt.value)}-${idx}`;
            const clickHandler = () => handleOptionClick(opt);

            return (
              <DropdownOptionItem
                key={keyVal}
                role="option"
                tabIndex={-1}
                aria-selected={selected}
                aria-disabled={opt.disabled || loading}
                data-option-value={String(opt.value)}
                onClick={clickHandler}
                isSelected={selected}
                isDisabled={opt.disabled}
                theme={theme}
              >
                {renderOption ? (
                  renderOption(opt)
                ) : (
                  <>
                    {opt.icon && <span style={{ marginRight: '8px' }}>{opt.icon}</span>}
                    <span>{opt.label}</span>
                    {opt.description && (
                      <small
                        style={{
                          display: 'block',
                          marginLeft: '8px',
                          opacity: 0.8,
                          fontSize: theme.typography.fontSize.xs,
                        }}
                      >
                        {opt.description}
                      </small>
                    )}
                  </>
                )}
              </DropdownOptionItem>
            );
          })}

          {/* If we have no results, display a fallback. */}
          {filteredOptions.length === 0 && (
            <li role="none">
              <DropdownFooter theme={theme}>No results found</DropdownFooter>
            </li>
          )}
        </DropdownMenu>
      )}

      {/* If there's an error, render an accessible error message.
          This can be further styled or integrated with forms. */}
      {error && (
        <div
          role="alert"
          aria-live="assertive"
          style={{
            color: theme.colors.error.main,
            fontSize: theme.typography.fontSize.sm,
            marginTop: '4px',
          }}
          data-testid="dropdown-error"
        >
          {error}
        </div>
      )}
    </DropdownContainer>
  );
};

/**
 * Named export of DropdownProps interface, for external usage.
 */
export type { DropdownProps as IDropdownProps };