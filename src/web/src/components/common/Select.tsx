/**
 * Select.tsx
 *
 * A highly accessible and theme-aware select component that provides customizable
 * dropdown functionality with comprehensive keyboard navigation, search filtering,
 * and ARIA support. Implements the design system's dropdown specifications for both
 * light and dark themes.
 */

// react@^18.0.0
import React, {
  FC,
  useState,
  useRef,
  useCallback,
  useEffect,
  KeyboardEvent,
  FocusEvent,
  CompositionEvent,
  ChangeEvent
} from 'react';

// classnames@^2.3.2
import classNames from 'classnames';

// Internal theme enumeration for consistent styling across light and dark modes
import { Theme, DARK, LIGHT } from '../../types/common.types';
// Hook for accessing theme context and dark mode state
import { useTheme } from '../../hooks/useTheme';

/**
 * SelectOption:
 * Represents each selectable option within the dropdown.
 * - value: String or number identifying the option
 * - label: Display text of the option
 * - disabled: Whether the option is unselectable
 * - description: Supplementary text describing the option
 * - icon: (Optional) React node to render alongside text, such as an icon
 */
export interface SelectOption {
  value: string | number;
  label: string;
  disabled?: boolean;
  description?: string;
  icon?: React.ReactNode;
}

/**
 * SelectProps:
 * Defines the full set of properties accepted by the Select component.
 * - options: Array of SelectOption items to display
 * - value: Current selection (single or multiple) represented by value(s)
 * - onChange: Callback invoked when the selection changes
 * - placeholder: Placeholder text when no value is selected
 * - disabled: Disables the entire component if true
 * - multiple: Allows multiple item selection if true
 * - searchable: Enables search input if true
 * - error: Error message to show below the component
 * - className: Custom class names for container
 * - required: Marks the input as required for ARIA and form validations
 * - maxHeight: Optional numeric value to govern dropdown container max height
 * - loading: Displays loading spinner or loading state if true
 * - clearable: Displays clear button if true
 * - renderOption: Custom render function for each option
 */
export interface SelectProps {
  options: SelectOption[];
  value: string | string[] | number | number[];
  onChange: (value: string | string[] | number | number[]) => void;
  placeholder?: string;
  disabled?: boolean;
  multiple?: boolean;
  searchable?: boolean;
  error?: string;
  className?: string;
  required?: boolean;
  maxHeight?: number;
  loading?: boolean;
  clearable?: boolean;
  renderOption?: (option: SelectOption) => React.ReactNode;
}

/**
 * Select:
 * Accessible and theme-aware select component for form inputs.
 * Incorporates keyboard navigation, search filtering with debouncing,
 * ARIA attributes for screen readers, multiple selection handling,
 * and dynamic styling based on theme context.
 */
export const Select: FC<SelectProps> = ({
  options,
  value,
  onChange,
  placeholder,
  disabled = false,
  multiple = false,
  searchable = false,
  error,
  className,
  required = false,
  maxHeight,
  loading = false,
  clearable = false,
  renderOption
}) => {
  /**
   * useTheme hook:
   * Provides the 'theme' object and 'isDarkMode' boolean to adapt the component
   * styling accordingly (e.g., color palettes, backgrounds, text).
   */
  const { theme, isDarkMode } = useTheme();

  /**
   * Component State:
   * - isOpen: Controls whether the dropdown is expanded
   * - searchTerm: Current search filter text
   * - filteredOptions: Options filtered by searchTerm
   * - highlightedIndex: Tracks which option is currently highlighted (for keyboard nav)
   * - isFocused: Tracks if the component is focused
   * - isComposing: Tracks active IME composition (to avoid interfering with text input)
   * - prevSearchTerm: Maintains previous search term before debouncing
   */
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [filteredOptions, setFilteredOptions] = useState<SelectOption[]>(options);
  const [highlightedIndex, setHighlightedIndex] = useState<number>(-1);
  const [isFocused, setIsFocused] = useState<boolean>(false);
  const [isComposing, setIsComposing] = useState<boolean>(false);
  const [prevSearchTerm, setPrevSearchTerm] = useState<string | null>(null);

  /**
   * Refs:
   * - containerRef: Links to the main component wrapper for event handling
   * - searchInputRef: Links to the search input if 'searchable' is enabled
   * - debounceTimer: Tracks the debounce timeout ID for handleSearch
   */
  const containerRef = useRef<HTMLDivElement | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);
  const debounceTimer = useRef<NodeJS.Timeout | null>(null);

  /**
   * Utility: Casts the current value to an array to simplify multiple/single logic.
   */
  const valueArray = Array.isArray(value) ? value : [value];

  /**
   * openDropdown:
   * Opens the dropdown, focuses search input if available, resets highlight to first item.
   */
  const openDropdown = useCallback(() => {
    if (!disabled) {
      setIsOpen(true);
      setHighlightedIndex(-1);
      if (searchable && searchInputRef.current) {
        searchInputRef.current.focus();
      }
    }
  }, [disabled, searchable]);

  /**
   * closeDropdown:
   * Closes the dropdown and resets searching behavior.
   */
  const closeDropdown = useCallback(() => {
    setIsOpen(false);
    setHighlightedIndex(-1);
  }, []);

  /**
   * handleSelect: Processes an option click or keyboard selection event.
   * - If multiple is true, toggles the selected item in the array.
   * - Otherwise, sets the selected item as the current value.
   * Calls onChange with the updated value(s).
   */
  const handleSelect = useCallback(
    (option: SelectOption) => {
      if (option.disabled) return;

      if (multiple) {
        const optionValue = option.value;
        const newValues = valueArray.includes(optionValue)
          ? valueArray.filter((v) => v !== optionValue)
          : [...valueArray, optionValue];
        onChange(newValues);
      } else {
        onChange(option.value);
        closeDropdown();
      }
    },
    [multiple, valueArray, onChange, closeDropdown]
  );

  /**
   * handleKeyDown:
   * Manages keyboard navigation and selection within the dropdown.
   * Decorators: useCallback
   * Steps:
   * 1. Prevent default behavior for navigation keys where appropriate
   * 2. Handle ArrowUp/ArrowDown for option navigation
   * 3. Handle Home/End for first/last option navigation
   * 4. Process Enter/Space for option selection
   * 5. Handle Escape for dropdown closure
   * 6. Manage Tab for focus management
   * 7. Support type-ahead functionality
   */
  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      // If composition is ongoing, skip keyboard interactions
      if (isComposing) return;

      const { key } = event;

      // Type-ahead support: skip if we're focusing on search input
      // or if 'searchable' is true and user is typing normal characters
      // We'll rely on handleSearch for text-based matching.
      if (!searchable && /^[a-zA-Z0-9]$/.test(key)) {
        event.preventDefault();
        // Quick naive approach: attempt to locate the first match
        const typedChar = key.toLowerCase();
        let foundIndex = filteredOptions.findIndex((opt) =>
          opt.label.toLowerCase().startsWith(typedChar)
        );
        if (foundIndex === -1) foundIndex = filteredOptions.findIndex((opt) =>
          opt.label.toLowerCase().includes(typedChar)
        );
        if (foundIndex !== -1) {
          setHighlightedIndex(foundIndex);
        }
        return;
      }

      switch (key) {
        case 'ArrowDown':
          event.preventDefault();
          if (!isOpen) {
            openDropdown();
          } else {
            setHighlightedIndex((prev) => {
              const nextIndex = prev + 1;
              return nextIndex >= filteredOptions.length ? 0 : nextIndex;
            });
          }
          break;

        case 'ArrowUp':
          event.preventDefault();
          if (!isOpen) {
            openDropdown();
          } else {
            setHighlightedIndex((prev) => {
              const nextIndex = prev - 1;
              return nextIndex < 0 ? filteredOptions.length - 1 : nextIndex;
            });
          }
          break;

        case 'Home':
          event.preventDefault();
          if (isOpen) {
            setHighlightedIndex(0);
          }
          break;

        case 'End':
          event.preventDefault();
          if (isOpen) {
            setHighlightedIndex(filteredOptions.length - 1);
          }
          break;

        case 'Enter':
        case ' ':
          if (isOpen && highlightedIndex >= 0 && highlightedIndex < filteredOptions.length) {
            event.preventDefault();
            handleSelect(filteredOptions[highlightedIndex]);
          } else if (!isOpen) {
            event.preventDefault();
            openDropdown();
          }
          break;

        case 'Escape':
          if (isOpen) {
            event.preventDefault();
            closeDropdown();
          }
          break;

        case 'Tab':
          // Allow normal tabbing out but ensure dropdown closes
          closeDropdown();
          break;

        default:
          break;
      }
    },
    [
      isOpen,
      isComposing,
      searchable,
      openDropdown,
      closeDropdown,
      filteredOptions,
      highlightedIndex,
      handleSelect
    ]
  );

  /**
   * handleSearch:
   * Filters options based on search input with a 300ms debouncing.
   * Decorators: useCallback, "debounce(300)"
   * Steps:
   * 1. Normalize search term
   * 2. Apply fuzzy search algorithm
   * 3. Filter options based on label and description
   * 4. Update filtered options state
   * 5. Reset highlighted index
   * 6. Handle empty results state
   */
  const handleSearch = useCallback(
    (searchTermVal: string) => {
      // Clear any existing debounce timers
      if (debounceTimer.current) {
        clearTimeout(debounceTimer.current);
      }
      // Assign new debounce
      debounceTimer.current = setTimeout(() => {
        const normalized = searchTermVal.trim().toLowerCase();
        const newFiltered = options.filter((opt) => {
          const labelMatch = opt.label.toLowerCase().includes(normalized);
          const descrMatch = opt.description
            ? opt.description.toLowerCase().includes(normalized)
            : false;
          return labelMatch || descrMatch;
        });
        setFilteredOptions(newFiltered);
        setHighlightedIndex(-1);
        setPrevSearchTerm(normalized);
      }, 300);
    },
    [options]
  );

  /**
   * handleSearchChange:
   * Tracks input changes for the search term, calls handleSearch.
   */
  const handleSearchChange = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      const newValue = e.target.value;
      setSearchTerm(newValue);
      handleSearch(newValue);
    },
    [handleSearch]
  );

  /**
   * handleCompositionStart and handleCompositionEnd:
   * Manage isComposing state to avoid interfering with IME text entry.
   */
  const handleCompositionStart = useCallback((_: CompositionEvent<HTMLInputElement>) => {
    setIsComposing(true);
  }, []);

  const handleCompositionEnd = useCallback((_: CompositionEvent<HTMLInputElement>) => {
    setIsComposing(false);
  }, []);

  /**
   * handleClear:
   * Clears the current selection if clearable = true.
   * Resets the internal states & triggers onChange with empty selection.
   */
  const handleClear = useCallback(() => {
    if (!clearable || disabled) return;
    if (multiple) {
      onChange([]);
    } else {
      onChange('');
    }
    setSearchTerm('');
    setFilteredOptions(options);
  }, [clearable, disabled, multiple, onChange, options]);

  /**
   * handleFocus and handleBlur:
   * Track whether we have focus within the component to manage styling and ARIA states.
   */
  const handleFocus = useCallback((_: FocusEvent<HTMLDivElement>) => {
    setIsFocused(true);
  }, []);

  const handleBlur = useCallback(
    (e: FocusEvent<HTMLDivElement>) => {
      // If focus leaves the container, close dropdown
      if (
        containerRef.current &&
        !containerRef.current.contains(e.relatedTarget as Node)
      ) {
        setIsFocused(false);
        closeDropdown();
      }
    },
    [closeDropdown]
  );

  /**
   * useEffect to sync external 'options' or 'value' changes:
   * - Resets filtered options if the user toggled or changed them externally
   * - Attempt to preserve the searchTerm if it matches the previous pattern
   */
  useEffect(() => {
    if (prevSearchTerm && prevSearchTerm.length > 0) {
      const newFiltered = options.filter((opt) => {
        const labelMatch = opt.label.toLowerCase().includes(prevSearchTerm);
        const descrMatch = opt.description
          ? opt.description.toLowerCase().includes(prevSearchTerm)
          : false;
        return labelMatch || descrMatch;
      });
      setFilteredOptions(newFiltered);
      // Maintain existing highlight index if still in range
      setHighlightedIndex((prev) => (prev < newFiltered.length ? prev : -1));
    } else {
      setFilteredOptions(options);
    }
  }, [options, prevSearchTerm]);

  /**
   * renderDropdownOption:
   * Renders each option in the dropdown list, applying highlight and disabled states.
   * If a custom renderOption function is provided, it delegates the rendering logic.
   */
  const renderDropdownOption = (option: SelectOption, index: number) => {
    const isSelected = valueArray.includes(option.value);
    const isHighlighted = index === highlightedIndex;
    const isOptionDisabled = !!option.disabled;

    const optionClass = classNames('select-option', {
      'option-highlighted': isHighlighted,
      'option-selected': isSelected,
      'option-disabled': isOptionDisabled
    });

    const defaultRender = (
      <div className="option-content">
        {option.icon && <span className="option-icon">{option.icon}</span>}
        <span className="option-label">{option.label}</span>
        {option.description && (
          <span className="option-description"> {option.description}</span>
        )}
      </div>
    );

    return (
      <div
        key={`${option.value}-${index}`}
        role="option"
        aria-selected={isSelected}
        aria-disabled={isOptionDisabled}
        tabIndex={-1}
        className={optionClass}
        onMouseDown={(e) => {
          // Prevent losing focus
          e.preventDefault();
        }}
        onClick={() => {
          if (!isOptionDisabled) handleSelect(option);
        }}
      >
        {renderOption ? renderOption(option) : defaultRender}
      </div>
    );
  };

  /**
   * Computed class list for the container to apply theme variants,
   * error states, disabled states, and user-provided classes.
   */
  const containerClass = classNames(
    'select-container',
    className,
    {
      'select-focused': isFocused,
      'select-open': isOpen,
      'select-disabled': disabled,
      'select-error': !!error,
      'select-dark-mode': isDarkMode,
      'select-light-mode': !isDarkMode
    }
  );

  /**
   * Computed placeholder text if no selection is made (or empty when multiple).
   */
  const displayValue = multiple
    ? (valueArray.length > 0 ? '' : placeholder || '')
    : (typeof value === 'string' || typeof value === 'number') && value !== ''
    ? ''
    : placeholder || '';

  /**
   * Renders the selected label(s) for a single or multiple selection scenario.
   */
  const renderSelectedLabels = () => {
    if (multiple) {
      const selectedOptions = options.filter((opt) => valueArray.includes(opt.value));
      if (selectedOptions.length === 0 && placeholder) {
        return <span className="select-placeholder">{placeholder}</span>;
      }
      return selectedOptions.map((opt) => (
        <span key={opt.value} className="select-multi-item">
          {opt.label}
        </span>
      ));
    } else {
      const selectedOption = options.find((opt) => opt.value === value);
      if (!selectedOption && placeholder) {
        return <span className="select-placeholder">{placeholder}</span>;
      }
      return selectedOption ? <span>{selectedOption.label}</span> : null;
    }
  };

  /**
   * Inline style for dropdown panel max height if provided via props.
   */
  const dropdownStyle = maxHeight
    ? { maxHeight: `${maxHeight}px`, overflowY: 'auto' }
    : {};

  return (
    <div
      className={containerClass}
      ref={containerRef}
      onKeyDown={handleKeyDown}
      onFocus={handleFocus}
      onBlur={handleBlur}
      role="combobox"
      aria-expanded={isOpen}
      aria-required={required}
      aria-invalid={!!error}
      aria-disabled={disabled}
      aria-haspopup="listbox"
      tabIndex={disabled ? -1 : 0}
      style={{
        // Example usage of theme colors for background or border
        border: error
          ? `1px solid ${theme.colors.error.main}`
          : `1px solid ${isDarkMode ? '#444444' : '#dddddd'}`
      }}
    >
      {/* Main selection display (placeholder or selected labels) */}
      <div
        className="select-value"
        onClick={() => {
          if (!isOpen) openDropdown();
          else closeDropdown();
        }}
      >
        {displayValue ? (
          <span className="select-placeholder">{displayValue}</span>
        ) : (
          <>{renderSelectedLabels()}</>
        )}
      </div>

      {/* Clear button (only if clearable, not disabled, not loading) */}
      {clearable && !disabled && !loading && (
        <button
          type="button"
          className="select-clear-button"
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => handleClear()}
          aria-label="Clear selection"
        >
          ×
        </button>
      )}

      {/* Loading indicator */}
      {loading && (
        <div className="select-loading-spinner" aria-hidden="true">
          {/* Could insert an SVG spinner or animation based on design system */}
          <span className="spinner-dot">•</span>
          <span className="spinner-dot">•</span>
          <span className="spinner-dot">•</span>
        </div>
      )}

      {/* Dropdown Panel */}
      {isOpen && (
        <div
          className="select-dropdown"
          role="listbox"
          aria-activedescendant={
            highlightedIndex >= 0 && highlightedIndex < filteredOptions.length
              ? `option-${filteredOptions[highlightedIndex]?.value}`
              : undefined
          }
          style={dropdownStyle}
        >
          {/* Search input if searchable */}
          {searchable && (
            <div className="select-search-wrapper">
              <input
                ref={searchInputRef}
                className="select-search-input"
                type="text"
                value={searchTerm}
                onChange={handleSearchChange}
                onCompositionStart={handleCompositionStart}
                onCompositionEnd={handleCompositionEnd}
                placeholder="Search..."
                aria-label="Search options"
              />
            </div>
          )}

          {/* Render filtered options */}
          {filteredOptions.length === 0 ? (
            <div className="select-no-results" aria-live="polite">
              No results found
            </div>
          ) : (
            filteredOptions.map((opt, idx) => renderDropdownOption(opt, idx))
          )}
        </div>
      )}

      {/* Error message display */}
      {error && <div className="select-error-text">{error}</div>}
    </div>
  );
};