import React, {
  FC,
  useState,
  useCallback,
  KeyboardEvent as ReactKeyboardEvent,
  MouseEvent as ReactMouseEvent,
  useEffect
} from 'react'; // react@^18.0.0 - Core React library
import classNames from 'classnames'; // classnames@^2.3.2 - Conditionally join CSS class strings
import { Modal } from './Modal'; // Internal Modal component with isOpen, onClose
import { Button } from './Button'; // Internal Button component
import type { ButtonProps } from './Button'; // Named import of ButtonProps interface

/**
 * Global constants for Dialog usage, defined per specification.
 * These values may be considered "global" or "shared" across
 * the component library for consistent behavior.
 */
export const DIALOG_TYPES = {
  ALERT: 'alert',
  CONFIRM: 'confirm',
  CUSTOM: 'custom'
} as const;

export const DIALOG_VARIANTS = {
  SUCCESS: 'success',
  ERROR: 'error',
  WARNING: 'warning',
  INFO: 'info'
} as const;

/**
 * The default animation duration (in ms) for opening
 * and closing the dialog. Used for smooth transitions.
 */
export const ANIMATION_DURATION = 300;

/**
 * The default z-index for the dialog overlay. Ensures
 * it appears above most other elements in the application.
 */
export const Z_INDEX_DIALOG = 1000;

/**
 * DialogProps defines all configurable properties for the Dialog component.
 * It encompasses the essential elements required to render and manage
 * the dialog, including titles, messages, user actions, accessibility attributes,
 * and loading/error states for robust, production-grade usage.
 */
export interface DialogProps {
  /**
   * Controls whether the dialog is currently visible.
   * Typically managed by the parent component.
   */
  isOpen: boolean;

  /**
   * Callback invoked when the dialog requests to be closed.
   * Commonly triggers a state update in the parent to hide this dialog.
   */
  onClose: () => void;

  /**
   * A textual title displayed at the top of the dialog, providing
   * context or summary of the content within.
   */
  title?: string;

  /**
   * A brief body message or description. For more complex content or custom
   * layouts, the 'children' prop can be used instead or in addition.
   */
  message?: string;

  /**
   * The type of dialog, dictating specialized behavior
   * such as an alert (single button) or confirm (two buttons).
   */
  type?: keyof typeof DIALOG_TYPES;

  /**
   * Visual variant of the dialog, mapping to a color or style scheme.
   * For instance, 'error' might display red accents, while 'info'
   * might display blue highlights.
   */
  variant?: keyof typeof DIALOG_VARIANTS;

  /**
   * The visible label of the confirmation button.
   * Often defaults to "OK", "Yes", or "Confirm" in typical usage.
   */
  confirmText?: string;

  /**
   * The visible label of the cancellation button.
   * Often defaults to "Cancel", "No", or "Dismiss" in typical usage.
   */
  cancelText?: string;

  /**
   * Callback invoked when the user confirms the dialog action.
   * Typically includes business logic to finalize or commit an operation.
   */
  onConfirm?: () => Promise<void>;

  /**
   * Callback invoked when the user cancels or dismisses the dialog
   * without confirming. Typically includes logic to revert or ignore changes.
   */
  onCancel?: () => void;

  /**
   * Optional React children for fully custom content or additional elements,
   * especially useful when type is set to 'custom'.
   */
  children?: React.ReactNode;

  /**
   * An optional string of custom class names for style overrides,
   * special positioning, or theme-based modifications.
   */
  className?: string;

  /**
   * When true, indicates the dialog is in a loading state, preventing user
   * interactions and potentially showing a progress spinner.
   */
  isLoading?: boolean;

  /**
   * An optional error message to display if something goes wrong
   * in the process triggered by the dialog. May be shown in a distinct style
   * to alert the user.
   */
  error?: string;

  /**
   * Sets the aria-label attribute on the dialog container for accessibility
   * when a visible label is not present.
   */
  ariaLabel?: string;

  /**
   * Sets the aria-describedby attribute on the dialog container for
   * accessibility, referencing an element that describes the purpose or
   * content of this dialog.
   */
  ariaDescribedBy?: string;
}

/**
 * Dialog is a reusable, production-ready component providing a
 * styled overlay for alerts, confirmations, and custom interactions.
 * It leverages the internal Modal component for the foundation, adding
 * standardized buttons, loading/error states, animations, variant styling,
 * and improved focus management per enterprise requirements.
 */
export const Dialog: FC<DialogProps> = ({
  isOpen,
  onClose,
  title,
  message,
  type = DIALOG_TYPES.ALERT,
  variant = DIALOG_VARIANTS.INFO,
  confirmText = 'OK',
  cancelText = 'Cancel',
  onConfirm,
  onCancel,
  children,
  className,
  isLoading = false,
  error,
  ariaLabel,
  ariaDescribedBy
}) => {
  /**
   * Internal loading state used to manage
   * the asynchronous flow of the confirm action.
   */
  const [internalLoading, setInternalLoading] = useState(false);

  /**
   * Internal error state, which may be set during
   * confirmation handling if an exception occurs.
   */
  const [internalError, setInternalError] = useState<string | null>(null);

  /**
   * A derived value indicating whether the dialog
   * is in a loading state. This can account for both
   * externally supplied isLoading and the local one.
   */
  const showLoading = isLoading || internalLoading;

  /**
   * A derived value consolidating any external error message
   * plus any internally tracked error, if relevant.
   */
  const combinedError = error || internalError;

  /**
   * handleConfirm is triggered when the user clicks the confirm button
   * or presses Enter if such keyboard handling is desired. This function
   * may set a local loading indicator, invoke onConfirm, handle exceptions,
   * and ultimately close and reset the dialog.
   *
   * Steps (per specification):
   * 1) Prevent default form submission if event is from a button within a form.
   * 2) Set loading state to true.
   * 3) Call onConfirm callback if provided.
   * 4) Handle any errors during confirmation.
   * 5) Set loading state to false.
   * 6) Close dialog.
   * 7) Reset dialog state (e.g., clear errors).
   */
  const handleConfirm = useCallback(
    async (event: ReactMouseEvent<HTMLButtonElement>) => {
      event.preventDefault();
      setInternalLoading(true);
      setInternalError(null);

      if (onConfirm) {
        try {
          await onConfirm();
        } catch (err) {
          if (err instanceof Error) {
            setInternalError(err.message);
          } else {
            setInternalError('An unknown error occurred during confirmation.');
          }
        }
      }

      setInternalLoading(false);
      onClose();
      setInternalError(null);
    },
    [onConfirm, onClose]
  );

  /**
   * handleCancel is invoked when the user clicks the cancel button
   * or presses Escape if we choose to associate it with a key event.
   *
   * Steps (per specification):
   * 1) Prevent default form submission if relevant.
   * 2) Call onCancel callback if provided.
   * 3) Close dialog.
   * 4) Reset dialog state.
   */
  const handleCancel = useCallback(
    (event: ReactMouseEvent<HTMLButtonElement>) => {
      event.preventDefault();
      if (onCancel) {
        onCancel();
      }
      onClose();
      setInternalLoading(false);
      setInternalError(null);
    },
    [onCancel, onClose]
  );

  /**
   * handleKeyDown processes relevant keyboard interactions
   * within the dialog, such as:
   * - Escape key to close/cancel
   * - Enter key to confirm
   * - Potential focus trap navigation or preventing page scroll
   */
  const handleKeyDown = useCallback(
    (event: ReactKeyboardEvent<HTMLDivElement>) => {
      // Handle Escape key for closing
      if (event.key === 'Escape') {
        event.preventDefault();
        if (type === DIALOG_TYPES.CONFIRM || type === DIALOG_TYPES.ALERT) {
          handleCancel(event as unknown as ReactMouseEvent<HTMLButtonElement>);
        } else {
          onClose();
        }
      }

      // Handle Enter key for confirmation
      if (event.key === 'Enter' && (type === DIALOG_TYPES.CONFIRM || type === DIALOG_TYPES.ALERT)) {
        event.preventDefault();
        void handleConfirm(event as unknown as ReactMouseEvent<HTMLButtonElement>);
      }

      // Prevent default page scrolling if dialog is open
      // (For arrow keys or others, you could conditionally block them)
    },
    [handleConfirm, handleCancel, onClose, type]
  );

  /**
   * Reset internal states whenever the dialog closes externally,
   * ensuring that re-opening the dialog starts with a clean slate.
   */
  useEffect(() => {
    if (!isOpen) {
      setInternalLoading(false);
      setInternalError(null);
    }
  }, [isOpen]);

  /**
   * Compose the className for the dialog container,
   * merging variant-based and type-based styles with
   * user-provided className or error/loading indicators.
   */
  const dialogClasses = classNames(
    'dialog',
    `dialog--type-${type}`,
    `dialog--variant-${variant}`,
    {
      'dialog--loading': showLoading,
      'dialog--has-error': !!combinedError
    },
    className
  );

  /**
   * Layout for the body text or custom content. If 'message' is provided,
   * it can be displayed in a basic paragraph. If 'children' is passed,
   * it can be used for fully custom markup. Both can coexist.
   */
  const renderBodyContent = () => {
    return (
      <>
        {message && <p className="dialog__message" id="dialog-message">{message}</p>}
        {children && <div className="dialog__custom-content">{children}</div>}
      </>
    );
  };

  /**
   * Layout for the optional error message if one is present.
   * Typically displayed in a visually distinct manner (e.g., red text).
   */
  const renderErrorContent = () => {
    if (!combinedError) return null;
    return (
      <div className="dialog__error" role="alert">
        {combinedError}
      </div>
    );
  };

  /**
   * Layout for the dialog footer actions, typically including
   * Confirm and Cancel buttons. For an ALERT type, we might
   * only show one button.
   */
  const renderFooterActions = () => {
    if (type === DIALOG_TYPES.CUSTOM) {
      // In a custom dialog, we might allow the children to define their own actions
      return null;
    }

    if (type === DIALOG_TYPES.ALERT) {
      // Single button for alert
      return (
        <div className="dialog__footer">
          <Button
            variant="primary"
            size="medium"
            disabled={showLoading}
            loading={showLoading}
            onClick={handleConfirm}
          >
            {confirmText}
          </Button>
        </div>
      );
    }

    // For confirm type or fallback, show confirm + cancel
    return (
      <div className="dialog__footer">
        <Button
          variant="primary"
          size="medium"
          disabled={showLoading}
          loading={showLoading}
          onClick={handleConfirm}
        >
          {confirmText}
        </Button>
        <Button
          variant="secondary"
          size="medium"
          disabled={showLoading}
          loading={false}
          onClick={handleCancel}
        >
          {cancelText}
        </Button>
      </div>
    );
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      // We rely on the Dialog itself to handle key presses, so disable
      // built-in close triggers for overlay and escape to avoid duplicates.
      closeOnOverlay={false}
      closeOnEscape={false}
      // Combine user-defined class with a base 'dialog-wrapper' class
      className="dialog-wrapper"
    >
      <div
        className={dialogClasses}
        style={{ zIndex: Z_INDEX_DIALOG, transitionDuration: `${ANIMATION_DURATION}ms` }}
        aria-label={ariaLabel}
        aria-describedby={ariaDescribedBy}
        onKeyDown={handleKeyDown}
        tabIndex={0}
      >
        {title && (
          <h2 className="dialog__title" id="dialog-title">
            {title}
          </h2>
        )}

        {renderBodyContent()}
        {renderErrorContent()}
        {renderFooterActions()}
      </div>
    </Modal>
  );
};