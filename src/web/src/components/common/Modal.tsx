import React, {
  FC,
  ReactNode,
  useEffect,
  useRef,
  KeyboardEvent as ReactKeyboardEvent,
  MouseEvent as ReactMouseEvent
} from 'react';
// react@^18.0.0 - Core React functionality

import ReactDOM from 'react-dom'; // react-dom@^18.0.0 - For creating portals
import classNames from 'classnames'; // classnames@^2.3.2 - Manages conditional CSS class strings
import FocusTrap from 'focus-trap-react'; // focus-trap-react@^9.0.0 - Focus management for modals

// Internal hook for modal state management and control functions
// src/web/src/hooks/useModal.ts
// We use the isOpen and closeModal members from the hook's return object.
import { useModal } from '../../hooks/useModal';

//------------------------------------------------------------------------------
// Global constants referenced by the specification
//------------------------------------------------------------------------------
export const MODAL_SIZES = { sm: '400px', md: '600px', lg: '800px' };
export const ANIMATION_DURATION = 200;
export const PORTAL_ID = 'modal-root';
export const ANIMATION_CLASSES = {
  enter: 'modal-enter',
  enterActive: 'modal-enter-active',
  exit: 'modal-exit',
  exitActive: 'modal-exit-active'
};

//------------------------------------------------------------------------------
// Interface: ModalProps
// Defines all prop requirements, including optional sizing and behavior flags,
// per the provided JSON specification and design guidelines.
//------------------------------------------------------------------------------
interface ModalProps {
  /** The content to be displayed within the modal */
  children: ReactNode;

  /** Controls whether the modal is currently visible */
  isOpen: boolean;

  /**
   * Called when the modal should close
   * (overlay click, Escape key, or any close logic)
   */
  onClose: () => void;

  /**
   * Predefined size for the modal, mapped from MODAL_SIZES
   * or a custom string to allow flexible widths in px, %, etc.
   */
  size?: string;

  /** Additional CSS classes for styling or theming the modal */
  className?: string;

  /** If true, clicking the overlay (background) closes the modal */
  closeOnOverlay?: boolean;

  /** If true, pressing the Escape key closes the modal */
  closeOnEscape?: boolean;
}

//------------------------------------------------------------------------------
// createPortalContainer
// Creates or retrieves a DOM element for mounting the React portal. If it does
// not exist yet, a new container is created, configured, and appended to body.
//------------------------------------------------------------------------------
function createPortalContainer(): HTMLElement {
  let portalContainer = document.getElementById(PORTAL_ID);
  if (!portalContainer) {
    portalContainer = document.createElement('div');
    portalContainer.setAttribute('id', PORTAL_ID);
    portalContainer.setAttribute('aria-live', 'polite');
    document.body.appendChild(portalContainer);
  }
  return portalContainer;
}

//------------------------------------------------------------------------------
// handleEscapeKey
// Event handler for closing the modal when the Escape key is pressed. It follows
// the steps defined in the technical specification for cleaning up and
// restoring focus (handled elsewhere via effect). This function can be used
// within a keydown event listener as part of close-on-escape logic.
//------------------------------------------------------------------------------
function handleEscapeKey(
  event: KeyboardEvent,
  closeCallback: () => void
): void {
  // 1. Check if pressed key is Escape
  if (event.key === 'Escape') {
    // 2. If Escape key pressed, call onClose callback
    closeCallback();
    // Steps 3 and 4 (removing listeners and focus restoration) are handled
    // within React hooks to ensure consistent cleanup.
  }
}

//------------------------------------------------------------------------------
// handleOverlayClick
// Event handler for closing the modal when the user clicks outside of the modal
// content, targeting the overlay. Prevents bubbling if overlay click is detected.
//------------------------------------------------------------------------------
function handleOverlayClick(
  event: ReactMouseEvent<HTMLDivElement>,
  closeCallback: () => void
): void {
  // 1. Check if the current target is the same as the event target (overlay)
  if (event.currentTarget === event.target) {
    // 2. Overlay is clicked, call onClose callback
    closeCallback();
    // 3. Prevent further event bubbling
    event.stopPropagation();
  }
}

//------------------------------------------------------------------------------
// Modal: Enhanced modal component with accessibility and animation features.
// Implements the design system specifications with focus management,
// overlay click support, and optional Escape key handling.
//------------------------------------------------------------------------------
export const Modal: FC<ModalProps> = ({
  children,
  isOpen: externalIsOpen,
  onClose,
  size = 'md',
  className,
  closeOnOverlay = true,
  closeOnEscape = true
}) => {
  /**
   * Even though we receive isOpen as an external prop, demonstrate usage
   * of the internal modal hook per the JSON specification. The hook is
   * used here, and we reconcile external state with the hook's state
   * for demonstration. The 'initialState' can match our externalIsOpen.
   */
  const {
    isOpen: hookIsOpen,
    closeModal: hookCloseModal,
    modalRef
  } = useModal(externalIsOpen, {
    onClose: onClose,
    closeOnEscape: closeOnEscape
  });

  // Combine the external isOpen prop with the hook's isOpen to decide
  // final visibility. In typical usage, you might rely solely on one source.
  const finalIsOpen = externalIsOpen && hookIsOpen;

  /**
   * A ref to hold the previously focused element before opening this modal.
   * Will be used upon cleanup to restore focus, ensuring accessibility best practices.
   */
  const previousFocusRef = useRef<HTMLElement | null>(null);

  // Retrieve or create our portal container for this modal instance.
  const portalContainer = useRef<HTMLElement>(createPortalContainer());

  //--------------------------------------------------------------------------
  // Effect: Keyboard Escape
  // If closeOnEscape is true, add a keydown listener to close the modal.
  // Uses the handleEscapeKey function from the specification for logic.
  //--------------------------------------------------------------------------
  useEffect(() => {
    if (!finalIsOpen || !closeOnEscape) {
      return;
    }
    const keydownHandler = (event: KeyboardEvent) => {
      handleEscapeKey(event, () => {
        hookCloseModal();
      });
    };

    window.addEventListener('keydown', keydownHandler);

    // Cleanup event listener on unmount or when finalIsOpen changes
    return () => {
      window.removeEventListener('keydown', keydownHandler);
    };
  }, [finalIsOpen, closeOnEscape, hookCloseModal]);

  //--------------------------------------------------------------------------
  // Effect: Manage focus. When opening, store the currently focused element
  // in previousFocusRef. When closing, restore focus to that element.
  //--------------------------------------------------------------------------
  useEffect(() => {
    if (finalIsOpen) {
      previousFocusRef.current = document.activeElement as HTMLElement;
      // Optionally set focus to the modal container if needed
      modalRef.current?.focus();
    } else if (!finalIsOpen && previousFocusRef.current) {
      // Restore focus to the previously focused element
      previousFocusRef.current.focus();
    }
  }, [finalIsOpen, modalRef]);

  //--------------------------------------------------------------------------
  // Do not render the modal at all if finalIsOpen is false. That handles
  // the simplest approach to removing it from the DOM when closed.
  //--------------------------------------------------------------------------
  if (!finalIsOpen) {
    return null;
  }

  //--------------------------------------------------------------------------
  // Combine classes for overlay and modal content using classNames
  // with optional animation classes, dimension styles, etc.
  //--------------------------------------------------------------------------
  const overlayClasses = classNames(
    'modal-overlay',
    ANIMATION_CLASSES.enter,
    ANIMATION_CLASSES.enterActive
  );

  const containerClasses = classNames(
    'modal-container',
    className,
    ANIMATION_CLASSES.enter,
    ANIMATION_CLASSES.enterActive
  );

  const modalStyle = {
    width: MODAL_SIZES[size as keyof typeof MODAL_SIZES] || size,
    transitionDuration: `${ANIMATION_DURATION}ms`
  };

  //--------------------------------------------------------------------------
  // Render the modal via React portal for proper overlay layering.
  // Leverage FocusTrap for accessibility within the modal.
  //--------------------------------------------------------------------------
  return ReactDOM.createPortal(
    (
      <div
        className={overlayClasses}
        role="dialog"
        aria-modal="true"
        onClick={(e) => {
          if (closeOnOverlay) {
            handleOverlayClick(e, hookCloseModal);
          }
        }}
      >
        <FocusTrap active={true}>
          <div
            ref={modalRef}
            className={containerClasses}
            style={modalStyle}
            // ARIA attributes for improved screen reader support
            aria-labelledby="modal-title"
            aria-describedby="modal-description"
            tabIndex={-1}
          >
            {children}
          </div>
        </FocusTrap>
      </div>
    ),
    portalContainer.current
  );
};