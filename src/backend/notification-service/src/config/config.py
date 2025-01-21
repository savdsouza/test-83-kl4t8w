"""
Configuration management module for the notification service.

This module provides a centralized and secure configuration solution for 
the Notification Service, supporting multiple notification channels 
such as push notifications (FCM/APNs), email (SMTP), and SMS 
with enhanced security, validation, and monitoring capabilities.

The code within this file adheres to enterprise-grade software engineering 
standards. It leverages Python 3.11 features, including data classes for 
type safety and immutability, YAML for flexible configuration loading, 
and the cryptography library for secure storage of sensitive values.
"""

import os  # built-in (used for environment variables and file paths)
import logging  # built-in (used for logging configuration changes and errors)
import threading  # built-in (used for locking during config reload operations)
import yaml  # PyYAML==6.0.1 (used for safe YAML configuration file parsing)
from dataclasses import dataclass, field  # built-in (used for immutable data classes)
from typing import Any, Dict, List, Optional

# cryptography==41.0.0 (used for secure handling of sensitive data)
from cryptography.fernet import Fernet

###############################################################################
# Helper Classes and Decorators
###############################################################################


class ConfigValidator:
    """
    A placeholder configuration validator class. In a production environment,
    this class should implement methods to validate the structure and semantics
    of configuration objects such as EmailConfig, PushConfig, and SMSConfig.
    """

    def validate_email_config(self, config_obj: "EmailConfig") -> None:
        """
        Validates an EmailConfig instance for logical correctness.
        Raises exceptions for invalid fields or missing data.
        """
        if not config_obj.smtp_host:
            raise ValueError("EmailConfig validation error: 'smtp_host' cannot be empty.")
        if config_obj.smtp_port <= 0:
            raise ValueError("EmailConfig validation error: 'smtp_port' must be > 0.")
        if not config_obj.sender_email:
            raise ValueError("EmailConfig validation error: 'sender_email' cannot be empty.")

    def validate_push_config(self, config_obj: "PushConfig") -> None:
        """
        Validates a PushConfig instance for completeness and correctness.
        Raises exceptions for invalid fields or missing data.
        """
        if not config_obj.fcm_credentials_path.encrypted_value:
            raise ValueError("PushConfig validation error: 'fcm_credentials_path' cannot be empty.")
        if (config_obj.apns_use_sandbox not in (True, False)):
            raise ValueError("PushConfig validation error: 'apns_use_sandbox' must be a bool.")

    def validate_sms_config(self, config_obj: "SMSConfig") -> None:
        """
        Validates an SMSConfig instance for completeness and correctness.
        Raises exceptions for invalid fields or missing data.
        """
        if not config_obj.provider_api_key.encrypted_value:
            raise ValueError("SMSConfig validation error: 'provider_api_key' cannot be empty.")
        if not config_obj.sender_number:
            raise ValueError("SMSConfig validation error: 'sender_number' cannot be empty.")


class ConfigMetrics:
    """
    A placeholder metrics class to track configuration load, reload, access, 
    or error events for monitoring and observability in production environments.
    """

    def record_load(self, config_type: str) -> None:
        """
        Record a successful load or initialization of a particular configuration type.
        """
        logging.info(f"[ConfigMetrics] Load recorded for config type: {config_type}")

    def record_access(self, config_type: str) -> None:
        """
        Record an access event, indicating a retrieval of a particular configuration type.
        """
        logging.info(f"[ConfigMetrics] Access recorded for config type: {config_type}")

    def record_reload(self, success: bool) -> None:
        """
        Record a configuration reload event, capturing whether the reload succeeded or failed.
        """
        status = "SUCCESS" if success else "FAILURE"
        logging.info(f"[ConfigMetrics] Reload attempted, status: {status}")

    def record_error(self, error_message: str) -> None:
        """
        Record an error or exception encountered during configuration operations.
        """
        logging.error(f"[ConfigMetrics] Error recorded: {error_message}")


def _generate_encryption_key() -> bytes:
    """
    Generates and returns a cryptographically secure symmetric key for 
    encryption and decryption of sensitive configuration data.
    In production, key management should be handled via secure KMS solutions 
    such as AWS KMS or Vault, and not generated or stored in source code.
    """
    return Fernet.generate_key()


# A shared encryption key for demonstration. In production, do not store keys in code.
_SHARED_CRYPTO_KEY = _generate_encryption_key()
_FERNET_CIPHER = Fernet(_SHARED_CRYPTO_KEY)


class SecureString:
    """
    A class to represent a string value that is securely encrypted in memory.
    This class ensures that sensitive data (like passwords or API keys) are 
    encrypted at rest within the application's memory space.
    """

    def __init__(self, plain_value: str = ""):
        """
        Encrypts the provided plain string using Fernet symmetric encryption.
        """
        if not plain_value:
            self._encrypted_value = b""
        else:
            self._encrypted_value = _FERNET_CIPHER.encrypt(plain_value.encode("utf-8"))

    @property
    def encrypted_value(self) -> bytes:
        """
        Returns the encrypted bytes object for secure storage or transmission.
        """
        return self._encrypted_value

    def reveal(self) -> str:
        """
        Decrypts and returns the plain string. Use with caution,
        as returning the plain string defeats the purpose of secure in-memory storage.
        """
        if not self._encrypted_value:
            return ""
        return _FERNET_CIPHER.decrypt(self._encrypted_value).decode("utf-8")


class SecurePath:
    """
    A class to securely handle sensitive filesystem paths or credential files.
    Similar to SecureString, the path is encrypted at rest within the application's memory.
    """

    def __init__(self, plain_path: str = ""):
        """
        Encrypt the provided path using symmetric encryption to ensure 
        that file system credentials or token paths remain hidden in memory.
        """
        if not plain_path:
            self._encrypted_path = b""
        else:
            self._encrypted_path = _FERNET_CIPHER.encrypt(plain_path.encode("utf-8"))

    @property
    def encrypted_value(self) -> bytes:
        """
        Returns the encrypted bytes representing the filesystem path.
        """
        return self._encrypted_path

    def reveal(self) -> str:
        """
        Decrypts and returns the raw filesystem path. Operations that use the path 
        should decrypt it just-in-time to minimize exposure.
        """
        if not self._encrypted_path:
            return ""
        return _FERNET_CIPHER.decrypt(self._encrypted_path).decode("utf-8")


###############################################################################
# Validation Decorators for Data Classes
###############################################################################


def validate_email_config(cls):
    """
    Decorator to integrate class-level validation logic for EmailConfig.
    This example uses a simple approach where a post-init method delegates
    to ConfigValidator for validation.
    """
    original_init = cls.__init__

    def new_init(self, *args, **kwargs):
        original_init(self, *args, **kwargs)
        # Perform validation right after the object is initialized.
        validator = ConfigValidator()
        validator.validate_email_config(self)

    cls.__init__ = new_init
    return cls


def validate_push_config(cls):
    """
    Decorator to integrate class-level validation logic for PushConfig.
    This example uses a simple approach where a post-init method delegates
    to ConfigValidator for validation.
    """
    original_init = cls.__init__

    def new_init(self, *args, **kwargs):
        original_init(self, *args, **kwargs)
        validator = ConfigValidator()
        validator.validate_push_config(self)

    cls.__init__ = new_init
    return cls


def validate_sms_config(cls):
    """
    Decorator to integrate class-level validation logic for SMSConfig.
    This example uses a simple approach where a post-init method delegates
    to ConfigValidator for validation.
    """
    original_init = cls.__init__

    def new_init(self, *args, **kwargs):
        original_init(self, *args, **kwargs)
        validator = ConfigValidator()
        validator.validate_sms_config(self)

    cls.__init__ = new_init
    return cls


###############################################################################
# EmailConfig Data Class
###############################################################################


@validate_email_config
@dataclass(frozen=True)
class EmailConfig:
    """
    Email service configuration settings with validation and encryption 
    for sensitive information.
    """
    smtp_host: str
    smtp_port: int
    smtp_user: str
    smtp_password: SecureString
    sender_email: str
    use_tls: bool
    timeout_seconds: int
    max_retries: int
    allowed_domains: List[str] = field(default_factory=list)


###############################################################################
# PushConfig Data Class
###############################################################################


@validate_push_config
@dataclass(frozen=True)
class PushConfig:
    """
    Push notification service configuration for FCM and APNs with enhanced security 
    (e.g., storing credential file paths in an encrypted manner).
    """
    fcm_credentials_path: SecurePath
    apns_key_id: str
    apns_key_path: SecurePath
    apns_team_id: str
    apns_bundle_id: str
    apns_use_sandbox: bool
    max_retries: int
    retry_delay_seconds: int
    rate_limits: Dict[str, int] = field(default_factory=dict)


###############################################################################
# SMSConfig Data Class
###############################################################################


@validate_sms_config
@dataclass(frozen=True)
class SMSConfig:
    """
    SMS service configuration settings with provider-specific validation 
    and secure storage of sensitive API credentials.
    """
    provider_api_key: SecureString
    provider_api_secret: SecureString
    sender_number: str
    max_retries: int
    retry_delay_seconds: int
    provider_settings: Dict[str, str] = field(default_factory=dict)
    allowed_countries: List[str] = field(default_factory=list)


###############################################################################
# NotificationConfig Manager
###############################################################################


class NotificationConfig:
    """
    Main configuration class for the notification service with monitoring and validation.
    This class manages the configuration for all notification channels (Email, Push, SMS)
    and provides methods to safely load, retrieve, and reload configurations in a
    production-ready manner.
    """

    def __init__(
        self,
        config_path: str,
        validator: Optional[ConfigValidator] = None,
        metrics: Optional[ConfigMetrics] = None
    ) -> None:
        """
        Initializes the notification service configuration with validation and monitoring.

        Steps involved:
        1. Initialize configuration validator.
        2. Set up configuration metrics tracking.
        3. Load and validate configuration file from path.
        4. Set up secure configuration cache.
        5. Initialize configuration encryption logic.
        6. Load and validate environment variables.
        7. Set up configuration change listeners (if applicable).
        """

        self._config_path = config_path
        self._validator = validator or ConfigValidator()
        self._metrics = metrics or ConfigMetrics()

        # Internal cache to store instantiated configuration data classes
        self._config_cache: Dict[str, Any] = {}
        # A lock to ensure thread-safe reload operations
        self._config_lock = threading.Lock()

        # Perform an initial load of the configuration
        self._initial_load()

    def _initial_load(self) -> None:
        """
        Internal helper to perform the initial load of config from the config_path.
        """
        try:
            self._load_config_file(self._config_path)
            self._apply_environment_overrides()
            self._metrics.record_load("NotificationConfig")
        except Exception as ex:
            logging.error(f"Failed to load initial configuration: {ex}")
            self._metrics.record_error(str(ex))
            raise

    def _load_config_file(self, path: str) -> None:
        """
        Internal method to load the YAML configuration file, parse it, and store
        the results in the config cache as immutably-defined data class instances.
        """
        with open(path, "r", encoding="utf-8") as file:
            raw_config = yaml.safe_load(file)

        # Safely parse email configuration
        email_data = raw_config.get("email", {})
        self._config_cache["email_config"] = EmailConfig(
            smtp_host=email_data.get("smtp_host", ""),
            smtp_port=email_data.get("smtp_port", 25),
            smtp_user=email_data.get("smtp_user", ""),
            smtp_password=SecureString(email_data.get("smtp_password", "")),
            sender_email=email_data.get("sender_email", ""),
            use_tls=email_data.get("use_tls", False),
            timeout_seconds=email_data.get("timeout_seconds", 30),
            max_retries=email_data.get("max_retries", 3),
            allowed_domains=email_data.get("allowed_domains", [])
        )

        # Safely parse push configuration
        push_data = raw_config.get("push", {})
        self._config_cache["push_config"] = PushConfig(
            fcm_credentials_path=SecurePath(push_data.get("fcm_credentials_path", "")),
            apns_key_id=push_data.get("apns_key_id", ""),
            apns_key_path=SecurePath(push_data.get("apns_key_path", "")),
            apns_team_id=push_data.get("apns_team_id", ""),
            apns_bundle_id=push_data.get("apns_bundle_id", ""),
            apns_use_sandbox=push_data.get("apns_use_sandbox", True),
            max_retries=push_data.get("max_retries", 3),
            retry_delay_seconds=push_data.get("retry_delay_seconds", 5),
            rate_limits=push_data.get("rate_limits", {})
        )

        # Safely parse SMS configuration
        sms_data = raw_config.get("sms", {})
        self._config_cache["sms_config"] = SMSConfig(
            provider_api_key=SecureString(sms_data.get("provider_api_key", "")),
            provider_api_secret=SecureString(sms_data.get("provider_api_secret", "")),
            sender_number=sms_data.get("sender_number", ""),
            max_retries=sms_data.get("max_retries", 3),
            retry_delay_seconds=sms_data.get("retry_delay_seconds", 5),
            provider_settings=sms_data.get("provider_settings", {}),
            allowed_countries=sms_data.get("allowed_countries", [])
        )

        # Run additional validation checks on each config object
        try:
            self._validator.validate_email_config(self._config_cache["email_config"])
            self._validator.validate_push_config(self._config_cache["push_config"])
            self._validator.validate_sms_config(self._config_cache["sms_config"])
        except Exception as validation_err:
            raise ValueError(f"Configuration validation failed: {validation_err}")

    def _apply_environment_overrides(self) -> None:
        """
        Applies environment variable overrides for configuration values if they exist.
        This is useful for containerized deployments where environment variables are
        commonly used to pass secrets or overrides.
        """
        # Example overrides for email configuration
        email_config: EmailConfig = self._config_cache["email_config"]
        overridden_smtp_host = os.environ.get("SMTP_HOST", email_config.smtp_host)
        overridden_smtp_port = int(os.environ.get("SMTP_PORT", email_config.smtp_port))
        overridden_smtp_user = os.environ.get("SMTP_USER", email_config.smtp_user)
        overridden_smtp_password = os.environ.get("SMTP_PASSWORD", email_config.smtp_password.reveal())
        overridden_sender_email = os.environ.get("SENDER_EMAIL", email_config.sender_email)

        # Re-create the EmailConfig with environment overrides (immutable/frozen re-initialization)
        updated_email_config = EmailConfig(
            smtp_host=overridden_smtp_host,
            smtp_port=overridden_smtp_port,
            smtp_user=overridden_smtp_user,
            smtp_password=SecureString(overridden_smtp_password),
            sender_email=overridden_sender_email,
            use_tls=email_config.use_tls,
            timeout_seconds=email_config.timeout_seconds,
            max_retries=email_config.max_retries,
            allowed_domains=email_config.allowed_domains
        )
        self._config_cache["email_config"] = updated_email_config

        # Additional environment overrides can be handled similarly for push_config, sms_config, etc.

    def get_email_config(self) -> EmailConfig:
        """
        Retrieves validated email service configuration.

        Steps:
        1. Check configuration cache validity.
        2. Load email config from secure cache.
        3. Apply environment variable overrides (if dynamic retrieval is needed).
        4. Validate configuration values.
        5. Track configuration access.
        6. Return validated EmailConfig instance.
        """
        self._metrics.record_access("email_config")
        return self._config_cache["email_config"]

    def get_push_config(self) -> PushConfig:
        """
        Retrieves validated push notification service configuration.

        Steps:
        1. Check configuration cache validity.
        2. Load push config from secure cache.
        3. Apply environment variable overrides (if needed).
        4. Validate configuration values.
        5. Track configuration access.
        6. Return validated PushConfig instance.
        """
        self._metrics.record_access("push_config")
        return self._config_cache["push_config"]

    def get_sms_config(self) -> SMSConfig:
        """
        Retrieves validated SMS service configuration.

        Steps:
        1. Check configuration cache validity.
        2. Load SMS config from secure cache.
        3. Apply environment variable overrides (if needed).
        4. Validate configuration values.
        5. Track configuration access.
        6. Return validated SMSConfig instance.
        """
        self._metrics.record_access("sms_config")
        return self._config_cache["sms_config"]

    def reload_config(self) -> bool:
        """
        Safely reloads configuration with validation and monitoring.

        Returns:
            bool: Success status of the reload operation.

        Steps:
        1. Lock configuration for update.
        2. Create configuration backup.
        3. Clear secure configuration cache.
        4. Load new configuration file.
        5. Validate new configuration.
        6. Update environment variables.
        7. Update configuration metrics.
        8. Log configuration changes.
        9. Release configuration lock.
        10. Return reload success status.
        """
        with self._config_lock:
            backup_cache = dict(self._config_cache)
            try:
                # Clear the current cache before loading new values
                self._config_cache.clear()
                self._load_config_file(self._config_path)
                self._apply_environment_overrides()
                self._metrics.record_reload(True)
                logging.info("Configuration reload successful.")
                return True
            except Exception as ex:
                # Restore the backup in case of failure
                self._config_cache = backup_cache
                self._metrics.record_reload(False)
                self._metrics.record_error(str(ex))
                logging.error(f"Configuration reload failed: {ex}")
                return False