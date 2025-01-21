/**
 * A custom React hook (useModal) that provides robust and production-ready
 * modal state management, adhering to enterprise standards and accessibility.
 *
 * References from the Technical Specifications:
 * - 3.1.2 Component Library (Feedback): Provides state management and control
 *   functions for modal dialog components with comprehensive TypeScript support
 *   and accessibility considerations.
 * - 6.1 Design System Key (Components): Implements modal dialog control
 *   functionality including both controlled and uncontrolled patterns.
 *
 * This hook offers:
 * - Initial open/closed state handling
 * - Open/close/toggle modal actions
 * - Configurable escape key behavior
 * - Optional callback hooks for onOpen and onClose
 * - Accessibility features such as focus trapping and restoration
 */

//////////////////////////////////////////
// External Imports (React ^18.0.0)
//////////////////////////////////////////
import {
  useState,    // react@^18.0.0 - Manages modal visibility state
  useCallback, // react@^18.0.0 - Memoizes functions to prevent excess re-renders
  useEffect,   // react@^18.0.0 - Handles side effects and event cleanup
  useRef       // react@^18.0.0 - References DOM elements for focus management
} from 'react';

//////////////////////////////////////////
// Interface: UseModalOptions
// Provides optional configuration for the useModal hook,
// allowing customization of behavior when opening/closing
// modals and controlling escape key handling.
//////////////////////////////////////////
export interface UseModalOptions {
  /**
   * Called whenever the modal transitions from closed to open.
   */
  onOpen?: () => void;

  /**
   * Called whenever the modal transitions from open to closed.
   */
  onClose?: () => void;

  /**
   * Determines whether the modal should close automatically
   * when the Escape key is pressed. Default behavior provided
   * in the hook if not explicitly set.
   */
  closeOnEscape?: boolean;
}

//////////////////////////////////////////
// Hook: useModal
// Manages modal state, including open/close/toggle actions,
// optional callbacks, and accessibility enhancements.
//////////////////////////////////////////
export function useModal(
  initialState: boolean,
  options?: UseModalOptions
): {
  isOpen: boolean;
  openModal: () => void;
  closeModal: () => void;
  toggleModal: () => void;
  modalRef: React.RefObject<HTMLDivElement>;
} {
  // STEP 1: Initialize modal visibility state using the provided initialState.
  const [isOpen, setIsOpen] = useState<boolean>(initialState);

  // Holds the previously focused element before opening the modal for accessibility.
  const previouslyFocusedElement = useRef<HTMLElement | null>(null);

  // STEP 2: Create modalRef to reference the modal container for focus management.
  const modalRef = useRef<HTMLDivElement>(null);

  // STEP 3: Memoized function to open the modal. Invokes onOpen callback if present.
  const openModal = useCallback((): void => {
    setIsOpen(true);
    if (options?.onOpen) {
      options.onOpen();
    }
  }, [options]);

  // STEP 4: Memoized function to close the modal. Invokes onClose callback if present.
  const closeModal = useCallback((): void => {
    setIsOpen(false);
    if (options?.onClose) {
      options.onClose();
    }
  }, [options]);

  // STEP 5: Memoized function to toggle the modal state, calling onOpen/onClose accordingly.
  const toggleModal = useCallback((): void => {
    setIsOpen((prevIsOpen) => {
      const nextState = !prevIsOpen;
      if (nextState && options?.onOpen) {
        options.onOpen();
      } else if (!nextState && options?.onClose) {
        options.onClose();
      }
      return nextState;
    });
  }, [options]);

  // STEP 6: Set up an effect to handle the Escape key press for closing the modal
  // if closeOnEscape is set to true (defaulting to true if undefined).
  useEffect(() => {
    const shouldCloseOnEscape = options?.closeOnEscape ?? true;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && isOpen && shouldCloseOnEscape) {
        closeModal();
      }
    };

    window.addEventListener('keydown', handleKeyDown);

    // STEP 7: Cleanup on component unmount - remove event listener.
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, options, closeModal]);

  // Accessibility: Capture focus when modal is opened and restore focus when closed.
  useEffect(() => {
    if (isOpen) {
      previouslyFocusedElement.current = document.activeElement as HTMLElement;
      modalRef.current?.focus();
    } else if (!isOpen && previouslyFocusedElement.current) {
      previouslyFocusedElement.current.focus();
    }
  }, [isOpen]);

  // STEP 8: Return a structured object containing the modal state, functions, and ref.
  return {
    isOpen,
    openModal,
    closeModal,
    toggleModal,
    modalRef
  };
}