import React, {
  FC,
  useState,
  useCallback,
  useMemo,
  MouseEvent,
} from 'react'; // react@^18.0.0
import classNames from 'classnames'; // classnames@^2.3.2
import { Card } from '../common/Card';
import { Button } from '../common/Button';
import { Dog } from '../../types/dog.types';
import { useTheme } from '../../hooks/useTheme';

/**
 * DogCardProps
 * ----------------------------------------------------------------------------
 * Defines the full set of properties required by the DogCard component,
 * including dog information, event handlers, styling options, loading/error
 * states, and responsive image configuration.
 */
export interface DogCardProps {
  /**
   * The dog profile data to display, providing all necessary
   * details (e.g., name, breed, medical info).
   */
  dog: Dog;

  /**
   * Handler for when an edit action is triggered,
   * receiving the dog's unique identifier for updates.
   */
  onEdit: (dogId: string) => Promise<void>;

  /**
   * Handler for when a delete action is triggered,
   * receiving the dog's unique identifier for removal.
   */
  onDelete: (dogId: string) => Promise<void>;

  /**
   * Handler for when the user wishes to view the full dog profile,
   * receiving the dog's unique identifier for navigation or expansion.
   */
  onViewProfile: (dogId: string) => void;

  /**
   * An optional additional class name to allow merging
   * external styles with this component's styling.
   */
  className?: string;

  /**
   * The elevation level of the card, dictating the intensity
   * of the shadow. Acceptable values are 1, 2, or 3.
   */
  elevation?: 1 | 2 | 3;

  /**
   * When true, indicates that the card content is loading,
   * which can display a spinner or loading overlay and disable
   * user interactions until loading completes.
   */
  isLoading?: boolean;

  /**
   * If present, displays an error message in a dedicated
   * alert area, informing the user about issues such as unsuccessful requests.
   */
  errorMessage?: string;

  /**
   * Indicates the size configuration for the dog profile image.
   * Options allow for small, medium, or large displays.
   */
  imageSize?: 'small' | 'medium' | 'large';
}

/**
 * getDogAge
 * ----------------------------------------------------------------------------
 * Utility function to derive an approximate age (in years) from
 * the dog's birth date string. Returns a string suitable for display
 * (e.g., "2 years old") or "Unknown" if parsing fails.
 */
function getDogAge(birthDate: string): string {
  if (!birthDate) return 'Unknown';
  try {
    const birth = new Date(birthDate);
    const now = new Date();
    const diff = now.getTime() - birth.getTime();
    const ageDate = new Date(diff); // epoch difference
    const year = ageDate.getUTCFullYear() - 1970;
    if (year < 0) {
      return 'Unknown';
    }
    return year === 1 ? `${year} year old` : `${year} years old`;
  } catch (err) {
    return 'Unknown';
  }
}

/**
 * trackInteraction
 * ----------------------------------------------------------------------------
 * Stub analytics function for demonstration purposes. Logs an event to
 * the console or a real analytics instrument, helping us track user
 * interactions with the dog card component.
 *
 * @param eventName The name of the event or interaction being tracked
 * @param dogId     The unique identifier of the dog involved in the event
 */
function trackInteraction(eventName: string, dogId: string): void {
  // In a real production environment, this might integrate with a
  // logging or analytics service like Google Analytics or Datadog.
  // Here, we simply log the interaction for demonstration.
  console.log(`[Analytics] Event: ${eventName}, Dog ID: ${dogId}`);
}

/**
 * DogCard
 * ----------------------------------------------------------------------------
 * Renders an enhanced card displaying dog profile information with:
 *  - Theme support via useTheme()
 *  - Loading states and error handling
 *  - Collapsible medical info section
 *  - Responsive image handling for small/medium/large
 *  - Accessibility features (ARIA labeling, focus mgmt)
 *  - Action buttons (View, Edit, Delete) with integrated analytics tracking
 */
export const DogCard: FC<DogCardProps> = React.memo(
  ({
    dog,
    onEdit,
    onDelete,
    onViewProfile,
    className,
    elevation = 2,
    isLoading = false,
    errorMessage = '',
    imageSize = 'medium',
  }) => {
    /**
     * STEP 1: Access and apply theme context
     * ------------------------------------------------------------------------
     * We retrieve the theme and isDarkMode values from useTheme(). Although
     * they might or might not be used directly for styling here, they serve
     * as an example of how to incorporate global theming or dynamic class names.
     */
    const { theme, isDarkMode } = useTheme();

    /**
     * STEP 2: Manage collapsible state for medical info
     * ------------------------------------------------------------------------
     * The showMedicalInfo flag determines whether the dog's medical info
     * section is expanded or collapsed. This allows the user to reveal
     * or hide detailed health data as needed.
     */
    const [showMedicalInfo, setShowMedicalInfo] = useState<boolean>(false);

    /**
     * Toggles the visibility of the dog's detailed medical info.
     */
    const toggleMedicalInfo = useCallback(() => {
      setShowMedicalInfo((prev) => !prev);
      trackInteraction('ToggleMedicalInfo', dog.id);
    }, [dog.id]);

    /**
     * STEP 3: Helper to determine image container styling
     * ------------------------------------------------------------------------
     * We apply a specific style or class name based on the imageSize prop,
     * allowing responsive adaptation (small, medium, large) for the dog's
     * profile image.
     */
    const getImageSizeStyle = useMemo((): React.CSSProperties => {
      switch (imageSize) {
        case 'small':
          return { width: '60px', height: '60px', objectFit: 'cover' };
        case 'large':
          return { width: '140px', height: '140px', objectFit: 'cover' };
        case 'medium':
        default:
          return { width: '100px', height: '100px', objectFit: 'cover' };
      }
    }, [imageSize]);

    /**
     * STEP 4: Action handlers with analytics tracking
     * ------------------------------------------------------------------------
     * We wrap the provided event handlers (onViewProfile, onEdit, onDelete)
     * to inject analytics tracking for each user interaction.
     */
    const handleViewProfile = useCallback(
      (e: MouseEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        trackInteraction('ViewProfile', dog.id);
        onViewProfile(dog.id);
      },
      [dog.id, onViewProfile]
    );

    const handleEdit = useCallback(
      (e: MouseEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        trackInteraction('EditDog', dog.id);
        onEdit(dog.id).catch(() => {
          // Additional error handling or toast might be placed here
        });
      },
      [dog.id, onEdit]
    );

    const handleDelete = useCallback(
      (e: MouseEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        trackInteraction('DeleteDog', dog.id);
        onDelete(dog.id).catch(() => {
          // Additional error handling or toast might be placed here
        });
      },
      [dog.id, onDelete]
    );

    /**
     * STEP 5: Construct class names for the Card container
     * ------------------------------------------------------------------------
     * We combine user-defined className with theming and dynamic
     * dark-mode adjustments. The isLoading state might also alter
     * card UI or interactions.
     */
    const cardClassNames = useMemo(
      () =>
        classNames(className, {
          'dogcard--dark-mode': isDarkMode,
          'dogcard--loading': isLoading,
          'dogcard--error': !!errorMessage,
        }),
      [className, isDarkMode, isLoading, errorMessage]
    );

    /**
     * STEP 6: Conditionally render the dog's detailed medical info
     * ------------------------------------------------------------------------
     * The medical info is collapsed by default and expanded on user request.
     * This helps keep the UI succinct while still providing advanced details
     * for those who need them.
     */
    const medicalInfoSection = showMedicalInfo && (
      <div
        className="dogcard__medical-info"
        aria-live="polite"
        aria-expanded={showMedicalInfo}
        style={{
          marginTop: theme.spacing.grid['2x'],
          backgroundColor: isDarkMode
            ? theme.colors.background.tertiary
            : theme.colors.background.secondary,
          padding: theme.spacing.compound.cardPadding,
          borderRadius: theme.spacing.base,
        }}
      >
        <h4>Medical Info</h4>
        <ul style={{ margin: 0, paddingLeft: '1rem' }}>
          {dog.medicalInfo?.allergies?.length ? (
            <li>
              <strong>Allergies:</strong> {dog.medicalInfo.allergies.join(', ')}
            </li>
          ) : null}
          {dog.medicalInfo?.medications?.length ? (
            <li>
              <strong>Medications:</strong>{' '}
              {dog.medicalInfo.medications
                .map((med) => `${med.name} (${med.dosage} - ${med.schedule})`)
                .join(', ')}
            </li>
          ) : null}
          {dog.medicalInfo?.conditions?.length ? (
            <li>
              <strong>Conditions:</strong>{' '}
              {dog.medicalInfo.conditions
                .map((cond) => `${cond.name} (${cond.severity})`)
                .join(', ')}
            </li>
          ) : null}
          <li>
            <strong>Last Checkup:</strong> {dog.medicalInfo.lastCheckup}
          </li>
          {dog.medicalInfo?.vetContact?.name && (
            <li>
              <strong>Vet:</strong> {dog.medicalInfo.vetContact.name} |{' '}
              {dog.medicalInfo.vetContact.phone}
            </li>
          )}
        </ul>
      </div>
    );

    /**
     * STEP 7: Render the DogCard
     * ------------------------------------------------------------------------
     * We wrap all content in a <Card> component, ensuring a consistent
     * look, feel, and elevation across the application. Inside, we display
     * the dog's image, name, breed, age, buttons for actions, and any
     * conditional elements for error/loading states.
     */
    return (
      <Card
        className={cardClassNames}
        elevation={elevation}
        /**
         * ARIA role and tabIndex ensure the card is accessible by keyboard,
         * making it possible to focus the card for expanded interactions
         * in a broader UI context if needed.
         */
        role="article"
        tabIndex={0}
        aria-label={`Dog card for ${dog.name}`}
        style={{
          position: 'relative',
          padding: theme.spacing.compound.cardPadding,
          marginBottom: theme.spacing.grid['3x'],
          opacity: isLoading ? 0.7 : 1,
          cursor: isLoading ? 'default' : 'auto',
          transition: theme.typography.lineHeight.normal + 's',
        }}
      >
        {/* Step 7.1: Loading overlay or spinner (simple text fallback) */}
        {isLoading && (
          <div
            style={{
              position: 'absolute',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%,-50%)',
              backgroundColor: 'rgba(255,255,255,0.8)',
              color: '#000',
              padding: '8px 16px',
              borderRadius: '4px',
              zIndex: 10,
            }}
            aria-live="assertive"
          >
            Loading...
          </div>
        )}

        {/* Step 7.2: Error message display (if errorMessage is set) */}
        {errorMessage && (
          <div
            style={{
              marginBottom: theme.spacing.grid['2x'],
              color: theme.colors.error.main,
              fontWeight: theme.typography.fontWeight.medium,
            }}
            role="alert"
            aria-live="assertive"
          >
            {errorMessage}
          </div>
        )}

        {/* Step 7.3: Dog image and primary details section */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            marginBottom: theme.spacing.grid['2x'],
          }}
        >
          {dog.profileImageUrl ? (
            <img
              src={dog.profileImageUrl}
              alt={`Profile of ${dog.name}`}
              style={{
                borderRadius: '50%',
                marginRight: theme.spacing.grid['3x'],
                ...getImageSizeStyle,
              }}
              aria-hidden={isLoading ? true : false}
            />
          ) : (
            <div
              style={{
                borderRadius: '50%',
                backgroundColor: theme.colors.background.tertiary,
                marginRight: theme.spacing.grid['3x'],
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: theme.typography.fontSize.md,
                color: theme.colors.text.secondary,
                ...getImageSizeStyle,
              }}
              aria-hidden={isLoading ? true : false}
            >
              N/A
            </div>
          )}

          <div style={{ flex: 1, overflow: 'hidden' }}>
            <h3
              style={{
                margin: 0,
                fontSize: theme.typography.fontSize.lg,
                fontWeight: theme.typography.fontWeight.semibold,
                color: theme.colors.text.primary,
              }}
            >
              {dog.name}
            </h3>
            <p
              style={{
                margin: '4px 0',
                color: theme.colors.text.secondary,
                fontSize: theme.typography.fontSize.sm,
              }}
            >
              Breed: {dog.breed?.name || 'Unknown'} | {getDogAge(dog.birthDate)}
            </p>
          </div>
        </div>

        {/* Step 7.4: Action buttons (View Profile, Edit, Delete) */}
        <div
          style={{
            display: 'flex',
            gap: theme.spacing.grid['2x'],
            marginBottom: theme.spacing.grid['2x'],
          }}
        >
          <Button
            variant="primary"
            size="small"
            onClick={handleViewProfile}
            disabled={isLoading}
            aria-label={`View profile of ${dog.name}`}
            data-testid="DogCard-ViewProfileBtn"
          >
            View Profile
          </Button>
          <Button
            variant="secondary"
            size="small"
            onClick={handleEdit}
            disabled={isLoading}
            aria-label={`Edit dog profile of ${dog.name}`}
            data-testid="DogCard-EditBtn"
          >
            Edit
          </Button>
          <Button
            variant="text"
            size="small"
            onClick={handleDelete}
            disabled={isLoading}
            aria-label={`Delete dog profile of ${dog.name}`}
            data-testid="DogCard-DeleteBtn"
          >
            Delete
          </Button>
        </div>

        {/* Step 7.5: Collapsible medical info toggle */}
        <Button
          variant="text"
          size="small"
          onClick={toggleMedicalInfo}
          disabled={isLoading}
          aria-label={`Toggle medical info for ${dog.name}`}
          data-testid="DogCard-MedicalInfoToggle"
        >
          {showMedicalInfo ? 'Hide Medical Info' : 'Show Medical Info'}
        </Button>

        {/* Step 7.6: Conditionally render medical info */}
        {medicalInfoSection}
      </Card>
    );
  }
);