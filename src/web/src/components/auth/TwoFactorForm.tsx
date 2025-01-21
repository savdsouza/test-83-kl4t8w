import React, {
  useState, 
  useEffect, 
  useCallback, 
  FormEvent, 
  useRef 
} from 'react'; // ^18.0.0

////////////////////////////////////////////////////////////////////////////////
// Internal Imports - AuthService & Additional Components
////////////////////////////////////////////////////////////////////////////////
import { AuthService } from '../../services/auth.service'; // AuthService class with enhanced MFA support
// Note: The JSON specification indicates we use verifyMfa and verifyBackupCode methods on AuthService.
//       We assume these methods exist on AuthService for MFA and backup code verification.
import { Input } from '../common/Input'; // Enhanced input with error handling & onPaste support
import { Button } from '../common/Button'; // Enhanced button with loading & disabled states

////////////////////////////////////////////////////////////////////////////////
// TwoFactorFormProps Interface
////////////////////////////////////////////////////////////////////////////////
/**
 * Props interface for the TwoFactorForm component, providing callback handlers
 * and configurations for maximum attempt limits, allowing or disallowing
 * backup code usage, and success/cancel workflows.
 */
export interface TwoFactorFormProps {
  /**
   * Callback function invoked after a successful MFA verification flow.
   */
  onSuccess: () => void;

  /**
   * Callback function invoked when the user opts to cancel or abort
   * the two-factor authentication flow, typically returning them
   * to a previous step or screen.
   */
  onCancel: () => void;

  /**
   * Defines the maximum number of verification attempts
   * before the user is locked out or forced to retry later.
   */
  maxAttempts: number;

  /**
   * If set to true, enables an alternative path for users
   * to enter a backup code instead of a time-based OTP code.
   */
  allowBackupCodes: boolean;
}

////////////////////////////////////////////////////////////////////////////////
// TwoFactorForm Component
////////////////////////////////////////////////////////////////////////////////
/**
 * The TwoFactorForm component is responsible for securely handling user input
 * for multi-factor authentication (MFA). It accommodates Time-based OTP (TOTP)
 * verification, supports backup codes if enabled, and implements progressive
 * rate limiting and comprehensive error handling to mitigate authentication
 * attacks.
 */
export const TwoFactorForm: React.FC<TwoFactorFormProps> = ({
  onSuccess,
  onCancel,
  maxAttempts,
  allowBackupCodes
}) => {
  //////////////////////////////////////////////////////////////////////////////
  // (1) Initialize state for OTP input with validation
  //////////////////////////////////////////////////////////////////////////////
  const [otpValue, setOtpValue] = useState<string>('');
  const [backupCodeValue, setBackupCodeValue] = useState<string>('');

  //////////////////////////////////////////////////////////////////////////////
  // (2) Initialize state for attempt tracking
  //////////////////////////////////////////////////////////////////////////////
  const [attemptCount, setAttemptCount] = useState<number>(0);

  //////////////////////////////////////////////////////////////////////////////
  // (3) Initialize state for rate limiting (progressive delays & lockouts)
  //////////////////////////////////////////////////////////////////////////////
  const [isLocked, setIsLocked] = useState<boolean>(false);
  const [lockoutMessage, setLockoutMessage] = useState<string>('');
  const [rateLimitDelay, setRateLimitDelay] = useState<number>(0);

  //////////////////////////////////////////////////////////////////////////////
  // Error and Loading States
  //////////////////////////////////////////////////////////////////////////////
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);

  //////////////////////////////////////////////////////////////////////////////
  // (4) Setup input focus management
  //////////////////////////////////////////////////////////////////////////////
  // We maintain refs to dynamically re-focus fields under certain conditions.
  const otpInputRef = useRef<HTMLInputElement | null>(null);
  const backupCodeRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    // Automatically focus the OTP input on mount if no lockout is active
    if (!isLocked && !allowBackupCodes) {
      otpInputRef.current?.focus();
    }
    // If backup codes are allowed and the user is using them, focus that field
    if (!isLocked && allowBackupCodes) {
      backupCodeRef.current?.focus();
    }
  }, [isLocked, allowBackupCodes]);

  //////////////////////////////////////////////////////////////////////////////
  // (5) Implement input sanitization & (6) Handle clipboard paste events
  //////////////////////////////////////////////////////////////////////////////
  const handleOtpChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setOtpValue(e.target.value.replace(/[^0-9]/g, '').trim());
  }, []);

  const handleBackupCodeChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    // Backup codes may include alphanumeric or special chars; sanitize as needed
    setBackupCodeValue(e.target.value.trim());
  }, []);

  // Also handle direct paste events to ensure unwanted characters are removed
  const handleOtpPaste = useCallback((e: React.ClipboardEvent<HTMLInputElement>) => {
    e.preventDefault();
    const pasteData = e.clipboardData.getData('Text').replace(/[^0-9]/g, '').trim();
    setOtpValue(pasteData);
  }, []);

  const handleBackupCodePaste = useCallback((e: React.ClipboardEvent<HTMLInputElement>) => {
    e.preventDefault();
    const pasteData = e.clipboardData.getData('Text').trim();
    setBackupCodeValue(pasteData);
  }, []);

  //////////////////////////////////////////////////////////////////////////////
  // (7) Validate input format (OTP/backup code) & Additional Lockout Checks
  //////////////////////////////////////////////////////////////////////////////
  useEffect(() => {
    if (attemptCount >= maxAttempts) {
      // Lock out the user if attempts exceed the allowed max
      setIsLocked(true);
      setLockoutMessage('You have exceeded the maximum number of verification attempts. Please try again later.');
    }
  }, [attemptCount, maxAttempts]);

  //////////////////////////////////////////////////////////////////////////////
  // (8) Track verification attempts & (9) Implement progressive rate limiting
  //////////////////////////////////////////////////////////////////////////////
  // For progressive rate limiting, we can store a delay that increments
  // with each failed attempt, up to some threshold. The user must wait for
  // the delay to expire before trying again.
  useEffect(() => {
    if (attemptCount > 0) {
      // For demonstration, increment delay by 5 seconds for each attempt
      const newDelay = attemptCount * 5000;
      setRateLimitDelay(newDelay);
    }
  }, [attemptCount]);

  // When rateLimitDelay changes, if > 0 we can block interaction for that time.
  useEffect(() => {
    let timer: NodeJS.Timeout | null = null;
    if (rateLimitDelay > 0 && !isLocked) {
      setIsLocked(true);
      setLockoutMessage(`Please wait ${rateLimitDelay / 1000} seconds before your next attempt.`);

      timer = setTimeout(() => {
        setIsLocked(false);
        setLockoutMessage('');
      }, rateLimitDelay);
    }
    return () => {
      if (timer) clearTimeout(timer);
    };
  }, [rateLimitDelay, isLocked]);

  //////////////////////////////////////////////////////////////////////////////
  // handleVerification (Inner Function)
  // Description: Enhanced verification handler with security measures.
  //////////////////////////////////////////////////////////////////////////////
  const handleVerification = useCallback(async (event: FormEvent<HTMLFormElement>) => {
    /**
     * Steps:
     *  1) Prevent default form submission
     *  2) Validate input format
     *  3) Check rate limiting status
     *  4) Track attempt count
     *  5) Sanitize input value
     *  6) Attempt MFA verification
     *  7) Handle verification errors
     *  8) Update rate limiting state
     *  9) Manage error messages
     * 10) Update accessibility announcements
     * 11) Handle successful verification
     * 12) Reset form state
     */
    event.preventDefault();

    // (2) Validate input format (Ensure we have an OTP or backup code if allowed)
    const trimmedOtp = otpValue.trim();
    const trimmedBackupCode = backupCodeValue.trim();

    // (3) Check rate limit or lock status before proceeding
    if (isLocked) {
      setError(lockoutMessage || 'Please wait before attempting again.');
      return;
    }

    // (4) Track attempt count by incrementing prior to the verification
    setAttemptCount((prev) => prev + 1);

    // Clear previous error messages
    setError('');
    setLoading(true);

    try {
      // (5) Inputs are already sanitized on each change, but we can ensure final checks
      if (!allowBackupCodes && !trimmedOtp) {
        throw new Error('Please enter your 6-digit code.');
      }
      if (allowBackupCodes && !trimmedOtp && !trimmedBackupCode) {
        throw new Error('Please enter your 6-digit code or a valid backup code.');
      }

      // (6) Attempt MFA verification via AuthService
      const authService = new AuthService(/* pass ApiService if required */);

      let verificationSuccessful = false;
      if (trimmedBackupCode && allowBackupCodes) {
        // If user typed a backup code
        // We assume the service method returns a boolean or throws an Error
        verificationSuccessful = await authService.verifyBackupCode(trimmedBackupCode);
      } else {
        // If user typed an OTP
        verificationSuccessful = await authService.verifyMfa(trimmedOtp);
      }

      if (!verificationSuccessful) {
        // (7) Handle verification errors
        throw new Error('Verification failed. The code or backup entry is incorrect.');
      }

      // (11) Handle successful verification
      setLoading(false);
      onSuccess();

      // (12) Reset form state
      setOtpValue('');
      setBackupCodeValue('');
      setAttemptCount(0);
      setRateLimitDelay(0);
    } catch (err: any) {
      // (8) Update rate limiting state is already handled in useEffect by attemptCount
      // (9) Manage error messages
      setLoading(false);
      setError(err.message || 'An unknown error occurred. Please try again.');
    }
  }, [
    allowBackupCodes,
    otpValue,
    backupCodeValue,
    isLocked,
    onSuccess,
    lockoutMessage
  ]);

  //////////////////////////////////////////////////////////////////////////////
  // UI Rendering
  // (12) Render secure form with ARIA support & handle locked states
  //////////////////////////////////////////////////////////////////////////////
  return (
    <form
      onSubmit={handleVerification}
      aria-label="Two-Factor Authentication Form"
      aria-live="assertive"
      style={{ maxWidth: '400px', margin: '0 auto' }}
    >
      {/* 
        If the user is locked out or must wait due to progressive rate limiting,
        provide a user-friendly message describing the next step.
      */}
      {isLocked && lockoutMessage && (
        <div
          className="tfa-lockout-message"
          role="alert"
          style={{ marginBottom: '1rem', color: 'red', fontWeight: 'bold' }}
        >
          {lockoutMessage}
        </div>
      )}

      {allowBackupCodes ? (
        <>
          {/* 
            If backup codes are allowed, present two fields: 
            One for OTP, one for backup code, letting the user decide which to use.
          */}
          <label htmlFor="otp-field" style={{ display: 'block', fontWeight: 'bold' }}>
            Time-Based OTP Code
          </label>
          <Input
            id="otp-field"
            name="otp-code"
            type="text"
            placeholder="Enter your 6-digit OTP"
            value={otpValue}
            onChange={handleOtpChange}
            onPaste={handleOtpPaste}
            error={error ? '' : undefined} 
            disabled={isLocked || loading}
            aria-invalid={!!error}
            aria-describedby="otp-error"
            ref={otpInputRef}
            required={!backupCodeValue}
            data-testid="tfa-otp-input"
          />

          <div style={{ marginTop: '1rem', fontWeight: 'bold' }}>OR</div>

          <label htmlFor="backup-field" style={{ display: 'block', fontWeight: 'bold', marginTop: '1rem' }}>
            Backup Code
          </label>
          <Input
            id="backup-field"
            name="backup-code"
            type="text"
            placeholder="Enter backup code"
            value={backupCodeValue}
            onChange={handleBackupCodeChange}
            onPaste={handleBackupCodePaste}
            error={error ? '' : undefined}
            disabled={isLocked || loading}
            aria-invalid={!!error}
            aria-describedby="backup-error"
            ref={backupCodeRef}
            required={!otpValue}
            data-testid="tfa-backup-code-input"
          />
        </>
      ) : (
        <>
          {/* 
            If backup codes are not allowed, only show the TOTP field.
          */}
          <label htmlFor="otp-field" style={{ display: 'block', fontWeight: 'bold' }}>
            Time-Based OTP Code
          </label>
          <Input
            id="otp-field"
            name="otp-code"
            type="text"
            placeholder="Enter your 6-digit OTP"
            value={otpValue}
            onChange={handleOtpChange}
            onPaste={handleOtpPaste}
            error={error ? '' : undefined}
            disabled={isLocked || loading}
            aria-invalid={!!error}
            aria-describedby="otp-error"
            ref={otpInputRef}
            required
            data-testid="tfa-otp-input"
          />
        </>
      )}

      {/* 
        Display error messages in a dedicated alert area for screen reader accessibility
      */}
      {error && (
        <div
          id="otp-error"
          className="tfa-error"
          role="alert"
          style={{ color: 'red', margin: '0.5rem 0', fontWeight: 'bold' }}
        >
          {error}
        </div>
      )}

      {/* 
        Action Buttons Section 
      */}
      <div style={{ marginTop: '1rem', display: 'flex', gap: '1rem' }}>
        {/* 
          Verify Button:
          - Disabled if locked, loading, or no input
        */}
        <Button
          variant="primary"
          size="medium"
          onClick={() => { /* Handled by form submission */ }}
          loading={loading}
          disabled={
            isLocked 
            || loading 
            || !(otpValue || backupCodeValue || allowBackupCodes)
          }
          fullWidth={false}
          type="submit"
          data-testid="tfa-verify-button"
          aria-label="Verify Two-Factor Code"
        >
          Verify
        </Button>

        {/* 
          Cancel Button:
          - Always available to abort the MFA flow
        */}
        <Button
          variant="secondary"
          size="medium"
          onClick={(e) => {
            e.preventDefault();
            onCancel();
          }}
          loading={false}
          disabled={loading}
          fullWidth={false}
          type="button"
          data-testid="tfa-cancel-button"
          aria-label="Cancel Two-Factor Authentication"
        >
          Cancel
        </Button>
      </div>
    </form>
  );
};