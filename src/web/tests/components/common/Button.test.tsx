import React from 'react'; // react@^18.0.0
import { render, screen, fireEvent, waitFor } from '@testing-library/react'; // @testing-library/react@^13.4.0
import userEvent from '@testing-library/user-event'; // @testing-library/user-event@^14.4.3
import { Button, ButtonProps } from '../../src/components/common/Button'; // Internal import for Button component

/**
 * Mock click handler to verify that clicks are either captured
 * or prevented based on the current button state (e.g., disabled, loading).
 */
const onClick = jest.fn();

/**
 * Helper function to render the Button component while providing:
 * 1) A userEvent instance for simulating advanced user interactions
 * 2) The render result object from React Testing Library
 * 
 * This function consolidates the initial test setup, simplifying
 * repeated tasks across multiple test cases.
 * 
 * @param {Partial<ButtonProps>} props - Partial or full set of ButtonProperties
 * @returns {object} An object containing a userEvent instance plus the full
 *                   render result (queries, container, etc.)
 */
function renderButton(props: Partial<ButtonProps> = {}) {
  // Create a userEvent instance for simulating user actions (hover, keyboard, etc.)
  const user = userEvent.setup();

  // Render the Button component with desired props or defaults
  const result = render(
    <Button
      variant={props.variant ?? 'primary'}
      size={props.size ?? 'medium'}
      disabled={props.disabled ?? false}
      loading={props.loading ?? false}
      fullWidth={props.fullWidth ?? false}
      className={props.className}
      type={props.type || 'button'}
      onClick={props.onClick || onClick}
      aria-label={props['aria-label']}
      aria-describedby={props['aria-describedby']}
      data-testid={props['data-testid'] || 'button-test'}
    >
      {props.children ?? 'Sample Button'}
    </Button>
  );

  // Return an object merging the userEvent setup with the render result
  return { user, ...result };
}

describe('Button Component', () => {
  beforeEach(() => {
    // Reset mock before each test to ensure clean invocation counts
    onClick.mockClear();
  });

  test('renders with default props', () => {
    /**
     * Steps:
     * 1) Render button with default props
     * 2) Verify button is in the document
     * 3) Check default classes and styling
     */
    const { getByTestId } = renderButton();
    const buttonEl = getByTestId('button-test');

    // Ensure button is rendered in the DOM
    expect(buttonEl).toBeInTheDocument();

    // Check for default classes (assuming 'primary' & 'medium' as provided in setup)
    expect(buttonEl).toHaveClass('btn', 'btn--primary', 'btn--medium');
    // By default, it should not be disabled or loading
    expect(buttonEl).not.toBeDisabled();
  });

  test('renders different variants', () => {
    /**
     * Steps:
     * 1) Test primary variant with proper classes
     * 2) Test secondary variant with proper classes
     * 3) Test text variant with proper classes
     * 4) Verify variant-specific styling
     */
    // Primary
    const { rerender, getByTestId } = renderButton({ variant: 'primary' });
    let buttonEl = getByTestId('button-test');
    expect(buttonEl).toHaveClass('btn--primary');

    // Secondary
    rerender(
      <Button
        variant="secondary"
        size="medium"
        disabled={false}
        loading={false}
        fullWidth={false}
        onClick={onClick}
        data-testid="button-test"
      >
        Secondary Button
      </Button>
    );
    buttonEl = getByTestId('button-test');
    expect(buttonEl).toHaveClass('btn--secondary');
    expect(buttonEl).not.toHaveClass('btn--primary');

    // Text
    rerender(
      <Button
        variant="text"
        size="medium"
        disabled={false}
        loading={false}
        fullWidth={false}
        onClick={onClick}
        data-testid="button-test"
      >
        Text Button
      </Button>
    );
    buttonEl = getByTestId('button-test');
    expect(buttonEl).toHaveClass('btn--text');
    expect(buttonEl).not.toHaveClass('btn--secondary');
  });

  test('renders different sizes', () => {
    /**
     * Steps:
     * 1) Test small size with proper classes
     * 2) Test medium size with proper classes
     * 3) Test large size with proper classes
     * 4) Verify size-specific dimensions or class naming
     */
    const { rerender, getByTestId } = renderButton({ size: 'small' });
    let buttonEl = getByTestId('button-test');
    expect(buttonEl).toHaveClass('btn--small');

    rerender(
      <Button
        variant="primary"
        size="medium"
        disabled={false}
        loading={false}
        fullWidth={false}
        data-testid="button-test"
      >
        Medium Button
      </Button>
    );
    buttonEl = getByTestId('button-test');
    expect(buttonEl).toHaveClass('btn--medium');

    rerender(
      <Button
        variant="primary"
        size="large"
        disabled={false}
        loading={false}
        fullWidth={false}
        data-testid="button-test"
      >
        Large Button
      </Button>
    );
    buttonEl = getByTestId('button-test');
    expect(buttonEl).toHaveClass('btn--large');
  });

  test('handles interaction states', async () => {
    /**
     * Steps:
     * 1) Test hover state using userEvent
     * 2) Test active state during click
     * 3) Test focus state with keyboard navigation
     * 4) Verify state-specific styling
     */
    const { user, getByTestId } = renderButton();
    const buttonEl = getByTestId('button-test');

    // 1) Hover state
    await user.hover(buttonEl);
    // Depending on your styling approach, you might check a class or a style
    // Here we simply confirm no errors thrown; advanced CSS-based states might require style checks
    expect(buttonEl).toBeInTheDocument();

    // 2) Active state (during click)
    await user.click(buttonEl);
    expect(onClick).toHaveBeenCalledTimes(1);

    // 3) Focus state with keyboard navigation
    // Move focus away first, then tab onto the button
    await user.tab();
    await user.tab();
    expect(buttonEl).toHaveFocus();

    // 4) (Optional) We could check final class or style if the button applies any active/focus classes
    // expect(buttonEl).toHaveClass('btn--focus'); // Example only if implemented
  });

  test('handles disabled state', async () => {
    /**
     * Steps:
     * 1) Render disabled button
     * 2) Verify disabled attribute
     * 3) Attempt click and verify no handler call
     * 4) Verify disabled styling
     */
    const { user, getByTestId } = renderButton({ disabled: true });
    const buttonEl = getByTestId('button-test');

    expect(buttonEl).toBeDisabled();

    // Attempt to click the disabled button
    await user.click(buttonEl);
    expect(onClick).not.toHaveBeenCalled();

    // Confirm disabled styling class
    expect(buttonEl).toHaveClass('btn--disabled');
  });

  test('handles loading state', () => {
    /**
     * Steps:
     * 1) Render button in loading state
     * 2) Verify loading spinner presence
     * 3) Verify button is disabled while loading
     * 4) Check loading text accessibility
     */
    const { getByTestId } = renderButton({ loading: true });
    const buttonEl = getByTestId('button-test');

    // Confirm loading text or spinner element
    expect(screen.getByText(/Loading\.\.\./i)).toBeInTheDocument();

    // Verify it's effectively disabled (cannot be clicked)
    expect(buttonEl).toBeDisabled();

    // We can also confirm the loading class is applied
    expect(buttonEl).toHaveClass('btn--loading');
  });

  test('maintains accessibility', async () => {
    /**
     * Steps:
     * 1) Verify ARIA attributes
     * 2) Test keyboard navigation
     * 3) Verify focus visible indicator
     * 4) Test screen reader text
     */
    const { user, getByRole } = renderButton({
      'aria-label': 'Descriptive Button Label',
    });

    // 1) We can retrieve the button by its accessible name (aria-label)
    const accessibleButton = getByRole('button', { name: /Descriptive Button Label/i });
    expect(accessibleButton).toBeInTheDocument();

    // 2) Test keyboard navigation
    // Move focus away, then tab until the button is focused
    await user.tab();
    await user.tab();
    expect(accessibleButton).toHaveFocus();

    // 3) (Optional) If your styling includes a focus ring or styling,
    // you might check the presence of a class or style here

    // 4) Screen reader text is tested by verifying the aria-label,
    // so if the label is found by getByRole, we confirm SR access works
    // Additional checks can be made if there's hidden text or describedBy references
  });
});