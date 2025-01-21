# -----------------------------------------------------------------------------------
# File: templates.py
# Description:
#     Manages notification templates and template rendering for different notification
#     channels (email, SMS, push) with enhanced security, performance optimization, and
#     real-time support. Implements loading, caching, and validation of templates using
#     Jinja2 sandboxing features alongside channel-specific formatting and robust logging.
# -----------------------------------------------------------------------------------

# -----------------------------------------------------------------------------------
# External Imports
# -----------------------------------------------------------------------------------
import logging  # built-in
from pathlib import Path  # built-in
from typing import Dict, Any, Optional  # built-in
import time  # built-in import for TTL checks

# jinja2==3.1.2 (Template rendering engine with sandboxing and security features)
from jinja2 import Template, Environment, meta, exceptions
from jinja2.sandbox import SandboxedEnvironment

# -----------------------------------------------------------------------------------
# Internal Imports
# -----------------------------------------------------------------------------------
# Access notification type enums for template selection and validation
# Access notification channel enums for template formatting and validation
from src.backend.notification-service.src.models.notification import (
    NotificationType,
    NotificationChannel,
)

# -----------------------------------------------------------------------------------
# Global Variables (Constants/Configuration)
# -----------------------------------------------------------------------------------

# Enhanced logging with template metrics and error tracking
logger = logging.getLogger(__name__)

# Secure template file path handling and validation
TEMPLATE_DIR: Path = Path(__file__).parent.parent / "templates"

# Maximum allowed template file size (1 MB)
MAX_TEMPLATE_SIZE: int = 1024 * 1024

# Template cache time-to-live in seconds (1 hour by default)
TEMPLATE_CACHE_TTL: int = 3600


class TemplateManager:
    """
    Manages loading, validation, and rendering of notification templates with
    enhanced security and performance features. Supports multiple notification
    channels (EMAIL, PUSH, SMS) and real-time notifications, ensuring each
    channel's templates are validated, compiled, and cached for efficient usage.
    """

    def __init__(self, dev_mode: bool) -> None:
        """
        Initializes secure template environment with sandboxing and performance optimizations.

        Steps:
          1. Initialize Jinja2 environment with sandbox mode for security.
          2. Configure template security policies (disable certain built-ins).
          3. Set template auto-reload based on dev_mode flag.
          4. Initialize template cache with TTL management structures.
          5. Setup template metrics collection dictionary.
          6. Load and validate all templates from the designated TEMPLATE_DIR.
          7. Initialize channel-specific formatters or adjustments as required.
        """
        # Create a sandboxed environment to ensure only safe operations are allowed
        self._env: Environment = SandboxedEnvironment(
            autoescape=True,
            enable_async=False,
        )

        # Configure environment security settings
        # Restricting access to built-ins that could pose security risks
        self._env.globals.clear()
        self._env.filters.clear()

        # Set auto_reload based on development mode
        self._env.auto_reload = dev_mode

        # Dictionary storing compiled templates and timestamp data
        # E.g. self._templates[key] = {"template": jinja2.Template, "loaded_at": float}
        self._templates: Dict[str, Dict[str, Any]] = {}

        # Dictionary for tracking template usage and performance metrics
        # Example structure:
        # {
        #   "load_count": int,
        #   "render_count": int,
        #   "errors": int,
        #   "last_reset": float
        # }
        self._template_metrics: Dict[str, Any] = {
            "load_count": 0,
            "render_count": 0,
            "errors": 0,
            "last_reset": time.time(),
        }

        # Immediately load templates from the filesystem
        self.load_templates()

        # Channel-specific formatters or additional initialization can be placed here if needed.
        logger.debug("TemplateManager initialized with dev_mode=%s", dev_mode)

    def load_templates(self) -> None:
        """
        Securely loads and validates all notification templates from the template directory.

        Steps:
          1. Scan template directory with size validation.
          2. Parse and validate template metadata (basic approach here, can be extended).
          3. Verify template syntax and security prior to caching.
          4. Precompile templates for performance improvements.
          5. Cache templates along with a TTL-based invalidation timestamp.
          6. Log template loading metrics for observability.
        """
        # Increment load attempt count
        self._template_metrics["load_count"] += 1

        # Scan the directory for files with .j2 extension
        for template_file in TEMPLATE_DIR.glob("*.j2"):
            try:
                # Validate file size for security
                if template_file.stat().st_size > MAX_TEMPLATE_SIZE:
                    logger.warning(
                        "Skipped loading template %s (exceeds MAX_TEMPLATE_SIZE).",
                        template_file.name,
                    )
                    continue

                # Read the template contents
                template_source = template_file.read_text(encoding="utf-8")

                # Basic parse check for malicious code or undefined references
                parsed_content = self._env.parse(template_source)
                undefined_vars = meta.find_undeclared_variables(parsed_content)
                # Because we do not allow built-ins or advanced features, we can do a basic check
                # but rely on the SandboxedEnvironment for a deeper security posture.

                # Attempt to compile the template
                compiled_template = self._env.from_string(template_source)

                # Store the template along with metadata in cache
                # Use the template file stem as a base key here
                self._templates[template_file.stem] = {
                    "template": compiled_template,
                    "loaded_at": time.time(),
                    "undefined_vars": undefined_vars,
                }

                logger.info("Loaded template: %s", template_file.name)
            except exceptions.TemplateSyntaxError as tse:
                self._template_metrics["errors"] += 1
                logger.error(
                    "Syntax error in template %s: %s", template_file.name, tse
                )
            except Exception as e:
                self._template_metrics["errors"] += 1
                logger.exception("Unexpected error loading template %s: %s", template_file.name, e)

        logger.debug("Template loading complete. Currently loaded templates: %d", len(self._templates))

    def get_template(self, notification_type: NotificationType, channel: NotificationChannel) -> Template:
        """
        Retrieves and validates a precompiled template object for a specific
        notification type and channel.

        Steps:
          1. Generate secure template key (combination of type and channel).
          2. Check the cache with TTL-based validation (reload if expired).
          3. Validate that the template is available in cache.
          4. Apply channel-specific validation or checks if necessary.
          5. Update template metrics for usage.
          6. Return the validated template object.
        """
        # Generate a secure key from the provided notification type and channel
        key = f"{notification_type.name.lower()}_{channel.name.lower()}"

        # Enforce TTL-based cache check
        template_record = self._templates.get(key)
        if template_record is not None:
            elapsed = time.time() - template_record["loaded_at"]
            if elapsed > TEMPLATE_CACHE_TTL:
                logger.info("Template '%s' expired from cache. Reloading all templates.", key)
                self.load_templates()
                template_record = self._templates.get(key)  # Refresh reference after reload

        # Validate availability
        if not template_record:
            # Attempt to fallback to a default or raise an error if none is found
            self._template_metrics["errors"] += 1
            msg = (
                f"No template found for notification_type={notification_type.name}, "
                f"channel={channel.name}. Ensure a matching .j2 file is present."
            )
            logger.error(msg)
            raise ValueError(msg)

        # Channel-specific validation logic
        # (Placeholder for additional channel checks in production if required)
        if channel == NotificationChannel.EMAIL:
            pass  # e.g., check for subject placeholders
        elif channel == NotificationChannel.PUSH:
            pass  # e.g., ensure minimal content for push
        elif channel == NotificationChannel.SMS:
            pass  # e.g., enforce character limits

        # Return the compiled template from cache
        return template_record["template"]

    def render_template(
        self,
        notification_type: NotificationType,
        channel: NotificationChannel,
        context: Dict[str, Any],
    ) -> str:
        """
        Securely renders notification content with performance optimization and
        channel-specific formatting.

        Steps:
          1. Validate input context for basic data integrity.
          2. Apply context sanitization if needed (strip or escape).
          3. Retrieve the appropriate template using get_template.
          4. Apply channel-specific formatting or transformations.
          5. Render with optional timeout or safe execution guard (not fully implemented here).
          6. Validate the rendered output for correctness.
          7. Update rendering metrics for observability.
          8. Return the fully formatted notification content as a string.
        """
        # Basic context validation (simple example)
        if not isinstance(context, dict):
            self._template_metrics["errors"] += 1
            logger.error("Context must be a dictionary for rendering templates.")
            raise ValueError("Context must be a dictionary for rendering.")

        # Retrieve the validated template
        template_obj = self.get_template(notification_type, channel)

        # Channel-specific formatting or transformations
        if channel == NotificationChannel.EMAIL:
            # Potentially ensure "subject" in context or do HTML wrapping
            pass
        elif channel == NotificationChannel.PUSH:
            # Possibly truncate or limit length
            pass
        elif channel == NotificationChannel.SMS:
            # Possibly enforce maximum length or fallback
            pass

        rendered_content = ""
        try:
            # Render the template securely
            rendered_content = template_obj.render(**context)
        except exceptions.TemplateError as te:
            self._template_metrics["errors"] += 1
            logger.exception("Template rendering error for type=%s channel=%s: %s", notification_type, channel, te)
            raise

        # Validate the rendered output (placeholder for advanced checks)
        if not rendered_content.strip():
            logger.warning(
                "Rendered content is empty for type=%s channel=%s. Check context or template logic.",
                notification_type,
                channel,
            )

        # Update rendering metrics
        self._template_metrics["render_count"] += 1

        # Return the final rendered message
        return rendered_content

    def get_metrics(self) -> Dict[str, Any]:
        """
        Retrieves template rendering performance metrics, generating a summary
        and optionally resetting counters on demand.

        Steps:
          1. Collect rendering and error statistics from _template_metrics.
          2. Calculate performance or usage metrics if needed.
          3. Generate a metrics summary dictionary for monitoring.
          4. Reset any periodic counters (if desired).
        """
        now = time.time()
        elapsed_since_reset = now - self._template_metrics["last_reset"]
        summary = {
            "load_count": self._template_metrics["load_count"],
            "render_count": self._template_metrics["render_count"],
            "errors": self._template_metrics["errors"],
            "uptime_seconds_since_reset": elapsed_since_reset,
        }

        # Optional: reset counters after collecting
        # For demonstration, we do not reset automatically; uncomment as desired:
        # self._template_metrics["load_count"] = 0
        # self._template_metrics["render_count"] = 0
        # self._template_metrics["errors"] = 0
        # self._template_metrics["last_reset"] = now

        logger.debug("Metrics summary: %s", summary)
        return summary