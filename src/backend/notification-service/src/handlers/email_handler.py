import re  # built-in (used for basic email validation)
import logging  # built-in (comprehensive logging for email operations and errors)
import smtplib  # built-in (SMTP email sending functionality)
from typing import Dict, Any, Optional  # built-in (type hints for better readability)
from email.mime.text import MIMEText  # built-in (plain text/HTML email support)
from email.mime.multipart import MIMEMultipart  # built-in (mixed email content)
from tenacity import retry, stop_after_attempt, wait_exponential  # tenacity==8.2.3 (advanced retry support)

# Internal imports based on JSON specification
from ..config.config import EmailConfig  # Email service configuration (SMTP, credentials, security)
from ..utils.templates import TemplateManager  # Template rendering and management

# Global logger instance
logger = logging.getLogger(__name__)


class EmailHandler:
    """
    Manages email notification delivery with connection pooling, retry capabilities, and
    comprehensive delivery tracking. This class is designed to handle secure, robust, and
    scalable email sending operations, including HTML/plain text content rendering,
    advanced retry mechanisms, and thorough logging.

    Attributes:
        _config (EmailConfig): Holds SMTP server configuration (host, port, TLS usage, credentials).
        _template_manager (TemplateManager): Manages template retrieval and rendering for emails.
        _smtp_connection (smtplib.SMTP): Active SMTP connection instance used for sending emails.
        _delivery_stats (dict): Tracks sent and failed email delivery counts for monitoring.
        _is_connected (bool): Indicates whether the handler currently has an active SMTP connection.
    """

    def __init__(self, config: EmailConfig, template_manager: TemplateManager) -> None:
        """
        Initializes the EmailHandler with configuration and template manager. Also sets up
        a connection pool (represented here by a single re-usable connection), delivery
        statistics, and detailed logging.

        Steps:
            1. Initialize email configuration (store the provided EmailConfig).
            2. Set up the template manager for HTML/plain text rendering.
            3. Prepare SMTP connection pool placeholder (_smtp_connection = None).
            4. Initialize delivery statistics dictionary for tracking email success/failure.
            5. Configure logging with detailed formatting (relies on global logger setup).
            6. Set the connection status flag to False, indicating no active connection yet.

        Args:
            config (EmailConfig): The validated email configuration object.
            template_manager (TemplateManager): Manages retrieval and rendering of email templates.

        Raises:
            None
        """
        self._config: EmailConfig = config
        self._template_manager: TemplateManager = template_manager
        self._smtp_connection: Optional[smtplib.SMTP] = None
        self._delivery_stats: Dict[str, int] = {
            "sent_count": 0,
            "failed_count": 0
        }
        self._is_connected: bool = False

        logger.debug("EmailHandler initialized with given EmailConfig and TemplateManager.")

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    def connect(self) -> bool:
        """
        Establishes a secure SMTP connection with retry mechanism. If the connection
        is already active, it returns True immediately; otherwise, it attempts to create
        a new SMTP session, optionally upgrading to TLS, and logs the success or failure.

        Steps:
            1. Check if a valid SMTP connection already exists; if so, return True.
            2. Create a new SMTP connection using host, port, and configured timeout.
            3. If use_tls is True, initiate TLS communication.
            4. Authenticate using the stored SMTP credentials (username, password).
            5. Update _is_connected to True and log the connection event.
            6. Return True if successfully connected.

        Returns:
            bool: True if connection is established (or was already active), False otherwise.

        Raises:
            Exception: Propagated if connection fails repeatedly, triggering tenacity retries.
        """
        if self._is_connected:
            logger.info("SMTP connection already established. No action required.")
            return True

        try:
            logger.debug(
                "Attempting to connect to SMTP host='%s' on port=%d with timeout=%d seconds.",
                self._config.smtp_host,
                self._config.smtp_port,
                self._config.timeout_seconds
            )

            # Create SMTP connection with explicit timeout
            self._smtp_connection = smtplib.SMTP(
                host=self._config.smtp_host,
                port=self._config.smtp_port,
                timeout=self._config.timeout_seconds
            )

            if self._config.use_tls:
                logger.debug("TLS is enabled in EmailConfig. Starting TLS negotiation.")
                self._smtp_connection.starttls()

            # Login with credentials
            if self._config.smtp_user and self._config.smtp_password:
                self._smtp_connection.login(
                    self._config.smtp_user,
                    self._config.smtp_password.reveal()
                )

            self._is_connected = True
            logger.info(
                "Successfully connected to SMTP server at %s:%d (use_tls=%s).",
                self._config.smtp_host,
                self._config.smtp_port,
                self._config.use_tls
            )
            return True

        except Exception as ex:
            logger.exception("Failed to connect to SMTP server. Retrying...")
            raise ex

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    def send_email(
        self,
        recipient_email: str,
        subject: str,
        template_name: str,
        context: Dict[str, Any],
        priority: bool
    ) -> bool:
        """
        Sends an email notification with both HTML and plain text content using the
        configured SMTP connection and a robust retry strategy. Tracks successful or
        failed deliveries in self._delivery_stats.

        Steps:
            1. Validate the recipient email format (basic pattern check).
            2. Ensure the SMTP connection is active; if not, attempt to connect.
            3. Render HTML and plain text templates using the TemplateManager.
            4. Create a multipart email message and set essential headers (From, To, Subject).
            5. If priority is True, set the X-Priority header to indicate a high-priority email.
            6. Attach the plain text and HTML parts to the message.
            7. Attempt to send the email to the SMTP server with sendmail().
            8. If successful, increment sent_count in _delivery_stats; otherwise log and raise.
            9. Log the final sending status for observability.
            10. Return True if the email is sent without errors; otherwise raise to trigger retry.

        Args:
            recipient_email (str): The destination email address.
            subject (str): Subject line for the email.
            template_name (str): The base template identifier for generating message content.
            context (dict): Dynamic data to inject into the templates.
            priority (bool): If True, the email is flagged as high priority.

        Returns:
            bool: True if the email is successfully sent, otherwise raises an exception.

        Raises:
            ValueError: If the recipient email is invalid.
            Exception: If sending fails, triggering the tenacity retry mechanism.
        """
        if not self._validate_email_format(recipient_email):
            logger.error("Invalid recipient email format: %s", recipient_email)
            raise ValueError(f"Invalid email address: {recipient_email}")

        # Ensure we have a live connection
        if not self._is_connected:
            self.connect()

        # Render HTML and plain text from the same logical template
        # For demonstration, we use the same template for both HTML and text.
        # In production, separate templates or channels might be used.
        try:
            # Render an HTML version (CHANNEL=EMAIL)
            rendered_html = self._template_manager.render_template_by_name(template_name + "_html", context)
            # Render a plain text version (CHANNEL=SMS or fallback) - if not found, fallback to minimal text
            try:
                rendered_text = self._template_manager.render_template_by_name(template_name + "_txt", context)
            except Exception:
                logger.warning(
                    "Plain text template '%s_txt' not found. Falling back to basic text.",
                    template_name
                )
                rendered_text = "This is an automatically-generated email.\n\n" \
                                "Content could not be rendered in plain text."

        except Exception as tmpl_ex:
            logger.exception("Template rendering failed for template '%s'.", template_name)
            self._delivery_stats["failed_count"] += 1
            raise tmpl_ex

        # Build the MIME message containing the HTML and TEXT parts
        mime_msg = MIMEMultipart("alternative")
        mime_msg["Subject"] = subject
        mime_msg["From"] = self._config.sender_email
        mime_msg["To"] = recipient_email

        # Add priority if requested
        if priority:
            mime_msg["X-Priority"] = "1"
            mime_msg["Importance"] = "High"

        # Attach plain text and HTML content
        part_text = MIMEText(rendered_text, "plain", "utf-8")
        part_html = MIMEText(rendered_html, "html", "utf-8")
        mime_msg.attach(part_text)
        mime_msg.attach(part_html)

        try:
            self._smtp_connection.sendmail(
                from_addr=self._config.sender_email,
                to_addrs=[recipient_email],
                msg=mime_msg.as_string()
            )
            self._delivery_stats["sent_count"] += 1
            logger.info(
                "Email successfully sent to '%s' with subject '%s'. Priority=%s",
                recipient_email,
                subject,
                priority
            )
            return True

        except Exception as send_ex:
            logger.exception(
                "Failed to send email to '%s' with subject '%s'. Retrying...",
                recipient_email,
                subject
            )
            self._delivery_stats["failed_count"] += 1
            raise send_ex

    def close(self) -> None:
        """
        Safely closes the SMTP connection and updates internal resources. This method
        should be called when the handler is no longer needed or before application
        shutdown to ensure graceful resource cleanup.

        Steps:
            1. Check if an SMTP connection is active.
            2. If active, quit the SMTP connection to release server resources.
            3. Reset the _is_connected flag to False.
            4. Log the connection closure event for monitoring.
            5. Optionally update or log final delivery statistics as needed.

        Returns:
            None
        """
        if self._is_connected and self._smtp_connection:
            try:
                self._smtp_connection.quit()
                logger.info("SMTP connection closed gracefully.")
            except Exception:
                logger.exception("Exception occurred while closing the SMTP connection.")
            finally:
                self._is_connected = False
                self._smtp_connection = None
        else:
            logger.debug("No active SMTP connection found. Close operation skipped.")

        logger.debug(
            "Delivery stats on close => sent_count: %d, failed_count: %d.",
            self._delivery_stats["sent_count"],
            self._delivery_stats["failed_count"]
        )

    def _validate_email_format(self, email_address: str) -> bool:
        """
        Simple validation of email address format using a basic regex pattern.
        An enterprise solution might integrate more advanced validation or
        external email verification services.

        Args:
            email_address (str): Email address to validate.

        Returns:
            bool: True if format appears valid, False otherwise.
        """
        if not email_address:
            return False
        # Basic pattern check for demonstration
        pattern = r"^[\w\.-]+@[\w\.-]+\.\w+$"
        return bool(re.match(pattern, email_address))


# Extend TemplateManager to illustrate how we might handle "template_name" directly.
# In production, a separate specialized function or naming convention can be used.
def _extend_template_manager():
    """
    This extends the existing TemplateManager with a new method 'render_template_by_name'
    to align with the requirement of using 'template_name' in the EmailHandler. This is
    a simple example to demonstrate how the EmailHandler can render content from a string
    identifier rather than strictly using Notification enums.
    """

    # Check if the method is already defined (avoid re-definition in a real environment).
    if not hasattr(TemplateManager, 'render_template_by_name'):
        def render_template_by_name(self, template_name: str, context: Dict[str, Any]) -> str:
            """
            Renders a template directly by file-stem name, ignoring NotificationType or Channel
            enum usage. This is a convenience method to keep the EmailHandler code aligned with
            a 'template_name' parameter.
            """
            if not template_name:
                logger.error("No template_name provided. Unable to render template.")
                raise ValueError("template_name must be a non-empty string.")

            # Attempt direct retrieval using the internal _templates dictionary keys
            template_record = self._templates.get(template_name)
            if not template_record:
                logger.error(
                    "No template found under '%s'. Ensure the template file '%s.j2' is present.",
                    template_name,
                    template_name
                )
                raise ValueError(f"Template '{template_name}' not found in the template cache.")

            template_obj = template_record["template"]
            try:
                return template_obj.render(**context)
            except Exception as ex:
                logger.exception(
                    "Failed to render template '%s' with context: %s",
                    template_name,
                    context
                )
                raise ex

        # Dynamically add the method to TemplateManager
        setattr(TemplateManager, 'render_template_by_name', render_template_by_name)


# Automatically extend TemplateManager at import time to fulfill 'template_name' usage in EmailHandler
_extend_template_manager()